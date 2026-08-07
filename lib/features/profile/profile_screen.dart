import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:slowride/features/auth/login_screen.dart';
import 'package:slowride/features/auth/mfa_setup_screen.dart';
import 'package:slowride/features/auth/register_screen.dart';
import 'package:slowride/features/paywall/paywall_screen.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/widgets/app_background.dart';
import 'dart:convert';
import 'dart:typed_data';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isUploadingAvatar = false;
  String? _pendingAvatarPath;

  Uint8List? _decodeDataUrlImage(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma <= 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final l10n = AppLocalizations.of(context)!;

    // Show bottom sheet with options.
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.profileChangePhoto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white70),
                title: Text(
                  l10n.profileTakePhoto,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white70),
                title: Text(
                  l10n.profileChooseFromGallery,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 95);
      if (image == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        maxWidth: 512,
        maxHeight: 512,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: l10n.profileChangePhoto,
            toolbarColor: const Color(0xFF0A2A9F),
            toolbarWidgetColor: Colors.white,
            backgroundColor: const Color(0xFF070F2B),
            activeControlsWidgetColor: const Color(0xFF3AA8FF),
            dimmedLayerColor: Colors.black.withValues(alpha: 0.7),
            cropFrameColor: const Color(0xFF3AA8FF),
            cropGridColor: Colors.white.withValues(alpha: 0.25),
            showCropGrid: false,
            hideBottomControls: true,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: l10n.profileChangePhoto,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: true,
            aspectRatioPickerButtonHidden: true,
            doneButtonTitle: 'Klar',
            cancelButtonTitle: 'Avbryt',
            cropStyle: CropStyle.circle,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
          ),
        ],
      );
      if (cropped == null) return;

      setState(() {
        _isUploadingAvatar = true;
        _pendingAvatarPath = cropped.path;
      });

      final bytes = await File(cropped.path).readAsBytes();
      final fileName = cropped.path.split('/').last;
      final url = await AuthService.instance.updateAvatar(bytes, fileName);

      if (url == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profilePhotoUploadFailed),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profilePhotoUploadFailed),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          _pendingAvatarPath = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = AuthService.instance;

    return AppBackground(
      child: ValueListenableBuilder<bool>(
        valueListenable: authService.isLoggedIn,
        builder: (context, isLoggedIn, _) {
          return ValueListenableBuilder<String?>(
            valueListenable: authService.userName,
            builder: (context, userName, _) {
              final email = authService.userEmail.value;
              final displayName = userName ?? l10n.profileDefaultName;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    // Avatar (tappable when logged in)
                    ValueListenableBuilder<String?>(
                      valueListenable: authService.avatarUrl,
                      builder: (context, avatarUrl, _) {
                        final hasPendingAvatar =
                            _pendingAvatarPath != null &&
                            _pendingAvatarPath!.isNotEmpty;
                        final hasAvatar =
                            avatarUrl != null && avatarUrl.isNotEmpty;

                        Widget avatarContent;
                        if (hasPendingAvatar) {
                          avatarContent = ClipOval(
                            child: Image.file(
                              File(_pendingAvatarPath!),
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Icon(
                                isLoggedIn
                                    ? Icons.person
                                    : Icons.person_outline,
                                size: 48,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        } else if (_isUploadingAvatar) {
                          avatarContent = const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white70,
                            ),
                          );
                        } else if (hasAvatar) {
                          if (avatarUrl.startsWith('data:image/')) {
                            final bytes = _decodeDataUrlImage(avatarUrl);
                            if (bytes != null) {
                              avatarContent = ClipOval(
                                child: Image.memory(
                                  bytes,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              );
                            } else {
                              avatarContent = Icon(
                                isLoggedIn
                                    ? Icons.person
                                    : Icons.person_outline,
                                size: 48,
                                color: Colors.white70,
                              );
                            }
                          } else {
                            avatarContent = ClipOval(
                              child: Image.network(
                                avatarUrl,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Icon(
                                  isLoggedIn
                                      ? Icons.person
                                      : Icons.person_outline,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                            );
                          }
                        } else {
                          avatarContent = Icon(
                            isLoggedIn ? Icons.person : Icons.person_outline,
                            size: 48,
                            color: Colors.white70,
                          );
                        }

                        return GestureDetector(
                          onTap: isLoggedIn ? _pickAndUploadAvatar : null,
                          child: Stack(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasAvatar
                                      ? Colors.transparent
                                      : Colors.white.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 2,
                                  ),
                                ),
                                child: Center(child: avatarContent),
                              ),
                              if (isLoggedIn)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E6BFF),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF0D1B2A),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Namn / inloggad status
                    if (isLoggedIn) ...[
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ] else
                      Text(
                        l10n.profileNotSignedIn,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 28),

                    if (isLoggedIn) ...[
                      // Info-kort
                      _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.check_circle_outline,
                            text: l10n.profileSignedIn,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 4),

                    // Stats card
                    _InfoCard(
                      title: l10n.profileStatsTitle,
                      children: [
                        _StatRow(label: l10n.profileStatsConvoys, value: '—'),
                        _StatRow(
                          label: l10n.profileStatsTotalDistance,
                          value: '— km',
                        ),
                        _StatRow(
                          label: l10n.profileStatsSpeedViolations,
                          value: '—',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Vehicle settings card
                    _InfoCard(
                      title: l10n.profileVehicleTitle,
                      children: [
                        // EV toggle — only for Moped car
                        ValueListenableBuilder<String>(
                          valueListenable:
                              UserPreferencesService.instance.vehicleType,
                          builder: (_, vehicleType, _) {
                            if (vehicleType != 'Moped car') {
                              return const SizedBox.shrink();
                            }
                            return ValueListenableBuilder<bool>(
                              valueListenable:
                                  UserPreferencesService.instance.isElectric,
                              builder: (_, isEv, _) {
                                return SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    l10n.profileVehicleElectric,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    l10n.profileVehicleElectricSubtitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                  secondary: Icon(
                                    Icons.ev_station,
                                    color: isEv
                                        ? const Color(0xFF4CD964)
                                        : Colors.white38,
                                  ),
                                  value: isEv,
                                  activeThumbColor: const Color(0xFF4CD964),
                                  onChanged: (v) =>
                                      UserPreferencesService
                                              .instance
                                              .isElectric
                                              .value =
                                          v,
                                );
                              },
                            );
                          },
                        ),
                        // Studded tires toggle
                        ValueListenableBuilder<bool>(
                          valueListenable:
                              UserPreferencesService.instance.hasStuddedTires,
                          builder: (_, hasStudded, _) {
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                l10n.profileVehicleStuddedTires,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                l10n.profileVehicleStuddedTiresSubtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13,
                                ),
                              ),
                              secondary: Icon(
                                Icons.tire_repair,
                                color: hasStudded
                                    ? const Color(0xFF00C8FF)
                                    : Colors.white38,
                              ),
                              value: hasStudded,
                              activeThumbColor: const Color(0xFF00C8FF),
                              onChanged: (v) =>
                                  UserPreferencesService
                                          .instance
                                          .hasStuddedTires
                                          .value =
                                      v,
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Subscription plan card (always visible)
                    ValueListenableBuilder<bool>(
                      valueListenable: SubscriptionService.instance.isPro,
                      builder: (context, isPro, _) {
                        if (isPro) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D3320),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(
                                  0xFF52B788,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.workspace_premium,
                                  color: Color(0xFF52B788),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.profileProPlan,
                                  style: const TextStyle(
                                    color: Color(0xFF52B788),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final sub = SubscriptionService.instance;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.13),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.profileFreePlan,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          l10n.profileRoutesUsed(
                                            sub.routesToday,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<bool>(
                                  builder: (_) => const PaywallScreen(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.workspace_premium,
                                size: 18,
                              ),
                              label: Text(l10n.profileUpgradeToPro),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB800),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Logga in / Skapa konto (ej inloggad)
                    if (!isLoggedIn) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: Text(AppLocalizations.of(context)!.signIn),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E6BFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.white70,
                          ),
                          label: Text(
                            l10n.signUp,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 2FA / Tvåfaktorsautentisering
                    if (isLoggedIn && SupabaseService.instance.isEnabled)
                      _TwoFactorCard(),

                    // Logga ut-knapp
                    if (isLoggedIn)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: authService.signOut,
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          label: Text(
                            l10n.signOut,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white60),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoFactorCard extends StatefulWidget {
  @override
  State<_TwoFactorCard> createState() => _TwoFactorCardState();
}

class _TwoFactorCardState extends State<_TwoFactorCard> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final on = await AuthService.instance.mfaEnabled;
    if (mounted) setState(() => _enabled = on);
  }

  Future<void> _enable() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MfaSetupScreen()),
    );
    if (result == true) _checkStatus();
  }

  Future<void> _disable() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B3D),
        title: Text(
          l10n.mfaDisableTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.mfaDisableBody,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.mfaDisableConfirm,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.unenrollMfa();
    } finally {
      _checkStatus();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_enabled == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(
              _enabled! ? Icons.verified_user : Icons.shield_outlined,
              color: _enabled! ? const Color(0xFF4CAF50) : Colors.white38,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.mfaProfileTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _enabled! ? l10n.mfaStatusOn : l10n.mfaStatusOff,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : TextButton(
                    onPressed: _enabled! ? _disable : _enable,
                    child: Text(
                      _enabled! ? l10n.mfaTurnOff : l10n.mfaTurnOn,
                      style: TextStyle(
                        color: _enabled!
                            ? Colors.redAccent
                            : const Color(0xFF1E6BFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
