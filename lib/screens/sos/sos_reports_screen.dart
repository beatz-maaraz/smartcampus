import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/campus_data_service.dart';
import '../../config/constants.dart';
import '../../widgets/widgets.dart';

class SOSReportsScreen extends StatelessWidget {
  const SOSReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('SOS Reports'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Consumer<CampusDataService>(
        builder: (ctx, data, _) {
          final incidents = data.incidents.toList();
          incidents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          if (incidents.isEmpty) {
            return const Center(
              child: EmptyState(
                message: 'No SOS reports available.',
                icon: Icons.history,
              ),
            );
          }
          
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: SectionHeader(title: 'SOS Incident History'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return IncidentCard(
                        incident: incidents[index],
                        data: data,
                      );
                    },
                    childCount: incidents.length,
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
