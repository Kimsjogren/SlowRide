import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/services/user_preferences_service.dart';

enum PaywallReason { routeLimit, convoyLimit, memberLimit }

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const int freeMaxDailyRoutes = 4;
  static const int freeMaxConvoyMembers = 2;

  /// App Store Connect product ID for monthly subscription.
  static const String _monthlyProductId = 'cruizx_pro_monthly_v2';

  static const String _isProKey = 'sub_is_pro';
  static const String _routeCountKey = 'sub_route_count';
  static const String _routeDateKey = 'sub_route_date';

  final InAppPurchase _iap = InAppPurchase.instance;
  late SharedPreferences _prefs;
  bool _initialized = false;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  ProductDetails? _monthlyProduct;
  Completer<bool>? _purchaseCompleter;
  Completer<bool>? _restoreCompleter;
  Timer? _webSyncTimer;
  bool _authListenersAttached = false;
  bool _webSyncInFlight = false;
  bool _languageListenerAttached = false;
  Map<String, String> _webPriceByLocale = const {};

  final ValueNotifier<bool> isPro = ValueNotifier<bool>(false);

  /// Localized price string from App Store or Stripe pricing endpoint.
  final ValueNotifier<String?> localizedPrice = ValueNotifier<String?>(null);

  bool get isWebCheckout => kIsWeb || BackendConfig.webCheckoutOnly;

  String? get webCheckoutUrl {
    final raw = BackendConfig.webCheckoutUrl.trim();
    if (raw.isEmpty) return null;
    return raw;
  }

  Uri? buildWebCheckoutUri() {
    final raw = webCheckoutUrl;
    if (raw == null) return null;

    final baseUri = Uri.tryParse(raw);
    if (baseUri == null) return null;

    final merged = Map<String, String>.from(baseUri.queryParameters);
    merged['source'] = 'slowride_web';

    final uid = AuthService.instance.userId.value;
    final email = AuthService.instance.userEmail.value;
    if (uid != null && uid.isNotEmpty) {
      merged['uid'] = uid;
    }
    if (email != null && email.isNotEmpty) {
      merged['email'] = email;
    }

    return baseUri.replace(queryParameters: merged);
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    // FORCE_FREE clears saved Pro and sets free mode (for testing ads etc.)
    if (BackendConfig.forceFree) {
      await _prefs.setBool(_isProKey, false);
      isPro.value = false;
    } else if (BackendConfig.forcePro) {
      // FORCE_PRO overrides to Pro mode
      isPro.value = true;
    } else {
      // Normal: read from stored preferences
      isPro.value = _prefs.getBool(_isProKey) ?? false;
    }

    if (kIsWeb) {
      _attachLanguageListener();
      await _loadWebPricing();
      _attachAuthListeners();
      await syncWebEntitlement();
      _startWebEntitlementPolling();
    } else if (isWebCheckout) {
      _attachLanguageListener();
      await _loadWebPricing();
    } else {
      await _startIap();
    }

    _initialized = true;
  }

  void _attachAuthListeners() {
    if (_authListenersAttached) return;
    AuthService.instance.userId.addListener(_onAuthChanged);
    AuthService.instance.isLoggedIn.addListener(_onAuthChanged);
    _authListenersAttached = true;
  }

  void _attachLanguageListener() {
    if (_languageListenerAttached) return;
    UserPreferencesService.instance.languageCode.addListener(
      _refreshWebDisplayPrice,
    );
    _languageListenerAttached = true;
  }

  String _currentLanguageCode() {
    final explicit = UserPreferencesService.instance.languageCode.value;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final platformCode = PlatformDispatcher.instance.locale.languageCode;
    return platformCode.isEmpty ? 'en' : platformCode;
  }

  void _refreshWebDisplayPrice() {
    final lang = _currentLanguageCode();
    localizedPrice.value =
        _webPriceByLocale[lang] ??
        _webPriceByLocale['en'] ??
        BackendConfig.webCheckoutDisplayPrice;
  }

  Future<void> _loadWebPricing() async {
    try {
      final res = await http.get(Uri.parse(BackendConfig.webPricingUrl));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _refreshWebDisplayPrice();
        return;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final pricing = Map<String, dynamic>.from(
        (data['pricing'] as Map?) ?? const {},
      );
      final amountByLocale = Map<String, dynamic>.from(
        (pricing['amount_by_locale'] as Map?) ?? const {},
      );
      _webPriceByLocale = amountByLocale.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      _refreshWebDisplayPrice();
    } catch (e) {
      debugPrint('Web pricing fetch failed: $e');
      _refreshWebDisplayPrice();
    }
  }

  void _onAuthChanged() {
    if (!kIsWeb) return;
    unawaited(syncWebEntitlement(force: true));
  }

  void _startWebEntitlementPolling() {
    _webSyncTimer?.cancel();
    _webSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(syncWebEntitlement());
    });
  }

  Future<bool> syncWebEntitlement({bool force = false}) async {
    if (!kIsWeb) return isPro.value;
    if (_webSyncInFlight && !force) return isPro.value;
    if (BackendConfig.forcePro) {
      await activatePro();
      return true;
    }
    if (BackendConfig.forceFree) {
      await deactivatePro();
      return false;
    }
    if (!SupabaseService.instance.isEnabled) {
      return isPro.value;
    }

    _webSyncInFlight = true;
    try {
      final uid = AuthService.instance.userId.value;
      if (uid == null || uid.isEmpty) {
        await deactivatePro();
        return false;
      }

      final rows = await SupabaseService.instance.client
          .from('web_subscriptions')
          .select('status,current_period_end,updated_at')
          .eq('user_id', uid)
          .order('updated_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) {
        await deactivatePro();
        return false;
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      final status = (row['status'] ?? '').toString().toLowerCase();
      final endRaw = row['current_period_end']?.toString();
      final periodEnd = endRaw == null ? null : DateTime.tryParse(endRaw);
      final nowUtc = DateTime.now().toUtc();
      final periodEndUtc = periodEnd?.toUtc();

      final activeStatus = status == 'active' || status == 'trialing';
      final graceStatus =
          status == 'canceled' &&
          periodEndUtc != null &&
          periodEndUtc.isAfter(nowUtc);

      if (activeStatus || graceStatus) {
        await activatePro();
        return true;
      }

      await deactivatePro();
      return false;
    } catch (e) {
      debugPrint('Web subscription sync failed: $e');
      return isPro.value;
    } finally {
      _webSyncInFlight = false;
    }
  }

  Future<void> _startIap() async {
    if (kIsWeb) return;
    try {
      final available = await _iap.isAvailable();
      if (!available) return;

      await _purchaseSub?.cancel();
      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e) {
          debugPrint('IAP purchase stream error: $e');
        },
      );

      await _loadProductDetails();
    } catch (e) {
      debugPrint('Failed to initialize IAP: $e');
    }
  }

  Future<void> _loadProductDetails() async {
    try {
      final response = await _iap.queryProductDetails({_monthlyProductId});
      if (response.productDetails.isEmpty) {
        debugPrint('IAP product not found: $_monthlyProductId');
        return;
      }
      _monthlyProduct = response.productDetails.first;
      localizedPrice.value = _monthlyProduct!.price;
    } catch (e) {
      debugPrint('Failed to fetch IAP product details: $e');
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.productID != _monthlyProductId) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await activatePro();
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete(true);
          }
          if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
            _restoreCompleter!.complete(true);
          }
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete(false);
          }
          if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
            _restoreCompleter!.complete(false);
          }
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  // ── Daily route tracking ────────────────────────────────────────────────

  int get routesToday {
    final savedDate = _prefs.getString(_routeDateKey) ?? '';
    if (savedDate != _todayString) return 0;
    return _prefs.getInt(_routeCountKey) ?? 0;
  }

  bool canStartRoute() => isPro.value || routesToday < freeMaxDailyRoutes;

  void recordRoute() {
    final today = _todayString;
    final savedDate = _prefs.getString(_routeDateKey) ?? '';
    final count = savedDate == today ? (_prefs.getInt(_routeCountKey) ?? 0) : 0;
    _prefs.setString(_routeDateKey, today);
    _prefs.setInt(_routeCountKey, count + 1);
  }

  String get _todayString {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  // ── Convoy limits ───────────────────────────────────────────────────────

  /// Free users can only be in 1 convoy at a time.
  bool canCreateOrJoinConvoy(int currentJoinedCount) =>
      isPro.value || currentJoinedCount == 0;

  /// Free users cannot join a convoy that already has max members.
  bool canJoinConvoyWithMemberCount(int memberCount) =>
      isPro.value || memberCount < freeMaxConvoyMembers;

  // ── Purchase ─────────────────────────────────────────────────────────────

  /// Starts native store purchase flow for monthly Pro subscription.
  Future<bool> purchaseProMonthly() async {
    if (kIsWeb) return false;
    if (BackendConfig.forceFree) return false;
    if (BackendConfig.forcePro) {
      await activatePro();
      return true;
    }

    final available = await _iap.isAvailable();
    if (!available) return false;

    if (_monthlyProduct == null) {
      await _loadProductDetails();
      if (_monthlyProduct == null) return false;
    }

    final completer = Completer<bool>();
    _purchaseCompleter = completer;

    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: _monthlyProduct!),
    );
    if (!started) {
      _purchaseCompleter = null;
      return false;
    }

    final result = await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => false,
    );
    if (identical(_purchaseCompleter, completer)) {
      _purchaseCompleter = null;
    }
    return result;
  }

  /// Activates Pro after successful verified purchase.
  Future<void> activatePro() async {
    isPro.value = true;
    await _prefs.setBool(_isProKey, true);
  }

  /// Restores previous store purchases and reapplies Pro entitlement.
  Future<bool> restorePurchase() async {
    if (kIsWeb) return false;
    if (BackendConfig.forcePro) {
      await activatePro();
      return true;
    }

    final available = await _iap.isAvailable();
    if (!available) return false;

    final completer = Completer<bool>();
    _restoreCompleter = completer;
    await _iap.restorePurchases();

    final result = await completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => isPro.value,
    );
    if (identical(_restoreCompleter, completer)) {
      _restoreCompleter = null;
    }
    return result;
  }

  /// Deactivates Pro (for testing / subscription lapse).
  Future<void> deactivatePro() async {
    isPro.value = false;
    await _prefs.setBool(_isProKey, false);
  }
}
