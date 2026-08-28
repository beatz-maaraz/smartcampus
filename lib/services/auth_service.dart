import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/models.dart';

/// Handles Student / Faculty / Admin login (Application Flow §2).
///
/// DEMO_MODE = true uses the hardcoded prototype credentials from
/// Section 2.1 of the Application Flow doc, so the app can be run and
/// judged without a live Firebase project. Flip DEMO_MODE to false and
/// fill in the firebase_auth calls (stubbed below) once real Student /
/// Faculty / Admin accounts exist in Firebase Authentication.
///
/// Reminder (flagged in the docs, §8.5): demo credentials must never
/// ship in a production/public build.
class AuthService extends ChangeNotifier {
  static const bool demoMode = true;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  static const _prefsKeyId = 'session_user_id';
  static const _prefsKeyRole = 'session_user_role';
  static const _prefsKeyName = 'session_user_name';

  /// Restores a previous session (e.g. app relaunch) from shared_preferences.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKeyId);
    final roleStr = prefs.getString(_prefsKeyRole);
    final name = prefs.getString(_prefsKeyName);
    if (id != null && roleStr != null && name != null) {
      final role = UserRole.values.firstWhere((r) => r.name == roleStr);
      _currentUser = AppUser(id: id, name: name, role: role);
      notifyListeners();
    }
  }

  Future<String?> login({
    required UserRole role,
    required String id,
    required String password,
  }) async {
    if (demoMode) {
      return _demoLogin(role: role, id: id, password: password);
    }
    return _firebaseLogin(role: role, id: id, password: password);
  }

  Future<String?> _demoLogin({
    required UserRole role,
    required String id,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // simulate network

    final ok = switch (role) {
      UserRole.student =>
        id == DemoCredentials.studentId && password == DemoCredentials.studentPassword,
      UserRole.faculty =>
        id == DemoCredentials.facultyId && password == DemoCredentials.facultyPassword,
      UserRole.admin =>
        id == DemoCredentials.adminId && password == DemoCredentials.adminPassword,
    };

    if (!ok) return 'Invalid ID or password. Please try again.';

    final name = switch (role) {
      UserRole.student => 'Demo Student',
      UserRole.faculty => 'Demo Faculty',
      UserRole.admin => 'Demo Admin',
    };

    _currentUser = AppUser(id: id, name: name, role: role, department: 'CSE');
    await _persistSession();
    notifyListeners();
    return null; // null = success
  }

  /// Wire this up once a real Firebase project is attached:
  ///
  /// final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
  ///   email: '$id@campus.edu', password: password,
  /// );
  /// final doc = await FirebaseFirestore.instance
  ///     .collection('users').doc(cred.user!.uid).get();
  /// ... build AppUser from doc.data(), verify role matches `role` ...
  Future<String?> _firebaseLogin({
    required UserRole role,
    required String id,
    required String password,
  }) async {
    throw UnimplementedError(
      'Attach firebase_auth here once the Firebase project is configured. '
      'See the comment above _firebaseLogin for the intended flow.',
    );
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyId, _currentUser!.id);
    await prefs.setString(_prefsKeyRole, _currentUser!.role.name);
    await prefs.setString(_prefsKeyName, _currentUser!.name);
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyId);
    await prefs.remove(_prefsKeyRole);
    await prefs.remove(_prefsKeyName);
    notifyListeners();
  }
}
