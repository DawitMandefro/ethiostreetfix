import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_role.dart';
import 'cloudinary_service.dart';

class AuthService {
  // Lazy access to FirebaseAuth so code won't throw at import time when
  // Firebase isn't initialized (useful for local/dev/demo runs and tests).
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  FirebaseAuth? get _safeAuth {
    _auth ??= _tryGetAuth();
    return _auth;
  }

  FirebaseFirestore? get _safeFirestore {
    _firestore ??= _tryGetFirestore();
    return _firestore;
  }

  // Cached role for synchronous access in UI
  static UserRole? _cachedRole;

  // Local demo profiles for offline mode (email -> profile map)
  static final Map<String, Map<String, dynamic>> _localProfiles = {};

  static FirebaseAuth? _tryGetAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  static FirebaseFirestore? _tryGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Safe stream that doesn't throw when Firebase isn't initialized.
  static Stream<User?> authStateChangesSafe() {
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (e) {
      // Firebase unavailable — return a stream that emits null (signed out)
      print('authStateChangesSafe: Firebase unavailable: $e');
      return Stream<User?>.value(null);
    }
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      final auth = _safeAuth;
      if (auth == null) throw Exception('Auth backend unavailable');
      UserCredential result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _loadRoleForUser(result.user);
      return result.user;
    } catch (e) {
      // Log and return null (caller shows friendly message)
      print('AuthService.signIn error: ${e.toString()}');
      return null;
    }
  }

  // Sign in with Google (interactive)
  Future<User?> signInWithGoogle() async {
    try {
      final auth = _safeAuth;
      if (auth == null) throw Exception('Auth backend unavailable');

      if (kIsWeb) {
        // Use Firebase web popup flow
        final provider = GoogleAuthProvider();
        final result = await auth.signInWithPopup(provider);
        await _loadRoleForUser(result.user);
        return result.user;
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await auth.signInWithCredential(credential);
      // load role for this user into cache
      await _loadRoleForUser(result.user);
      return result.user;
    } catch (e) {
      print('AuthService.signInWithGoogle error: ${e.toString()}');
      return null;
    }
  }

  // Sign out (also disconnect GoogleSignIn session)
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _safeAuth?.signOut();
    _cachedRole = null;
  }

  // Persist role in Firestore for the current user
  Future<void> setRole(UserRole role) async {
    final auth = _safeAuth;
    final firestore = _safeFirestore;
    _cachedRole = role;
    final user = auth?.currentUser;
    if (user == null || firestore == null) return;
    await firestore.collection('users').doc(user.uid).set({
      'role': role.name,
      'email': user.email,
    }, SetOptions(merge: true));
  }

  // Static convenience wrapper
  static Future<void> saveRole(UserRole role) => AuthService().setRole(role);

  // Set cached role only (no backend persistence). Useful for navigation
  // flows where we want the UI to reflect an expected role immediately
  // without necessarily writing to Firestore.
  static void cacheRole(UserRole role) => _cachedRole = role;

  // Load role for a user and cache it (internal)
  // SRS Section 3.1: RBAC implementation
  Future<void> _loadRoleForUser(User? user) async {
    if (user == null) return;
    try {
      final firestore = _safeFirestore;
      if (firestore == null) {
        _cachedRole = UserRole.citizen;
        return;
      }
      final doc = await firestore.collection('users').doc(user.uid).get();
      final roleStr = doc.data()?['role'] as String?;
      switch (roleStr) {
        case 'authority':
          _cachedRole = UserRole.authority;
          break;
        case 'administrator':
          _cachedRole = UserRole.administrator;
          break;
        case 'citizen':
        default:
          _cachedRole = UserRole.citizen;
      }
    } catch (_) {
      _cachedRole = UserRole.citizen;
    }
  }

  // Public: load role for current signed-in user (async)
  Future<void> loadRoleForCurrentUser() async {
    await _loadRoleForUser(_safeAuth?.currentUser);
  }

  // Synchronous getter used by UI code (returns cached or default)
  static UserRole currentUserRole() => _cachedRole ?? UserRole.citizen;

  /// Update the current user's profile. In production this uploads the image
  /// to Cloudinary (if bytes provided), updates Firebase Auth profile and
  /// writes metadata to Firestore's `users` document. In offline/demo mode
  /// it stores profile info in `_localProfiles` keyed by email.
  Future<void> updateProfile({
    String? displayName,
    Uint8List? photoBytes,
    String? photoFilename,
  }) async {
    final auth = _safeAuth;
    final firestore = _safeFirestore;
    final user = auth?.currentUser;

    String? photoUrl;
    try {
      // Upload image if provided
      if (photoBytes != null && user != null) {
        final cloud = CloudinaryService();
        photoUrl = await cloud.uploadImageBytes(
          photoBytes,
          user.uid,
          photoFilename ?? 'profile.jpg',
        );
      }

      if (user != null && firestore != null) {
        // Update FirebaseAuth profile
        try {
          await user.updateDisplayName(displayName);
          if (photoUrl != null) await user.updatePhotoURL(photoUrl);
          // Also update Firestore users doc
          await firestore.collection('users').doc(user.uid).set({
            if (displayName != null) 'displayName': displayName,
            if (photoUrl != null) 'photoUrl': photoUrl,
            'email': user.email,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          print('Error updating Firebase profile: $e');
        }
        return;
      }

      // Local/demo fallback
      final email = user?.email ?? 'demo@local';
      final current =
          _localProfiles[email] ??
          <String, dynamic>{
            'displayName': 'User Name',
            'email': email,
            'photoUrl': null,
            'photoData': null,
          };
      if (displayName != null) current['displayName'] = displayName;
      if (photoUrl != null) {
        current['photoUrl'] = photoUrl;
      } else if (photoBytes != null) {
        // store inline base64 for local preview and tests (avoids network)
        current['photoData'] = base64.encode(photoBytes);
      }
      _localProfiles[email] = current;
    } catch (e) {
      print('AuthService.updateProfile error: $e');
      rethrow;
    }
  }

  /// Get profile map for the current user (reads Firestore if available,
  /// otherwise local fallback). Returned keys: displayName, email, photoUrl.
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final auth = _safeAuth;
    final firestore = _safeFirestore;
    final user = auth?.currentUser;

    if (user != null && firestore != null) {
      try {
        final doc = await firestore.collection('users').doc(user.uid).get();
        final data = doc.data() ?? <String, dynamic>{};
        // Prefer username (signup value) for profile display, then displayName
        final displayName =
            data['username'] ??
            data['displayName'] ??
            user.displayName ??
            'User Name';
        return {
          'displayName': displayName,
          'email': user.email ?? 'Unknown',
          'photoUrl': data['photoUrl'] ?? user.photoURL,
        };
      } catch (_) {
        return {
          'displayName': user.displayName ?? 'User Name',
          'email': user.email ?? 'Unknown',
          'photoUrl': user.photoURL,
        };
      }
    }

    final email = user?.email ?? 'demo@local';
    final local = _localProfiles[email];
    if (local != null) return local;
    return {
      'displayName': 'User Name',
      'email': email,
      'photoUrl': null,
      'photoData': null,
    };
  }
}
