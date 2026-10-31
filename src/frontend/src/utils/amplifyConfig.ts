import { Amplify } from 'aws-amplify';

export const getAppConfig = (key: string): string => {
    // 1. Runtime config injected via /config.js from container env
    if (typeof window !== 'undefined' && (window as any).__APP_CONFIG__?.[key]) {
        return (window as any).__APP_CONFIG__[key];
    }
    // 2. Build-time Vite env fallback
    return (import.meta.env as any)[key] || '';
};

const cognitoConfig = {
    Auth: {
        Cognito: {
            userPoolId: getAppConfig('VITE_COGNITO_USER_POOL_ID'),
            userPoolClientId: getAppConfig('VITE_COGNITO_CLIENT_ID'),
            loginWith: {
                email: true,
            },
            signUpVerificationMethod: 'code' as const,
            userAttributes: {
                email: { required: true },
                name: { required: true },
            },
        },
    },
};

export const configureAmplify = () => {
    Amplify.configure(cognitoConfig);
};

export default cognitoConfig;
