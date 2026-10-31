import axios from 'axios';
import { getAppConfig } from '../utils/amplifyConfig';

const configuredApiUrl = getAppConfig('VITE_API_BASE_URL');
const API_BASE_URL =
    configuredApiUrl !== ''
        ? configuredApiUrl
        : (import.meta.env.PROD ? '' : 'http://localhost:8000');

const axiosClient = axios.create({
    baseURL: API_BASE_URL,
    headers: {
        'Content-Type': 'application/json',
    },
    timeout: 30000,
});

// Request interceptor — attach JWT token from Cognito session
axiosClient.interceptors.request.use(
    async (config) => {
        try {
            const { fetchAuthSession } = await import('aws-amplify/auth');
            const session = await fetchAuthSession();
            const token = session.tokens?.idToken?.toString();
            if (token) {
                config.headers.Authorization = `Bearer ${token}`;
            }
        } catch {
            // Not authenticated — let the request through without a token
        }
        return config;
    },
    (error) => Promise.reject(error)
);

// Response interceptor — normalize errors
axiosClient.interceptors.response.use(
    (response) => response,
    (error) => {
        const message =
            error.response?.data?.message ||
            error.response?.data?.error ||
            error.message ||
            'An unexpected error occurred';
        return Promise.reject({ message, status: error.response?.status });
    }
);

export default axiosClient;
