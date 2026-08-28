import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricLogin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _biometricLogin = prefs.getBool('setting_biometric') ?? false;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveBiometricSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setting_biometric', value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final campusData = context.watch<CampusDataService>();

    return Scaffold(
      backgroundColor: campusData.isDarkMode ? const Color(0xFF0F172A) : AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(kPad),
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _biometricLogin,
                        title: const Text('Biometric Authentication'),
                        subtitle: const Text('Lock app using fingerprint or Face ID'),
                        activeColor: AppColors.primary,
                        secondary: const Icon(Icons.fingerprint, color: AppColors.primary),
                        onChanged: (val) {
                          setState(() => _biometricLogin = val);
                          _saveBiometricSetting(val);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: campusData.isDarkMode,
                        title: const Text('AI Campus Dark Theme'),
                        subtitle: const Text('Toggle dark color palette for late night study'),
                        activeColor: AppColors.primary,
                        secondary: const Icon(Icons.dark_mode, color: AppColors.primary),
                        onChanged: (val) {
                          campusData.toggleDarkMode(val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
