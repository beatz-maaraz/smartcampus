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
    // Sort notices so newest appear first
    final notices = List.of(data.notices)
      ..sort((a, b) => b.postedOn.compareTo(a.postedOn));

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light, clean background
      appBar: AppBar(
        title: const Text('Notices & Announcements',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: notices.isEmpty
          ? const EmptyState(
              message: 'You\'re all caught up!\nNo new notices.',
              icon: Icons.notifications_off_outlined)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: notices.length,
              itemBuilder: (context, i) {
                final n = notices[i];
                final isGlobal = n.scope == 'global';
                
                // Determine styling based on scope
                final accentColor = isGlobal ? Colors.indigo : Colors.teal;
                final icon = isGlobal ? Icons.campaign_rounded : Icons.label_important_rounded;
                final badgeLabel = isGlobal ? 'CAMPUS-WIDE' : n.scope.toUpperCase();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left color bar indicator
                          Container(
                            width: 6,
                            color: accentColor,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row with Icon, Badge and Time
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(icon, color: accentColor, size: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('MMM d').format(n.postedOn),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Title
                                  Text(
                                    n.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                  
                                  // Body
                                  if (n.body.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      n.body,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 12),
                                  Divider(height: 1, color: Colors.grey[200]),
                                  const SizedBox(height: 12),
                                  
                                  // Footer
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Posted by ${n.postedBy}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('h:mm a').format(n.postedOn),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

