import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slowride/features/auth/login_screen.dart';
import 'package:slowride/features/settings/parent_dashboard_screen.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/parent_service.dart';
import 'package:slowride/widgets/app_background.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key});

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.parentModeTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackground(
        showLogo: false,
        child: SafeArea(
          child: ValueListenableBuilder<bool>(
            valueListenable: AuthService.instance.isLoggedIn,
            builder: (context, isLoggedIn, _) {
              if (!isLoggedIn) {
                return _buildLoginRequired(context, l10n);
              }
              return _buildContent(context, l10n);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequired(BuildContext context, AppLocalizations l10n) {
    return Align(
      alignment: const Alignment(0, -0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logga_nobg.png',
              width: 290,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.family_restroom,
                    size: 36,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.parentModeLoginRequired,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: Text(l10n.login),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<bool>(
      valueListenable: ParentService.instance.isEnabled,
      builder: (context, isEnabled, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Parent dashboard card (for parents to view children).
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ParentDashboardScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C8FF), Color(0xFF0088CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.parentDashboardViewChild,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.parentDashboardNoChildrenHint,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Divider with "or"
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withAlpha(50))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'eller / or',
                    style: TextStyle(color: Colors.white.withAlpha(100)),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withAlpha(50))),
              ],
            ),
            const SizedBox(height: 16),

            // Info card.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF00C8FF),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.parentModeDescription,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Enable/disable toggle.
            _buildSettingsCard(
              children: [
                SwitchListTile(
                  title: Text(
                    l10n.parentModeEnable,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    isEnabled
                        ? l10n.parentModeEnabledSubtitle
                        : l10n.parentModeDisabledSubtitle,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  value: isEnabled,
                  activeTrackColor: const Color(0xFF00C8FF),
                  onChanged: _isLoading
                      ? null
                      : (value) => _toggleEnabled(value),
                ),
              ],
            ),

            if (isEnabled) ...[
              const SizedBox(height: 16),
              _buildInviteCodeCard(l10n),
              const SizedBox(height: 16),
              _buildLinkedParentsCard(l10n),
              const SizedBox(height: 16),
              _buildShareSettingsCard(l10n),
              const SizedBox(height: 16),
              _buildAlertSettingsCard(l10n),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInviteCodeCard(AppLocalizations l10n) {
    return ValueListenableBuilder<String?>(
      valueListenable: ParentService.instance.inviteCode,
      builder: (context, code, _) {
        return _buildSettingsCard(
          children: [
            ListTile(
              title: Text(
                l10n.parentModeInviteCode,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                l10n.parentModeInviteCodeSubtitle,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            if (code != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8FF).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00C8FF).withAlpha(100),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C8FF),
                          letterSpacing: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(l10n.parentModeCopyCode),
                        onPressed: () => _copyCode(code),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C8FF),
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(l10n.parentModeShareCode),
                        onPressed: () => _shareCode(code, l10n),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLinkedParentsCard(AppLocalizations l10n) {
    return ValueListenableBuilder<List<LinkedParent>>(
      valueListenable: ParentService.instance.linkedParents,
      builder: (context, parents, _) {
        return _buildSettingsCard(
          children: [
            ListTile(
              title: Text(
                l10n.parentModeLinkedParents,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8FF).withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${parents.length}',
                  style: const TextStyle(
                    color: Color(0xFF00C8FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (parents.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Text(
                  l10n.parentModeNoParentsLinked,
                  style: const TextStyle(color: Colors.white54),
                ),
              )
            else
              ...parents.map(
                (parent) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00C8FF).withAlpha(50),
                    child: Text(
                      (parent.name ?? parent.email)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(color: Color(0xFF00C8FF)),
                    ),
                  ),
                  title: Text(
                    parent.name ?? parent.email,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: parent.name != null
                      ? Text(
                          parent.email,
                          style: const TextStyle(color: Colors.white54),
                        )
                      : null,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.person_remove,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _unlinkParent(parent, l10n),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildShareSettingsCard(AppLocalizations l10n) {
    return ValueListenableBuilder<ParentShareSettings>(
      valueListenable: ParentService.instance.settings,
      builder: (context, settings, _) {
        return _buildSettingsCard(
          children: [
            ListTile(
              title: Text(
                l10n.parentModeShareSettings,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              title: Text(
                l10n.parentModeShareLocation,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                l10n.parentModeShareLocationSubtitle,
                style: const TextStyle(color: Colors.white54),
              ),
              secondary: const Icon(Icons.location_on, color: Colors.white54),
              value: settings.shareLocation,
              activeTrackColor: const Color(0xFF00C8FF),
              onChanged: (value) =>
                  _updateSettings(settings.copyWith(shareLocation: value)),
            ),
            SwitchListTile(
              title: Text(
                l10n.parentModeShareSpeed,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                l10n.parentModeShareSpeedSubtitle,
                style: const TextStyle(color: Colors.white54),
              ),
              secondary: const Icon(Icons.speed, color: Colors.white54),
              value: settings.shareSpeed,
              activeTrackColor: const Color(0xFF00C8FF),
              onChanged: (value) =>
                  _updateSettings(settings.copyWith(shareSpeed: value)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertSettingsCard(AppLocalizations l10n) {
    return ValueListenableBuilder<ParentShareSettings>(
      valueListenable: ParentService.instance.settings,
      builder: (context, settings, _) {
        return _buildSettingsCard(
          children: [
            ListTile(
              title: Text(
                l10n.parentModeAlertSettings,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              title: Text(
                l10n.parentModeSpeedAlert,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                l10n.parentModeSpeedAlertSubtitle(
                  settings.speedLimitKmh.toInt(),
                ),
                style: const TextStyle(color: Colors.white54),
              ),
              secondary: const Icon(
                Icons.warning_amber,
                color: Colors.orangeAccent,
              ),
              value: settings.alertOnSpeeding,
              activeTrackColor: const Color(0xFF00C8FF),
              onChanged: (value) =>
                  _updateSettings(settings.copyWith(alertOnSpeeding: value)),
            ),
            if (settings.alertOnSpeeding)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${l10n.parentModeSpeedLimit}: ${settings.speedLimitKmh.toInt()} km/h',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Expanded(
                      child: Slider(
                        value: settings.speedLimitKmh,
                        min: 20,
                        max: 50,
                        divisions: 30,
                        activeColor: const Color(0xFF00C8FF),
                        inactiveColor: Colors.white24,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(speedLimitKmh: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SwitchListTile(
              title: Text(
                l10n.parentModeNightAlert,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                l10n.parentModeNightAlertSubtitle(
                  settings.nightStartHour,
                  settings.nightEndHour,
                ),
                style: const TextStyle(color: Colors.white54),
              ),
              secondary: const Icon(
                Icons.nightlight_round,
                color: Colors.blueAccent,
              ),
              value: settings.alertOnNightDriving,
              activeTrackColor: const Color(0xFF00C8FF),
              onChanged: (value) => _updateSettings(
                settings.copyWith(alertOnNightDriving: value),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _isLoading = true);
    try {
      if (value) {
        await ParentService.instance.enableSharing();
      } else {
        await ParentService.instance.disableSharing();
      }
    } catch (e) {
      debugPrint('Parent mode toggle error: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSettings(ParentShareSettings settings) {
    ParentService.instance.updateSettings(settings);
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.parentModeCodeCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareCode(String code, AppLocalizations l10n) {
    SharePlus.instance.share(
      ShareParams(
        text: l10n.parentModeShareMessage(code),
        subject: l10n.parentModeShareSubject,
      ),
    );
  }

  Future<void> _unlinkParent(LinkedParent parent, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          l10n.parentModeUnlinkTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.parentModeUnlinkMessage(parent.name ?? parent.email),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(l10n.parentModeUnlink),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ParentService.instance.unlinkParent(parent.id);
    }
  }
}
