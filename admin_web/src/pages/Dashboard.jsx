import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { 
  Users, 
  Database, 
  AlertCircle, 
  Activity, 
  TrendingUp, 
  Smartphone, 
  MessageSquare,
  ShieldCheck
} from 'lucide-react';
import { 
  PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend,
  BarChart, Bar, XAxis, YAxis, CartesianGrid
} from 'recharts';

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
    activeSubmissions: 0,
    pendingFeedback: 0,
    lowBatteryDevices: 0,
    avgAccuracy: 0
  });
  const [subData, setSubData] = useState([]);
  const [pipelineData, setPipelineData] = useState([]);
  const [loading, setLoading] = useState(true);

  const COLORS = ['#0B1F3B', '#16A34A', '#F59E0B', '#DC2626', '#123A6F'];

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      // Run concurrent queries for dashboard overview
      const [
        users, 
        models, 
        detections, 
        queue, 
        subs, 
        submissions, 
        feedback,
        devices
      ] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }),
        supabase.from('trained_models').select('id', { count: 'exact', head: true }),
        supabase.from('detection_history').select('id', { count: 'exact', head: true }),
        supabase.from('training_queue').select('id', { count: 'exact', head: true }).in('status', ['queued', 'processing']),
        supabase.from('subscriptions').select('tier'),
        supabase.from('audio_submissions').select('status'),
        supabase.from('app_feedbacks').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
        supabase.from('device_registry').select('id', { count: 'exact', head: true }).lt('battery_last_reported', 20),
        supabase.from('trained_models').select('accuracy_metric')
      ]);

      // Calculate Subscription Distribution
      const subCounts = (subs.data || []).reduce((acc, curr) => {
        acc[curr.tier] = (acc[curr.tier] || 0) + 1;
        return acc;
      }, {});
      setSubData(Object.keys(subCounts).map(tier => ({ name: tier.toUpperCase(), value: subCounts[tier] })));

      // Calculate Pipeline Status
      const pipelineCounts = (submissions.data || []).reduce((acc, curr) => {
        acc[curr.status] = (acc[curr.status] || 0) + 1;
        return acc;
      }, {});
      setPipelineData(Object.keys(pipelineCounts).map(status => ({ name: status, count: pipelineCounts[status] })));

      // Calculate Avg Accuracy
      const accuracies = models.data || [];
      const avgAcc = accuracies.length > 0 
        ? (accuracies.reduce((sum, m) => sum + (m.accuracy_metric || 0), 0) / accuracies.length * 100).toFixed(1)
        : 0;

      setStats({
        users: users.count || 0,
        models: models.count || 0,
        detections: detections.count || 0,
        activeSubmissions: queue.count || 0,
        pendingFeedback: feedback.count || 0,
        lowBatteryDevices: devices.count || 0,
        avgAccuracy: avgAcc
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%', color: 'var(--color-text-muted)' }}>
        <p>Analyzing system data...</p>
      </div>
    );
  }

  return (
    <div className="animate-fade-in">
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <StatCard title="Total Users" value={stats.users} icon={<Users size={28} />} color="46, 91, 255" />
        <StatCard title="Avg. Model Accuracy" value={`${stats.avgAccuracy}%`} icon={<ShieldCheck size={28} />} color="28, 196, 130" />
        <StatCard title="Daily Detections" value={stats.detections} icon={<Activity size={28} />} color="245, 176, 74" />
        <StatCard title="Active Training" value={stats.activeSubmissions} icon={<Database size={28} />} color="224, 62, 82" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        {/* Subscription Distribution */}
        <div className="card">
          <h3>Subscription Tiers</h3>
          <div style={{ height: 300, width: '100%', marginTop: '1rem' }}>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={subData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={80}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {subData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip 
                  contentStyle={{ backgroundColor: 'var(--color-surface)', borderColor: 'var(--color-border)', borderRadius: '8px', color: 'var(--color-text)' }}
                  itemStyle={{ color: 'var(--color-text)' }}
                />
                <Legend verticalAlign="bottom" height={36}/>
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Training Pipeline */}
        <div className="card">
          <h3>Training Pipeline Status</h3>
          <div style={{ height: 300, width: '100%', marginTop: '1rem' }}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={pipelineData}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--color-border)" />
                <XAxis dataKey="name" stroke="var(--color-text-muted)" tick={{ fontSize: 12 }} />
                <YAxis stroke="var(--color-text-muted)" tick={{ fontSize: 12 }} />
                <Tooltip 
                  cursor={{ fill: 'var(--color-bg)' }}
                  contentStyle={{ backgroundColor: 'var(--color-surface)', borderColor: 'var(--color-border)', borderRadius: '8px', color: 'var(--color-text)' }}
                />
                <Bar dataKey="count" fill="var(--color-primary)" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' }}>
        {/* System Health / Alerts */}
        <div className="card" style={{ borderLeft: stats.lowBatteryDevices > 0 ? '4px solid var(--color-danger)' : '4px solid var(--color-success)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
            <Smartphone size={20} color={stats.lowBatteryDevices > 0 ? 'var(--color-danger)' : 'var(--color-success)'} />
            <h3 style={{ margin: 0 }}>Device Health</h3>
          </div>
          <p style={{ color: 'var(--color-text-muted)' }}>
            {stats.lowBatteryDevices > 0 
              ? `Attention: ${stats.lowBatteryDevices} devices reported battery below 20%.`
              : "All connected devices report healthy battery levels."
            }
          </p>
        </div>

        <div className="card" style={{ borderLeft: stats.pendingFeedback > 0 ? '4px solid var(--color-warning)' : '4px solid var(--color-success)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
            <MessageSquare size={20} color={stats.pendingFeedback > 0 ? 'var(--color-warning)' : 'var(--color-success)'} />
            <h3 style={{ margin: 0 }}>Pending Feedbacks</h3>
          </div>
          <p style={{ color: 'var(--color-text-muted)' }}>
            {stats.pendingFeedback > 0 
              ? `You have ${stats.pendingFeedback} unresolved feedbacks from users.`
              : "All user feedbacks have been processed."
            }
          </p>
          {stats.pendingFeedback > 0 && (
            <a href="/feedbacks" style={{ display: 'inline-block', marginTop: '1rem', color: 'var(--color-primary)', fontSize: '0.875rem', fontWeight: 500 }}>
              Review Feedback →
            </a>
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
