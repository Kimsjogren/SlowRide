import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DestinationHistoryEntry {
  const DestinationHistoryEntry({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lon,
    required this.updatedAt,
  });

  final String id;
  final String label;
  final String address;
  final double lat;
  final double lon;
  final DateTime updatedAt;

  LatLng get position => LatLng(lat, lon);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'address': address,
    'lat': lat,
    'lon': lon,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DestinationHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DestinationHistoryEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DestinationHistoryService {
  DestinationHistoryService._();
  static final DestinationHistoryService instance =
      DestinationHistoryService._();

  static const String _key = 'destination_history';
  static const int _maxEntries = 12;

  final ValueNotifier<List<DestinationHistoryEntry>> entries =
      ValueNotifier<List<DestinationHistoryEntry>>(const []);

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) {
      entries.value = const [];
      return;
    }
    try {
      final list =
          (jsonDecode(raw) as List)
              .whereType<Map<String, dynamic>>()
              .map(DestinationHistoryEntry.fromJson)
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      entries.value = list.take(_maxEntries).toList(growable: false);
    } catch (_) {
      entries.value = const [];
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(entries.value.map((e) => e.toJson()).toList());
    await _prefs?.setString(_key, json);
  }

  Future<void> add({
    required String label,
    required String address,
    required LatLng position,
  }) async {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) return;

    final deduped = entries.value.where((entry) {
      final sameName =
          entry.label.trim().toLowerCase() == trimmedLabel.toLowerCase();
      final samePlace =
          (entry.lat - position.latitude).abs() < 0.00015 &&
          (entry.lon - position.longitude).abs() < 0.00015;
      return !(sameName || samePlace);
    }).toList();

    entries.value = [
      DestinationHistoryEntry(
        id: 'history_${DateTime.now().millisecondsSinceEpoch}',
        label: trimmedLabel,
        address: address.trim(),
        lat: position.latitude,
        lon: position.longitude,
        updatedAt: DateTime.now(),
      ),
      ...deduped,
    ].take(_maxEntries).toList(growable: false);
    await _save();
  }

  Future<void> clear() async {
    entries.value = const [];
    await _save();
  }
}
