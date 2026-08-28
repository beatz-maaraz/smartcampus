import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';
import '../../widgets/widgets.dart';

/// Reads alerts posted by Faculty (department-specific) and Admin
/// (campus-wide broadcast) — Application Flow §7 "Notification: Read alerts".
class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<CampusDataService>();
    final notices = data.notices;

    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: notices.isEmpty
          ? const EmptyState(
              message: 'No notices yet.',
              icon: Icons.notifications_off_outlined)
          : ListView.builder(
              padding: const EdgeInsets.all(kPad),
              itemCount: notices.length,
              itemBuilder: (_, i) {
                final n = notices[i];
                final isGlobal = n.scope == 'global';
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isGlobal ? Icons.campaign : Icons.notifications_outlined,
                      color:
                          isGlobal ? AppColors.primaryDark : AppColors.primary,
                    ),
                    title: Text(n.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (n.body.isNotEmpty) Text(n.body),
                        const SizedBox(height: 4),
                        Text(
                          '${n.postedBy} • ${isGlobal ? "Campus-wide" : n.scope} • '
                          '${DateFormat('MMM d, h:mm a').format(n.postedOn)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
