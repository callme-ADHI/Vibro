import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Navigate } from 'react-router-dom';

const Admins = () => {
  const { isSuperAdmin } = useAuth();
  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [newAdminEmail, setNewAdminEmail] = useState('');
  const [message, setMessage] = useState(null);
  const [errorMsg, setErrorMsg] = useState(null);

  if (!isSuperAdmin) {
    return <Navigate to="/" replace />;
  }

  useEffect(() => {
    fetchAdmins();
  }, []);

  const fetchAdmins = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .in('role', ['admin', 'super_admin'])
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAdmins(data);
      setErrorMsg(null);
    } catch (error) {
      console.error('Error fetching admins:', error);
      setErrorMsg(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDemote = async (id, currentRole) => {
    if (currentRole === 'super_admin') {
      alert("Cannot demote a super admin from this dashboard.");
      return;
    }
    if (!window.confirm("Are you sure you want to demote this admin to a regular user?")) return;

    try {
      const { error } = await supabase.from('profiles').update({ role: 'user' }).eq('id', id);
      if (error) throw error;
      fetchAdmins();
    } catch (error) {
      alert('Failed to demote admin: ' + error.message);
    }
  };

  const handlePromote = async (e) => {
    e.preventDefault();
    setMessage(null);
    try {
      // 1. Get the user by email
      const { data: users, error: searchError } = await supabase
        .from('profiles')
        .select('id, role')
        .eq('email', newAdminEmail);
        
      if (searchError) throw searchError;
      if (!users || users.length === 0) {
        throw new Error("No user found with this email. They must sign up first.");
      }
      
      const user = users[0];
      if (user.role === 'admin' || user.role === 'super_admin') {
        throw new Error("User is already an admin.");
      }

      // 2. Update their role
      const { error: updateError } = await supabase
        .from('profiles')
        .update({ role: 'admin' })
        .eq('id', user.id);

      if (updateError) throw updateError;
      
      setMessage({ type: 'success', text: 'Successfully promoted user to Admin.' });
      setNewAdminEmail('');
      fetchAdmins();
    } catch (error) {
      setMessage({ type: 'error', text: error.message });
    }
  };

  if (loading) return <div>Loading admins...</div>;

  return (
    <div className="animate-fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2>Admin Management</h2>
      </div>

      {errorMsg && (
        <div style={{ padding: '1rem', background: 'rgba(224, 62, 82, 0.1)', color: 'var(--color-danger)', borderRadius: 'var(--radius-sm)', marginBottom: '1rem' }}>
          Error loading admins: {errorMsg}
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: '1.5rem', alignItems: 'start' }}>
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {admins.map((admin) => (
                  <tr key={admin.id}>
                    <td>{admin.email}</td>
                    <td>
                      <span className={`badge ${admin.role === 'super_admin' ? 'badge-primary' : 'badge-success'}`}>
                        {admin.role}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${admin.is_active ? 'badge-success' : 'badge-danger'}`}>
                        {admin.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td>
                      {admin.role !== 'super_admin' && (
                        <button className="btn btn-secondary" style={{ padding: '0.25rem 0.5rem', fontSize: '0.75rem' }} onClick={() => handleDemote(admin.id, admin.role)}>
                          Revoke Access
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card">
          <h3 style={{ fontSize: '1.1rem', marginBottom: '1rem' }}>Promote to Admin</h3>
          {message && (
            <div style={{ 
              marginBottom: '1rem', 
              padding: '0.75rem', 
              borderRadius: 'var(--radius-sm)',
              fontSize: '0.875rem',
              background: message.type === 'error' ? 'rgba(224, 62, 82, 0.1)' : 'rgba(28, 196, 130, 0.1)',
              color: message.type === 'error' ? 'var(--color-danger)' : 'var(--color-success)'
            }}>
              {message.text}
            </div>
          )}
          <form onSubmit={handlePromote} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.875rem' }}>User Email</label>
              <input 
                type="email" 
                value={newAdminEmail}
                onChange={(e) => setNewAdminEmail(e.target.value)}
                placeholder="user@example.com"
                required
              />
            </div>
            <button type="submit" className="btn btn-primary">Grant Admin Role</button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Admins;
