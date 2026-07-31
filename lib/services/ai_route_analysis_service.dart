import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:slowride/services/supabase_service.dart';

class AiRouteAnalysis {
  const AiRouteAnalysis({
    required this.responseId,
    required this.headline,
    required this.summary,
    required this.suitability,
    required this.highlights,
    required this.cautions,
    required this.recommendation,
  });

  final String responseId;
  final String headline;
  final String summary;
  final String suitability;
  final List<String> highlights;
  final List<String> cautions;
  final String recommendation;

  factory AiRouteAnalysis.fromJson(Map<String, dynamic> json) {
    String cleanText(Object? value) =>
        (value as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(cleanText)
            .where((item) => item.isNotEmpty)
            .take(4)
            .toList(growable: false);

    return AiRouteAnalysis(
      responseId: json['response_id'] as String? ?? '',
      headline: cleanText(json['headline']),
      summary: cleanText(json['summary']),
      suitability: json['suitability'] as String? ?? 'caution',
      highlights: strings('highlights'),
      cautions: strings('cautions'),
      recommendation: cleanText(json['recommendation']),
    );
  }
}

class AiRouteAnalysisException implements Exception {
  const AiRouteAnalysisException(this.code);
  final String code;
}

class _CachedAiRouteAnalysis {
  const _CachedAiRouteAnalysis(this.analysis, this.createdAt);

  final AiRouteAnalysis analysis;
  final DateTime createdAt;
}

class AiRouteAnalysisService {
  AiRouteAnalysisService._();

  static final AiRouteAnalysisService instance = AiRouteAnalysisService._();
  static const int freeDailyLimit = 4;
  static const int proDailyLimit = 15;
  static const String _consentKey = 'ai_route_analysis_consent_v1';
  static const String _usageDateKey = 'ai_route_analysis_usage_date_v1';
  static const String _usageCountKey = 'ai_route_analysis_usage_count_v1';
  static const Duration _cacheLifetime = Duration(minutes: 10);
  final http.Client _client = http.Client();
  final Map<String, _CachedAiRouteAnalysis> _cache = {};
  final Map<String, Future<AiRouteAnalysis>> _inFlight = {};

  Future<bool> hasConsent() async =>
      (await SharedPreferences.getInstance()).getBool(_consentKey) ?? false;

  Future<void> setConsent(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_consentKey, value);

  String? get _accessToken {
    if (!SupabaseService.instance.isEnabled) return null;
    return SupabaseService.instance.client.auth.currentSession?.accessToken;
  }

  Future<AiRouteAnalysis> analyze({
    required String language,
    required String vehicleType,
    required String countryCode,
    required double maxSpeedKmh,
    required double distanceKm,
    required double durationMinutes,
    required List<String> streetNames,
    required Map<String, int> alertCounts,
  }) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw const AiRouteAnalysisException('sign_in_required');
    }

    final routeFacts = {
      'language': language,
      'vehicle_type': vehicleType,
      'country_code': countryCode,
      'max_speed_kmh': maxSpeedKmh,
      'route': {
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'street_names': streetNames.take(24).toList(growable: false),
      },
      'alert_counts': Map<String, int>.fromEntries(
        alertCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
    };
    final userId =
        SupabaseService.instance.client.auth.currentSession?.user.id ?? '';
    final cacheKey = '$userId|${jsonEncode(routeFacts)}';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheLifetime) {
      return cached.analysis;
    }
    _cache.removeWhere(
      (_, value) =>
          DateTime.now().difference(value.createdAt) >= _cacheLifetime,
    );

    final existingRequest = _inFlight[cacheKey];
    if (existingRequest != null) return existingRequest;
    final dailyLimit = SubscriptionService.instance.isPro.value
        ? proDailyLimit
        : freeDailyLimit;
    if (await _usageToday() >= dailyLimit) {
      throw const AiRouteAnalysisException('daily_limit');
    }
    final request = _requestAnalysis(token: token, routeFacts: routeFacts);
    _inFlight[cacheKey] = request;
    try {
      final analysis = await request;
      _cache[cacheKey] = _CachedAiRouteAnalysis(analysis, DateTime.now());
      await _recordSuccessfulAnalysis();
      return analysis;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  String get _todayUtc {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<int> _usageToday() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(_usageDateKey) != _todayUtc) {
      await preferences.setString(_usageDateKey, _todayUtc);
      await preferences.setInt(_usageCountKey, 0);
      return 0;
    }
    return preferences.getInt(_usageCountKey) ?? 0;
  }

  Future<void> _recordSuccessfulAnalysis() async {
    final preferences = await SharedPreferences.getInstance();
    final current = await _usageToday();
    await preferences.setString(_usageDateKey, _todayUtc);
    await preferences.setInt(_usageCountKey, current + 1);
  }

  Future<AiRouteAnalysis> _requestAnalysis({
    required String token,
    required Map<String, Object> routeFacts,
  }) async {
    final response = await _client
        .post(
          Uri.parse(BackendConfig.aiRouteAnalysisUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(routeFacts),
        )
        .timeout(const Duration(seconds: 30));

    final body = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AiRouteAnalysisException(body['error'] as String? ?? 'unavailable');
    }
    return AiRouteAnalysis.fromJson(body);
  }

  Future<void> report({
    required String responseId,
    required String reason,
  }) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw const AiRouteAnalysisException('sign_in_required');
    }
    final response = await _client
        .post(
          Uri.parse(BackendConfig.aiReportUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'response_id': responseId, 'reason': reason}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const AiRouteAnalysisException('report_failed');
    }
  }
}
