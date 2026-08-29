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
    if (widget.incident.status != IncidentStatus.resolved) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant IncidentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.incident.status != IncidentStatus.resolved && !_pulseController.isAnimating) {
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
    final status = widget.incident.status;
    final priority = widget.incident.priorityLevel;
    
    // Determine header appearance dynamically
    String statusTitle;
    List<Color> headerColors;
    
    if (status == IncidentStatus.resolved) {
      statusTitle = 'RESOLVED INCIDENT';
      headerColors = [Colors.green.shade900, Colors.green.shade600];
    } else if (status == IncidentStatus.inProgress) {
      statusTitle = 'ACTIVE EMERGENCY'; // keep active label matching screenshot
      headerColors = [Colors.red.shade900, Colors.red.shade700];
    } else {
      statusTitle = 'ACTIVE EMERGENCY';
      if (priority == 1) {
        headerColors = [Colors.red.shade900, Colors.red.shade700];
      } else if (priority == 2) {
        headerColors = [Colors.orange.shade900, Colors.orange.shade700];
      } else {
        headerColors = [Colors.grey.shade900, Colors.grey.shade600];
      }
    }

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
              if (status != IncidentStatus.resolved)
                BoxShadow(
                  color: priority == 1
                      ? Colors.red.withValues(alpha: 0.15 + (pulse * 0.35))
                      : (priority == 2 
                          ? Colors.orange.withValues(alpha: 0.12 + (pulse * 0.2)) 
                          : Colors.grey.withValues(alpha: 0.1 + (pulse * 0.1))),
                  blurRadius: priority == 1 ? 16 + (pulse * 16) : 10 + (pulse * 10),
                  spreadRadius: priority == 1 ? 3 + (pulse * 6) : 1 + (pulse * 4),
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
            border: Border.all(
              color: status != IncidentStatus.resolved
                  ? (priority == 1 
                      ? Colors.red.withValues(alpha: 0.4 + (pulse * 0.6)) 
                      : (priority == 2 ? Colors.orange.withValues(alpha: 0.3 + (pulse * 0.4)) : Colors.grey.withValues(alpha: 0.2)))
                  : Colors.grey.shade200,
              width: status != IncidentStatus.resolved ? 2 : 1,
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
                    colors: headerColors,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == IncidentStatus.resolved
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded, // warning icon as per screenshot
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                statusTitle,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                              ),
                              if (widget.incident.emergencyType != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.incident.emergencyType!.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: priority == 1
                                      ? Colors.red.shade100
                                      : (priority == 2 ? Colors.orange.shade100 : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'L$priority',
                                  style: TextStyle(
                                    color: priority == 1
                                        ? Colors.red.shade900
                                        : (priority == 2 ? Colors.orange.shade900 : Colors.grey.shade900),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'User: ${widget.incident.userId.replaceAll('_', ' ')}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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
                    // Last Known Location custom row as per screenshot
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.red.shade50,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Last Known Location',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${widget.incident.location.lat.toStringAsFixed(5)}, ${widget.incident.location.lng.toStringAsFixed(5)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openMaps(widget.incident.location.lat, widget.incident.location.lng),
                            icon: const Icon(Icons.map, size: 16, color: Colors.white),
                            label: const Text('Map', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Nearest Faculty Routing custom row as per screenshot
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyan.shade100, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.route_outlined, color: Colors.cyan.shade800, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nearest Faculty Routed To',
                                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.incident.routedToLabel ?? 'Security Desk',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyan.shade900),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'ETA: ${widget.incident.etaMinutes ?? 3} min',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Photo grid
                    const SizedBox(height: 16),
                    const Text(
                      'Live Auto-Captured Photos',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    if (widget.incident.photoUrls.isNotEmpty)
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.incident.photoUrls.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _showPhotoDialog(context, widget.incident.photoUrls[index]),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                  image: DecorationImage(
                                    image: NetworkImage(widget.incident.photoUrls[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else if (status != IncidentStatus.resolved)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Awaiting background photo uploads...',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      
                    // Actions
                    if (status != IncidentStatus.resolved) ...[
                      const SizedBox(height: 20),
                      if (status == IncidentStatus.triggered)
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
                                status: IncidentStatus.inProgress, // assistance dispatched
                                matchedVenueId: widget.incident.matchedVenueId,
                                routedToFacultyId: user.id,
                                routedToLabel: '${user.role.label} ${user.name}',
                                acknowledgedAt: DateTime.now(),
                                etaMinutes: 3,
                                emergencyType: widget.incident.emergencyType,
                              );
                              widget.data.addOrUpdateIncident(ack);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('SOS Acknowledged. Response sent to student.')),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                            label: const Text('ACKNOWLEDGE ALERT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      if (status == IncidentStatus.inProgress)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final resolved = Incident(
                                id: widget.incident.id,
                                userId: widget.incident.userId,
                                location: widget.incident.location,
                                timestamp: widget.incident.timestamp,
                                photoUrls: widget.incident.photoUrls,
                                status: IncidentStatus.resolved,
                                matchedVenueId: widget.incident.matchedVenueId,
                                routedToFacultyId: widget.incident.routedToFacultyId,
                                routedToLabel: widget.incident.routedToLabel,
                                acknowledgedAt: widget.incident.acknowledgedAt ?? DateTime.now(),
                                etaMinutes: widget.incident.etaMinutes,
                                emergencyType: widget.incident.emergencyType,
                              );
                              widget.data.addOrUpdateIncident(resolved);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident marked as resolved.')));
                            },
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            label: const Text('MARK AS RESOLVED', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 0.5, fontSize: 14)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.green, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: Colors.green.shade50.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                    ],
                    
                    if (status == IncidentStatus.resolved) ...[
                      const Divider(height: 32),
                      const Text(
                        'INCIDENT TIMELINE REPORT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTimelineItem(
                        Icons.gpp_maybe_rounded,
                        'SOS Alert Triggered',
                        _formatTime(widget.incident.timestamp),
                        Colors.red,
                      ),
                      if (widget.incident.acknowledgedAt != null) ...[
                        _buildTimelineItem(
                          Icons.directions_run_rounded,
                          'Dispatched & Acknowledged',
                          _formatTime(widget.incident.acknowledgedAt!),
                          Colors.amber.shade700,
                        ),
                        _buildTimelineItem(
                          Icons.assignment_turned_in_rounded,
                          'Faculty Responder: ${widget.incident.routedToLabel}',
                          'Response Time: ${_getResponseTime()}',
                          Colors.blue,
                        ),
                      ],
                      _buildTimelineItem(
                        Icons.check_circle_rounded,
                        'Marked Safe & Resolved',
                        'Incident Closed Successfully',
                        Colors.green,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final int hour = dt.hour;
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }

  String _getResponseTime() {
    if (widget.incident.acknowledgedAt == null) return '0 mins';
    final diff = widget.incident.acknowledgedAt!.difference(widget.incident.timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds} sec';
    return '${diff.inMinutes} min';
  }

  Widget _buildTimelineItem(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(double lat, double lng) async {
    final nativeUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(nativeUrl)) {
        await launchUrl(nativeUrl);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showPhotoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          height: 350,
          width: 350,
          decoration: BoxDecoration(
            image: DecorationImage(image: NetworkImage(url), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
