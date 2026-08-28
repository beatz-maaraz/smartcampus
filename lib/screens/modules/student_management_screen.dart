import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Faculty — Student Management (§1: student records, §2: daily
/// attendance marking, §3: automated absence notifications to student +
/// parent). Two tabs: the student roster (add/view records) and today's
/// attendance marking sheet.
class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _attendanceSubjectController =
      TextEditingController(text: 'Data Structures');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _attendanceSubjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<CampusDataService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Daily Attendance'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddStudentDialog(context, data),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add Student'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentList(data),
          _buildAttendanceTab(context, data),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // TAB 1 — Student roster
  // ---------------------------------------------------------------------

  Widget _buildStudentList(CampusDataService data) {
    final students = data.students;
    if (students.isEmpty) {
      return const EmptyState(
        message: 'No students added yet. Tap "Add Student" to get started.',
        icon: Icons.people_outline,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(kPad),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = students[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(s.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${s.rollNumber} • ${s.year} • ${s.department}\n'
                'Student: ${s.studentMobile}  •  Parent: ${s.parentMobile}'),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () =>
                  _showAddStudentDialog(context, data, existing: s),
            ),
          ),
        );
      },
    );
  }

  void _showAddStudentDialog(BuildContext context, CampusDataService data,
      {StudentProfile? existing}) {
    final rollController =
        TextEditingController(text: existing?.rollNumber ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final yearController = TextEditingController(text: existing?.year ?? '');
    final deptController =
        TextEditingController(text: existing?.department ?? '');
    final studentMobileController =
        TextEditingController(text: existing?.studentMobile ?? '');
    final parentMobileController =
        TextEditingController(text: existing?.parentMobile ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Student' : 'Edit Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rollController,
                enabled: existing ==
                    null, // roll number is the unique key — lock it on edit
                decoration: const InputDecoration(labelText: 'Roll Number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: yearController,
                decoration:
                    const InputDecoration(labelText: 'Year (e.g. 3rd Year)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deptController,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: studentMobileController,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Student Mobile Number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: parentMobileController,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Parent Mobile Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (rollController.text.trim().isEmpty ||
                  nameController.text.trim().isEmpty) {
                return;
              }
              data.addOrUpdateStudent(StudentProfile(
                rollNumber: rollController.text.trim(),
                name: nameController.text.trim(),
                year: yearController.text.trim(),
                department: deptController.text.trim(),
                studentMobile: studentMobileController.text.trim(),
                parentMobile: parentMobileController.text.trim(),
              ));
              Navigator.pop(ctx);
              _toast(context,
                  existing == null ? 'Student added.' : 'Student updated.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // TAB 2 — Daily attendance marking
  // ---------------------------------------------------------------------

  Widget _buildAttendanceTab(BuildContext context, CampusDataService data) {
    final students = data.students;
    final today = DateTime.now();
    final dateLabel = '${today.day}/${today.month}/${today.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _attendanceSubjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Date',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  Text(dateLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Mark each student'),
        Expanded(
          child: students.isEmpty
              ? const EmptyState(
                  message:
                      'Add students first (Students tab) before marking attendance.',
                  icon: Icons.fact_check_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: kPad),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final s = students[i];
                    return Card(
                      child: ListTile(
                        title: Text(s.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${s.rollNumber} • ${s.department}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger),
                              onPressed: () =>
                                  _mark(context, data, s, present: false),
                              child: const Text('Absent'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.safe),
                              onPressed: () =>
                                  _mark(context, data, s, present: true),
                              child: const Text('Present'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (data.notifications.isNotEmpty) _buildNotificationLog(data),
      ],
    );
  }

  void _mark(BuildContext context, CampusDataService data, StudentProfile s,
      {required bool present}) {
    final subject = _attendanceSubjectController.text.trim().isEmpty
        ? 'General'
        : _attendanceSubjectController.text.trim();
    data.markDailyAttendance(
        rollNumber: s.rollNumber, subject: subject, present: present);

    if (present) {
      _toast(context, '${s.name} marked present.');
      return;
    }

    // Absent — instantly open the SMS composer to the student, pre-filled,
    // then offer a one-tap follow-up to also message the parent. This
    // still needs a manual "Send" tap in the SMS app itself: there is no
    // way to actually transmit an SMS without either a paid SMS gateway
    // API (Fast2SMS/MSG91/Twilio) or, on Android only, the SEND_SMS
    // permission via a native plugin — url_launcher can only open the
    // composer, not send silently in the background.
    final message = '${s.name} (${s.rollNumber}) was marked ABSENT for '
        '$subject today. Please follow up.';
    _launchSms(context, s.studentMobile, message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('SMS opened for ${s.name} (student). Also message parent?'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Message Parent',
        onPressed: () => _launchSms(context, s.parentMobile, message),
      ),
    ));
  }

  Future<void> _launchSms(
      BuildContext context, String phoneNumber, String message) async {
    if (phoneNumber.trim().isEmpty) {
      _toast(context, 'No mobile number on file for this contact.');
      return;
    }
    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber.trim(),
      queryParameters: {'body': message},
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      _toast(context, 'Could not open the SMS app on this device.');
    }
  }

  Widget _buildNotificationLog(CampusDataService data) {
    final recent = data.notifications.take(5).toList();
    return Padding(
      padding: const EdgeInsets.all(kPad),
      child: ExpansionTile(
        title: Text('Recent Notifications (${data.notifications.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: recent
            .map((n) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.notifications_active_outlined,
                      size: 18, color: AppColors.warning),
                  title: Text(n.recipient,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle:
                      Text(n.message, style: const TextStyle(fontSize: 12)),
                ))
            .toList(),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
