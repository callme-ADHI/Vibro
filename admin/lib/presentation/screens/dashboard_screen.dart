import 'package:flutter/material.dart';
import '../widgets/main_layout.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Dashboard",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          const _StatsGrid(),
          const SizedBox(height: 32),

          // Recent Activity or Charts
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _RecentActivityCard(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: _SystemHealthCard(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    // 4 Columns for large screen
    return GridView.count(
      crossAxisCount: 5,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      shrinkWrap: true,
      childAspectRatio: 1.4,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        SummaryCard(
          title: "Total Users",
          value: "142",
          icon: Icons.people,
          color: Colors.blue,
        ),
        SummaryCard(
          title: "Names Uploaded",
          value: "583",
          icon: Icons.mic,
          color: Colors.purple,
        ),
        SummaryCard(
          title: "Models Trained",
          value: "135",
          icon: Icons.model_training,
          color: Colors.green,
        ),
        SummaryCard(
          title: "Pending Training",
          value: "7",
          icon: Icons.hourglass_top,
          color: Colors.orange,
        ),
        SummaryCard(
          title: "Failed Trainings",
          value: "2",
          icon: Icons.error_outline,
          color: Colors.red,
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Pending Training Requests",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: () {}, child: const Text("View All"))
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: const Icon(Icons.person_outline, color: Colors.orange),
                ),
                title: Text("User #${100 + index}"),
                subtitle: const Text("Requested training for 'Adhi'"),
                trailing: ElevatedButton(
                  onPressed: () {},
                  child: const Text("Start Training"),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "System Health",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _HealthItem(label: "Storage Usage", value: "45%", color: Colors.blue),
          _HealthItem(label: "API Latency", value: "120ms", color: Colors.green),
          _HealthItem(label: "Training Queues", value: "Idle", color: Colors.grey),
          _HealthItem(label: "Active Connections", value: "32", color: Colors.purple),
        ],
      ),
    );
  }
}

class _HealthItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HealthItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
