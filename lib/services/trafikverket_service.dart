import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/models/alert_model.dart';

/// Fetches cached real-time incidents through the CruizX backend. The
/// Trafikverket API key is held by Cloudflare and never embedded in the app.
class TrafikverketService {
  TrafikverketService._();
  static final TrafikverketService instance = TrafikverketService._();

  static const double _radiusKm = 50;

  bool get isEnabled => BackendConfig.trafficIncidentsUrl.trim().isNotEmpty;

  /// Fetches traffic situations (accidents, roadworks, etc.) near [center].
  Future<List<AlertModel>> fetchNearby(LatLng center) async {
    if (!isEnabled) return const [];

    try {
      final endpoint = Uri.parse(BackendConfig.trafficIncidentsUrl).replace(
        queryParameters: {
          'lat': center.latitude.toStringAsFixed(6),
          'lng': center.longitude.toStringAsFixed(6),
          'radius_km': _radiusKm.toStringAsFixed(0),
        },
      );
      final response = await http
          .get(endpoint, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final incidents = data['incidents'] as List?;
      if (incidents == null) return const [];

      final alerts = <AlertModel>[];
      for (final incident in incidents) {
        final alert = _parseIncident(
          Map<String, dynamic>.from(incident as Map),
        );
        if (alert != null && alert.distanceTo(center) <= _radiusKm * 1000) {
          alerts.add(alert);
        }
      }
      return alerts;
    } catch (e) {
      debugPrint('TrafikverketService error: $e');
      return const [];
    }
  }

  AlertModel? _parseIncident(Map<String, dynamic> incident) {
    try {
      final lat = (incident['lat'] as num?)?.toDouble();
      final lng = (incident['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final id = incident['id']?.toString() ?? '';
      if (id.isEmpty) return null;
      final iconId = (incident['icon_id'] ?? '').toString().toLowerCase();
      final messageCode = (incident['message_code'] ?? '')
          .toString()
          .toLowerCase();
      final header = (incident['header'] ?? '').toString();
      final roadNumber = (incident['road_number'] ?? '').toString();

      final type = classifyAlert(
        iconId: iconId,
        messageCode: messageCode,
        header: header,
      );

      final description = [
        if (roadNumber.isNotEmpty) roadNumber,
        if (header.isNotEmpty) header,
      ].join(' — ');

      final startRaw = incident['start_time']?.toString();
      final endRaw = incident['end_time']?.toString();
      final createdAt = startRaw != null
          ? DateTime.tryParse(startRaw) ?? DateTime.now()
          : DateTime.now();
      final expiresAt = endRaw != null ? DateTime.tryParse(endRaw) : null;

      // Skip if already expired
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        return null;
      }

      return AlertModel(
        id: 'tv_$id',
        type: type,
        position: LatLng(lat, lng),
        description: description,
        upvotes: 0,
        createdAt: createdAt,
        userId: 'trafikverket',
      );
    } catch (_) {
      return null;
    }
  }

  /// Maps Trafikverket's varying icon/message vocabulary to CruizX alerts.
  /// Kept public so classification changes can be covered by unit tests.
  static AlertType classifyAlert({
    required String iconId,
    required String messageCode,
    String header = '',
  }) {
    final text = '$iconId $messageCode $header'.toLowerCase();

    if (text.contains('roadclosed') ||
        text.contains('road closed') ||
        text.contains('road closure') ||
        text.contains('closed road') ||
        text.contains('totalstopp') ||
        text.contains('vägstopp') ||
        text.contains('vägen avstängd') ||
        text.contains('väg avstängd') ||
        text.contains('vagen avstangd') ||
        text.contains('vag avstangd') ||
        iconId.contains('closure') ||
        iconId.contains('blocked')) {
      return AlertType.roadClosure;
    }
    if (text.contains('accident') || text.contains('olycka')) {
      return AlertType.accident;
    }
    if (text.contains('roadwork') ||
        text.contains('maintenance') ||
        text.contains('vägarbete')) {
      return AlertType.roadwork;
    }
    if (text.contains('congestion') ||
        text.contains('queue') ||
        text.contains('köbildning')) {
      return AlertType.trafficJam;
    }
    if (text.contains('speedcamera') ||
        text.contains('speed camera') ||
        text.contains('fartkamera')) {
      return AlertType.speedCamera;
    }
    if (text.contains('police') || text.contains('polis')) {
      return AlertType.police;
    }
    return AlertType.hazard;
  }
}
