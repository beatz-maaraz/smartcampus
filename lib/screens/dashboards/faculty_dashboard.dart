import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../../services/campus_data_service.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../modules/timetable_screen.dart';
import '../modules/student_management_screen.dart';
import '../modules/study_materials_screen.dart';
import '../modules/chatbot_screen.dart';
import '../modules/anti_ragging/anti_ragging_dashboard.dart';
import '../modules/notice_screen.dart';
import '../modules/settings_screen.dart';

class FacultyDashboard extends StatefulWidget {
  const FacultyDashboard({super.key});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const FacultyHomeTab(),
          const ChatbotScreen(),
          const FacultyProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: const Icon(Icons.smart_toy_outlined), activeIcon: const Icon(Icons.smart_toy), label: 'Assistant'),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class FacultyHomeTab extends StatelessWidget {
  const FacultyHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<CampusDataService>();
    final user = auth.currentUser!;
    final todaysClasses = data.todaysTimetable();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await data.refresh();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 8),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${user.name}',
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Faculty Dashboard',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary)),
                    ],
                  ),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      user.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SectionHeader(title: "Today's Reminder"),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: todaysClasses.isEmpty
                      ? const Text('No classes scheduled for today.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: todaysClasses
                              .map((t) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.class_outlined,
                                            size: 18, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                              '${t.hour} — ${t.subject} (${t.room})'),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Actions'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  ModuleCard(
                    title: 'Student Management',
                    icon: Icons.groups_outlined,
                    color: AppColors.accent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const StudentManagementScreen()),
                    ),
                  ),
                  ModuleCard(
                    title: 'Study Materials',
                    icon: Icons.folder_shared_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const StudyMaterialsScreen()),
                    ),
                  ),
                  ModuleCard(
                    title: 'Mark / Edit Attendance',
                    icon: Icons.fact_check_outlined,
                    onTap: () => _markAttendance(context, data),
                  ),
                  ModuleCard(
                    title: 'Post Assignment',
                    icon: Icons.assignment_add,
                    color: AppColors.accent,
                    onTap: () => _postAssignment(context, data, user.name),
                  ),
                  ModuleCard(
                    title: 'Post Material / Syllabus',
                    icon: Icons.upload_file_outlined,
                    onTap: () => _postMaterial(context, data),
                  ),
                  ModuleCard(
                    title: 'Mark / Remark Fees',
                    icon: Icons.currency_rupee,
                    color: AppColors.warning,
                    onTap: () => _markFees(context, data),
                  ),
                  ModuleCard(
                    title: 'Modify Time Slot',
                    icon: Icons.edit_calendar_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TimetableScreen()),
                    ),
                  ),
                  ModuleCard(
                    title: 'Post Dept. Notice',
                    icon: Icons.campaign_outlined,
                    color: AppColors.primaryDark,
                    onTap: () => _postNotice(context, data, user),
                  ),
                  ModuleCard(
                    title: 'Anti-Ragging',
                    icon: Icons.shield_outlined,
                    color: AppColors.danger,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AntiRaggingDashboard()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markAttendance(BuildContext context, CampusDataService data) {
    final subjectController = TextEditingController(text: 'Data Structures');
    final studentIdController = TextEditingController(text: 'student');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: studentIdController,
              decoration: const InputDecoration(labelText: 'Student ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              data.markAttendance(
                studentId: studentIdController.text.trim(),
                subject: subjectController.text.trim(),
                present: false,
              );
              Navigator.pop(ctx);
              _toast(context, 'Marked absent — Student % updated instantly.');
            },
            child: const Text('Mark Absent'),
          ),
          ElevatedButton(
            onPressed: () {
              data.markAttendance(
                studentId: studentIdController.text.trim(),
                subject: subjectController.text.trim(),
                present: true,
              );
              Navigator.pop(ctx);
              _toast(context, 'Marked present — Student % updated instantly.');
            },
            child: const Text('Mark Present'),
          ),
        ],
      ),
    );
  }

  void _postAssignment(
      BuildContext context, CampusDataService data, String facultyName) {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Assignment Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              data.postAssignment(AssignmentItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                subject: subjectController.text.trim(),
                dueDate: DateTime.now().add(const Duration(days: 7)),
                postedBy: facultyName,
              ));
              Navigator.pop(ctx);
              _toast(
                  context, 'Assignment posted — visible on Student dashboard.');
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _postMaterial(BuildContext context, CampusDataService data) {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Material / Syllabus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                // Hook up file_picker here to select the real file.
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('Choose File (file_picker)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              data.postMaterial(MaterialItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                subject: subjectController.text.trim(),
                fileName:
                    '${titleController.text.trim().replaceAll(' ', '_')}.pdf',
                postedOn: DateTime.now(),
              ));
              Navigator.pop(ctx);
              _toast(context,
                  'Material posted — downloadable from Student dashboard.');
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _markFees(BuildContext context, CampusDataService data) {
    final studentIdController = TextEditingController(text: 'student');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark / Remark Fee Status'),
        content: TextField(
          controller: studentIdController,
          decoration: const InputDecoration(labelText: 'Student ID'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              data.setFeeStatus(studentIdController.text.trim(), paid: true);
              Navigator.pop(ctx);
              _toast(context, 'Marked as paid.');
            },
            child: const Text('Mark Paid'),
          ),
          ElevatedButton(
            onPressed: () {
              data.setFeeStatus(studentIdController.text.trim(), paid: false);
              Navigator.pop(ctx);
              _toast(context,
                  'Marked unpaid — notice shown + SMS reminder queued.');
            },
            child: const Text('Mark Unpaid'),
          ),
        ],
      ),
    );
  }

  void _postNotice(BuildContext context, CampusDataService data, AppUser user) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Department Notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              data.postDepartmentNotice(NoticeItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                body: bodyController.text.trim(),
                postedBy: user.name,
                scope: user.department ?? 'General',
                postedOn: DateTime.now(),
              ));
              Navigator.pop(ctx);
              _toast(context, 'Notice posted to department students.');
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class FacultyProfileTab extends StatelessWidget {
  const FacultyProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(kPad),
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                user.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            user.role.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NoticeScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
            onTap: () => auth.logout(),
          ),
        ],
      ),
    );
  }
}
