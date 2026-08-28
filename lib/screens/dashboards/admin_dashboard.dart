import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../../services/campus_data_service.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<CampusDataService>();
    final user = auth.currentUser!;
    final report = data.globalAttendanceReport();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout), onPressed: () => auth.logout()),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await data.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(kPad),
          children: [
            Text('Welcome, ${user.name} 👋',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const SectionHeader(title: '🚨 CRITICAL: Active SOS Incidents'),
            if (data.incidents.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No active incidents at the moment.')))
            else ...[
              ...data.incidents.map(
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
              childAspectRatio: 1.4,
              children: [
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
