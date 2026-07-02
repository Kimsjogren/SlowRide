import 'package:flutter/material.dart';
import 'package:slowride/features/auth/mfa_verify_screen.dart';
import 'package:slowride/features/auth/register_screen.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/widgets/app_background.dart';

String _localizeAuthError(AuthException e, AppLocalizations l10n) {
  return switch (e.code) {
    AuthErrorCode.allFieldsRequired => l10n.authErrorAllFieldsRequired,
    AuthErrorCode.passwordTooShort => l10n.authErrorPasswordTooShort,
    AuthErrorCode.confirmationEmailSent => l10n.authErrorConfirmEmail,
    AuthErrorCode.emailAndPasswordRequired =>
      l10n.authErrorEmailAndPasswordRequired,
    AuthErrorCode.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthErrorCode.emailAlreadyInUse => l10n.authErrorEmailAlreadyInUse,
    _ => l10n.authGenericError,
  };
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Check if 2FA is required
      if (AuthService.instance.mfaRequired) {
        final verified = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const MfaVerifyScreen()),
        );
        if (mounted) Navigator.of(context).pop(verified == true);
      } else {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      setState(
        () => _error = _localizeAuthError(e, AppLocalizations.of(context)!),
      );
    } catch (_) {
      setState(() => _error = AppLocalizations.of(context)!.authGenericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ForgotEmailSheet(initialEmail: _emailController.text),
    );
    if (sent != true || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF0A1A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _ResetCodeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        showLogo: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Image.asset(
                    'assets/logga_nobg.png',
                    width: 290,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.signIn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.authWelcomeBack,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 32),

                // Glassmorphism-kort
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // E-post
                        _GlassField(
                          controller: _emailController,
                          label: l10n.authEmailLabel,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l10n.authEmailRequired;
                            }
                            if (!v.contains('@')) return l10n.authEmailInvalid;
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Lösenord
                        _GlassField(
                          controller: _passwordController,
                          label: l10n.authPasswordLabel,
                          icon: Icons.lock_outline,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white54,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return l10n.authPasswordRequired;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _showForgotPasswordDialog,
                            child: Text(
                              l10n.authForgotPasswordLink,
                              style: const TextStyle(
                                color: Color(0xFF3AA8FF),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        // Felmeddelande
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Logga in-knapp
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E6BFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    l10n.signIn,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Skapa konto-länk
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.authNoAccountPrompt,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        l10n.signUp,
                        style: const TextStyle(
                          color: Color(0xFF3AA8FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Avbryt
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    l10n.authCancel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Reusable glass text field ────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3AA8FF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.9)),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}

class _ForgotEmailSheet extends StatefulWidget {
  const _ForgotEmailSheet({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotEmailSheet> createState() => _ForgotEmailSheetState();
}

class _ForgotEmailSheetState extends State<_ForgotEmailSheet> {
  late final TextEditingController _emailController;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = l10n.authEmailInvalid);
      return;
    }
    setState(() => _sending = true);
    try {
      await AuthService.instance.resetPassword(email: email);
    } catch (_) {
      // Ignore to avoid revealing whether the email exists.
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.authForgotPasswordTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.authForgotPasswordDescription,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _GlassField(
              controller: _emailController,
              label: l10n.authEmailLabel,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.authForgotPasswordButton,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetCodeSheet extends StatefulWidget {
  const _ResetCodeSheet();

  @override
  State<_ResetCodeSheet> createState() => _ResetCodeSheetState();
}

class _ResetCodeSheetState extends State<_ResetCodeSheet> {
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _totpController = TextEditingController();
  bool _showRecoveryCode = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _saving = false;
  bool _resending = false;
  String? _message;
  bool _success = false;
  bool _needsMfa = false;
  bool _recoveryVerified = false;
  String? _verifiedRecoveryCode;
  bool _recoveryCodeExpired = false;

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    final pw = _newPasswordController.text;
    final pw2 = _confirmPasswordController.text;
    if (code.isEmpty) {
      setState(() {
        _message = l10n.signInOtpInvalid;
        _success = false;
      });
      return;
    }
    setState(() {
      _message = null;
      _recoveryCodeExpired = false;
    });
    final recoveryOk = await _ensureRecoverySession(code, l10n);
    if (!recoveryOk) return;
    if (pw.length < 6) {
      setState(() {
        _message = l10n.authErrorPasswordTooShort;
        _success = false;
      });
      return;
    }
    if (pw != pw2) {
      setState(() {
        _message = l10n.authPasswordsDoNotMatch;
        _success = false;
      });
      return;
    }
    if (_needsMfa && _totpController.text.trim().length != 6) {
      setState(() {
        _message = l10n.mfaInvalidCode;
        _success = false;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      if (AuthService.instance.mfaRequired) {
        final totp = _totpController.text.trim();
        if (totp.length != 6) {
          setState(() {
            _saving = false;
            _needsMfa = true;
            _message = l10n.mfaVerifySubtitle;
            _success = false;
          });
          return;
        }
        await AuthService.instance.verifyCurrentSessionMfa(code: totp);
      }
      await AuthService.instance.updatePassword(newPassword: pw);
      // Sign out of the temporary recovery session so the user logs in fresh
      // with the new password (avoids a lingering half-authenticated state).
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.authResetPasswordSuccess),
          backgroundColor: const Color(0xFF00913F),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final detail = e is AuthException ? e.message : e.toString();
      final needsMfaFromError =
          detail.contains('insufficient_aal') ||
          detail.contains('AAL2 session is required');
      setState(() {
        _saving = false;
        _needsMfa = _needsMfa || needsMfaFromError;
        _message = needsMfaFromError
            ? l10n.mfaVerifySubtitle
            : '${l10n.signInOtpInvalid} ($detail)';
        _success = false;
      });
    }
  }

  Future<bool> _ensureRecoverySession(
    String code,
    AppLocalizations l10n,
  ) async {
    if (_recoveryVerified && _verifiedRecoveryCode == code) {
      return true;
    }
    try {
      await AuthService.instance.verifyRecoveryCode(code: code);
      if (!mounted) return false;
      setState(() {
        _recoveryVerified = true;
        _verifiedRecoveryCode = code;
        _recoveryCodeExpired = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      final detail = e is AuthException ? e.message : e.toString();
      final expired =
          detail.contains('otp_expired') ||
          detail.contains('Token has expired');
      setState(() {
        _recoveryVerified = false;
        _verifiedRecoveryCode = null;
        _recoveryCodeExpired = expired;
        _message = expired
            ? '${l10n.signInOtpInvalid} (Koden har gått ut. Skicka ny kod.)'
            : '${l10n.signInOtpInvalid} ($detail)';
        _success = false;
      });
      return false;
    }
  }

  Future<void> _resendRecoveryCode() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      await AuthService.instance.resendRecoveryCode();
      if (!mounted) return;
      setState(() {
        _recoveryVerified = false;
        _verifiedRecoveryCode = null;
        _recoveryCodeExpired = false;
        _message =
            '${l10n.authForgotPasswordButton}: OK. Kontrollera din e-post för ny kod.';
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '${l10n.authGenericError} (${e.toString()})';
        _success = false;
      });
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.authResetPasswordTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            Text(
              l10n.authResetPasswordDescription,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _GlassField(
              controller: _codeController,
              label: l10n.signInOtpFieldLabel,
              icon: Icons.pin_outlined,
              obscureText: !_showRecoveryCode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                icon: Icon(
                  _showRecoveryCode
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white54,
                ),
                onPressed: () =>
                    setState(() => _showRecoveryCode = !_showRecoveryCode),
              ),
              onFieldSubmitted: (_) async {
                final value = _codeController.text.trim();
                if (value.isNotEmpty) {
                  await _ensureRecoverySession(value, l10n);
                }
              },
            ),
            if (_recoveryCodeExpired) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _resending ? null : _resendRecoveryCode,
                  child: _resending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.authForgotPasswordButton),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _GlassField(
              controller: _newPasswordController,
              label: l10n.authNewPasswordLabel,
              icon: Icons.lock_outline,
              obscureText: !_showNewPassword,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                icon: Icon(
                  _showNewPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white54,
                ),
                onPressed: () =>
                    setState(() => _showNewPassword = !_showNewPassword),
              ),
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _confirmPasswordController,
              label: l10n.authConfirmPasswordLabel,
              icon: Icons.lock_outline,
              obscureText: !_showConfirmPassword,
              textInputAction: TextInputAction.done,
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white54,
                ),
                onPressed: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword,
                ),
              ),
            ),
            if (_needsMfa) ...[
              const SizedBox(height: 12),
              _GlassField(
                controller: _totpController,
                label: l10n.mfaVerifyTitle,
                icon: Icons.security,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _success ? const Color(0xFF3AA8FF) : Colors.redAccent,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.authResetPasswordButton,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
