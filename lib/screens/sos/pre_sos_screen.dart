import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../services/location_service.dart';
import '../../services/campus_data_service.dart';
import '../../services/auth_service.dart';
import '../../services/silent_sos_service.dart';
import '../../widgets/sos_button_widget.dart';

class PreSOSScreen extends StatelessWidget {
  const PreSOSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 80, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              'Emergency SOS',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Hold the button below for 2 seconds to trigger an emergency alert.\n\n'
                'This will instantly notify campus security and share your live location.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
              ),
            ),
            const SizedBox(height: 64),
            // We use the existing SOSButtonWidget here
            SOSButtonWidget(
              size: 140, // We will add a size parameter to SOSButtonWidget
              onTriggered: () async {
                // Request camera explicitly via permission_handler
                await Permission.camera.request();

                // Request location explicitly via Geolocator (avoids conflicts)
                try {
                  await LocationService.ensurePermission();
                } catch (e) {
                  // If location fails here, we still push the screen so it shows the error UI
                }

                if (!context.mounted) return;

                final campusData = context.read<CampusDataService>();
                final user = context.read<AuthService>().currentUser!;

                // Trigger silently in the background
                SilentSosService.trigger(campusData, user);

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'SOS Activated! Security has been notified and live tracking started.'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
