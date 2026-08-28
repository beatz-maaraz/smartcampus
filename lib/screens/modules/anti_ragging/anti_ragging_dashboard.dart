import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/campus_data_service.dart';
import '../../../services/auth_service.dart';
import '../../../config/constants.dart';
import '../../../widgets/widgets.dart';

class AntiRaggingDashboard extends StatelessWidget {
  const AntiRaggingDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Anti-Ragging Complaints'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: Consumer<CampusDataService>(
        builder: (ctx, data, _) {
          final complaints = data.complaints;
          final activeIncidents = data.incidents.where((i) => i.status == IncidentStatus.triggered).toList();
          
          return CustomScrollView(
            slivers: [
              // Active SOS Incidents Section
              if (activeIncidents.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: SectionHeader(title: '🚨 CRITICAL: Active SOS Incidents'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return IncidentCard(
                          incident: activeIncidents[index],
                          data: data,
                        );
                      },
                      childCount: activeIncidents.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 32),
                  ),
                ),
              ],
              
              // Complaints Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, activeIncidents.isNotEmpty ? 0 : 20, 16, 10),
                  child: const SectionHeader(title: 'Anti-Ragging Complaints'),
                ),
              ),
              if (complaints.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      message: 'No complaints registered.',
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final c = complaints[idx];
                        
                        // Apply Anonymity Rules
                        final reportedBy = c.isAnonymous ? '🔒 Anonymous Student' : _resolveStudentName(c.studentId, data.students);
                        final byColor = c.isAnonymous ? AppColors.warning : AppColors.primary;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _showComplaintDetails(context, c, data),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        c.id,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(c.status).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          c.status,
                                          style: TextStyle(
                                            color: _getStatusColor(c.status),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    c.title,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 16, color: byColor),
                                      const SizedBox(width: 4),
                                      Text(reportedBy, style: TextStyle(color: byColor, fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${c.incidentDate.day}/${c.incidentDate.month}/${c.incidentDate.year}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  if (c.updatedBy != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.admin_panel_settings, size: 16, color: AppColors.safe),
                                        const SizedBox(width: 4),
                                        Text('Last updated by ${c.updatedBy}', 
                                          style: const TextStyle(fontSize: 12, color: AppColors.safe, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: complaints.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _resolveStudentName(String studentId, List<StudentProfile> students) {
    try {
      final s = students.firstWhere((s) => s.rollNumber == studentId);
      return '${s.name} (${s.rollNumber})';
    } catch (_) {
      return studentId;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return AppColors.danger;
      case 'Under Investigation':
        return AppColors.warning;
      case 'Resolved':
        return AppColors.safe;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showComplaintDetails(BuildContext context, Complaint c, CampusDataService data) {
    final reportedBy = c.isAnonymous ? '🔒 Anonymous Student' : _resolveStudentName(c.studentId, data.students);
    String currentStatus = c.status;
    final commentController = TextEditingController(text: c.facultyComments ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(c.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Ref: ${c.id}', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.isAnonymous ? AppColors.warning.withValues(alpha: 0.1) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.isAnonymous ? AppColors.warning.withValues(alpha: 0.5) : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.report, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Reported By', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(reportedBy, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(c.description, style: const TextStyle(fontSize: 15, height: 1.5)),
                  ),
                ),
                
                const Divider(height: 32),
                
                const Text('Action & Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                DropdownButtonFormField<String>(
                  value: currentStatus,
                  decoration: InputDecoration(
                    labelText: 'Update Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: ['Pending', 'Under Investigation', 'Resolved']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => currentStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Faculty/Admin Comments',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final auth = context.read<AuthService>();
                      final u = auth.currentUser!;
                      
                      final updated = Complaint(
                        id: c.id,
                        studentId: c.studentId,
                        title: c.title,
                        description: c.description,
                        incidentDate: c.incidentDate,
                        isAnonymous: c.isAnonymous,
                        status: currentStatus,
                        facultyComments: commentController.text.trim(),
                        updatedBy: '${u.role.label} ${u.name}',
                        createdAt: c.createdAt,
                      );
                      data.updateComplaint(updated);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complaint updated successfully.')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          );
        },
      ),
    );
  }
}
