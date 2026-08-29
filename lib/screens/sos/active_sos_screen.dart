import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/campus_data_service.dart';
import '../../services/silent_sos_service.dart';
import '../../services/ai_service.dart';
import '../../config/constants.dart';

class ActiveSOSScreen extends StatefulWidget {
  final String emergencyType;
  const ActiveSOSScreen({super.key, required this.emergencyType});

  @override
  State<ActiveSOSScreen> createState() => _ActiveSOSScreenState();
}

class _ActiveSOSScreenState extends State<ActiveSOSScreen> {
  int _countdownSeconds = 5;
  Timer? _countdownTimer;
  bool _isCountdownActive = true;
  String? _triggeredIncidentId;
  String? _aiGuidance;
  bool _loadingGuidance = false;
  IncidentStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _isCountdownActive = false;
        });
        _triggerSOS();
      }
    });
  }

  Future<void> _triggerSOS() async {
    try {
      final campusData = context.read<CampusDataService>();
      final user = context.read<AuthService>().currentUser!;

      // Trigger standard background SOS
      final incident = await SilentSosService.trigger(
        campusData,
        user,
        emergencyType: widget.emergencyType,
      );

      if (incident != null) {
        setState(() {
          _triggeredIncidentId = incident.id;
        });
        _loadAiGuidance();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error triggering alert: $e')),
        );
      }
    }
  }

  Future<void> _loadAiGuidance() async {
    setState(() {
      _loadingGuidance = true;
    });
    try {
      final aiService = AiService(context.read<CampusDataService>());
      final guidance = await aiService.getEmergencyGuidance(widget.emergencyType);
      if (mounted) {
        setState(() {
          _aiGuidance = guidance;
          _loadingGuidance = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingGuidance = false);
      }
    }
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Trigger cancelled (false alarm).'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campusData = context.watch<CampusDataService>();
    Incident? activeIncident;
    
    if (_triggeredIncidentId != null) {
      try {
        activeIncident = campusData.incidents.firstWhere((i) => i.id == _triggeredIncidentId);
      } catch (_) {}
    }

    final status = activeIncident?.status ?? IncidentStatus.triggered;
    
    if (_lastStatus == IncidentStatus.triggered && status == IncidentStatus.inProgress && activeIncident != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAcknowledgementDialog(activeIncident!);
      });
    }
    _lastStatus = status;
    
    // Dynamic background color mapping based on feedback loop status
    Color backgroundColor;
    if (status == IncidentStatus.resolved) {
      backgroundColor = Colors.blueGrey.shade900;
    } else if (status == IncidentStatus.inProgress) {
      backgroundColor = Colors.teal.shade900; // Blue/Green banner color when Acknowledged!
    } else {
      backgroundColor = Colors.red.shade900; // Flashing alarm Red when pending
    }

    final themeColor = _getEmergencyTypeColor(widget.emergencyType);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isCountdownActive ? 'PREPARING SOS' : 'EMERGENCY SOS ACTIVE',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: _isCountdownActive
              ? _buildCountdownUI(themeColor)
              : _buildActiveSOSUI(activeIncident, themeColor, campusData),
        ),
      ),
    );
  }

  Widget _buildCountdownUI(Color themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 90, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            'Triggering SOS in $_countdownSeconds seconds...',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'A critical safety alert is about to be sent. If this is a mistake, cancel now.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: _countdownSeconds / 5.0,
                    strokeWidth: 8,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white24,
                  ),
                ),
                GestureDetector(
                  onTap: _cancelCountdown,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'CANCEL\n(False Alarm)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSOSUI(Incident? incident, Color themeColor, CampusDataService campusData) {
    final status = incident?.status ?? IncidentStatus.triggered;
    
    // Dynamic status text calculations
    String badgeText;
    IconData headerIcon;
    String titleText;
    String subtitleText;
    Color badgeColor;
    
    if (status == IncidentStatus.resolved) {
      badgeText = 'RESOLVED';
      headerIcon = Icons.verified_user_outlined;
      titleText = 'Situation Resolved';
      subtitleText = 'Safety confirmed. Return to home dashboard.';
      badgeColor = Colors.teal;
    } else if (status == IncidentStatus.inProgress) {
      badgeText = 'RESPONDED';
      headerIcon = Icons.check_circle_outline_rounded;
      titleText = 'Help is on the Way!';
      subtitleText = '${incident?.routedToLabel ?? "Faculty/Admin"} has acknowledged your emergency.';
      badgeColor = Colors.teal;
    } else {
      badgeText = 'PENDING';
      headerIcon = Icons.gpp_maybe_rounded;
      titleText = 'Emergency SOS Dispatched';
      subtitleText = 'Routing to nearest campus responder...';
      badgeColor = Colors.red.shade700;
    }

    return ListView(
      children: [
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      badgeText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Icon(
                headerIcon,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        
        // Acknowledged explicit feedback loop banner card
        if (status == IncidentStatus.inProgress) ...[
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACKNOWLEDGEMENT RECEIVED',
                          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${incident?.routedToLabel ?? "Faculty/Admin"} has responded. Help is arriving in ~${incident?.etaMinutes ?? 3} mins.',
                          style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),
        Card(
          color: Colors.white.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('EMERGENCY DETAILS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.emergencyType.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                _buildInfoRow(Icons.pin_drop_outlined, 'Location status', 'Live GPS Tracking Enabled'),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.person_outline,
                  'Assigned Responder',
                  incident?.routedToLabel ?? 'Security Desk',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.watch_later_outlined,
                  'Response Status',
                  status == IncidentStatus.resolved
                      ? 'Situation Resolved'
                      : (status == IncidentStatus.inProgress
                          ? 'Assistance Dispatched (ETA: ${incident?.etaMinutes ?? 3} min)'
                          : 'Routing to nearest Faculty...'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // AI First-Response guidance
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'AI First-Response Guidance',
                      style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _loadingGuidance
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Text(
                        _aiGuidance ?? 'Fetching safety steps...',
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (status != IncidentStatus.resolved)
          ElevatedButton.icon(
            onPressed: () {
              // Mark incident as resolved / cancelled by student
              if (incident != null) {
                final resolved = Incident(
                  id: incident.id,
                  userId: incident.userId,
                  location: incident.location,
                  timestamp: incident.timestamp,
                  photoUrls: incident.photoUrls,
                  status: IncidentStatus.resolved,
                  matchedVenueId: incident.matchedVenueId,
                  routedToFacultyId: incident.routedToFacultyId,
                  routedToLabel: incident.routedToLabel,
                  acknowledgedAt: incident.acknowledgedAt,
                  etaMinutes: incident.etaMinutes,
                  emergencyType: incident.emergencyType,
                );
                campusData.addOrUpdateIncident(resolved);
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SOS incident marked as resolved.')),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('I am Safe Now (Resolve SOS)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Color _getEmergencyTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'medical emergency':
        return Colors.red;
      case 'fire':
        return Colors.orange;
      case 'threat/violence':
        return Colors.amber.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  void _showAcknowledgementDialog(Incident incident) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            const Text('HELP DISPATCHED', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '${incident.routedToLabel ?? "Faculty/Admin"} has acknowledged your emergency and is arriving in ~${incident.etaMinutes ?? 3} minutes.\n\nKeep calm. Stay where you are.',
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('UNDERSTOOD'),
          ),
        ],
      ),
    );
  }
}
