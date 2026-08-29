import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../../services/campus_data_service.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../modules/chatbot_screen.dart';
import '../modules/notice_screen.dart';
import '../modules/settings_screen.dart';
import '../modules/anti_ragging/anti_ragging_dashboard.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<String> tabTitles = ['Admin Dashboard', 'AI Assistant', 'Admin Profile'];

    return Scaffold(
      appBar: AppBar(
        title: Text(tabTitles[_currentIndex], style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        elevation: 8,
        shadowColor: AppColors.primary.withValues(alpha: 0.4),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const AdminHomeTab(),
          const ChatbotScreen(),
          const AdminProfileTab(),
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

class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<CampusDataService>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink(); // Prevent crash during auth transition
    final report = data.globalAttendanceReport();
    final activeIncidents = data.incidents.where((i) => i.status != IncidentStatus.resolved).toList();

    final hour = DateTime.now().hour;
    String greeting = 'Good Evening';
    IconData greetingIcon = Icons.nights_stay_outlined;
    Color greetingColor = Colors.indigo;
    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny_outlined;
      greetingColor = Colors.orange;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_cloudy_outlined;
      greetingColor = Colors.blue;
    } else if (hour < 20) {
      greeting = 'Good Evening';
      greetingIcon = Icons.nights_stay_outlined;
      greetingColor = Colors.indigo;
    } else {
      greeting = 'Good Night';
      greetingIcon = Icons.bedtime_outlined;
      greetingColor = Colors.deepPurple;
    }

    return Scaffold(
      body: RefreshIndicator(
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
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutExpo,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 15 * (1 - value)),
                          child: Opacity(
                            opacity: (value * 1.5).clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Icon(greetingIcon, color: greetingColor, size: 24),
                              ),
                            ),
                            TextSpan(
                              text: '$greeting, ',
                              style: TextStyle(
                                  fontSize: 22,
                                  color: greetingColor,
                                  fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: user.name,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Admin Dashboard',
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
            const SizedBox(height: 16),
            const SectionHeader(title: '🚨 CRITICAL: Active SOS Incidents'),
            if (activeIncidents.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No active incidents at the moment.')))
            else ...[
              ...activeIncidents.map(
                  (incident) => IncidentCard(incident: incident, data: data)),
            ],
            const SizedBox(height: 24),
            const SectionHeader(title: 'Actions'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                ModuleCard(
                  title: 'Create User',
                  icon: Icons.person_add_outlined,
                  color: AppColors.safe,
                  onTap: () => _createUser(context, auth),
                ),
                ModuleCard(
                  title: 'Drop Location Pin',
                  icon: Icons.add_location_alt_outlined,
                  onTap: () => _addVenue(context, data),
                ),
                ModuleCard(
                  title: 'Manage Chemical Safety',
                  icon: Icons.science_outlined,
                  color: AppColors.warning,
                  onTap: () => _manageChemical(context, data),
                ),
                ModuleCard(
                  title: 'Edit Master Schedule',
                  icon: Icons.event_note_outlined,
                  onTap: () => _addSlot(context, data),
                ),
                ModuleCard(
                  title: 'Global Attendance Report',
                  icon: Icons.bar_chart_outlined,
                  color: AppColors.accent,
                  onTap: () => _showReport(context, report),
                ),
                ModuleCard(
                  title: 'Broadcast Notice',
                  icon: Icons.campaign_outlined,
                  color: AppColors.primaryDark,
                  onTap: () => _broadcast(context, data, user),
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
            const SectionHeader(title: 'Global Attendance Snapshot'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: report.isEmpty
                    ? const Text('No attendance data yet.')
                    : Column(
                        children: report.entries
                            .map((e) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(e.key),
                                  trailing:
                                      Text('${e.value.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: e.value >= 75
                                                ? AppColors.safe
                                                : AppColors.danger,
                                          )),
                                ))
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createUser(BuildContext context, AuthService auth) {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole role = UserRole.student;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<UserRole>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [UserRole.student, UserRole.faculty].map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                  onChanged: (v) => setState(() => role = v ?? role),
                ),
                const SizedBox(height: 10),
                TextField(controller: idController, decoration: const InputDecoration(labelText: 'ID (e.g., student1)')),
                const SizedBox(height: 10),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 10),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (idController.text.trim().isEmpty || passwordController.text.isEmpty) return;
                
                // Show loading
                showDialog(context: ctx, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                
                final error = await auth.adminCreateUser(
                  role: role,
                  id: idController.text.trim(),
                  password: passwordController.text,
                  name: nameController.text.trim().isEmpty ? 'User ${idController.text}' : nameController.text.trim(),
                );
                
                Navigator.pop(ctx); // pop loading dialog
                
                if (error != null) {
                  _toast(context, error);
                } else {
                  Navigator.pop(ctx); // pop create dialog
                  _toast(context, '${role.label} created successfully!');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _addVenue(BuildContext context, CampusDataService data) {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final blockController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Drop New Location Pin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Venue Name')),
            const SizedBox(height: 10),
            TextField(
                controller: blockController,
                decoration: const InputDecoration(labelText: 'Block')),
            const SizedBox(height: 10),
            TextField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(
                controller: lngController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              data.addVenue(VenueLocation(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                lat: double.tryParse(latController.text) ?? 11.0168,
                lng: double.tryParse(lngController.text) ?? 76.9558,
                block: blockController.text.trim(),
              ));
              Navigator.pop(ctx);
              _toast(context, 'Venue added — now searchable in navigation.');
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _manageChemical(BuildContext context, CampusDataService data) {
    final nameController = TextEditingController();
    final formulaController = TextEditingController();
    final usageController = TextEditingController();
    final firstAidController = TextEditingController();
    HazardLevel hazard = HazardLevel.careful;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Manage Chemical Safety Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Chemical Name')),
                const SizedBox(height: 10),
                TextField(
                    controller: formulaController,
                    decoration: const InputDecoration(labelText: 'Formula')),
                const SizedBox(height: 10),
                DropdownButtonFormField<HazardLevel>(
                  initialValue: hazard,
                  decoration: const InputDecoration(labelText: 'Hazard Level'),
                  items: HazardLevel.values
                      .map((h) =>
                          DropdownMenuItem(value: h, child: Text(h.name)))
                      .toList(),
                  onChanged: (v) => setState(() => hazard = v ?? hazard),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: usageController,
                    decoration: const InputDecoration(labelText: 'Usage')),
                const SizedBox(height: 10),
                TextField(
                    controller: firstAidController,
                    decoration: const InputDecoration(labelText: 'First Aid')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                data.upsertChemical(ChemicalInfo(
                  name: nameController.text.trim(),
                  formula: formulaController.text.trim(),
                  hazard: hazard,
                  usage: usageController.text.trim(),
                  firstAid: firstAidController.text.trim(),
                ));
                Navigator.pop(ctx);
                _toast(context,
                    'Chemical safety note saved — reflected in Chemical Hub.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSlot(BuildContext context, CampusDataService data) {
    final dayController = TextEditingController(text: 'Monday');
    final hourController = TextEditingController(text: '9:00-10:00');
    final subjectController = TextEditingController();
    final facultyController = TextEditingController();
    final roomController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add / Edit Master Schedule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: dayController,
                  decoration: const InputDecoration(labelText: 'Day')),
              const SizedBox(height: 10),
              TextField(
                  controller: hourController,
                  decoration: const InputDecoration(labelText: 'Hour')),
              const SizedBox(height: 10),
              TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 10),
              TextField(
                  controller: facultyController,
                  decoration: const InputDecoration(labelText: 'Faculty')),
              const SizedBox(height: 10),
              TextField(
                  controller: roomController,
                  decoration: const InputDecoration(labelText: 'Room')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (subjectController.text.trim().isEmpty) return;
              data.addOrUpdateMasterSlot(TimetableSlot(
                day: dayController.text.trim(),
                hour: hourController.text.trim(),
                subject: subjectController.text.trim(),
                faculty: facultyController.text.trim(),
                room: roomController.text.trim(),
              ));
              Navigator.pop(ctx);
              _toast(context,
                  'Schedule updated — visible on Student & Faculty dashboards.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReport(BuildContext context, Map<String, double> report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Global Attendance Report'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: report.entries
                .map((e) => ListTile(
                      title: Text(e.key),
                      trailing: Text('${e.value.toStringAsFixed(1)}%'),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _broadcast(BuildContext context, CampusDataService data, AppUser user) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Broadcast Campus-Wide Notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(
                controller: bodyController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              data.broadcastNotice(NoticeItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                body: bodyController.text.trim(),
                postedBy: user.name,
                scope: 'global',
                postedOn: DateTime.now(),
              ));
              Navigator.pop(ctx);
              _toast(context, 'Broadcast sent to all students & faculty.');
            },
            child: const Text('Broadcast'),
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



class AdminProfileTab extends StatelessWidget {
  const AdminProfileTab({super.key});

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
