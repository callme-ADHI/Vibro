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
          audio_submissions(
            id,
            user_id,
            trained_name_id,
            clip_count, 
            storage_path, 
            trained_names(name_label, profiles(email))
          )
        `)
        .order('queued_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      console.log('DEBUG: Training queue fetched:', data);
      setQueue(data);
    } catch (error) {
      console.error('Error fetching queue:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateStatus = async (task, newStatus, accuracy = null) => {
    try {
      if (!task.audio_submissions) {
        throw new Error("Metadata for this task is missing or inaccessible (RLS issue)");
      }

      const submissionId = task.audio_submission_id;
      const trainedNameId = task.audio_submissions.trained_name_id;
      const userId = task.audio_submissions.user_id;

      // 1. Update training_queue
      const queueUpdate = { 
        status: newStatus
      };
      if (newStatus === 'processing') queueUpdate.started_at = new Date().toISOString();
      if (newStatus === 'completed' || newStatus === 'failed') queueUpdate.finished_at = new Date().toISOString();

      await supabase.from('training_queue').update(queueUpdate).eq('id', task.id);

      // 2. Update audio_submissions
      await supabase.from('audio_submissions').update({ status: newStatus }).eq('id', submissionId);

      // 3. Update user_training_status (the real-time table for the app)
      const appStatus = newStatus === 'queued' ? 'NOT_STARTED' : 
                        newStatus === 'processing' ? 'TRAINING' : 
                        newStatus === 'completed' ? 'COMPLETED' : 'FAILED';
      
      const trainingUpdate = {
        status: appStatus,
        progress_percentage: newStatus === 'completed' ? 100 : (newStatus === 'processing' ? 50 : 0),
        updated_at: new Date().toISOString()
      };
      
      if (accuracy !== null) trainingUpdate.accuracy_metric = accuracy / 100;
      
      await supabase.from('user_training_status')
        .update(trainingUpdate)
        .eq('user_id', userId)
        .eq('trained_name_id', trainedNameId);

      // 4. If completed, insert into trained_models
      if (newStatus === 'completed') {
        await supabase.from('trained_models').insert({
          user_id: userId,
          trained_name_id: trainedNameId,
          model_version: 1, // Default to 1 for manual
          model_path: `${userId}/${trainedNameId}/model_v1.tflite`, // Placeholder path
          training_sample_count: task.audio_submissions.clip_count,
          accuracy_metric: accuracy / 100
        });
      }

      fetchQueue();
    } catch (error) {
      console.error('Error updating status:', error);
      alert('Failed to update status: ' + error.message);
    }
  };

  const handleComplete = (task) => {
    const accuracy = prompt('Enter Training Accuracy % (0-100):', '95');
    if (accuracy !== null) {
      const accNum = parseFloat(accuracy);
      if (isNaN(accNum) || accNum < 0 || accNum > 100) {
        alert('Invalid accuracy percentage');
        return;
      }
      updateStatus(task, 'completed', accNum);
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
                <th>Actions</th>
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
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        {task.status === 'queued' && (
                          <button 
                            className="btn btn-secondary btn-sm"
                            onClick={() => updateStatus(task, 'processing')}
                          >
                            Start
                          </button>
                        )}
                        {task.status === 'processing' && (
                          <>
                            <button 
                              className="btn btn-success btn-sm"
                              onClick={() => handleComplete(task)}
                            >
                              Complete
                            </button>
                            <button 
                              className="btn btn-danger btn-sm"
                              onClick={() => updateStatus(task, 'failed')}
                            >
                              Fail
                            </button>
                          </>
                        )}
                        {task.status === 'completed' && (
                          <span style={{ fontSize: '0.75rem', color: 'var(--color-success)' }}>Done</span>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
              {queue.length === 0 && (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', padding: '2rem', color: 'var(--color-text-muted)' }}>
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
