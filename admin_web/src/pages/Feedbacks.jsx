import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Navigate } from 'react-router-dom';
import { Check, X } from 'lucide-react';

const Feedbacks = () => {
  const { isSuperAdmin } = useAuth();
  const [feedbacks, setFeedbacks] = useState([]);
  const [loading, setLoading] = useState(true);

  if (!isSuperAdmin) {
    return <Navigate to="/" replace />;
  }

  useEffect(() => {
    fetchFeedbacks();
  }, []);

  const fetchFeedbacks = async () => {
    try {
      const { data, error } = await supabase
        .from('app_feedbacks')
        .select(`
          *,
          profiles(email)
        `)
        .order('created_at', { ascending: false });

      if (error) {
        // Handle case where table might not exist if migration hasn't run
        if (error.code === '42P01') {
          console.warn('App feedbacks table not created yet.');
          setFeedbacks([]);
          return;
        }
        throw error;
      }
      setFeedbacks(data || []);
    } catch (error) {
      console.error('Error fetching feedbacks:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateStatus = async (id, status) => {
    try {
      const { error } = await supabase
        .from('app_feedbacks')
        .update({ status })
        .eq('id', id);
        
      if (error) throw error;
      fetchFeedbacks();
    } catch (error) {
      alert('Error updating feedback status: ' + error.message);
    }
  };

  const getStatusBadge = (status) => {
    switch(status) {
      case 'resolved': return 'badge-success';
      case 'ignored': return 'badge-danger';
      default: return 'badge-warning';
    }
  };

  if (loading) return <div>Loading feedbacks...</div>;

  return (
    <div className="animate-fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2>User Feedbacks & Complaints</h2>
        <button className="btn btn-secondary" onClick={fetchFeedbacks}>Refresh</button>
      </div>

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>User Email</th>
                <th>Message</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {feedbacks.map((fb) => (
                <tr key={fb.id}>
                  <td style={{ color: 'var(--color-text-muted)' }}>
                    {new Date(fb.created_at).toLocaleDateString()}
                  </td>
                  <td>{fb.profiles?.email || 'Unknown'}</td>
                  <td style={{ maxWidth: '300px', whiteSpace: 'pre-wrap' }}>{fb.message}</td>
                  <td>
                    <span className={`badge ${getStatusBadge(fb.status)}`}>{fb.status}</span>
                  </td>
                  <td style={{ display: 'flex', gap: '0.5rem' }}>
                    {fb.status === 'pending' && (
                      <>
                        <button className="btn btn-secondary" style={{ padding: '0.25rem', color: 'var(--color-success)' }} onClick={() => updateStatus(fb.id, 'resolved')} title="Resolve">
                          <Check size={18} />
                        </button>
                        <button className="btn btn-secondary" style={{ padding: '0.25rem', color: 'var(--color-danger)' }} onClick={() => updateStatus(fb.id, 'ignored')} title="Ignore">
                          <X size={18} />
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
              {feedbacks.length === 0 && (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', padding: '2rem', color: 'var(--color-text-muted)' }}>
                    No feedbacks or complaints found.
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

export default Feedbacks;
