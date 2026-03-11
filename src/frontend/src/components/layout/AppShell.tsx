import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';
import './AppShell.css';

const AppShell = () => {
    const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

    return (
        <div className={`app-shell ${sidebarCollapsed ? 'sidebar-collapsed' : ''}`}>
            <Sidebar collapsed={sidebarCollapsed} onToggle={() => setSidebarCollapsed((v) => !v)} />
            <div className="app-main">
                <Header sidebarCollapsed={sidebarCollapsed} />
                <main className="app-content page-enter">
                    <Outlet />
                </main>
            </div>
        </div>
    );
};

export default AppShell;
