/// <reference types="vite/client" />

interface ImportMetaEnv {
    readonly VITE_AWS_REGION?: string;
    readonly VITE_COGNITO_USER_POOL_ID?: string;
    readonly VITE_COGNITO_CLIENT_ID?: string;
    readonly VITE_API_BASE_URL?: string;
}

interface ImportMeta {
    readonly env: ImportMetaEnv;
}

interface Window {
    __APP_CONFIG__?: Record<string, string>;
}


