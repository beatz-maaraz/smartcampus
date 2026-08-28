import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/campus_data_service.dart';
import '../services/auth_service.dart';
import '../config/constants.dart';

class IncidentCard extends StatefulWidget {
  final Incident incident;
  final CampusDataService data;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.data,
  });

  @override
  State<IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends State<IncidentCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.incident.status == IncidentStatus.triggered) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant IncidentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.incident.status == IncidentStatus.triggered && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.incident.status == IncidentStatus.resolved && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTriggered = widget.incident.status == IncidentStatus.triggered;
    
    final int hour = widget.incident.timestamp.hour;
    final String minute = widget.incident.timestamp.minute.toString().padLeft(2, '0');
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final String timeString = '$hour12:$minute $period';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              if (isTriggered)
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.15 + (pulse * 0.2)),
                  blurRadius: 12 + (pulse * 12),
                  spreadRadius: 2 + (pulse * 6),
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
            border: Border.all(
              color: isTriggered ? AppColors.danger.withValues(alpha: 0.5 + (pulse * 0.5)) : Colors.grey.shade200,
              width: isTriggered ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  gradient: LinearGradient(
                    colors: isTriggered
                        ? [Colors.red.shade800, Colors.red.shade500]
                        : [Colors.green.shade700, Colors.green.shade500],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isTriggered ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTriggered ? 'ACTIVE EMERGENCY' : 'RESOLVED INCIDENT',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'User: ${widget.incident.userId.replaceAll('_', ' ')}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        timeString,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Body
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on, color: AppColors.danger, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Last Known Location', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.incident.location.lat.toStringAsFixed(5)}, ${widget.incident.location.lng.toStringAsFixed(5)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${widget.incident.location.lat},${widget.incident.location.lng}');
                              try {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open map application.')));
                                }
                              }
                            },
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Routing Information
                    if (widget.incident.routedToLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.route, color: AppColors.accent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Nearest Faculty Routed To', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.incident.routedToLabel!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.incident.etaMinutes != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.safe.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'ETA: ${widget.incident.etaMinutes} min',
                                  style: const TextStyle(color: AppColors.safe, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Photos Section
                    const Text('Live Auto-Captured Photos', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    if (widget.incident.photoUrls.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.incident.photoUrls.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(width: 12),
                          itemBuilder: (ctx, idx) {
                            final photoUrl = widget.incident.photoUrls[idx];
                            return GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(photoUrl);
                                try {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open photo.')));
                                  }
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  photoUrl,
                                  height: 100,
                                  width: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 100,
                                    width: 140,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Awaiting background photo uploads...',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      
                    // Actions
                    if (isTriggered) ...[
                      const SizedBox(height: 20),
                      if (widget.incident.acknowledgedAt == null)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final auth = Provider.of<AuthService>(context, listen: false);
                              final user = auth.currentUser!;
                              
                              final ack = Incident(
                                id: widget.incident.id,
                                userId: widget.incident.userId,
                                location: widget.incident.location,
                                timestamp: widget.incident.timestamp,
                                photoUrls: widget.incident.photoUrls,
                                status: widget.incident.status,
                                matchedVenueId: widget.incident.matchedVenueId,
                                routedToFacultyId: user.id,
                                routedToLabel: '${user.role.label} ${user.name}',
                                acknowledgedAt: DateTime.now(),
                                etaMinutes: 3,
                              );
                              widget.data.addOrUpdateIncident(ack);
                            },
                            icon: const Icon(Icons.directions_run),
                            label: const Text('ACKNOWLEDGE (ETA 3 MIN)', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      if (widget.incident.acknowledgedAt == null) const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final auth = Provider.of<AuthService>(context, listen: false);
                            final user = auth.currentUser!;
                            
                            final resolved = Incident(
                              id: widget.incident.id,
                              userId: widget.incident.userId,
                              location: widget.incident.location,
                              timestamp: widget.incident.timestamp,
                              photoUrls: widget.incident.photoUrls,
                              status: IncidentStatus.resolved,
                              matchedVenueId: widget.incident.matchedVenueId,
                              routedToFacultyId: user.id,
                              routedToLabel: 'Resolved by ${user.role.label} ${user.name}',
                              acknowledgedAt: widget.incident.acknowledgedAt ?? DateTime.now(),
                              etaMinutes: widget.incident.etaMinutes,
                            );
                            widget.data.addOrUpdateIncident(resolved);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident marked as resolved.')));
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('MARK AS RESOLVED', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.safe.withValues(alpha: 0.1),
                            foregroundColor: AppColors.safe,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.safe, width: 1.5),
                            ),
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
      },
    );
  }
}
