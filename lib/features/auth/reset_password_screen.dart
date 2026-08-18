// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/widgets/app_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // MFA step
  bool _needsMfa = false;
  bool _checkingMfa = true;
  final _totpController = TextEditingController();

  // Password step
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkMfaRequirement();
  }

  Future<void> _checkMfaRequirement() async {
    try {
      final res = Supabase.instance.client.auth.mfa
          .getAuthenticatorAssuranceLevel();
      // nextLevel == aal2 means user has MFA enrolled and AAL2 is needed
      if (res.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
          res.currentLevel != AuthenticatorAssuranceLevels.aal2) {
        setState(() {
          _needsMfa = true;
          _checkingMfa = false;
        });
      } else {
        setState(() {
          _needsMfa = false;
          _checkingMfa = false;
        });
      }
    } catch (_) {
      setState(() => _checkingMfa = false);
    }
  }

  Future<void> _verifyMfa() async {
    final code = _totpController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      final totp = factors.totp.firstOrNull;
      if (totp == null) {
        // No TOTP factor, skip MFA
        setState(() {
          _needsMfa = false;
          _loading = false;
        });
        return;
      }
      await Supabase.instance.client.auth.mfa.challengeAndVerify(
        factorId: totp.id,
        code: code,
      );
      setState(() {
        _needsMfa = false;
      });
    } catch (e) {
      debugPrint('MFA verify error: $e');
      setState(() => _error = 'Ogiltig kod. Försök igen.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.updatePassword(
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.authResetPasswordSuccess),
          backgroundColor: const Color(0xFF1E6BFF),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('updatePassword error: $e');
      setState(() => _error = AppLocalizations.of(context)!.authGenericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _totpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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
                const SizedBox(height: 24),
                Text(
                  l10n.authResetPasswordTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _checkingMfa
                      ? ''
                      : _needsMfa
                      ? 'Verifiera din autentiseringskod för att fortsätta.'
                      : l10n.authResetPasswordDescription,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (_checkingMfa)
                  const CircularProgressIndicator(color: Colors.white)
                else if (_needsMfa)
                  _buildMfaForm()
                else
                  _buildPasswordForm(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMfaForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.security, color: Colors.white70, size: 40),
          const SizedBox(height: 16),
          const Text(
            'Tvåfaktorsautentisering',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ange koden från din autentiseringsapp.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3AA8FF)),
              ),
            ),
            onChanged: (v) {
              if (v.length == 6) _verifyMfa();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(_error!),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _verifyMfa,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E6BFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Verifiera',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authNewPasswordLabel,
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Colors.white54,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white54,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3AA8FF)),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.authPasswordRequired;
                if (v.length < 6 ||
                    !RegExp(r'\d').hasMatch(v) ||
                    !RegExp('[^A-Za-z0-9]').hasMatch(v)) {
                  return l10n.authErrorPasswordTooShort;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authConfirmPasswordLabel,
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Colors.white54,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white54,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3AA8FF)),
                ),
              ),
              validator: (v) {
                if (v != _passwordController.text) {
                  return l10n.authPasswordsDoNotMatch;
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _errorBox(_error!),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
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
                        l10n.authResetPasswordButton,
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
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
