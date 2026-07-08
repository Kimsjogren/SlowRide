// ignore_for_file: deprecated_member_use

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slowride/core/constants/backend_config.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;
  bool _enabled = false;

  bool get isEnabled => _enabled;
  bool get isInitialized => _initialized;

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final url = BackendConfig.supabaseUrl.trim();
    final anonKey = BackendConfig.supabaseAnonKey.trim();

    if (url.isEmpty || anonKey.isEmpty) {
      _enabled = false;
      _initialized = true;
      return;
    }

    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _enabled = true;
    } catch (_) {
      _enabled = false;
    }

    _initialized = true;
  }
}
