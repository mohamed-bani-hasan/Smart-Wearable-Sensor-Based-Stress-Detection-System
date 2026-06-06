import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

FirebaseApp? globalFirebaseApp;
DatabaseReference? globalDatabaseRef;

const String firebaseDatabaseUrl =
    'https://stress-detection-d208d-default-rtdb.europe-west1.firebasedatabase.app';

bool get isFirebaseDatabaseReady => globalDatabaseRef != null;

DatabaseReference requireDatabaseRef() {
  final ref = globalDatabaseRef;
  if (ref == null) {
    throw StateError('Firebase Realtime Database is not initialized.');
  }
  return ref;
}

/// Initializes Firebase Core + Realtime Database. Safe to call more than once.
Future<bool> initializeFirebaseServices() async {
  try {
    if (Firebase.apps.isEmpty) {
      globalFirebaseApp = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      globalFirebaseApp = Firebase.app();
    }

    globalDatabaseRef = FirebaseDatabase.instanceFor(
      app: globalFirebaseApp!,
      databaseURL: firebaseDatabaseUrl,
    ).ref();

    return true;
  } catch (e, stack) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('$stack');
    globalDatabaseRef = null;
    return false;
  }
}
