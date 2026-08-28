import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../config/constants.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/campus_data_service.dart';

class MyComplaintsScreen extends StatelessWidget {
  const MyComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<CampusDataService>();
    final user = auth.currentUser!;
    
    final myComplaints = data.complaints.where((c) => c.studentId == user.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Complaints & Status'),
      ),
      body: myComplaints.isEmpty
          ? const Center(
              child: Text(
                'You have not submitted any complaints.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myComplaints.length,
              itemBuilder: (ctx, idx) {
                final c = myComplaints[idx];
                final dateStr = DateFormat('MMM d, yyyy').format(c.incidentDate);
                
                Color statusColor = AppColors.warning;
                if (c.status == 'Under Investigation') statusColor = AppColors.primary;
                if (c.status == 'Resolved') statusColor = AppColors.safe;
                if (c.status == 'Dismissed') statusColor = AppColors.textSecondary;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ref ID: ${c.id}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                c.status,
                                style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          c.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.description,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.event, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('Incident Date: $dateStr',
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                        if (c.facultyComments != null && c.facultyComments!.isNotEmpty) ...[
                          const Divider(height: 24),
                          Text(c.updatedBy != null ? 'Remarks by ${c.updatedBy}:' : 'Admin/Faculty Remarks:',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                            c.facultyComments!,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
