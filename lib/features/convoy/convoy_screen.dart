import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/features/auth/login_screen.dart';
import 'package:slowride/features/auth/register_screen.dart';
import 'package:slowride/features/convoy/convoy_controller.dart';
import 'package:slowride/features/convoy/convoy_room_screen.dart';
import 'package:slowride/models/convoy_model.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/features/paywall/paywall_screen.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:slowride/widgets/ad_banner_widget.dart';
import 'package:slowride/widgets/app_background.dart';
import 'package:slowride/services/ad_service.dart';
import 'package:slowride/services/public_gathering_notification_service.dart';
import 'package:slowride/services/user_preferences_service.dart';

class ConvoyScreen extends StatefulWidget {
  const ConvoyScreen({super.key});

  @override
  State<ConvoyScreen> createState() => _ConvoyScreenState();
}

class _ConvoyScreenState extends State<ConvoyScreen> {
  final ConvoyController _controller = ConvoyController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInCodeController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _meetupController = TextEditingController();
  int _streamKey = 0;
  bool _showPublicGatherings = false;
  int _joinedConvoyCount = 0;
  List<ConvoyModel> _stableConvoys = const <ConvoyModel>[];
  DateTime? _stableConvoysUpdatedAt;

  @override
  void dispose() {
    _nameController.dispose();
    _joinCodeController.dispose();
    _meetupController.dispose();
    _signInEmailController.dispose();
    _signInCodeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<LatLng?> _currentGatheringPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showCreateDialog(
    AppLocalizations l10n, {
    bool publicGathering = false,
  }) async {
    _nameController.text = '';
    _meetupController.text = '';
    var selectedStart = DateTime.now().add(const Duration(minutes: 15));
    var selectedEnd = selectedStart.add(const Duration(hours: 6));

    Future<DateTime?> pickDateTime(
      BuildContext pickerContext,
      DateTime initial,
    ) async {
      final date = await showDatePicker(
        context: pickerContext,
        initialDate: initial,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (date == null || !pickerContext.mounted) return null;
      final time = await showTimePicker(
        context: pickerContext,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    String formatDateTime(BuildContext formatContext, DateTime value) {
      final material = MaterialLocalizations.of(formatContext);
      return '${material.formatMediumDate(value)} · '
          '${material.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF1E6BFF).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.groups,
                        color: Color(0xFF3AA8FF),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        publicGathering
                            ? l10n.publicGatheringCreateTitle
                            : l10n.convoyNameDialogTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: l10n.convoyNameHint,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                        borderSide: const BorderSide(color: Color(0xFF1E6BFF)),
                      ),
                    ),
                  ),
                  if (publicGathering) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _meetupController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.publicGatheringPlaceHint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          color: Colors.white54,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.publicGatheringLocationExplanation,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l10n.publicGatheringStartTime),
                                Text(
                                  formatDateTime(ctx, selectedStart),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            onPressed: () async {
                              final picked = await pickDateTime(
                                ctx,
                                selectedStart,
                              );
                              if (picked == null) return;
                              setSheetState(() {
                                final duration = selectedEnd.difference(
                                  selectedStart,
                                );
                                selectedStart = picked;
                                selectedEnd = picked.add(
                                  duration.isNegative ||
                                          duration == Duration.zero
                                      ? const Duration(hours: 6)
                                      : duration,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event_available, size: 18),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l10n.publicGatheringEndTime),
                                Text(
                                  formatDateTime(ctx, selectedEnd),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            onPressed: () async {
                              final picked = await pickDateTime(
                                ctx,
                                selectedEnd,
                              );
                              if (picked != null) {
                                setSheetState(() => selectedEnd = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          l10n.convoyCreateCancel,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E6BFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) return;
                          final meetupLabel = _meetupController.text.trim();
                          if (publicGathering && meetupLabel.isEmpty) return;
                          if (publicGathering &&
                              !selectedEnd.isAfter(selectedStart)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.publicGatheringScheduleInvalid,
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.of(ctx).pop();
                          LatLng? meetupPosition;
                          if (publicGathering) {
                            meetupPosition = await _currentGatheringPosition();
                            if (meetupPosition == null) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.publicGatheringLocationRequired,
                                  ),
                                ),
                              );
                              return;
                            }
                          }
                          await _controller.createConvoy(
                            name: name,
                            isPublic: publicGathering,
                            meetupPosition: meetupPosition,
                            meetupLabel: meetupLabel,
                            startsAt: publicGathering ? selectedStart : null,
                            endsAt: publicGathering ? selectedEnd : null,
                          );
                          if (mounted) setState(() => _streamKey++);
                        },
                        child: Text(
                          publicGathering
                              ? l10n.publicGatheringPublish
                              : l10n.convoyCreateConfirm,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _shareConvoy(ConvoyModel convoy) {
    final l10n = AppLocalizations.of(context)!;
    final code = convoy.id.split('-').first.toUpperCase();
    Clipboard.setData(
      ClipboardData(text: l10n.convoyShareClipboard(convoy.name, code)),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.convoyShareCopied(convoy.name, code)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _confirmAction(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _chooseReportReason(AppLocalizations l10n) {
    final reasons = <String, String>{
      'inappropriate': l10n.reportReasonInappropriate,
      'harassment': l10n.reportReasonHarassment,
      'dangerous': l10n.reportReasonDangerous,
      'spam': l10n.reportReasonSpam,
      'other': l10n.reportReasonOther,
    };
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.publicGatheringReportReason,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final reason in reasons.entries)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(reason.value),
                onTap: () => Navigator.pop(sheetContext, reason.key),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGatheringMenu(
    String action,
    ConvoyModel convoy,
    AppLocalizations l10n,
  ) async {
    if (action == 'end') {
      if (!await _confirmAction(l10n.publicGatheringEndConfirm)) return;
      await _controller.endGathering(convoyId: convoy.id);
    } else if (action == 'delete') {
      if (!await _confirmAction(l10n.publicGatheringDeleteConfirm)) return;
      await _controller.deleteGathering(convoyId: convoy.id);
    } else if (action == 'report') {
      final reason = await _chooseReportReason(l10n);
      if (reason == null) return;
      await _controller.reportGathering(convoyId: convoy.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.publicGatheringReportSent)));
      }
      return;
    } else if (action == 'block') {
      await _controller.blockGathering(convoyId: convoy.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.publicGatheringBlocked)));
      }
    }
    if (mounted) setState(() => _streamKey++);
  }

  Future<void> _showJoinByCodeDialog(AppLocalizations l10n) async {
    _joinCodeController.text = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.vpn_key,
                      color: Color(0xFF3AA8FF),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.convoyJoinByCodeTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.convoyJoinByCodeHint,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _joinCodeController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XXXXXXXX',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      letterSpacing: 3,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                      borderSide: const BorderSide(color: Color(0xFF1E6BFF)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        l10n.convoyCreateCancel,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E6BFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () async {
                        final code = _joinCodeController.text.trim();
                        if (code.isEmpty) return;
                        Navigator.of(ctx).pop();
                        final convoy = await _controller.joinByCode(code);
                        if (!mounted) return;
                        if (convoy == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.convoyJoinByCodeNotFound),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        setState(() => _streamKey++);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.convoyJoinByCodeSuccess(convoy.name),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text(l10n.convoyJoinButton),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = AuthService.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: authService.isLoggedIn,
      builder: (context, isLoggedIn, _) {
        return AppBackground(
          showLogo: false,
          child: Column(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (!isLoggedIn) {
                      return Align(
                        alignment: const Alignment(0, -0.35),
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
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.groups,
                                      size: 36,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.convoyRequiresSignInTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      l10n.convoyRequiresSignInSubtitle,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () async {
                                            await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const LoginScreen(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.login),
                                          label: Text(l10n.signIn),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const RegisterScreen(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.person_add_alt_1,
                                          ),
                                          label: Text(l10n.signUp),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white70,
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Center(
                          child: Image.asset(
                            'assets/logga_nobg.png',
                            width: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _showPublicGatherings
                                      ? l10n.publicGatheringsTitle
                                      : l10n.convoyModeTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _showPublicGatherings
                                      ? l10n.publicGatheringsSubtitle
                                      : l10n.convoyModeSubtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SegmentedButton<bool>(
                                  segments: [
                                    ButtonSegment<bool>(
                                      value: false,
                                      icon: const Icon(Icons.lock_outline),
                                      label: Text(l10n.publicGatheringsMineTab),
                                    ),
                                    ButtonSegment<bool>(
                                      value: true,
                                      icon: const Icon(Icons.public),
                                      label: Text(
                                        l10n.publicGatheringsPublicTab,
                                      ),
                                    ),
                                  ],
                                  selected: {_showPublicGatherings},
                                  onSelectionChanged: (selection) {
                                    setState(() {
                                      _showPublicGatherings = selection.first;
                                      _streamKey++;
                                    });
                                  },
                                  style: ButtonStyle(
                                    foregroundColor: WidgetStateProperty.all(
                                      Colors.white,
                                    ),
                                    side: WidgetStateProperty.all(
                                      BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_showPublicGatherings) ...[
                                  const SizedBox(height: 8),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: UserPreferencesService
                                        .instance
                                        .nearbyGatheringNotifications,
                                    builder: (context, enabled, _) => SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      value: enabled,
                                      title: Text(
                                        l10n.publicGatheringNearbyNotifications,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        l10n.publicGatheringNearbyNotificationsSubtitle,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                      onChanged: (value) async {
                                        if (!value) {
                                          PublicGatheringNotificationService
                                              .instance
                                              .disable();
                                          return;
                                        }
                                        final enabled =
                                            await PublicGatheringNotificationService
                                                .instance
                                                .enable();
                                        if (!enabled && context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.publicGatheringLocationRequired,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  onPressed: () {
                                    final sub = SubscriptionService.instance;
                                    if (!sub.canCreateOrJoinConvoy(
                                      _joinedConvoyCount,
                                    )) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<bool>(
                                          builder: (_) => const PaywallScreen(
                                            reason: PaywallReason.convoyLimit,
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    _showCreateDialog(
                                      l10n,
                                      publicGathering: _showPublicGatherings,
                                    );
                                  },
                                  icon: Icon(
                                    _showPublicGatherings
                                        ? Icons.add_location_alt
                                        : Icons.add,
                                  ),
                                  label: Text(
                                    _showPublicGatherings
                                        ? l10n.publicGatheringCreateButton
                                        : l10n.convoyCreateButton,
                                  ),
                                ),
                                if (!_showPublicGatherings) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      final sub = SubscriptionService.instance;
                                      if (!sub.canCreateOrJoinConvoy(
                                        _joinedConvoyCount,
                                      )) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<bool>(
                                            builder: (_) => const PaywallScreen(
                                              reason: PaywallReason.convoyLimit,
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      _showJoinByCodeDialog(l10n);
                                    },
                                    icon: const Icon(Icons.vpn_key, size: 18),
                                    label: Text(l10n.convoyJoinWithCodeButton),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!authService.supportsRealtimeBackend)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Text(
                              l10n.convoyRealtimeBackendMissing,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        Expanded(
                          child: StreamBuilder<List<ConvoyModel>>(
                            key: ValueKey(_streamKey),
                            stream: _showPublicGatherings
                                ? _controller.watchPublicGatherings()
                                : _controller.watchConvoys(),
                            builder: (context, snapshot) {
                              final allConvoys = snapshot.data ?? const [];
                              if (allConvoys.isNotEmpty) {
                                _stableConvoys = allConvoys;
                                _stableConvoysUpdatedAt = DateTime.now();
                              }

                              final stableAge = _stableConvoysUpdatedAt == null
                                  ? null
                                  : DateTime.now().difference(
                                      _stableConvoysUpdatedAt!,
                                    );
                              final useStableConvoys =
                                  allConvoys.isEmpty &&
                                  _stableConvoys.isNotEmpty &&
                                  (snapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      stableAge != null &&
                                          stableAge <
                                              const Duration(seconds: 10));

                              if (!useStableConvoys && allConvoys.isEmpty) {
                                _stableConvoys = const <ConvoyModel>[];
                                _stableConvoysUpdatedAt = null;
                              }

                              final effectiveConvoys = useStableConvoys
                                  ? _stableConvoys
                                  : allConvoys;
                              final joinedCount = effectiveConvoys
                                  .where((convoy) => convoy.isJoined)
                                  .length;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted &&
                                    _joinedConvoyCount != joinedCount) {
                                  setState(
                                    () => _joinedConvoyCount = joinedCount,
                                  );
                                }
                              });
                              final convoys = effectiveConvoys;

                              if (convoys.isEmpty) {
                                return Center(
                                  child: Text(
                                    _showPublicGatherings
                                        ? l10n.publicGatheringsEmpty
                                        : l10n.convoyListEmptyMine,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  20,
                                ),
                                itemCount: convoys.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final convoy = convoys[index];
                                  final isLeader =
                                      convoy.leaderId ==
                                      AuthService.instance.userId.value;
                                  final isPublic = convoy.isPublic;
                                  return Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      12,
                                      14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1E6BFF,
                                      ).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF3AA8FF,
                                        ).withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Ikon
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF1E6BFF,
                                                ).withValues(alpha: 0.25),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                isPublic
                                                    ? Icons.location_on
                                                    : Icons.groups,
                                                color: const Color(0xFF3AA8FF),
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    convoy.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.person_outline,
                                                        size: 11,
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        l10n.convoyMembers(
                                                          convoy.memberCount,
                                                        ),
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      if (isLeader) ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                const Color(
                                                                  0xFF1E6BFF,
                                                                ).withValues(
                                                                  alpha: 0.35,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            l10n.convoyYouBadge,
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFF3AA8FF,
                                                                  ),
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (isPublic &&
                                                      convoy
                                                          .meetupLabel
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.public,
                                                          size: 11,
                                                          color: Color(
                                                            0xFF66D9FF,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            convoy.meetupLabel,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFF66D9FF,
                                                                  ),
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  if (isPublic &&
                                                      convoy.startsAt !=
                                                          null) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.schedule,
                                                          size: 11,
                                                          color: Colors.white60,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            '${convoy.hasStarted ? l10n.publicGatheringStarted : l10n.publicGatheringUpcoming}: '
                                                            '${MaterialLocalizations.of(context).formatMediumDate(convoy.startsAt!.toLocal())} · '
                                                            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(convoy.startsAt!.toLocal()))}',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white60,
                                                                  fontSize: 11,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            if (isPublic)
                                              PopupMenuButton<String>(
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  color: Colors.white70,
                                                ),
                                                onSelected: (action) =>
                                                    _handleGatheringMenu(
                                                      action,
                                                      convoy,
                                                      l10n,
                                                    ),
                                                itemBuilder: (_) => isLeader
                                                    ? [
                                                        PopupMenuItem(
                                                          value: 'end',
                                                          child: Text(
                                                            l10n.publicGatheringEndAction,
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text(
                                                            l10n.publicGatheringDeleteAction,
                                                          ),
                                                        ),
                                                      ]
                                                    : [
                                                        PopupMenuItem(
                                                          value: 'report',
                                                          child: Text(
                                                            l10n.publicGatheringReportAction,
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'block',
                                                          child: Text(
                                                            l10n.publicGatheringBlockAction,
                                                          ),
                                                        ),
                                                      ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        // Åtgärdsknappar
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (!isPublic)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _shareConvoy(convoy),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        foregroundColor:
                                                            const Color(
                                                              0xFF3AA8FF,
                                                            ),
                                                        side: const BorderSide(
                                                          color: Color(
                                                            0xFF3AA8FF,
                                                          ),
                                                        ),
                                                      ),
                                                  icon: const Icon(
                                                    Icons.person_add_alt_1,
                                                    size: 14,
                                                  ),
                                                  label: Text(
                                                    l10n.convoyInviteButton,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 4),
                                            SizedBox(
                                              height: 36,
                                              child: FilledButton(
                                                onPressed: () async {
                                                  if (!convoy.isJoined) {
                                                    final sub =
                                                        SubscriptionService
                                                            .instance;
                                                    if (!sub
                                                        .canCreateOrJoinConvoy(
                                                          _joinedConvoyCount,
                                                        )) {
                                                      await Navigator.of(
                                                        context,
                                                      ).push(
                                                        MaterialPageRoute<bool>(
                                                          builder: (_) =>
                                                              const PaywallScreen(
                                                                reason: PaywallReason
                                                                    .convoyLimit,
                                                              ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    await _controller
                                                        .joinConvoy(
                                                          convoy: convoy,
                                                        );
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                  }
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          ConvoyRoomScreen(
                                                            convoy: convoy,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF1E6BFF,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  convoy.isJoined
                                                      ? l10n.convoyOpenButton
                                                      : l10n.convoyJoinButton,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              AdBannerWidget(adUnitId: AdService.instance.bannerConvoyUnitId),
            ],
          ),
        );
      },
    );
  }
}
