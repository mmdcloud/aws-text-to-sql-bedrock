import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
    LayoutDashboard,
    BookOpen,
    ChevronLeft,
    ChevronRight,
    Database,
    LogOut,
    User,
} from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import './Sidebar.css';

interface SidebarProps {
    collapsed: boolean;
    onToggle: () => void;
}

const navItems = [
    {
        path: '/dashboard',
        label: 'Text to SQL',
        icon: LayoutDashboard,
        description: 'Query your data',
    },
    {
        path: '/knowledge-base',
        label: 'Knowledge Base',
        icon: BookOpen,
        description: 'Manage documents',
    },
];

const Sidebar = ({ collapsed, onToggle }: SidebarProps) => {
    const { user, logout } = useAuth();
    const navigate = useNavigate();

    const handleLogout = async () => {
        await logout();
        navigate('/login');
    };

    return (
        <aside className={`sidebar ${collapsed ? 'sidebar--collapsed' : ''}`}>
            {/* Logo */}
            <div className="sidebar-logo">
                <div className="sidebar-logo-icon">
                    <Database size={22} />
                </div>
                {!collapsed && (
                    <div className="sidebar-logo-text">
                        <span className="sidebar-logo-name">TextSQL</span>
                        <span className="sidebar-logo-sub">AWS Bedrock</span>
                    </div>
                )}
                <button className="sidebar-toggle" onClick={onToggle} aria-label="Toggle sidebar">
                    {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
                </button>
            </div>

            {/* Navigation */}
            <nav className="sidebar-nav">
                {!collapsed && <span className="sidebar-nav-label">Navigation</span>}
                {navItems.map(({ path, label, icon: Icon, description }) => (
                    <NavLink
                        key={path}
                        to={path}
                        className={({ isActive }) =>
                            `sidebar-nav-item ${isActive ? 'sidebar-nav-item--active' : ''}`
                        }
                        title={collapsed ? label : undefined}
                    >
                        <span className="sidebar-nav-icon">
                            <Icon size={20} />
                        </span>
                        {!collapsed && (
                            <div className="sidebar-nav-text">
                                <span className="sidebar-nav-label-text">{label}</span>
                                <span className="sidebar-nav-desc">{description}</span>
                            </div>
                        )}
                    </NavLink>
                ))}
            </nav>

            {/* User Profile */}
            <div className="sidebar-footer">
                <div className="sidebar-user">
                    <div className="sidebar-user-avatar">
                        <User size={16} />
                    </div>
                    {!collapsed && (
                        <div className="sidebar-user-info">
                            <span className="sidebar-user-name">{user?.name || user?.email?.split('@')[0]}</span>
                            <span className="sidebar-user-email">{user?.email}</span>
                        </div>
                    )}
                </div>
                <button
                    className="sidebar-logout btn btn-ghost btn-icon"
                    onClick={handleLogout}
                    title="Logout"
                    aria-label="Logout"
                >
                    <LogOut size={18} />
                </button>
            </div>
        </aside>
    );
};

export default Sidebar;
