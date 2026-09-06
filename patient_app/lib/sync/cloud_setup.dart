import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class CloudSetup {
  static Future<void>? _initialization;
  static bool get configured =>
      const String.fromEnvironment('FIREBASE_PROJECT_ID').isNotEmpty;
  static Future<void> ensureReady() async {
    try {
      await (_initialization ??= _initialize());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static Future<void> _initialize() async {
    if (!configured) throw StateError('Firebase configuration is required');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        ),
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }
}
