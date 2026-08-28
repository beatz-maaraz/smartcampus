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

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const StudentHomeTab(),
          const ChatbotScreen(),
          const ProfileTab(),
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

class StudentHomeTab extends StatelessWidget {
  const StudentHomeTab({super.key});

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
      floatingActionButton: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.red.shade900.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PreSOSScreen()),
            );
          },
          child: const Icon(Icons.sos_rounded, color: Colors.white, size: 36),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
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
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Student Dashboard',
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

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser!;
    
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
            onTap: () {},
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
