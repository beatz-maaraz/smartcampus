import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/campus_data_service.dart';

class IncidentCard extends StatelessWidget {
  final Incident incident;
  final CampusDataService data;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isTriggered = incident.status == IncidentStatus.triggered;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isTriggered ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTriggered ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isTriggered ? Colors.red.shade700 : Colors.orange.shade600,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(isTriggered ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTriggered ? 'ACTIVE EMERGENCY' : 'RESOLVED INCIDENT',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'User: ${incident.userId.replaceAll('_', ' ')}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${incident.timestamp.hour.toString().padLeft(2, '0')}:${incident.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS: ${incident.location.lat.toStringAsFixed(5)}, ${incident.location.lng.toStringAsFixed(5)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${incident.location.lat},${incident.location.lng}');
                        try {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open map application.')));
                        }
                      },
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Live Auto-Captured Photos', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (incident.photoUrls.isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: incident.photoUrls.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          incident.photoUrls[idx],
                          height: 120,
                          width: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 120,
                            width: 160,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Awaiting background photo uploads...',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                if (isTriggered) ...[
                  const Divider(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final resolved = Incident(
                          id: incident.id,
                          userId: incident.userId,
                          location: incident.location,
                          timestamp: incident.timestamp,
                          photoUrls: incident.photoUrls,
                          status: IncidentStatus.resolved,
                        );
                        data.addOrUpdateIncident(resolved);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident marked as resolved.')));
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark as Resolved'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
