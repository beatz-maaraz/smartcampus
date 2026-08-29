import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/campus_data_service.dart';
import '../../config/constants.dart';
import '../../widgets/widgets.dart';

class SOSDashboard extends StatelessWidget {
  const SOSDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('SOS Alerts'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Consumer<CampusDataService>(
        builder: (ctx, data, _) {
          final activeIncidents = data.incidents.where((i) => i.status != IncidentStatus.resolved).toList();
          activeIncidents.sort((a, b) {
            final pA = a.priorityLevel;
            final pB = b.priorityLevel;
            if (pA != pB) return pA.compareTo(pB);
            return b.timestamp.compareTo(a.timestamp);
          });
          
          if (activeIncidents.isEmpty) {
            return const Center(
              child: EmptyState(
                message: 'No active SOS alerts.',
                icon: Icons.check_circle_outline,
              ),
            );
          }
          
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: SectionHeader(title: '🚨 CRITICAL: Active SOS Incidents'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return IncidentCard(
                        incident: activeIncidents[index],
                        data: data,
                      );
                    },
                    childCount: activeIncidents.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
