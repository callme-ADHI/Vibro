import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { Users, Database, AlertCircle, Activity } from 'lucide-react';

const StatCard = ({ title, value, icon, color }) => (
  <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '1.5rem' }}>
    <div style={{ 
      width: 56, 
      height: 56, 
      borderRadius: 'var(--radius-md)', 
      background: `rgba(${color}, 0.15)`, 
      color: `rgb(${color})`,
      display: 'flex', 
      alignItems: 'center', 
      justifyContent: 'center' 
    }}>
      {icon}
    </div>
    <div>
      <p style={{ color: 'var(--color-text-muted)', fontSize: '0.875rem', fontWeight: 500, marginBottom: '0.25rem' }}>{title}</p>
      <h3 style={{ fontSize: '1.75rem', margin: 0 }}>{value}</h3>
    </div>
  </div>
);

const Dashboard = () => {
  const [stats, setStats] = useState({
    users: 0,
    models: 0,
    detections: 0,
    activeSubmissions: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      // Run concurrent queries for dashboard overview
      const [users, models, detections, queue] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }),
        supabase.from('trained_models').select('id', { count: 'exact', head: true }),
        supabase.from('detection_history').select('id', { count: 'exact', head: true }),
        supabase.from('training_queue').select('id', { count: 'exact', head: true }).in('status', ['queued', 'processing'])
      ]);

      setStats({
        users: users.count || 0,
        models: models.count || 0,
        detections: detections.count || 0,
        activeSubmissions: queue.count || 0
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div>Loading dashboard...</div>;
  }

  return (
    <div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <StatCard title="Total Users" value={stats.users} icon={<Users size={28} />} color="46, 91, 255" />
        <StatCard title="Trained Models" value={stats.models} icon={<Database size={28} />} color="28, 196, 130" />
        <StatCard title="Total Detections" value={stats.detections} icon={<Activity size={28} />} color="245, 176, 74" />
        <StatCard title="Active Training Queue" value={stats.activeSubmissions} icon={<AlertCircle size={28} />} color="224, 62, 82" />
      </div>

      <div className="card">
        <h3>System Overview</h3>
        <p style={{ color: 'var(--color-text-muted)', marginTop: '0.5rem' }}>
          Welcome to the new Vibro React Admin space. Here you can monitor system capacity, user registrations, and model training in real-time.
        </p>
      </div>
    </div>
  );
};

export default Dashboard;
