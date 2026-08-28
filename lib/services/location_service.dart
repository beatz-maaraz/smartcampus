import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static Future<void> ensurePermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    if (kIsWeb) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }
      return;
    }

    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied) {
        throw Exception('Foreground location permissions are denied');
      }
    }

    if (status.isPermanentlyDenied) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Now request background location ("Always")
    final alwaysStatus = await Permission.locationAlways.status;
    if (alwaysStatus.isDenied) {
      await Permission.locationAlways.request();
    }
  }

  /// Gets the current high-accuracy position.
  static Future<GeoPoint> getCurrentPosition() async {
    await ensurePermission();
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return GeoPoint(lat: position.latitude, lng: position.longitude);
  }

  /// Streams location updates every 10 meters.
  static Stream<GeoPoint> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((pos) => GeoPoint(lat: pos.latitude, lng: pos.longitude));
  }
}
