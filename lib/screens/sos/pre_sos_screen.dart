import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/location_service.dart';
import '../../widgets/sos_button_widget.dart';
import 'active_sos_screen.dart';

class PreSOSScreen extends StatefulWidget {
  const PreSOSScreen({super.key});

  @override
  State<PreSOSScreen> createState() => _PreSOSScreenState();
}

class _PreSOSScreenState extends State<PreSOSScreen> {
  String _selectedEmergencyType = 'Other';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Medical Emergency', 'icon': Icons.local_hospital_rounded, 'color': Colors.red, 'desc': 'Injury or illness'},
    {'name': 'Fire', 'icon': Icons.local_fire_department_rounded, 'color': Colors.orange, 'desc': 'Smoke, gas, or fire'},
    {'name': 'Threat/Violence', 'icon': Icons.security_rounded, 'color': Colors.amber.shade700, 'desc': 'Personal danger'},
    {'name': 'Other', 'icon': Icons.warning_rounded, 'color': Colors.grey.shade700, 'desc': 'General incident'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Select Emergency Type',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isSelected = _selectedEmergencyType == cat['name'];
                final color = cat['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedEmergencyType = cat['name'];
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat['icon'] as IconData, color: isSelected ? color : Colors.grey.shade600, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          cat['name'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? color : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat['desc'] as String,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            const Text(
              'Hold the button below for 2 seconds to trigger emergency routing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 24),
            SOSButtonWidget(
              size: 130,
              onTriggered: () async {
                await Permission.camera.request();
                try {
                  await LocationService.ensurePermission();
                } catch (_) {}

                if (!context.mounted) return;

                // Push replacement directly to ActiveSOSScreen with selected emergencyType
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ActiveSOSScreen(emergencyType: _selectedEmergencyType),
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
