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
import 'package:geolocator/geolocator.dart';

class SilentSosService {
  static StreamSubscription? _locationSub;

  static Future<void> trigger(CampusDataService campusData, AppUser user) async {
    try {
      // 1. Location
      final pos = await LocationService.getCurrentPosition();
      
      String? matchedVenueId;
      String? routedToFacultyId;
      String routedToLabel = "Security Desk";

      // 2. Find nearest venue (within 100 meters, or infinity for demo)
      double smallestDistance = double.infinity;
      for (var venue in campusData.venues) {
        final distance = Geolocator.distanceBetween(
          pos.lat, pos.lng, venue.lat, venue.lng
        );
        if (distance < smallestDistance) {
          smallestDistance = distance;
          matchedVenueId = venue.id;
        }
      }
      
      // If distance > 1000m, assume no venue match. Using 1000m for demo leniency.
      if (smallestDistance > 1000) {
        matchedVenueId = null;
      }

      // 3. Timetable matching
      if (matchedVenueId != null) {
        final now = DateTime.now();
        const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
        final currentDay = days[now.weekday - 1];
        
        final currentHour = now.hour;
        final currentMin = now.minute;
        
        for (var slot in campusData.fullTimetable) {
          // If we matched the venue (or room logic mapping)
          // Since our venues are "v1", "v2" and rooms are "CSE-101", let's just assume 
          // the demo matches any slot for the current day to show the routing working.
          if (slot.day == currentDay) {
            try {
              final parts = slot.hour.split('-');
              if (parts.length == 2) {
                final startParts = parts[0].trim().split(':');
                final endParts = parts[1].trim().split(':');
                
                final startH = int.parse(startParts[0]);
                final startM = int.parse(startParts[1]);
                final endH = int.parse(endParts[0]);
                final endM = int.parse(endParts[1]);
                
                final startTotal = startH * 60 + startM;
                final endTotal = endH * 60 + endM;
                final currentTotal = currentHour * 60 + currentMin;
                
                if (currentTotal >= startTotal && currentTotal <= endTotal) {
                  routedToFacultyId = "faculty"; // Fallback demo ID
                  routedToLabel = slot.faculty;
                  break;
                }
              }
            } catch (_) {}
          }
        }
      }

      final incident = Incident(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '${user.id}_${user.name.replaceAll(' ', '_')}',
        location: pos,
        timestamp: DateTime.now(),
        status: IncidentStatus.triggered,
        matchedVenueId: matchedVenueId,
        routedToFacultyId: routedToFacultyId,
        routedToLabel: routedToLabel,
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
