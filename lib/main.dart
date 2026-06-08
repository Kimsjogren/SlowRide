import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/core/theme/app_theme.dart';
import 'package:slowride/features/auth/reset_password_screen.dart';
import 'package:slowride/features/convoy/convoy_screen.dart';
import 'package:slowride/features/map/map_screen.dart';
import 'package:slowride/features/profile/profile_screen.dart';
import 'package:slowride/features/settings/settings_screen.dart';
import 'package:slowride/services/ad_service.dart';
import 'package:slowride/services/analytics_service.dart';
import 'package:slowride/services/tts_service.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/firebase_service.dart';
import 'package:slowride/services/navigation_request_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error\n$stack');
    return false;
  };

  try {
    await FirebaseService.instance.initialize();
  } catch (e, st) {
    debugPrint('Firebase init error: $e\n$st');
  }
  await AnalyticsService.instance.initialize();
  try {
    await UserPreferencesService.instance.initialize();
  } catch (e, st) {
    debugPrint('UserPreferences init error: $e\n$st');
  }
  try {
    await SupabaseService.instance.initialize();
  } catch (e, st) {
    debugPrint('Supabase init error: $e\n$st');
  }
  runApp(const CruizXApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CruizXApp extends StatefulWidget {
  const CruizXApp({super.key});

  @override
  State<CruizXApp> createState() => _CruizXAppState();
}

class _CruizXAppState extends State<CruizXApp> {
  StreamSubscription<AuthState>? _authSub;
  bool _pendingPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _startAuthListener();
  }

  void _startAuthListener() {
    if (!SupabaseService.instance.isEnabled) return;
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        debugPrint(
          'Auth event: ${data.event}, session: ${data.session != null}',
        );
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _pendingPasswordRecovery = true;
          _tryNavigateToReset();
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Auth stream error: $e\n$st');
        _showErrorDialog('Auth-fel: $e');
      },
    );
  }

  void _tryNavigateToReset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pendingPasswordRecovery) return;
      final nav = navigatorKey.currentState;
      if (nav == null) {
        debugPrint('Auth: navigatorKey null, retrying in 200ms…');
        Future.delayed(const Duration(milliseconds: 200), _tryNavigateToReset);
        return;
      }
      _pendingPasswordRecovery = false;
      try {
        nav.push(
          MaterialPageRoute<void>(builder: (_) => const ResetPasswordScreen()),
        );
      } catch (e, st) {
        debugPrint('Auth navigation error: $e\n$st');
        _showErrorDialog('Navigationsfel: $e');
      }
    });
  }

  void _showErrorDialog(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Debug Error'),
          content: SelectableText(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = UserPreferencesService.instance;

    return ValueListenableBuilder<String?>(
      valueListenable: preferences.languageCode,
      builder: (context, _, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: preferences.localeOverride,
          navigatorObservers: AnalyticsService.instance.navigatorObservers,
          home: const StartupSplashScreen(),
        );
      },
    );
  }
}

class StartupSplashScreen extends StatefulWidget {
  const StartupSplashScreen({super.key});

  @override
  State<StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends State<StartupSplashScreen> {
  static const Duration _holdAtHundred = Duration(milliseconds: 2500);

  int _progress = 0;
  String _startupStatus = '';
  bool _defaultsInitialized = false;

  @override
  void initState() {
    super.initState();
    _runStartupProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_defaultsInitialized) {
      return;
    }

    _startupStatus = AppLocalizations.of(context)!.splashPreparingStartup;
    _defaultsInitialized = true;
  }

  Future<void> _runStartupProgress() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    _updateStartupStatus(l10n.splashPreparingStartup);
    await _setProgress(8);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    _updateStartupStatus(l10n.splashLoadingCoreModules);
    await _setProgress(18);

    try {
      await FirebaseService.instance.initialize();
    } catch (_) {}
    await _setProgress(28);

    // Supabase already initialized in main() before runApp().
    await _setProgress(38);

    _updateStartupStatus(l10n.splashInitializingAccountSession);
    try {
      await AuthService.instance.initialize();
    } catch (_) {}
    await _setProgress(58);

    _updateStartupStatus(l10n.splashLoadingPreferences);
    try {
      await UserPreferencesService.instance.initialize();
    } catch (_) {}
    try {
      await SubscriptionService.instance.initialize();
    } catch (_) {}
    try {
      await AdService.instance.initialize();
    } catch (_) {}
    try {
      await TtsService.instance.initialize();
    } catch (_) {}
    await _setProgress(90);

    _updateStartupStatus(l10n.splashFinalizingStartup);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _setProgress(100);

    _updateStartupStatus(l10n.splashReady);

    await Future<void>.delayed(_holdAtHundred);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  void _updateStartupStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _startupStatus = status;
    });
  }

  Future<void> _setProgress(int target) async {
    final clampedTarget = target.clamp(0, 100);
    while (mounted && _progress < clampedTarget) {
      await Future<void>.delayed(const Duration(milliseconds: 22));
      if (!mounted) {
        return;
      }
      setState(() {
        _progress += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final size = MediaQuery.sizeOf(context);
    final logoWidth = size.width * 0.82;
    final barWidth = size.width * 0.62;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen splash background
          Image.asset('assets/background.png', fit: BoxFit.cover),
          // Centered logo + progress section
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logga_nobg.png', width: logoWidth),
                const SizedBox(height: 12),
                SizedBox(
                  width: barWidth,
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF37C871),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$_progress%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _startupStatus,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Version text bottom-right
          Positioned(
            right: 40,
            bottom: 12,
            child: Text(
              AppLocalizations.of(context)!.splashVersionLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    NavigationRequestService.instance.pendingDestination.addListener(
      _onNavigationRequest,
    );
  }

  @override
  void dispose() {
    NavigationRequestService.instance.pendingDestination.removeListener(
      _onNavigationRequest,
    );
    super.dispose();
  }

  void _onNavigationRequest() {
    final dest = NavigationRequestService.instance.pendingDestination.value;
    if (dest != null && mounted) {
      setState(() => _index = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    const pages = [
      MapScreen(),
      ConvoyScreen(),
      ProfileScreen(),
      SettingsScreen(),
    ];

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.map_outlined),
        label: l10n.navMap,
      ),
      NavigationDestination(
        icon: const Icon(Icons.groups_outlined),
        label: l10n.navConvoy,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        label: l10n.navProfile,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        label: l10n.navSettings,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: destinations,
          onDestinationSelected: (value) {
            if (value == 1 && _index != 1) {
              // Convoy tab — show interstitial for free users first
              AdService.instance.showConvoyInterstitial(
                onDone: () {
                  if (mounted) setState(() => _index = 1);
                },
              );
            } else {
              setState(() => _index = value);
            }
          },
        ),
      ),
    );
  }
}
