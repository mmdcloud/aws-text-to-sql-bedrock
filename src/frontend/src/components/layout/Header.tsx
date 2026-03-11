import React from 'react';
import { useLocation } from 'react-router-dom';
import { Bell, Settings } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import './Header.css';

interface HeaderProps {
    sidebarCollapsed: boolean;
}

const pageTitles: Record<string, { title: string; subtitle: string }> = {
    '/dashboard': {
        title: 'Text to SQL',
        subtitle: 'Query your database with natural language',
    },
    '/knowledge-base': {
        title: 'Knowledge Base',
        subtitle: 'Manage your document knowledge base',
    },
};

const Header = ({ sidebarCollapsed: _ }: HeaderProps) => {
    const location = useLocation();
    const { user } = useAuth();
    const page = pageTitles[location.pathname] || { title: 'Dashboard', subtitle: '' };

    return (
        <header className="header">
            <div className="header-left">
                <h1 className="header-title">{page.title}</h1>
                {page.subtitle && <p className="header-subtitle">{page.subtitle}</p>}
            </div>
            <div className="header-right">
                <button className="btn btn-ghost btn-icon header-action" aria-label="Notifications">
                    <Bell size={18} />
                </button>
                <button className="btn btn-ghost btn-icon header-action" aria-label="Settings">
                    <Settings size={18} />
                </button>
                <div className="header-avatar">
                    {user?.name?.[0]?.toUpperCase() || user?.email?.[0]?.toUpperCase() || 'U'}
                </div>
            </div>
        </header>
    );
};

export default Header;
