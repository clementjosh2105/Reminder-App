import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuration class for Firebase.
/// Replace the placeholders with your actual Firebase project credentials
/// from your Firebase console console.firebase.google.com
class FirebaseConfig {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for iOS. '
          'Run FlutterFire CLI or add real iOS options before building iOS.',
        );
      default:
        throw UnsupportedError(
          'FirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBW-mjGUM_TLHmmcYSJ5PzOad6Vt7hN3s4',
    appId: '1:881110997358:android:4554bbe6ca84c0d753097f',
    messagingSenderId: '881110997358',
    projectId: 'momentum-501101',
    storageBucket: 'momentum-501101.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBW-mjGUM_TLHmmcYSJ5PzOad6Vt7hN3s4',
    appId: '1:881110997358:web:4554bbe6ca84c0d753097f',
    messagingSenderId: '881110997358',
    projectId: 'momentum-501101',
    storageBucket: 'momentum-501101.firebasestorage.app',
    authDomain: 'momentum-501101.firebaseapp.com',
  );
}
