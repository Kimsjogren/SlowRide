import 'dart:convert';
import 'dart:typed_data';

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
  final ValueNotifier<String?> avatarUrl = ValueNotifier<String?>(null);

  bool get supportsRealtimeBackend => SupabaseService.instance.isEnabled;

  static const String _isLoggedInKey = 'auth_is_logged_in';
  static const String _userNameKey = 'auth_user_name';
  static const String _userEmailKey = 'auth_user_email';
  static const String _avatarUrlKey = 'auth_avatar_url';
  // Local mock: stores {"email": {"name":"...", "pw":"..."}}
  static const String _localAccountsKey = 'auth_local_accounts';

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
      userName.value =
          user?.userMetadata?['display_name'] as String? ??
          _nameFromEmail(user?.email);
      avatarUrl.value = user?.userMetadata?['avatar_url'] as String?;
    } else {
      isLoggedIn.value = _prefs?.getBool(_isLoggedInKey) ?? false;
      userName.value = _prefs?.getString(_userNameKey);
      userEmail.value = _prefs?.getString(_userEmailKey);
      avatarUrl.value = _prefs?.getString(_avatarUrlKey);
      userId.value = null;
    }

    if (!_listenersAttached) {
      isLoggedIn.addListener(_persistAuthState);
      userName.addListener(_persistUserName);
      userEmail.addListener(_persistUserEmail);
      avatarUrl.addListener(_persistAvatarUrl);
      _listenersAttached = true;
    }
  }

  // ── Email + password ──────────────────────────────────────────────────────

  /// Creates a new account. Works locally (no Supabase needed).
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = displayName.trim();

    if (normalizedEmail.isEmpty || password.isEmpty || trimmedName.isEmpty) {
      throw const AuthException(
        'allFieldsRequired',
        code: AuthErrorCode.allFieldsRequired,
      );
    }
    if (password.length < 6) {
      throw const AuthException(
        'passwordTooShort',
        code: AuthErrorCode.passwordTooShort,
      );
    }

    if (SupabaseService.instance.isEnabled) {
      await SupabaseService.instance.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'display_name': trimmedName},
      );
      // If email confirmation is off, session is active immediately.
      final user = SupabaseService.instance.client.auth.currentUser;
      if (user != null) {
        userId.value = user.id;
        userEmail.value = user.email;
        userName.value = trimmedName;
        isLoggedIn.value = true;
      } else {
        // Email confirmation required — tell the caller.
        throw const AuthException(
          'confirmationEmailSent',
          code: AuthErrorCode.confirmationEmailSent,
        );
      }
      return;
    }

    // ── Local mock ────────────────────────────────────────────────────────
    final accounts = _loadLocalAccounts();
    if (accounts.containsKey(normalizedEmail)) {
      throw const AuthException(
        'emailAlreadyInUse',
        code: AuthErrorCode.emailAlreadyInUse,
      );
    }
    accounts[normalizedEmail] = {
      'name': trimmedName,
      'pw': password, // MVP: plaintext. Swap for hash when using real backend.
    };
    _saveLocalAccounts(accounts);

    userName.value = trimmedName;
    userEmail.value = normalizedEmail;
    userId.value = null;
    isLoggedIn.value = true;
  }

  /// Signs in with email + password. Works locally (no Supabase needed).
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthException(
        'emailAndPasswordRequired',
        code: AuthErrorCode.emailAndPasswordRequired,
      );
    }

    if (SupabaseService.instance.isEnabled) {
      final response = await SupabaseService.instance.client.auth
          .signInWithPassword(email: normalizedEmail, password: password);
      final user = response.user;
      if (user == null)
        throw const AuthException(
          'invalidCredentials',
          code: AuthErrorCode.invalidCredentials,
        );
      userId.value = user.id;
      userEmail.value = user.email;
      userName.value =
          user.userMetadata?['display_name'] as String? ??
          _nameFromEmail(user.email);
      isLoggedIn.value = true;
      return;
    }

    // ── Local mock ────────────────────────────────────────────────────────
    final accounts = _loadLocalAccounts();
    final account = accounts[normalizedEmail];
    if (account == null || account['pw'] != password) {
      throw const AuthException(
        'invalidCredentials',
        code: AuthErrorCode.invalidCredentials,
      );
    }
    userName.value = account['name'] ?? _nameFromEmail(normalizedEmail);
    userEmail.value = normalizedEmail;
    userId.value = null;
    isLoggedIn.value = true;
  }

  // ── OTP (Supabase only) ───────────────────────────────────────────────────

  Future<void> requestOtp({required String email}) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;
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
    if (user == null) throw StateError('otp_verification_failed');
    userId.value = user.id;
    userEmail.value = user.email;
    userName.value = _nameFromEmail(user.email);
    isLoggedIn.value = true;
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    if (SupabaseService.instance.isEnabled) {
      await SupabaseService.instance.client.auth.signOut();
    }
    userName.value = null;
    userEmail.value = null;
    userId.value = null;
    avatarUrl.value = null;
    isLoggedIn.value = false;
    _pendingOtpEmail = null;
  }

  // ── Avatar upload ─────────────────────────────────────────────────────────

  /// Uploads avatar image and returns the public URL.
  Future<String?> updateAvatar(Uint8List bytes, String fileName) async {
    if (!SupabaseService.instance.isEnabled) {
      // Local mode: can't store avatars without backend.
      return null;
    }

    final uid = userId.value;
    if (uid == null) return null;

    final ext = fileName.split('.').last.toLowerCase();
    final path = 'avatars/$uid.$ext';

    try {
      // Upload to Supabase Storage (bucket: avatars).
      await SupabaseService.instance.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL with cache-busting timestamp.
      final baseUrl = SupabaseService.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);
      final publicUrl = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Save to user metadata.
      await SupabaseService.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      avatarUrl.value = publicUrl;
      return publicUrl;
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _nameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'CruizX Driver';
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email;
    return email.substring(0, atIndex);
  }

  Map<String, Map<String, String>> _loadLocalAccounts() {
    final raw = _prefs?.getString(_localAccountsKey) ?? '{}';
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  void _saveLocalAccounts(Map<String, Map<String, String>> accounts) {
    _prefs?.setString(_localAccountsKey, jsonEncode(accounts));
  }

  Future<void> _persistAuthState() async {
    await _prefs?.setBool(_isLoggedInKey, isLoggedIn.value);
  }

  Future<void> _persistUserName() async {
    final v = userName.value;
    if (v == null || v.isEmpty) {
      await _prefs?.remove(_userNameKey);
    } else {
      await _prefs?.setString(_userNameKey, v);
    }
  }

  Future<void> _persistUserEmail() async {
    final v = userEmail.value;
    if (v == null || v.isEmpty) {
      await _prefs?.remove(_userEmailKey);
    } else {
      await _prefs?.setString(_userEmailKey, v);
    }
  }

  Future<void> _persistAvatarUrl() async {
    final v = avatarUrl.value;
    if (v == null || v.isEmpty) {
      await _prefs?.remove(_avatarUrlKey);
    } else {
      await _prefs?.setString(_avatarUrlKey, v);
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code = AuthErrorCode.unknown});
  final String message;
  final AuthErrorCode code;
  @override
  String toString() => message;
}

enum AuthErrorCode {
  allFieldsRequired,
  passwordTooShort,
  confirmationEmailSent,
  emailAndPasswordRequired,
  invalidCredentials,
  emailAlreadyInUse,
  unknown,
}
