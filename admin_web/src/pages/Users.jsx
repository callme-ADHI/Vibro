import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

const Users = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState(null);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);

      if (error) throw error;
      setUsers(data);
      setErrorMsg(null);
    } catch (error) {
      console.error('Error fetching users:', error);
      setErrorMsg(error.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div>Loading users...</div>;

  return (
    <div className="animate-fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2>User Management</h2>
        <button className="btn btn-secondary" onClick={fetchUsers}>Refresh Data</button>
      </div>

      {errorMsg && (
        <div style={{ padding: '1rem', background: 'rgba(224, 62, 82, 0.1)', color: 'var(--color-danger)', borderRadius: 'var(--radius-sm)', marginBottom: '1rem' }}>
          Error loading users: {errorMsg}
        </div>
      )}

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>Email</th>
                <th>Username</th>
                <th>Role</th>
                <th>Status</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id}>
                  <td>{user.email}</td>
                  <td style={{ color: 'var(--color-text-muted)' }}>{user.username || 'N/A'}</td>
                  <td>
                    <span className={`badge ${user.role === 'super_admin' || user.role === 'admin' ? 'badge-primary' : 'badge-success'}`}>
                      {user.role}
                    </span>
                  </td>
                  <td>
                    <span className={`badge ${user.is_active ? 'badge-success' : 'badge-danger'}`}>
                      {user.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td style={{ color: 'var(--color-text-muted)' }}>
                    {new Date(user.created_at).toLocaleDateString()}
                  </td>
                </tr>
              ))}
              {users.length === 0 && (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', padding: '2rem', color: 'var(--color-text-muted)' }}>
                    No users found
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default Users;
