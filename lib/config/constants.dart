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
  static const primary = Color(0xFF2E5CFF);
  static const primaryDark = Color(0xFF1A3FCC);
  static const accent = Color(0xFF00C2A8);
  static const bgLight = Color(0xFFF5F7FB);
  static const cardLight = Colors.white;
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFF5A623);
  static const safe = Color(0xFF34C759);
  static const textPrimary = Color(0xFF1B1F3B);
  static const textSecondary = Color(0xFF6B7280);
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
const double kRadius = 16.0;
