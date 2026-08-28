import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';
import '../models/models.dart';

class AuthService extends ChangeNotifier {
  static const bool demoMode = false; // Turned off for Firebase integration

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  static const _prefsKeyId = 'session_user_id';
  static const _prefsKeyRole = 'session_user_role';
  static const _prefsKeyName = 'session_user_name';

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKeyId);
    final roleStr = prefs.getString(_prefsKeyRole);
    final name = prefs.getString(_prefsKeyName);
    
    // Also verify firebase auth
    final user = FirebaseAuth.instance.currentUser;

    if (id != null && roleStr != null && name != null && user != null) {
      final role = UserRole.values.firstWhere((r) => r.name == roleStr);
      _currentUser = AppUser(id: id, name: name, role: role);
      notifyListeners();
    } else {
      await logout();
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
    // ... demo login omitted ...
    return 'Demo mode is disabled.';
  }

  Future<String?> _firebaseLogin({
    required UserRole role,
    required String id,
    required String password,
  }) async {
    final email = '$id@campus.edu';
    
    try {
      // 1. Attempt to sign in
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, 
        password: password,
      );
      return await _checkRoleAndSetUser(cred.user!, role, id);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        if (role != UserRole.admin) {
          return 'Account not found. Please contact the Admin to create your account.';
        }
        
        // 2. Auto-register hack for Admin only (prototype fallback)
        try {
          final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email, 
            password: password,
          );
          
          // Create the Firestore doc
          await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
            'role': role.name,
            'id': id,
            'name': 'Admin $id', // Placeholder name
          });

          // Return user immediately using the new Firestore logic
          return await _checkRoleAndSetUser(FirebaseAuth.instance.currentUser!, role, id);
        } on FirebaseAuthException catch (regErr) {
          if (regErr.code == 'email-already-in-use') {
            return 'Invalid password. Please try again.';
          }
          return 'Failed to register admin: ${regErr.message}';
        }
      }
      return 'Login failed: ${e.message}';
    } catch (e) {
      return 'An error occurred: $e';
    }
  }

  Future<String?> adminCreateUser({
    required UserRole role,
    required String id,
    required String password,
    required String name,
  }) async {
    if (_currentUser?.role != UserRole.admin) return 'Access Denied.';
    
    final email = '$id@campus.edu';
    try {
      // Use a secondary app so the current Admin isn't logged out
      FirebaseApp app;
      try {
        app = Firebase.app('SecondaryApp');
      } catch (e) {
        app = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }
      
      final cred = await FirebaseAuth.instanceFor(app: app).createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      // We must write to Firestore using the PRIMARY app where Admin is logged in.
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'role': role.name,
        'id': id,
        'name': name,
      });

      await app.delete();
      return null;
    } catch (e) {
      return 'Failed to create user: $e';
    }
  }

  Future<String?> _checkRoleAndSetUser(User firebaseUser, UserRole expectedRole, String id) async {
    // Fetch user details from Firestore directly (no need for Custom Claims)
    final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
    
    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return 'User profile not found.';
    }

    final data = doc.data()!;
    final name = data['name'] ?? 'User $id';
    final roleStr = data['role'] as String? ?? expectedRole.name;
    
    final assignedRole = UserRole.values.firstWhere((r) => r.name == roleStr, orElse: () => expectedRole);
    
    if (assignedRole != expectedRole) {
       await FirebaseAuth.instance.signOut();
       return 'Access Denied. You are registered as ${assignedRole.name}, not ${expectedRole.name}.';
    }

    _currentUser = AppUser(id: id, name: name, role: assignedRole, department: 'CSE');
    await _persistSession();
    notifyListeners();
    return null;
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyId, _currentUser!.id);
    await prefs.setString(_prefsKeyRole, _currentUser!.role.name);
    await prefs.setString(_prefsKeyName, _currentUser!.name);
  }

  Future<void> logout() async {
    _currentUser = null;
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyId);
    await prefs.remove(_prefsKeyRole);
    await prefs.remove(_prefsKeyName);
    notifyListeners();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
