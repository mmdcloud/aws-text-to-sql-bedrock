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

    const login = async (email: string, password: string) => {
        const result = await signIn({ username: email, password });
        if (result.isSignedIn) {
            await loadUser();
        }
    };

    const logout = async () => {
        await signOut();
        setUser(null);
    };

    const register = async (name: string, email: string, password: string) => {
        await signUp({
            username: email,
            password,
            options: {
                userAttributes: { email, name },
            },
        });
    };

    const confirmRegistration = async (email: string, code: string) => {
        await confirmSignUp({ username: email, confirmationCode: code });
    };

    const resendCode = async (email: string) => {
        await resendSignUpCode({ username: email });
    };

    const forgotPassword = async (email: string) => {
        await resetPassword({ username: email });
    };

    const resetForgotPassword = async (email: string, code: string, newPassword: string) => {
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

// ─── Hook ────────────────────────────────────────────────────────────────────────
export const useAuth = (): AuthContextType => {
    const ctx = useContext(AuthContext);
    if (!ctx) throw new Error('useAuth must be used within <AuthProvider>');
    return ctx;
};

export default AuthContext;
