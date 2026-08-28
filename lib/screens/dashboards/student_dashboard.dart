import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../../services/campus_data_service.dart';
import '../../widgets/widgets.dart';
import '../modules/timetable_screen.dart';
import '../modules/navigation_screen.dart';
import '../modules/chatbot_screen.dart';
import '../modules/chemical_hub_screen.dart';
import '../modules/notice_screen.dart';
import '../modules/study_materials_screen.dart';
import '../modules/assignments_screen.dart';
import '../sos/pre_sos_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<CampusDataService>();
    final user = auth.currentUser!;

    final attendancePercent = data.attendancePercentFor(user.id);
    final fee = data.feeStatusFor(user.id);
    final pendingAssignments = data.pendingAssignmentCount;
    final todaysClasses = data.todaysTimetable();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NoticeScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.sos, color: Colors.white, size: 32),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PreSOSScreen()),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(kPad),
          children: [
            Text('Welcome, ${user.name} 👋',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SectionHeader(title: "Today's Summary"),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                SummaryTile(
                  label: 'Attendance',
                  value: '${attendancePercent.toStringAsFixed(1)}%',
                  icon: Icons.pie_chart_outline,
                  color: attendancePercent >= 75
                      ? AppColors.safe
                      : AppColors.danger,
                ),
                SummaryTile(
                  label:
                      fee == null || fee.paid ? 'Fees Cleared' : 'Fees Pending',
                  value: fee == null || fee.paid
                      ? '✓'
                      : '₹${fee.amountDue.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: (fee == null || fee.paid)
                      ? AppColors.safe
                      : AppColors.warning,
                ),
                SummaryTile(
                  label: 'Assignments Pending',
                  value: '$pendingAssignments',
                  icon: Icons.assignment_outlined,
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AssignmentsScreen()),
                  ),
                ),
                SummaryTile(
                  label: "Today's Classes",
                  value: '${todaysClasses.length}',
                  icon: Icons.schedule_outlined,
                  color: AppColors.accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TimetableScreen()),
                  ),
                ),
              ],
            ),
            const SectionHeader(title: 'Modules'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: [
                ModuleCard(
                  title: 'Time Table',
                  icon: Icons.calendar_month_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TimetableScreen()),
                  ),
                ),
                ModuleCard(
                  title: 'Smart Navigation',
                  icon: Icons.map_outlined,
                  color: AppColors.accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NavigationScreen()),
                  ),
                ),
                ModuleCard(
                  title: 'Study Materials',
                  icon: Icons.folder_open_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const StudyMaterialsScreen()),
                  ),
                ),
                ModuleCard(
                  title: 'Assignments',
                  icon: Icons.assignment_outlined,
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AssignmentsScreen()),
                  ),
                ),
                ModuleCard(
                  title: 'Event Browser',
                  icon: Icons.event_outlined,
                  onTap: () => _showEvents(context, data),
                ),
                ModuleCard(
                  title: 'AI Chatbot',
                  icon: Icons.smart_toy_outlined,
                  color: AppColors.primaryDark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                  ),
                ),
                ModuleCard(
                  title: 'Chemical Hub',
                  icon: Icons.science_outlined,
                  color: AppColors.warning,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ChemicalHubScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEvents(BuildContext context, CampusDataService data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, controller) => data.events.isEmpty
            ? const EmptyState(message: 'No upcoming events.')
            : ListView.builder(
                controller: controller,
                padding: const EdgeInsets.all(kPad),
                itemCount: data.events.length,
                itemBuilder: (_, i) {
                  final e = data.events[i];
                  return ListTile(
                    leading: const Icon(Icons.event_outlined,
                        color: AppColors.primary),
                    title: Text(e.title),
                    subtitle: Text(
                        '${e.venue} • ${e.date.day}/${e.date.month}/${e.date.year}'),
                  );
                },
              ),
      ),
    );
  }
}
