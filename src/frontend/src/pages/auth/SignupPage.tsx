import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Mail, Lock, Eye, EyeOff, User, Database, AlertCircle, CheckCircle } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import './AuthPages.css';

const SignupPage = () => {
    const [formData, setFormData] = useState({
        name: '', email: '', password: '', confirmPassword: '',
    });
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirm, setShowConfirm] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState('');

    const { register } = useAuth();
    const navigate = useNavigate();

    const passwordStrength = (pwd: string): { score: number; label: string; color: string } => {
        let score = 0;
        if (pwd.length >= 8) score++;
        if (/[A-Z]/.test(pwd)) score++;
        if (/[0-9]/.test(pwd)) score++;
        if (/[^A-Za-z0-9]/.test(pwd)) score++;
        const map = [
            { score: 0, label: '', color: '' },
            { score: 1, label: 'Weak', color: '#ef4444' },
            { score: 2, label: 'Fair', color: '#f59e0b' },
            { score: 3, label: 'Good', color: '#06b6d4' },
            { score: 4, label: 'Strong', color: '#10b981' },
        ];
        return map[score] || map[0];
    };

    const strength = passwordStrength(formData.password);

    const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        setFormData((d) => ({ ...d, [e.target.name]: e.target.value }));
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        if (formData.password !== formData.confirmPassword) {
            setError('Passwords do not match.');
            return;
        }
        if (formData.password.length < 8) {
            setError('Password must be at least 8 characters.');
            return;
        }
        setIsLoading(true);
        try {
            await register(formData.name, formData.email, formData.password);
            navigate('/confirm-signup', { state: { email: formData.email } });
        } catch (err: unknown) {
            const e = err as { message?: string };
            setError(e?.message || 'Failed to create account.');
        } finally {
            setIsLoading(false);
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
                    <h1 className="auth-title">Create account</h1>
                    <p className="auth-subtitle">Join us and start querying with natural language</p>
                </div>

                {error && (
                    <div className="auth-error animate-fade-in">
                        <AlertCircle size={16} /><span>{error}</span>
                    </div>
                )}

                <form onSubmit={handleSubmit} className="auth-form">
                    <div className="form-group">
                        <label className="form-label" htmlFor="name">Full Name</label>
                        <div className="input-wrapper">
                            <User size={16} className="input-icon" />
                            <input id="name" name="name" type="text" className="input-with-icon"
                                placeholder="John Doe" value={formData.name} onChange={handleChange} required />
                        </div>
                    </div>

                    <div className="form-group">
                        <label className="form-label" htmlFor="email">Email Address</label>
                        <div className="input-wrapper">
                            <Mail size={16} className="input-icon" />
                            <input id="email" name="email" type="email" className="input-with-icon"
                                placeholder="you@company.com" value={formData.email} onChange={handleChange} required />
                        </div>
                    </div>

                    <div className="form-group">
                        <label className="form-label" htmlFor="password">Password</label>
                        <div className="input-wrapper">
                            <Lock size={16} className="input-icon" />
                            <input id="password" name="password" type={showPassword ? 'text' : 'password'}
                                className="input-with-icon" placeholder="Min. 8 characters"
                                value={formData.password} onChange={handleChange} required />
                            <button type="button" className="input-action" onClick={() => setShowPassword(v => !v)}>
                                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                            </button>
                        </div>
                        {formData.password && (
                            <div className="password-strength">
                                <div className="password-strength-bar">
                                    {[1, 2, 3, 4].map(i => (
                                        <div key={i} className="password-strength-segment"
                                            style={{ background: i <= strength.score ? strength.color : 'var(--border-subtle)' }} />
                                    ))}
                                </div>
                                <span className="password-strength-label" style={{ color: strength.color }}>
                                    {strength.label}
                                </span>
                            </div>
                        )}
                    </div>

                    <div className="form-group">
                        <label className="form-label" htmlFor="confirmPassword">Confirm Password</label>
                        <div className="input-wrapper">
                            <Lock size={16} className="input-icon" />
                            <input id="confirmPassword" name="confirmPassword"
                                type={showConfirm ? 'text' : 'password'} className="input-with-icon"
                                placeholder="Repeat password" value={formData.confirmPassword} onChange={handleChange} required />
                            <button type="button" className="input-action" onClick={() => setShowConfirm(v => !v)}>
                                {showConfirm ? <EyeOff size={16} /> : <Eye size={16} />}
                            </button>
                        </div>
                        {formData.confirmPassword && (
                            <div style={{
                                display: 'flex', alignItems: 'center', gap: 4, fontSize: '0.8125rem',
                                color: formData.password === formData.confirmPassword ? 'var(--color-success)' : 'var(--color-error)'
                            }}>
                                <CheckCircle size={13} />
                                {formData.password === formData.confirmPassword ? 'Passwords match' : 'Passwords do not match'}
                            </div>
                        )}
                    </div>

                    <button type="submit" className="btn btn-primary btn-lg w-full auth-submit" disabled={isLoading}>
                        {isLoading ? <><span className="auth-spinner" />Creating account...</> : 'Create Account'}
                    </button>
                </form>

                <div className="auth-footer">
                    <span>Already have an account?</span>
                    <Link to="/login" className="auth-link">Sign in</Link>
                </div>
            </div>
        </div>
    );
};

export default SignupPage;
