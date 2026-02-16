import 'package:flutter/material.dart';
import '../widgets/main_layout.dart';
import 'dashboard_screen.dart';

class UsersScreen extends StatelessWidget {
  static const String routeName = '/users';

  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "User Management",
      selectedIndex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UsersTable(),
        ],
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by Email or ID...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list),
                  label: const Text("Filter"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text("User Email")),
                  DataColumn(label: Text("Names")),
                  DataColumn(label: Text("Samples")),
                  DataColumn(label: Text("Accuracy")),
                  DataColumn(label: Text("Status")),
                  DataColumn(label: Text("Last Updated")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: _getMockRows(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataRow> _getMockRows(BuildContext context) {
    return List.generate(10, (index) {
      final status = index % 3 == 0
          ? "COMPLETED"
          : (index % 3 == 1 ? "TRAINING" : "FAILED");
      
      Color statusColor = status == "COMPLETED"
          ? Colors.green
          : (status == "TRAINING" ? Colors.blue : Colors.red);

      return DataRow(
        cells: [
          DataCell(Text("user_$index@vibro.ai")),
          DataCell(Text("${(index + 1) * 2}")),
          DataCell(Text("${(index + 1) * 25}")),
          DataCell(Text("9${index}%")),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                status,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          DataCell(Text("2026-02-14")),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  tooltip: "View Details",
                  onPressed: () {},
                ),
                if (status == "FAILED" || status == "COMPLETED")
                  IconButton(
                    icon: const Icon(Icons.replay, size: 20, color: Colors.orange),
                    tooltip: "Force Retrain",
                    onPressed: () {},
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  tooltip: "Delete",
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
