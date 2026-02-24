import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  /// Production → (default)
  /// Debug or Dev → db-dev
  static FirebaseFirestore get db {
    if (kReleaseMode) {
      // PRODUCTION
      return FirebaseFirestore.instance;
    } else {
      // DEV or DEBUG
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'db-dev', // <-- change according to need
      );
    }
  }
}
