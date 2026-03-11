import React, { useState, useRef } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { Database, AlertCircle, CheckCircle, RefreshCw } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import './AuthPages.css';

const ConfirmSignupPage = () => {
    const [code, setCode] = useState(['', '', '', '', '', '']);
    const [isLoading, setIsLoading] = useState(false);
    const [resendLoading, setResendLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const inputRefs = useRef<HTMLInputElement[]>([]);

    const { confirmRegistration, resendCode } = useAuth();
    const navigate = useNavigate();
    const location = useLocation();
    const email = (location.state as { email?: string })?.email || '';

    const handleCodeChange = (index: number, value: string) => {
        if (!/^\d?$/.test(value)) return;
        const newCode = [...code];
        newCode[index] = value;
        setCode(newCode);
        if (value && index < 5) {
            inputRefs.current[index + 1]?.focus();
        }
    };

    const handleKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
        if (e.key === 'Backspace' && !code[index] && index > 0) {
            inputRefs.current[index - 1]?.focus();
        }
        if (e.key === 'ArrowLeft' && index > 0) inputRefs.current[index - 1]?.focus();
        if (e.key === 'ArrowRight' && index < 5) inputRefs.current[index + 1]?.focus();
    };

    const handlePaste = (e: React.ClipboardEvent) => {
        const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
        if (pasted.length === 6) {
            setCode(pasted.split(''));
            inputRefs.current[5]?.focus();
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        const fullCode = code.join('');
        if (fullCode.length !== 6) { setError('Please enter the 6-digit code.'); return; }
        setError(''); setIsLoading(true);
        try {
            await confirmRegistration(email, fullCode);
            navigate('/login', { state: { confirmed: true } });
        } catch (err: unknown) {
            const e = err as { message?: string };
            setError(e?.message || 'Invalid confirmation code.');
        } finally {
            setIsLoading(false);
        }
    };

    const handleResend = async () => {
        setResendLoading(true); setError(''); setSuccess('');
        try {
            await resendCode(email);
            setSuccess('A new code has been sent to your email.');
        } catch (err: unknown) {
            const e = err as { message?: string };
            setError(e?.message || 'Failed to resend code.');
        } finally {
            setResendLoading(false);
        }
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
                    <h1 className="auth-title">Verify your email</h1>
                    <p className="auth-subtitle">We sent a 6-digit code to <strong>{email || 'your email'}</strong></p>
                </div>

                {error && <div className="auth-error animate-fade-in"><AlertCircle size={16} /><span>{error}</span></div>}
                {success && <div className="auth-success animate-fade-in"><CheckCircle size={16} /><span>{success}</span></div>}

                <form onSubmit={handleSubmit} className="auth-form">
                    <div className="otp-container" onPaste={handlePaste}>
                        {code.map((digit, i) => (
                            <input
                                key={i}
                                ref={(el) => { if (el) inputRefs.current[i] = el; }}
                                type="text"
                                inputMode="numeric"
                                maxLength={1}
                                value={digit}
                                onChange={(e) => handleCodeChange(i, e.target.value)}
                                onKeyDown={(e) => handleKeyDown(i, e)}
                                className="otp-input"
                                aria-label={`Digit ${i + 1}`}
                            />
                        ))}
                    </div>

                    <button type="submit" className="btn btn-primary btn-lg w-full auth-submit" disabled={isLoading}>
                        {isLoading ? <><span className="auth-spinner" />Verifying...</> : 'Verify Email'}
                    </button>
                </form>

                <div className="auth-footer">
                    <span>Didn't receive the code?</span>
                    <button onClick={handleResend} disabled={resendLoading} className="auth-link" style={{ background: 'none', border: 'none' }}>
                        {resendLoading ? <><RefreshCw size={13} className="animate-spin" /> Sending...</> : 'Resend code'}
                    </button>
                </div>
                <div className="auth-footer">
                    <Link to="/login" className="auth-link-small">← Back to login</Link>
                </div>
            </div>
        </div>
    );
};

export default ConfirmSignupPage;
