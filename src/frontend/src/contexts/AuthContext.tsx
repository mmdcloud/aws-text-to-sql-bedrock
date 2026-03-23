import React, {
    createContext,
    useContext,
    useState,
    useEffect,
    useCallback,
    type ReactNode,
} from 'react';
import {
    signIn,
    signOut,
    signUp,
    confirmSignUp,
    getCurrentUser,
    fetchUserAttributes,
    resetPassword,
    confirmResetPassword,
    resendSignUpCode,
} from 'aws-amplify/auth';

import {
    CognitoIdentityProviderClient,
    InitiateAuthCommand,
    SignUpCommand,
    ConfirmSignUpCommand,
    ForgotPasswordCommand,
    ConfirmForgotPasswordCommand,
    AuthFlowType,
} from "@aws-sdk/client-cognito-identity-provider";
import type { User } from '../types';

// ─── Context Shape ──────────────────────────────────────────────────────────────
interface AuthContextType {
    user: User | null;
    isAuthenticated: boolean;
    isLoading: boolean;
    login: (email: string, password: string) => Promise<void>;
    logout: () => Promise<void>;
    register: (name: string, email: string, password: string) => Promise<void>;
    confirmRegistration: (email: string, code: string) => Promise<void>;
    resendCode: (email: string) => Promise<void>;
    forgotPassword: (email: string) => Promise<void>;
    resetForgotPassword: (email: string, code: string, newPassword: string) => Promise<void>;
}

interface CognitoConfig {
    region: string;
    clientId: string;
    userPoolId?: string; // optional – only needed for admin flows
}

function createClient(config: CognitoConfig): CognitoIdentityProviderClient {
    return new CognitoIdentityProviderClient({ region: config.region });
}

// ---------------------------------------------------------------------------
// Return types
// ---------------------------------------------------------------------------

export interface AuthResult {
    accessToken: string;
    idToken: string;
    refreshToken: string;
    expiresIn: number;
    tokenType: string;
}

export interface AuthResponse {
    success: boolean;
    data?: AuthResult;
    error?: string;
}

export interface SignUpResponse {
    success: boolean;
    userSub?: string;          // UUID assigned by Cognito
    confirmed?: boolean;       // true if auto-confirmed
    error?: string;
}

export interface ConfirmSignUpResponse {
    success: boolean;
    error?: string;
}

export interface ForgotPasswordResponse {
    success: boolean;
    deliveryMedium?: string;   // "EMAIL" | "SMS"
    destination?: string;      // masked destination, e.g. "j***@example.com"
    error?: string;
}

export interface ResetPasswordResponse {
    success: boolean;
    error?: string;
}

// ─── Context ────────────────────────────────────────────────────────────────────
const AuthContext = createContext<AuthContextType | null>(null);

// ─── Provider ───────────────────────────────────────────────────────────────────
export const AuthProvider = ({ children }: { children: ReactNode }) => {
    const [user, setUser] = useState<User | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    const loadUser = useCallback(async () => {
        try {
            const currentUser = await getCurrentUser();
            const attrs = await fetchUserAttributes();
            setUser({
                sub: currentUser.userId,
                email: attrs.email || '',
                name: attrs.name || attrs.given_name || '',
                given_name: attrs.given_name,
                family_name: attrs.family_name,
            });
        } catch {
            setUser(null);
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => {
        loadUser();
    }, [loadUser]);

    const login = async (email: string, password: string,config: CognitoConfig,) => {
        try {
            const client = createClient(config);
            const command = new InitiateAuthCommand({
                AuthFlow: AuthFlowType.USER_PASSWORD_AUTH,
                ClientId: config.clientId,
                AuthParameters: {
                    USERNAME: email,
                    PASSWORD: password,
                },
            });

            const response = await client.send(command);
            const result = response.AuthenticationResult;

            if (!result?.AccessToken || !result.IdToken || !result.RefreshToken) {
                return { success: false, error: "Incomplete authentication result from Cognito." };
            }

            return {
                success: true,
                data: {
                    accessToken: result.AccessToken,
                    idToken: result.IdToken,
                    refreshToken: result.RefreshToken,
                    expiresIn: result.ExpiresIn ?? 3600,
                    tokenType: result.TokenType ?? "Bearer",
                },
            };
        }
        catch (err: unknown) {
            return { success: false, error: getErrorMessage(err) };
        }
        const result = await signIn({ username: email, password });
        if (result.isSignedIn) {
            await loadUser();
        }
    };

    const logout = async () => {
        await signOut();
        setUser(null);
    };

    const register = async (name: string, email: string, password: string,config: CognitoConfig,extraAttrs: Record<string, string> = {}) => {

        const client = createClient(config);

        const userAttributes = [
            { Name: "email", Value: email },
            ...Object.entries(extraAttrs).map(([Name, Value]) => ({ Name, Value })),
        ];

        try {
            const command = new SignUpCommand({
                ClientId: config.clientId,
                Username: email,
                Password: password,
                UserAttributes: userAttributes,
            });

            const response = await client.send(command);

            return {
                success: true,
                userSub: response.UserSub,
                confirmed: response.UserConfirmed ?? false,
            };
        } catch (err: unknown) {
            return { success: false, error: getErrorMessage(err) };
        }
        await signUp({
            username: email,
            password,
            options: {
                userAttributes: { email, name },
            },
        });
    };

    const confirmRegistration = async (email: string, code: string,config: CognitoConfig,) => {
        const client = createClient(config);

        try {
            const command = new ConfirmSignUpCommand({
                ClientId: config.clientId,
                Username: email,
                ConfirmationCode: code,
            });

            await client.send(command);

            return { success: true };
        } catch (err: unknown) {
            return { success: false, error: getErrorMessage(err) };
        }
        await confirmSignUp({ username: email, confirmationCode: code });
    };

    const resendCode = async (email: string) => {
        await resendSignUpCode({ username: email });
    };

    const forgotPassword = async (email: string,config: CognitoConfig,) => {
        const client = createClient(config);

        try {
            const command = new ForgotPasswordCommand({
                ClientId: config.clientId,
                Username: email,
            });

            const response = await client.send(command);
            const delivery = response.CodeDeliveryDetails;

            return {
                success: true,
                deliveryMedium: delivery?.DeliveryMedium,
                destination: delivery?.Destination,
            };
        } catch (err: unknown) {
            return { success: false, error: getErrorMessage(err) };
        }
        await resetPassword({ username: email });
    };

    const resetForgotPassword = async (email: string, code: string, newPassword: string,config: CognitoConfig,) => {
        const client = createClient(config);

        try {
            const command = new ConfirmForgotPasswordCommand({
                ClientId: config.clientId,
                Username: email,
                ConfirmationCode: code,
                Password: newPassword,
            });

            await client.send(command);

            return { success: true };
        } catch (err: unknown) {
            return { success: false, error: getErrorMessage(err) };
        }
        await confirmResetPassword({ username: email, confirmationCode: code, newPassword });
    };

    return (
        <AuthContext.Provider
            value={{
                user,
                isAuthenticated: !!user,
                isLoading,
                login,
                logout,
                register,
                confirmRegistration,
                resendCode,
                forgotPassword,
                resetForgotPassword,
            }}
        >
            {children}
        </AuthContext.Provider>
    );
};

function getErrorMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  return "An unknown error occurred.";
}

// ─── Hook ────────────────────────────────────────────────────────────────────────
export const useAuth = (): AuthContextType => {
    const ctx = useContext(AuthContext);
    if (!ctx) throw new Error('useAuth must be used within <AuthProvider>');
    return ctx;
};

export default AuthContext;
