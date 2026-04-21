import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      return;
    } catch (_) {
      // Fall back to dart-define options for Web/Desktop when no platform file is present.
    }

    final apiKey = const String.fromEnvironment('FIREBASE_API_KEY');
    final appId = const String.fromEnvironment('FIREBASE_APP_ID');
    final messagingSenderId = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID');

    if (apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty || projectId.isEmpty) {
      throw Exception(
        'Firebase is not configured. Add google-services.json/GoogleService-Info.plist '
        'or pass FIREBASE_* --dart-define values.',
      );
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        measurementId: const String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
      ),
    );

    if (kDebugMode) {
      debugPrint('Firebase initialized with dart-define options.');
    }
  }
}
