import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritePlace {
  final String id;
  final String label;
  final String? icon; // 'home', 'school', 'work', or null for custom
  final double lat;
  final double lon;
  final String address;

  const FavoritePlace({
    required this.id,
    required this.label,
    this.icon,
    required this.lat,
    required this.lon,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon': icon,
    'lat': lat,
    'lon': lon,
    'address': address,
  };

  factory FavoritePlace.fromJson(Map<String, dynamic> json) => FavoritePlace(
    id: json['id'] as String,
    label: json['label'] as String,
    icon: json['icon'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    address: json['address'] as String,
  );
}

class FavoritePlacesService {
  FavoritePlacesService._();
  static final FavoritePlacesService instance = FavoritePlacesService._();

  static const String _key = 'favorite_places';

  final ValueNotifier<List<FavoritePlace>> places =
      ValueNotifier<List<FavoritePlace>>(const []);

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) {
      places.value = const [];
      return;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(FavoritePlace.fromJson)
          .toList();
      places.value = list;
    } catch (_) {
      places.value = const [];
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(places.value.map((p) => p.toJson()).toList());
    await _prefs?.setString(_key, json);
  }

  Future<void> add(FavoritePlace place) async {
    places.value = [...places.value, place];
    await _save();
  }

  Future<void> remove(String id) async {
    places.value = places.value.where((p) => p.id != id).toList();
    await _save();
  }

  Future<void> update(FavoritePlace place) async {
    places.value = [
      for (final p in places.value)
        if (p.id == place.id) place else p,
    ];
    await _save();
  }

  FavoritePlace? findByIcon(String icon) {
    try {
      return places.value.firstWhere((p) => p.icon == icon);
    } catch (_) {
      return null;
    }
  }
}
