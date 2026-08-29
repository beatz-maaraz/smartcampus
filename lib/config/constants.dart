import 'package:flutter/material.dart';

/// Central place for colors, spacing, static strings and role enums.
/// Keeping this in one flat file (per project convention: lib/ files are
/// flat, no nested folders) so every screen imports one predictable source.

enum UserRole { student, faculty, admin }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.faculty:
        return 'Faculty';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class AppColors {
  static const primary = Color(0xFF4F46E5); // Royal Indigo
  static const primaryDark = Color(0xFF312E81); // Indigo 900
  static const accent = Color(0xFF0EA5E9); // Bright Sky Blue
  static const bgLight = Color(0xFFFDFDFF); // Soft Lavender-White
  static const cardLight = Colors.white;
  static const danger = Color(0xFFEF4444); // Red 500
  static const warning = Color(0xFFF59E0B); // Amber 500
  static const safe = Color(0xFF10B981); // Emerald 500
  static const textPrimary = Color(0xFF0F172A); // Slate 900
  static const textSecondary = Color(0xFF64748B); // Slate 500
}

class AppStrings {
  static const appName = 'AI Campus Assistant';
  static const teamName = 'Team Artemis';
  static const collegeName = 'Selvam College of Technology';
}

/// Demo / prototype credentials — matches Section 2.1 of the Application
/// Flow document. NOTE: these must never ship in a production build.
/// They exist here only so the app is runnable/demo-able before real
/// firebase_auth accounts are provisioned. See AuthService for the toggle.
class DemoCredentials {
  static const studentId = 'student';
  static const studentPassword = 'student123';
  static const facultyId = 'faculty';
  static const facultyPassword = 'faculty123';
  static const adminId = 'admin';
  static const adminPassword = 'admin123';
}

const double kPad = 16.0;
const double kRadius = 24.0;

class CloudinaryConfig {
  static const cloudName = 'vzjyyvtp';
  static const apiKey = '544988352783325';
  static const apiSecret = 'i2aP4Pw52Y9Ahh5kAZVCsJRBcJU';
}

class EmergencyType {
  static const medical = 'Medical';
  static const fire = 'Fire';
  static const threat = 'Threat';
  static const other = 'Other';

  static const all = [medical, fire, threat, other];

  static String emoji(String type) {
    switch (type) {
      case medical:
        return '🏥';
      case fire:
        return '🔥';
      case threat:
        return '⚠️';
      default:
        return '🚨';
    }
  }
}
