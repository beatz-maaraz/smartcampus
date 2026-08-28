import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';
import '../../widgets/widgets.dart';

/// Full weekly schedule. Application Flow §3.2: "Time Table — View the
/// full schedule (beyond just today)".
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<CampusDataService>();
    final timetable = data.fullTimetable;

    return DefaultTabController(
      length: _days.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Time Table'),
          bottom: TabBar(
            isScrollable: true,
            tabs: _days.map((d) => Tab(text: d)).toList(),
          ),
        ),
        body: TabBarView(
          children: _days.map((day) {
            final slots = timetable.where((t) => t.day == day).toList();
            if (slots.isEmpty) {
              return const EmptyState(message: 'No classes scheduled.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(kPad),
              itemCount: slots.length,
              itemBuilder: (_, i) {
                final s = slots[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.class_outlined,
                          color: Colors.white, size: 18),
                    ),
                    title: Text(s.subject),
                    subtitle: Text('${s.hour} • ${s.faculty} • ${s.room}'),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
