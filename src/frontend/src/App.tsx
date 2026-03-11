import React from 'react';
import { Toaster } from 'react-hot-toast';
import { AuthProvider } from './contexts/AuthContext';
import AppRouter from './router/AppRouter';
import './styles/globals.css';
import './styles/animations.css';

const App = () => {
    return (
        <AuthProvider>
            <AppRouter />
            <Toaster
                position="top-right"
                toastOptions={{
                    duration: 4000,
                    style: {
                        background: 'var(--bg-card)',
                        color: 'var(--text-primary)',
                        border: '1px solid var(--border-default)',
                        borderRadius: '10px',
                        fontFamily: 'var(--font-sans)',
                        fontSize: '0.9rem',
                        boxShadow: 'var(--shadow-lg)',
                    },
                    success: {
                        iconTheme: { primary: '#10b981', secondary: '#fff' },
                    },
                    error: {
                        iconTheme: { primary: '#ef4444', secondary: '#fff' },
                    },
                }}
            />
        </AuthProvider>
    );
};

export default App;
