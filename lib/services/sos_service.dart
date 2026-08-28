import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class SosService {
  /// Simulates POSTing the incident to the backend.
  static Future<void> triggerIncident(Incident incident) async {
    // In a real app, this would be an HTTP POST to /api/incidents
    debugPrint('🚨 [SOS Service] POSTing incident to backend...');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network latency
    debugPrint('✅ [SOS Service] Incident ${incident.id} created successfully!');
  }

  /// Simulates opening a WebSocket and streaming location updates to the admin.
  static void streamLocationUpdates(String incidentId, Stream<GeoPoint> stream) {
    debugPrint('🔌 [SOS Service] Opening WebSocket for incident: $incidentId');
    
    stream.listen((geoPoint) {
      // In a real app, this would be channel.sink.add(jsonEncode(...))
      debugPrint('📍 [SOS Service] Streamed location update: ${geoPoint.lat}, ${geoPoint.lng}');
    }, onError: (error) {
      debugPrint('❌ [SOS Service] WebSocket stream error: $error');
      // Here you would implement fallback polling
    }, onDone: () {
      debugPrint('🔒 [SOS Service] WebSocket closed.');
    });
  }

  /// Simulates uploading a compressed photo via multipart/form-data.
  static Future<void> uploadPhoto(String incidentId, File photo) async {
    debugPrint('📸 [SOS Service] Uploading photo for incident: $incidentId...');
    final bytes = await photo.length();
    debugPrint('   [SOS Service] Photo size: ${(bytes / 1024).toStringAsFixed(2)} KB');
    
    await Future.delayed(const Duration(seconds: 2)); // Simulate upload
    debugPrint('✅ [SOS Service] Photo uploaded and attached to incident!');
  }
}
