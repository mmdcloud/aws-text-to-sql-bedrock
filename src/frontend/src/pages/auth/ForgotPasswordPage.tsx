import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Mail, Lock, Eye, EyeOff, Database, AlertCircle, CheckCircle } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import './AuthPages.css';

const ForgotPasswordPage = () => {
    const [step, setStep] = useState<'request' | 'reset'>('request');
    const [email, setEmail] = useState('');
    const [code, setCode] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');

    const { forgotPassword, resetForgotPassword } = useAuth();
    const navigate = useNavigate();

    const handleRequest = async (e: React.FormEvent) => {
        e.preventDefault(); setError(''); setIsLoading(true);
        try {
            await forgotPassword(email);
            setStep('reset');
        } catch (err: unknown) {
            const e = err as { message?: string };
            setError(e?.message || 'Failed to send reset code.');
        } finally { setIsLoading(false); }
    };

    const handleReset = async (e: React.FormEvent) => {
        e.preventDefault(); setError(''); setIsLoading(true);
        try {
            await resetForgotPassword(email, code, newPassword);
            setSuccess('Password reset successfully!');
            setTimeout(() => navigate('/login'), 2000);
        } catch (err: unknown) {
            const e = err as { message?: string };
            setError(e?.message || 'Failed to reset password.');
        } finally { setIsLoading(false); }
    };

    return (
        <div className="auth-container">
            <div className="auth-bg-glow auth-bg-glow--1" />
            <div className="auth-bg-glow auth-bg-glow--2" />
            <div className="auth-card animate-scale-in">
                <div className="auth-brand">
                    <div className="auth-brand-icon"><Database size={26} /></div>
                    <div>
                        <h2 className="auth-brand-name">TextSQL</h2>
                        <p className="auth-brand-tagline">Powered by AWS Bedrock</p>
                    </div>
                </div>
                <div className="auth-header">
                    <h1 className="auth-title">{step === 'request' ? 'Reset password' : 'Enter new password'}</h1>
                    <p className="auth-subtitle">
                        {step === 'request'
                            ? "We'll send a reset code to your email" : `Enter the code sent to ${email}`}
                    </p>
                </div>

                {error && <div className="auth-error animate-fade-in"><AlertCircle size={16} /><span>{error}</span></div>}
                {success && <div className="auth-success animate-fade-in"><CheckCircle size={16} /><span>{success}</span></div>}

                {step === 'request' ? (
                    <form onSubmit={handleRequest} className="auth-form">
                        <div className="form-group">
                            <label className="form-label" htmlFor="email">Email Address</label>
                            <div className="input-wrapper">
                                <Mail size={16} className="input-icon" />
                                <input id="email" type="email" className="input-with-icon" placeholder="you@company.com"
                                    value={email} onChange={e => setEmail(e.target.value)} required />
                            </div>
                        </div>
                        <button type="submit" className="btn btn-primary btn-lg w-full auth-submit" disabled={isLoading}>
                            {isLoading ? <><span className="auth-spinner" />Sending...</> : 'Send Reset Code'}
                        </button>
                    </form>
                ) : (
                    <form onSubmit={handleReset} className="auth-form">
                        <div className="form-group">
                            <label className="form-label" htmlFor="code">Reset Code</label>
                            <div className="input-wrapper">
                                <input id="code" type="text" placeholder="6-digit code"
                                    value={code} onChange={e => setCode(e.target.value)} required />
                            </div>
                        </div>
                        <div className="form-group">
                            <label className="form-label" htmlFor="newPassword">New Password</label>
                            <div className="input-wrapper">
                                <Lock size={16} className="input-icon" />
                                <input id="newPassword" type={showPassword ? 'text' : 'password'}
                                    className="input-with-icon" placeholder="Min. 8 characters"
                                    value={newPassword} onChange={e => setNewPassword(e.target.value)} required />
                                <button type="button" className="input-action" onClick={() => setShowPassword(v => !v)}>
                                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                                </button>
                            </div>
                        </div>
                        <button type="submit" className="btn btn-primary btn-lg w-full auth-submit" disabled={isLoading}>
                            {isLoading ? <><span className="auth-spinner" />Resetting...</> : 'Reset Password'}
                        </button>
                    </form>
                )}

                <div className="auth-footer">
                    <Link to="/login" className="auth-link-small">← Back to login</Link>
                </div>
            </div>
        </div>
    );
};

export default ForgotPasswordPage;
