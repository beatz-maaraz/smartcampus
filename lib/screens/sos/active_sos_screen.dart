import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/campus_data_service.dart';
import '../../services/location_service.dart';
import '../../services/sos_service.dart';

class ActiveSOSScreen extends StatefulWidget {
  const ActiveSOSScreen({super.key});

  @override
  State<ActiveSOSScreen> createState() => _ActiveSOSScreenState();
}

class _ActiveSOSScreenState extends State<ActiveSOSScreen> {
  Incident? _incident;
  bool _isInitializing = true;
  StreamSubscription<GeoPoint>? _locationSub;

  @override
  void initState() {
    super.initState();
    _triggerSOS();
  }

  Future<void> _triggerSOS() async {
    try {
      final auth = context.read<AuthService>();
      final user = auth.currentUser!;

      // 1. Get high-accuracy initial fix
      final pos = await LocationService.getCurrentPosition();

      // 2. Create local incident
      final incident = Incident(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.id,
        location: pos,
        timestamp: DateTime.now(),
        status: IncidentStatus.triggered,
      );

      setState(() {
        _incident = incident;
        _isInitializing = false;
      });

      // 3. Trigger backend POST
      await SosService.triggerIncident(incident);

      // Track globally in CampusDataService
      if (mounted) {
        context.read<CampusDataService>().addOrUpdateIncident(incident);
      }

      // Trigger automatic background camera captures
      _captureAutoPhotos(incident.id);

      // 4. Start streaming live location updates
      final stream = LocationService.watchPosition();
      SosService.streamLocationUpdates(incident.id, stream);

      _locationSub = stream.listen((newPos) {
        // We could update local state if we want to show it, but SosService handles sending
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error triggering SOS: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _captureAutoPhotos(String incidentId) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      CameraDescription? backCamera;
      CameraDescription? frontCamera;

      for (var cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.back) {
          backCamera = cam;
        } else if (cam.lensDirection == CameraLensDirection.front) {
          frontCamera = cam;
        }
      }

      List<CameraDescription> sequence = [];
      if (backCamera != null) sequence.add(backCamera);
      if (frontCamera != null) sequence.add(frontCamera);
      if (backCamera != null) sequence.add(backCamera);

      if (sequence.isEmpty && cameras.isNotEmpty) {
        sequence = [cameras.first, cameras.first, cameras.first];
      }

      for (var cam in sequence.take(3)) {
        final controller = CameraController(
          cam,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await controller.initialize();
        // Give the camera a moment to adjust exposure/focus
        await Future.delayed(const Duration(milliseconds: 600));

        final xFile = await controller.takePicture();
        await controller.dispose();

        // Compress and upload
        final File file = File(xFile.path);
        final dir = await getTemporaryDirectory();
        final targetPath =
            '${dir.path}/auto_sos_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: 70,
          minWidth: 1280,
          minHeight: 720,
        );

        if (compressedFile != null) {
          if (mounted) {
            final dataService = context.read<CampusDataService>();
            final url = await dataService.uploadSOSPhoto(
                File(compressedFile.path),
                'sos_${incidentId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

            if (url != null) {
              final currentIncident = dataService.incidents.firstWhere(
                  (i) => i.id == incidentId,
                  orElse: () => _incident!);
              currentIncident.photoUrls.add(url);
              dataService.addOrUpdateIncident(currentIncident);
              if (mounted) {
                setState(() {
                  _incident = currentIncident;
                });
              }
            }
          }
          await SosService.uploadPhoto(incidentId, File(compressedFile.path));
        }
      }
    } catch (e) {
      debugPrint("Auto-capture failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('SOS ACTIVE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isInitializing
            ? const CircularProgressIndicator(color: Colors.white)
            : _incident == null
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 100, color: Colors.white),
                        const SizedBox(height: 24),
                        const Text(
                          'Failed to trigger SOS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Please ensure location permissions are granted and GPS is enabled, then try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isInitializing = true;
                            });
                            _triggerSOS();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry SOS'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.red.shade900,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white70),
                          label: const Text('Go Back',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 100, color: Colors.white),
                      const SizedBox(height: 24),
                      const Text(
                        'Help is on the way.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your live location is being shared with campus security.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 48),
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 24),
                      const Text(
                        'Photos are being automatically captured and uploaded to security in the background...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          // Optionally, send a cancel/resolve request to the backend here
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.cancel, color: Colors.white70),
                        label: const Text('Cancel SOS & Go Back',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
      ),
    );
  }
}
