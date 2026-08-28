import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'location_service.dart';
import 'sos_service.dart';
import 'campus_data_service.dart';

class SilentSosService {
  static StreamSubscription? _locationSub;

  static Future<void> trigger(CampusDataService campusData, AppUser user) async {
    try {
      // 1. Location
      final pos = await LocationService.getCurrentPosition();
      
      final incident = Incident(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '${user.id}_${user.name.replaceAll(' ', '_')}',
        location: pos,
        timestamp: DateTime.now(),
        status: IncidentStatus.triggered,
      );

      // Trigger backend
      await SosService.triggerIncident(incident);
      campusData.addOrUpdateIncident(incident);
      
      // Start streaming location
      _locationSub?.cancel(); // Cancel any existing
      final stream = LocationService.watchPosition();
      SosService.streamLocationUpdates(incident.id, stream);
      _locationSub = stream.listen((newPos) {
        try {
          final currentIncident = campusData.incidents.firstWhere((inc) => inc.id == incident.id);
          if (currentIncident.status == IncidentStatus.triggered) {
            final updatedIncident = Incident(
              id: currentIncident.id,
              userId: currentIncident.userId,
              location: newPos,
              timestamp: currentIncident.timestamp,
              photoUrls: currentIncident.photoUrls,
              status: currentIncident.status,
            );
            campusData.addOrUpdateIncident(updatedIncident);
          } else {
            // Incident was marked as resolved by admin, stop tracking
            stop();
          }
        } catch (_) {}
      });
      
      // 2. Create designated folder: SOS_Alerts/{UserID}_{Timestamp}/
      final folderId = await campusData.createSosFolder(incident.userId, incident.timestamp);
      
      // 3. Fire and forget auto capture
      if (!kIsWeb) {
        _captureAutoPhotos(campusData, incident.id, folderId);
      } else {
        debugPrint('Auto photo capture skipped on Web platform.');
      }
      
    } catch (e) {
      debugPrint("Silent SOS trigger failed: $e");
    }
  }

  static Future<void> _captureAutoPhotos(CampusDataService campusData, String incidentId, String? folderId) async {
    try {
      final cameras = await availableCameras();
      final backCameras = cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
      final frontCameras = cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      
      final sequence = [
        if (backCameras.isNotEmpty) backCameras.first,
        if (backCameras.isNotEmpty) backCameras.first,
        if (frontCameras.isNotEmpty) frontCameras.first,
      ];

      for (int i = 0; i < sequence.length; i++) {
        final cam = sequence[i];
        final controller = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
        await controller.initialize();
        // Give camera time to auto-focus and adjust exposure
        await Future.delayed(const Duration(milliseconds: 600));
        
        final xFile = await controller.takePicture();
        await controller.dispose();

        final File file = File(xFile.path);
        final dir = await getTemporaryDirectory();
        final targetPath = '${dir.path}/auto_sos_${incidentId}_$i.jpg';
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path, targetPath, quality: 70, minWidth: 1280, minHeight: 720,
        );
        
        if (compressedFile != null) {
          final url = await campusData.uploadSOSPhoto(File(compressedFile.path), 'sos_${incidentId}_$i.jpg', folderId: folderId);
          if (url != null) {
            final currentIncident = campusData.incidents.firstWhere((inc) => inc.id == incidentId);
            currentIncident.photoUrls.add(url);
            campusData.addOrUpdateIncident(currentIncident);
          }
        }
      }
    } catch (e) {
      debugPrint("Silent SOS photo capture failed: $e");
    }
  }

  static void stop() {
    _locationSub?.cancel();
    _locationSub = null;
  }
}
