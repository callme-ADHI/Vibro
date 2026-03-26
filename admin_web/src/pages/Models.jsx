import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

const Models = () => {
  const [queue, setQueue] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchQueue();
  }, []);

  const fetchQueue = async () => {
    try {
      const { data, error } = await supabase
        .from('training_queue')
        .select(`
          *,
          audio_submissions(clip_count, storage_path, trained_names(name_label, profiles(email)))
        `)
        .order('queued_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      setQueue(data);
    } catch (error) {
      console.error('Error fetching queue:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadge = (status) => {
    switch(status) {
      case 'completed': return 'badge-success';
      case 'failed': return 'badge-danger';
      case 'processing': return 'badge-warning';
      default: return 'badge-primary';
    }
  };

  if (loading) return <div>Loading model training queue...</div>;

  return (
    <div className="animate-fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2>Model Training Queue</h2>
        <button className="btn btn-secondary" onClick={fetchQueue}>Refresh Queue</button>
      </div>

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>User Email</th>
                <th>Name Label</th>
                <th>Clips</th>
                <th>Status</th>
                <th>Priority</th>
                <th>Queued At</th>
              </tr>
            </thead>
            <tbody>
              {queue.map((task) => {
                const submission = task.audio_submissions;
                const trainedName = submission?.trained_names;
                const userEmail = trainedName?.profiles?.email;

                return (
                  <tr key={task.id}>
                    <td>{userEmail || 'Unknown User'}</td>
                    <td>{trainedName?.name_label || 'Unknown'}</td>
                    <td>{submission?.clip_count || 0}</td>
                    <td>
                      <span className={`badge ${getStatusBadge(task.status)}`}>
                        {task.status}
                      </span>
                    </td>
                    <td>{task.priority}</td>
                    <td style={{ color: 'var(--color-text-muted)' }}>
                      {new Date(task.queued_at).toLocaleString()}
                    </td>
                  </tr>
                );
              })}
              {queue.length === 0 && (
                <tr>
                  <td colSpan="6" style={{ textAlign: 'center', padding: '2rem', color: 'var(--color-text-muted)' }}>
                    No training tasks in the queue
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

export default Models;
