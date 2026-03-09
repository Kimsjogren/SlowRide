import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slowride/services/supabase_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
  final ValueNotifier<String?> userName = ValueNotifier<String?>(null);
  final ValueNotifier<String?> userEmail = ValueNotifier<String?>(null);
  final ValueNotifier<String?> userId = ValueNotifier<String?>(null);

  bool get supportsRealtimeBackend => SupabaseService.instance.isEnabled;

  static const String _isLoggedInKey = 'auth_is_logged_in';
  static const String _userNameKey = 'auth_user_name';
  static const String _userEmailKey = 'auth_user_email';

  SharedPreferences? _prefs;
  bool _listenersAttached = false;
  String? _pendingOtpEmail;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    if (SupabaseService.instance.isEnabled) {
      final session = SupabaseService.instance.client.auth.currentSession;
      final user = session?.user;
      isLoggedIn.value = user != null;
      userId.value = user?.id;
      userEmail.value = user?.email;
      userName.value = _nameFromEmail(user?.email);
    } else {
      isLoggedIn.value = _prefs?.getBool(_isLoggedInKey) ?? false;
      userName.value = _prefs?.getString(_userNameKey);
      userEmail.value = _prefs?.getString(_userEmailKey);
      userId.value = null;
    }

    if (!_listenersAttached) {
      isLoggedIn.addListener(_persistAuthState);
      userName.addListener(_persistUserName);
      userEmail.addListener(_persistUserEmail);
      _listenersAttached = true;
    }
  }

  Future<void> _persistAuthState() async {
    await _prefs?.setBool(_isLoggedInKey, isLoggedIn.value);
  }

  Future<void> _persistUserName() async {
    final currentName = userName.value;
    if (currentName == null || currentName.isEmpty) {
      await _prefs?.remove(_userNameKey);
      return;
    }
    await _prefs?.setString(_userNameKey, currentName);
  }

  Future<void> _persistUserEmail() async {
    final currentEmail = userEmail.value;
    if (currentEmail == null || currentEmail.isEmpty) {
      await _prefs?.remove(_userEmailKey);
      return;
    }
    await _prefs?.setString(_userEmailKey, currentEmail);
  }

  String _nameFromEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'SlowRider';
    }
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) {
      return email;
    }
    return email.substring(0, atIndex);
  }

  Future<void> requestOtp({required String email}) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return;
    }

    await SupabaseService.instance.client.auth.signInWithOtp(
      email: normalizedEmail,
    );
    _pendingOtpEmail = normalizedEmail;
  }

  Future<void> verifyOtp({required String code}) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }

    final normalizedCode = code.trim();
    final pendingEmail = _pendingOtpEmail;

    if (normalizedCode.isEmpty ||
        pendingEmail == null ||
        pendingEmail.isEmpty) {
      throw StateError('otp_verification_failed');
    }

    final response = await SupabaseService.instance.client.auth.verifyOTP(
      email: pendingEmail,
      token: normalizedCode,
      type: OtpType.email,
    );

    final user = response.user;
    if (user == null) {
      throw StateError('otp_verification_failed');
    }

    userId.value = user.id;
    userEmail.value = user.email;
    userName.value = _nameFromEmail(user.email);
    isLoggedIn.value = true;
  }

  Future<void> signOut() async {
    if (SupabaseService.instance.isEnabled) {
      await SupabaseService.instance.client.auth.signOut();
    }

    userName.value = null;
    userEmail.value = null;
    userId.value = null;
    isLoggedIn.value = false;
    _pendingOtpEmail = null;
  }
}
