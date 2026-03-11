import { Amplify } from 'aws-amplify';

const cognitoConfig = {
    Auth: {
        Cognito: {
            userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID as string,
            userPoolClientId: import.meta.env.VITE_COGNITO_CLIENT_ID as string,
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
