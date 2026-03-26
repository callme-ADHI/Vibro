import React from 'react';
import { Navigate, Outlet, Link, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { LayoutDashboard, Users, Database, ShieldAlert, ShieldCheck, LogOut } from 'lucide-react';

const AdminLayout = () => {
  const { user, isAdmin, isSuperAdmin, logout } = useAuth();
  const location = useLocation();

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (!isAdmin) {
    return (
      <div className="app-container" style={{ alignItems: 'center', justifyContent: 'center' }}>
        <div className="card text-center" style={{ maxWidth: 400 }}>
          <ShieldAlert size={48} color="var(--color-danger)" style={{ margin: '0 auto 1rem' }} />
          <h2>Access Denied</h2>
          <p className="mb-4 text-muted">You do not have administrative privileges to access this dashboard.</p>
          <button className="btn btn-primary" onClick={logout}>Sign Out</button>
        </div>
      </div>
    );
  }

  const navItems = [
    { name: 'Dashboard', path: '/', icon: <LayoutDashboard size={20} /> },
    { name: 'Users', path: '/users', icon: <Users size={20} /> },
    { name: 'Model Training', path: '/training', icon: <Database size={20} /> },
  ];

  if (isSuperAdmin) {
    navItems.push({ name: 'Admins', path: '/admins', icon: <ShieldCheck size={20} /> });
    navItems.push({ name: 'Feedbacks', path: '/feedbacks', icon: <ShieldAlert size={20} /> });
  }

  return (
    <div className="app-container">
      <aside className="sidebar">
        <div className="sidebar-header">
          <div style={{ width: 32, height: 32, borderRadius: 8, background: 'var(--color-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <span style={{ fontWeight: 'bold', color: 'white' }}>V</span>
          </div>
          VIBRO Admin
        </div>
        <nav className="nav-links">
          {navItems.map((item) => (
            <Link 
              key={item.path} 
              to={item.path} 
              className={`nav-item ${location.pathname === item.path ? 'active' : ''}`}
            >
              {item.icon}
              {item.name}
            </Link>
          ))}
          <div style={{ flex: 1 }} />
          <button 
            onClick={logout} 
            className="nav-item" 
            style={{ width: '100%', background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left', marginTop: 'auto' }}
          >
            <LogOut size={20} />
            Sign Out
          </button>
        </nav>
      </aside>
      
      <main className="main-content">
        <header className="topbar">
          <h2 style={{ fontSize: '1.25rem', margin: 0 }}>
            {navItems.find(item => item.path === location.pathname)?.name || 'Dashboard'}
          </h2>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <span className="badge badge-primary">{isSuperAdmin ? 'Super Admin' : 'Admin'}</span>
            <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'var(--color-surface)', border: '1px solid var(--color-border)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {user.email.charAt(0).toUpperCase()}
            </div>
          </div>
        </header>
        <div className="content-area animate-fade-in">
          <Outlet />
        </div>
      </main>
    </div>
  );
};

export default AdminLayout;
