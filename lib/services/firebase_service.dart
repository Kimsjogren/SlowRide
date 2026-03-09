import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  bool _enabled = false;

  static const bool _firebaseRequested = bool.fromEnvironment(
    'ENABLE_FIREBASE',
    defaultValue: false,
  );

  bool get isEnabled => _enabled;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (!_firebaseRequested) {
      _enabled = false;
      _initialized = true;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _enabled = true;
    } catch (_) {
      _enabled = false;
    }

    _initialized = true;
  }
}
