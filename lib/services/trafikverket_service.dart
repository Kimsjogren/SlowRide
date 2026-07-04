import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/models/alert_model.dart';

/// Fetches real-time traffic incidents from Trafikverket Open API.
///
/// Register for a free API key at: https://api.trafikinfo.trafikverket.se/
/// Build with: --dart-define=TRAFIKVERKET_KEY=your_key_here
class TrafikverketService {
  TrafikverketService._();
  static final TrafikverketService instance = TrafikverketService._();

  static const String _endpoint =
      'https://api.trafikinfo.trafikverket.se/v2/data.json';

  static const double _radiusDeg = 0.45; // ~50 km

  bool get isEnabled => BackendConfig.trafikverketKey.isNotEmpty;

  /// Fetches traffic situations (accidents, roadworks, etc.) near [center].
  Future<List<AlertModel>> fetchNearby(LatLng center) async {
    if (!isEnabled) return const [];

    final minLat = center.latitude - _radiusDeg;
    final maxLat = center.latitude + _radiusDeg;
    final minLng = center.longitude - _radiusDeg;
    final maxLng = center.longitude + _radiusDeg;

    final query =
        '''
<REQUEST>
  <LOGIN authenticationkey="${BackendConfig.trafikverketKey}" />
  <QUERY objecttype="Situation" schemaversion="1.5" limit="100">
    <FILTER>
      <AND>
        <WITHIN name="Deviation.Geometry.WGS84" shape="box" value="$minLng $minLat, $maxLng $maxLat" />
        <EQ name="Deviation.IsActive" value="true" />
      </AND>
    </FILTER>
    <INCLUDE>Deviation.Id,Deviation.Header,Deviation.Geometry.WGS84,Deviation.IconId,Deviation.SeverityCode,Deviation.MessageCode,Deviation.StartTime,Deviation.EndTime,Deviation.RoadNumber</INCLUDE>
  </QUERY>
</REQUEST>''';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'text/xml', 'Accept': 'application/json'},
            body: query,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results =
          (data['RESPONSE']?['RESULT'] as List?)?.firstOrNull
              as Map<String, dynamic>?;
      final situations = results?['Situation'] as List?;
      if (situations == null) return const [];

      final alerts = <AlertModel>[];
      for (final sit in situations) {
        final deviations = sit['Deviation'];
        if (deviations == null) continue;
        final devList = deviations is List ? deviations : [deviations];

        for (final dev in devList) {
          final alert = _parseDeviation(dev as Map<String, dynamic>);
          if (alert != null) alerts.add(alert);
        }
      }
      return alerts;
    } catch (e) {
      debugPrint('TrafikverketService error: $e');
      return const [];
    }
  }

  AlertModel? _parseDeviation(Map<String, dynamic> dev) {
    try {
      final wgs84 = dev['Geometry']?['WGS84'] as String?;
      if (wgs84 == null) return null;

      final pos = _parseWgs84Point(wgs84);
      if (pos == null) return null;

      final id = dev['Id']?.toString() ?? '';
      final iconId = (dev['IconId'] ?? '').toString().toLowerCase();
      final messageCode = (dev['MessageCode'] ?? '').toString().toLowerCase();
      final header = (dev['Header'] ?? '').toString();
      final roadNumber = (dev['RoadNumber'] ?? '').toString();

      final type = _mapToAlertType(iconId, messageCode);

      final description = [
        if (roadNumber.isNotEmpty) roadNumber,
        if (header.isNotEmpty) header,
      ].join(' — ');

      final startRaw = dev['StartTime']?.toString();
      final endRaw = dev['EndTime']?.toString();
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
        position: pos,
        description: description,
        upvotes: 0,
        createdAt: createdAt,
        userId: 'trafikverket',
      );
    } catch (_) {
      return null;
    }
  }

  LatLng? _parseWgs84Point(String wgs84) {
    // Format: "POINT (longitude latitude)"
    final match = RegExp(
      r'POINT\s*\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)',
    ).firstMatch(wgs84);
    if (match == null) return null;
    final lng = double.tryParse(match.group(1)!);
    final lat = double.tryParse(match.group(2)!);
    if (lng == null || lat == null) return null;
    return LatLng(lat, lng);
  }

  AlertType _mapToAlertType(String iconId, String messageCode) {
    if (iconId.contains('accident') ||
        messageCode.contains('accident') ||
        messageCode.contains('olycka')) {
      return AlertType.accident;
    }
    if (iconId.contains('roadwork') ||
        messageCode.contains('roadwork') ||
        iconId.contains('maintenance') ||
        messageCode.contains('vägarbete')) {
      return AlertType.roadwork;
    }
    if (iconId.contains('congestion') ||
        iconId.contains('queue') ||
        messageCode.contains('queue') ||
        messageCode.contains('köbildning')) {
      return AlertType.trafficJam;
    }
    if (iconId.contains('police') || messageCode.contains('police')) {
      return AlertType.police;
    }
    return AlertType.hazard;
  }
}
