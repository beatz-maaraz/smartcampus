import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Student-side Assignments list — what the "Assignments Pending" tile on
/// the Student dashboard opens into. Shows every assignment Faculty have
/// posted (postAssignment in CampusDataService), pending ones first, with
/// a "Mark as submitted" action.
class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<CampusDataService>();
    final assignments = [...data.assignments]..sort((a, b) {
        // Pending first, then soonest due date first.
        if (a.submitted != b.submitted) return a.submitted ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });
    final pendingCount = assignments.where((a) => !a.submitted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              pendingCount == 0
                  ? 'All caught up — nothing pending'
                  : '$pendingCount pending',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ),
      body: assignments.isEmpty
          ? const EmptyState(
              message: 'No assignments posted yet.',
              icon: Icons.assignment_outlined,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(kPad),
              itemCount: assignments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _AssignmentCard(assignment: assignments[i]),
            ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignmentItem assignment;
  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = !assignment.submitted && assignment.dueDate.isBefore(now);
    final statusColor = assignment.submitted
        ? AppColors.safe
        : (isOverdue ? AppColors.danger : AppColors.warning);
    final statusLabel = assignment.submitted
        ? 'Submitted'
        : (isOverdue ? 'Overdue' : 'Pending');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    assignment.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${assignment.subject} • ${assignment.postedBy}',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Due ${DateFormat('MMM d, yyyy').format(assignment.dueDate)}',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? AppColors.danger : AppColors.textSecondary,
                fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (!assignment.submitted) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context
                        .read<CampusDataService>()
                        .markAssignmentSubmitted(assignment.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Marked "${assignment.title}" as submitted.')));
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark as submitted'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
