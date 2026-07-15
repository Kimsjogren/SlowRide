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
                          endsAt: publicGathering
                              ? DateTime.now().add(const Duration(hours: 6))
                              : null,
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
                                                ],
                                              ),
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
