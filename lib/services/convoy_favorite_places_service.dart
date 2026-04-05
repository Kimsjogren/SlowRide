import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/services/favorite_places_service.dart';

class ConvoyFavoritePlacesService {
  ConvoyFavoritePlacesService._();
  static final ConvoyFavoritePlacesService instance =
      ConvoyFavoritePlacesService._();

  static const String _key = 'convoy_favorite_places';

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

  FavoritePlace? findByIcon(String icon) {
    try {
      return places.value.firstWhere((p) => p.icon == icon);
    } catch (_) {
      return null;
    }
  }
}
