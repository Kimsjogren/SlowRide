import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
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
  static const String _pendingEmailConfirmationKey =
      'auth_pending_email_confirmation';
  // Local mock: stores {"email": {"name":"...", "pw":"..."}}
  static const String _localAccountsKey = 'auth_local_accounts';

  SharedPreferences? _prefs;
  bool _listenersAttached = false;
  String? _pendingOtpEmail;
  String? _pendingRecoveryEmail;

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
    if (password.length < 6 ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      throw const AuthException(
        'passwordTooShort',
        code: AuthErrorCode.passwordTooShort,
      );
    }

    if (SupabaseService.instance.isEnabled) {
      try {
        final response = await SupabaseService.instance.client.auth.signUp(
          email: normalizedEmail,
          password: password,
          emailRedirectTo: 'com.cruizx.mobile://login-callback/',
          data: {'display_name': trimmedName},
        );
        // If email confirmation is off, session is active immediately.
        final user = response.session?.user;
        if (user != null) {
          await _prefs?.remove(_pendingEmailConfirmationKey);
          userId.value = user.id;
          userEmail.value = user.email;
          userName.value = trimmedName;
          isLoggedIn.value = true;
        } else {
          await _prefs?.setString(
            _pendingEmailConfirmationKey,
            normalizedEmail,
          );
          // Email confirmation required — tell the caller.
          throw const AuthException(
            'confirmationEmailSent',
            code: AuthErrorCode.confirmationEmailSent,
          );
        }
      } on supabase.AuthException catch (error) {
        debugPrint(
          'Supabase signup failed: code=${error.code}, '
          'status=${error.statusCode}',
        );
        throw _mapSupabaseSignUpError(error);
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

  AuthException _mapSupabaseSignUpError(supabase.AuthException error) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();

    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        code == 'identity_already_exists' ||
        message.contains('already registered') ||
        message.contains('already exists')) {
      return const AuthException(
        'emailAlreadyInUse',
        code: AuthErrorCode.emailAlreadyInUse,
      );
    }
    if (code == 'weak_password' ||
        (message.contains('password') &&
            (message.contains('weak') || message.contains('at least')))) {
      return const AuthException(
        'passwordTooShort',
        code: AuthErrorCode.passwordTooShort,
      );
    }
    if (code == 'validation_failed' &&
        (message.contains('email') || message.contains('address'))) {
      return const AuthException(
        'invalidEmail',
        code: AuthErrorCode.invalidEmail,
      );
    }
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('too many')) {
      return const AuthException(
        'rateLimited',
        code: AuthErrorCode.rateLimited,
      );
    }
    if (code == 'signup_disabled' ||
        code == 'email_provider_disabled' ||
        code == 'provider_disabled') {
      return const AuthException(
        'signUpDisabled',
        code: AuthErrorCode.signUpDisabled,
      );
    }
    if (message.contains('confirmation email') ||
        message.contains('sending email') ||
        message.contains('send email') ||
        message.contains('smtp')) {
      return const AuthException(
        'emailDeliveryFailed',
        code: AuthErrorCode.emailDeliveryFailed,
      );
    }
    if (code == 'request_timeout' ||
        error is supabase.AuthRetryableFetchException) {
      return const AuthException(
        'networkUnavailable',
        code: AuthErrorCode.networkUnavailable,
      );
    }
    return AuthException(error.message, code: AuthErrorCode.unknown);
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
      if (user == null) {
        throw const AuthException(
          'invalidCredentials',
          code: AuthErrorCode.invalidCredentials,
        );
      }
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

  /// Synchronizes authentication initiated outside the running UI, such as a
  /// Supabase email-confirmation deep link. Returns true exactly once when a
  /// pending registration has been confirmed on this device.
  Future<bool> handleAuthStateChange(supabase.AuthState state) async {
    if (!SupabaseService.instance.isEnabled) return false;
    _prefs ??= await SharedPreferences.getInstance();

    final user = state.session?.user;
    if (user == null) {
      if (state.event == supabase.AuthChangeEvent.signedOut) {
        userId.value = null;
        userEmail.value = null;
        userName.value = null;
        avatarUrl.value = null;
        isLoggedIn.value = false;
      }
      return false;
    }

    userId.value = user.id;
    userEmail.value = user.email;
    userName.value =
        user.userMetadata?['display_name'] as String? ??
        _nameFromEmail(user.email);
    avatarUrl.value = user.userMetadata?['avatar_url'] as String?;
    isLoggedIn.value = true;

    final pendingEmail = _prefs?.getString(_pendingEmailConfirmationKey);
    final confirmedEmail = user.email?.trim().toLowerCase();
    final wasPendingConfirmation =
        pendingEmail != null &&
        pendingEmail == confirmedEmail &&
        user.emailConfirmedAt != null;
    if (wasPendingConfirmation) {
      await _prefs?.remove(_pendingEmailConfirmationKey);
    }
    return wasPendingConfirmation;
  }

  // ── Password reset (Supabase only) ────────────────────────────────────────

  Future<void> resetPassword({required String email}) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;
    // Sends the "Reset Password" email. With the Supabase email template
    // including {{ .Token }}, the user receives a 6-digit recovery code they
    // enter directly in the app — no website or deep link needed.
    await SupabaseService.instance.client.auth.resetPasswordForEmail(
      normalizedEmail,
    );
    _pendingRecoveryEmail = normalizedEmail;
  }

  /// Verifies the 6-digit recovery code from the reset email and establishes a
  /// temporary recovery session so the password can be updated.
  Future<void> verifyRecoveryCode({required String code}) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }
    final normalizedCode = code.trim();
    final email = _pendingRecoveryEmail;
    if (normalizedCode.isEmpty || email == null || email.isEmpty) {
      throw StateError('otp_verification_failed');
    }
    final response = await SupabaseService.instance.client.auth.verifyOTP(
      email: email,
      token: normalizedCode,
      type: supabase.OtpType.recovery,
    );
    if (response.user == null) throw StateError('otp_verification_failed');
  }

  Future<void> resendRecoveryCode() async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }
    final email = _pendingRecoveryEmail;
    if (email == null || email.isEmpty) {
      throw StateError('recovery_email_missing');
    }
    await SupabaseService.instance.client.auth.resetPasswordForEmail(email);
  }

  Future<void> updatePassword({required String newPassword}) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }
    await SupabaseService.instance.client.auth.updateUser(
      supabase.UserAttributes(password: newPassword),
    );
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
      type: supabase.OtpType.email,
    );
    final user = response.user;
    if (user == null) throw StateError('otp_verification_failed');
    userId.value = user.id;
    userEmail.value = user.email;
    userName.value = _nameFromEmail(user.email);
    isLoggedIn.value = true;
  }

  // ── MFA / TOTP ────────────────────────────────────────────────────────────

  /// Returns true when the signed-in user still needs to complete a second
  /// factor challenge before being fully authenticated.
  bool get mfaRequired {
    if (!SupabaseService.instance.isEnabled) return false;
    final aal = SupabaseService.instance.client.auth.mfa
        .getAuthenticatorAssuranceLevel();
    return aal.currentLevel == supabase.AuthenticatorAssuranceLevels.aal1 &&
        aal.nextLevel == supabase.AuthenticatorAssuranceLevels.aal2;
  }

  /// Returns true when the user has enrolled at least one TOTP factor.
  Future<bool> get mfaEnabled async {
    if (!SupabaseService.instance.isEnabled) return false;
    final factors = await SupabaseService.instance.client.auth.mfa
        .listFactors();
    return factors.totp.any((f) => f.status == supabase.FactorStatus.verified);
  }

  /// Enroll a new TOTP factor. Returns the TOTP QR-code SVG string, the
  /// manual secret and the factor-id needed for verification.
  Future<({String qrCode, String secret, String factorId})> enrollMfa() async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }
    final res = await SupabaseService.instance.client.auth.mfa.enroll(
      factorType: supabase.FactorType.totp,
      issuer: 'CruizX',
      friendlyName: 'CruizX 2FA',
    );
    return (
      qrCode: res.totp!.qrCode,
      secret: res.totp!.secret,
      factorId: res.id,
    );
  }

  /// Verify a TOTP code against an enrolled factor. Used both during initial
  /// setup (to confirm the user scanned the QR) and after login.
  Future<void> verifyMfa({
    required String factorId,
    required String code,
  }) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }
    await SupabaseService.instance.client.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: code.trim(),
    );
  }

  /// Completes MFA for the current authenticated session using the first
  /// verified TOTP factor.
  Future<void> verifyCurrentSessionMfa({required String code}) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }
    final factorId = await verifiedFactorId;
    if (factorId == null) {
      throw StateError('mfa_factor_missing');
    }
    await verifyMfa(factorId: factorId, code: code);
  }

  /// Remove (unenroll) a TOTP factor — effectively disables 2FA.
  Future<void> unenrollMfa() async {
    if (!SupabaseService.instance.isEnabled) return;
    final factors = await SupabaseService.instance.client.auth.mfa
        .listFactors();
    for (final f in factors.totp) {
      await SupabaseService.instance.client.auth.mfa.unenroll(f.id);
    }
  }

  /// Returns the factor-id of the first verified TOTP factor, or null.
  Future<String?> get verifiedFactorId async {
    if (!SupabaseService.instance.isEnabled) return null;
    final factors = await SupabaseService.instance.client.auth.mfa
        .listFactors();
    final verified = factors.totp.where(
      (f) => f.status == supabase.FactorStatus.verified,
    );
    return verified.isEmpty ? null : verified.first.id;
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
    _pendingRecoveryEmail = null;
  }

  // ── Avatar upload ─────────────────────────────────────────────────────────

  /// Uploads avatar image and returns the public URL.
  Future<String?> updateAvatar(Uint8List bytes, String fileName) async {
    final localDataUrl = _buildAvatarDataUrl(bytes, fileName);
    // Show the new avatar immediately so the UI does not flicker back.
    avatarUrl.value = localDataUrl;

    if (!SupabaseService.instance.isEnabled) {
      return localDataUrl;
    }

    final uid = userId.value;
    if (uid == null) {
      return localDataUrl;
    }

    final ext = fileName.split('.').last.toLowerCase();
    final path = 'avatars/$uid.$ext';

    try {
      // Upload to Supabase Storage (bucket: avatars).
      await SupabaseService.instance.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const supabase.FileOptions(upsert: true),
          );

      final bucket = SupabaseService.instance.client.storage.from('avatars');
      final cacheBust = DateTime.now().millisecondsSinceEpoch;

      // Prefer signed URL since bucket may be private.
      String remoteUrl;
      try {
        final signed = await bucket.createSignedUrl(path, 60 * 60 * 24 * 30);
        remoteUrl = '$signed&t=$cacheBust';
      } catch (_) {
        final baseUrl = bucket.getPublicUrl(path);
        remoteUrl = '$baseUrl?t=$cacheBust';
      }

      // Save to user metadata.
      await SupabaseService.instance.client.auth.updateUser(
        supabase.UserAttributes(data: {'avatar_url': remoteUrl}),
      );

      avatarUrl.value = remoteUrl;
      return remoteUrl;
    } catch (e, st) {
      debugPrint('Avatar upload failed: $e');
      debugPrint('Stack: $st');
      return localDataUrl;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _nameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'CruizX Driver';
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email;
    return email.substring(0, atIndex);
  }

  String _buildAvatarDataUrl(Uint8List bytes, String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final encoded = base64Encode(bytes);
    return 'data:$mime;base64,$encoded';
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
  invalidEmail,
  rateLimited,
  signUpDisabled,
  emailDeliveryFailed,
  networkUnavailable,
  unknown,
}
