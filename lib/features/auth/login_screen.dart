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
    final l10n = AppLocalizations.of(context)!;
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool sending = false;
        bool codeSent = false;
        String? resultMessage;
        bool success = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    codeSent
                        ? l10n.authResetPasswordTitle
                        : l10n.authForgotPasswordTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    codeSent
                        ? l10n.authResetPasswordDescription
                        : l10n.authForgotPasswordDescription,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!codeSent)
                    _GlassField(
                      controller: resetEmailController,
                      label: l10n.authEmailLabel,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: null,
                    )
                  else ...[
                    _GlassField(
                      controller: codeController,
                      label: l10n.signInOtpFieldLabel,
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: null,
                    ),
                    const SizedBox(height: 12),
                    _GlassField(
                      controller: newPasswordController,
                      label: l10n.authNewPasswordLabel,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      validator: null,
                    ),
                    const SizedBox(height: 12),
                    _GlassField(
                      controller: confirmPasswordController,
                      label: l10n.authConfirmPasswordLabel,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: null,
                    ),
                  ],
                  if (resultMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      resultMessage!,
                      style: TextStyle(
                        color: success
                            ? const Color(0xFF3AA8FF)
                            : Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: sending
                          ? null
                          : () async {
                              if (!codeSent) {
                                final email = resetEmailController.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  setSheetState(() {
                                    resultMessage = l10n.authEmailInvalid;
                                    success = false;
                                  });
                                  return;
                                }
                                setSheetState(() => sending = true);
                                try {
                                  await AuthService.instance.resetPassword(
                                    email: email,
                                  );
                                } catch (_) {
                                  // Ignore to avoid revealing whether the email
                                  // exists; still advance to the code step.
                                }
                                setSheetState(() {
                                  sending = false;
                                  codeSent = true;
                                  resultMessage = l10n.signInOtpSent;
                                  success = true;
                                });
                                return;
                              }

                              // Step 2: verify code and set the new password.
                              final code = codeController.text.trim();
                              final pw = newPasswordController.text;
                              final pw2 = confirmPasswordController.text;
                              if (code.isEmpty) {
                                setSheetState(() {
                                  resultMessage = l10n.signInOtpInvalid;
                                  success = false;
                                });
                                return;
                              }
                              if (pw.length < 6) {
                                setSheetState(() {
                                  resultMessage =
                                      l10n.authErrorPasswordTooShort;
                                  success = false;
                                });
                                return;
                              }
                              if (pw != pw2) {
                                setSheetState(() {
                                  resultMessage = l10n.authPasswordsDoNotMatch;
                                  success = false;
                                });
                                return;
                              }
                              setSheetState(() => sending = true);
                              try {
                                await AuthService.instance.verifyRecoveryCode(
                                  code: code,
                                );
                                await AuthService.instance.updatePassword(
                                  newPassword: pw,
                                );
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.authResetPasswordSuccess,
                                      ),
                                      backgroundColor: const Color(0xFF00913F),
                                    ),
                                  );
                                }
                              } catch (_) {
                                setSheetState(() {
                                  sending = false;
                                  resultMessage = l10n.signInOtpInvalid;
                                  success = false;
                                });
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E6BFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              codeSent
                                  ? l10n.authResetPasswordButton
                                  : l10n.authForgotPasswordButton,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    resetEmailController.dispose();
    codeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
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
