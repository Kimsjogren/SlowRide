import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:slowride/core/constants/backend_config.dart';

class SupportFaqEntry {
  const SupportFaqEntry({
    required this.id,
    required this.questions,
    required this.answers,
    required this.triggers,
  });

  final String id;
  final Map<String, String> questions;
  final Map<String, String> answers;
  final Map<String, List<String>> triggers;

  String question(String languageCode) =>
      questions[languageCode] ?? questions['en'] ?? '';

  String answer(String languageCode) =>
      answers[languageCode] ?? answers['en'] ?? '';

  factory SupportFaqEntry.fromJson(Map<String, dynamic> json) {
    Map<String, String> localizedStrings(String key) =>
        Map<String, dynamic>.from(
          json[key] as Map? ?? const {},
        ).map((language, value) => MapEntry(language, value.toString()));

    final rawTriggers = Map<String, dynamic>.from(
      json['triggers'] as Map? ?? const {},
    );
    return SupportFaqEntry(
      id: json['id']?.toString() ?? '',
      questions: localizedStrings('question'),
      answers: localizedStrings('answer'),
      triggers: rawTriggers.map(
        (language, value) => MapEntry(
          language,
          (value as List? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
        ),
      ),
    );
  }
}

class SupportFaqCatalog {
  const SupportFaqCatalog({required this.version, required this.entries});

  final int version;
  final List<SupportFaqEntry> entries;

  factory SupportFaqCatalog.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return SupportFaqCatalog(
      version: (json['version'] as num?)?.toInt() ?? 0,
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map(
                  (entry) => SupportFaqEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .where((entry) => entry.id.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class SupportFaqService {
  SupportFaqService._();

  static final SupportFaqService instance = SupportFaqService._();
  static const String _assetPath = 'assets/support_faq.json';
  static const Duration _refreshTimeout = Duration(seconds: 4);

  final http.Client _client = http.Client();
  SupportFaqCatalog? _catalog;

  Future<SupportFaqCatalog> load() async {
    final existing = _catalog;
    if (existing != null) return existing;
    final source = await rootBundle.loadString(_assetPath);
    final catalog = SupportFaqCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
    _catalog = catalog;
    return catalog;
  }

  Future<SupportFaqCatalog> refreshFromServer() async {
    final local = await load();
    if (BackendConfig.supportFaqUrl.trim().isEmpty) return local;
    try {
      final response = await _client
          .get(Uri.parse(BackendConfig.supportFaqUrl))
          .timeout(_refreshTimeout);
      if (response.statusCode != 200) return local;
      final remote = SupportFaqCatalog.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (remote.entries.isNotEmpty && remote.version >= local.version) {
        _catalog = remote;
        return remote;
      }
    } catch (_) {
      // The bundled catalog remains available without a network connection.
    }
    return local;
  }

  SupportFaqEntry? match(
    String question,
    String languageCode,
    SupportFaqCatalog catalog,
  ) {
    final normalizedQuestion = _normalize(question);
    if (normalizedQuestion.isEmpty) return null;
    SupportFaqEntry? best;
    var bestScore = 0;
    for (final entry in catalog.entries) {
      final localizedQuestion = _normalize(entry.question(languageCode));
      var score = normalizedQuestion == localizedQuestion ? 100 : 0;
      final triggers = <String>{
        ...?entry.triggers[languageCode],
        ...?entry.triggers['en'],
      };
      for (final trigger in triggers) {
        final normalizedTrigger = _normalize(trigger);
        if (normalizedTrigger.isNotEmpty &&
            normalizedQuestion.contains(normalizedTrigger)) {
          score = score < 20 + normalizedTrigger.split(' ').length
              ? 20 + normalizedTrigger.split(' ').length
              : score;
        }
      }
      if (score > bestScore) {
        best = entry;
        bestScore = score;
      }
    }
    return bestScore >= 20 ? best : null;
  }

  String _normalize(String value) {
    const replacements = {
      'å': 'a',
      'ä': 'a',
      'ö': 'o',
      'æ': 'a',
      'ø': 'o',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'à': 'a',
      'á': 'a',
      'í': 'i',
      'ì': 'i',
      'ó': 'o',
      'ò': 'o',
      'ú': 'u',
      'ù': 'u',
    };
    var normalized = value.toLowerCase();
    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    return normalized
        .replaceAll(RegExp('[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
