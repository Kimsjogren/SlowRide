import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:slowride/models/convoy_member_location.dart';
import 'package:slowride/models/convoy_message.dart';
import 'package:slowride/models/convoy_model.dart';
import 'package:slowride/models/convoy_pin.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/services/user_preferences_service.dart';

class ConvoyController {
  final List<ConvoyModel> _localConvoys = [];
  final Set<String> _localJoinedConvoyIds = <String>{};
  final Set<String> _localBlockedGatheringIds = <String>{};
  final Set<String> _localBlockedParticipantIds = <String>{};
  final StreamController<List<ConvoyModel>> _localStreamController =
      StreamController<List<ConvoyModel>>.broadcast();

  Stream<List<ConvoyModel>> watchConvoys() {
    if (!SupabaseService.instance.isEnabled) {
      _localStreamController.add(_buildLocalConvoysForCurrentUser());
      return _localStreamController.stream;
    }

    // Only show convoys the current user is a member of (private by default).
    return SupabaseService.instance.client
        .from('convoys')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap(_withMembershipState)
        .map((list) => list.where((c) => c.isJoined).toList(growable: false));
  }

  Stream<List<ConvoyModel>> watchPublicGatherings() {
    if (!SupabaseService.instance.isEnabled) {
      _localStreamController.add(
        _buildLocalConvoysForCurrentUser()
            .where((convoy) => convoy.isPublic && !convoy.hasEnded)
            .toList(growable: false),
      );
      return _localStreamController.stream.map(
        (convoys) => convoys
            .where((convoy) => convoy.isPublic && !convoy.hasEnded)
            .toList(growable: false),
      );
    }

    return SupabaseService.instance.client
        .from('convoys')
        .stream(primaryKey: ['id'])
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .asyncMap(_withMembershipState)
        .asyncMap(_withoutBlockedGatherings)
        .map(
          (convoys) => convoys
              .where((convoy) => convoy.isPublic && !convoy.hasEnded)
              .toList(growable: false),
        );
  }

  /// Join a convoy by its invite code (first segment of the UUID, case-insensitive).
  /// Returns the matched [ConvoyModel] on success, or `null` if not found.
  Future<ConvoyModel?> joinByCode(String code) async {
    final trimmed = code.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    if (!SupabaseService.instance.isEnabled) {
      // Local fallback: scan in-memory convoys.
      final match = _localConvoys.cast<ConvoyModel?>().firstWhere(
        (c) => c!.id.split('-').first.toLowerCase() == trimmed,
        orElse: () => null,
      );
      if (match != null) {
        await joinConvoy(convoy: match);
      }
      return match;
    }

    // Fetch all convoys and find the one whose id starts with the code prefix.
    final rows = await SupabaseService.instance.client
        .from('convoys')
        .select()
        .order('created_at', ascending: false);

    final matchRow = (rows as List).cast<Map<String, dynamic>>().firstWhere(
      (row) => row['id'].toString().split('-').first.toLowerCase() == trimmed,
      orElse: () => <String, dynamic>{},
    );
    if (matchRow.isEmpty || matchRow['id'] == null) return null;

    final convoyId = matchRow['id'].toString();
    final userId = AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) return null;

    // Join the convoy.
    await SupabaseService.instance.client.from('convoy_members').upsert({
      'convoy_id': convoyId,
      'user_id': userId,
    }, onConflict: 'convoy_id,user_id');

    // Return a model so the screen can navigate to it.
    return ConvoyModel(
      id: convoyId,
      name: matchRow['name']?.toString() ?? '',
      leaderId: matchRow['leader_id']?.toString() ?? '',
      memberCount: 0, // will be refreshed by the stream
      createdAt:
          DateTime.tryParse(matchRow['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isJoined: true,
      isPublic: matchRow['visibility']?.toString() == 'public',
      meetupLat: (matchRow['meetup_lat'] as num?)?.toDouble(),
      meetupLng: (matchRow['meetup_lng'] as num?)?.toDouble(),
      meetupLabel: matchRow['meetup_label']?.toString() ?? '',
      startsAt: DateTime.tryParse(matchRow['starts_at']?.toString() ?? ''),
      endsAt: DateTime.tryParse(matchRow['ends_at']?.toString() ?? ''),
    );
  }

  List<ConvoyModel> _buildLocalConvoysForCurrentUser() {
    return _localConvoys
        .map(
          (convoy) => ConvoyModel(
            id: convoy.id,
            name: convoy.name,
            leaderId: convoy.leaderId,
            memberCount: convoy.memberCount,
            createdAt: convoy.createdAt,
            isJoined: _localJoinedConvoyIds.contains(convoy.id),
            isPublic: convoy.isPublic,
            meetupLat: convoy.meetupLat,
            meetupLng: convoy.meetupLng,
            meetupLabel: convoy.meetupLabel,
            startsAt: convoy.startsAt,
            endsAt: convoy.endsAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<ConvoyModel>> _withMembershipState(
    List<Map<String, dynamic>> convoyRows,
  ) async {
    final currentUserId = AuthService.instance.userId.value;
    final convoyIds = convoyRows.map((row) => row['id'].toString()).toList();

    final Map<String, int> memberCounts = <String, int>{};
    final Set<String> joinedConvoyIds = <String>{};

    if (convoyIds.isNotEmpty) {
      final membershipRows = await SupabaseService.instance.client
          .from('convoy_members')
          .select('convoy_id,user_id')
          .inFilter('convoy_id', convoyIds);

      for (final row in membershipRows) {
        final convoyId = row['convoy_id'].toString();
        final memberUserId = row['user_id']?.toString();

        memberCounts[convoyId] = (memberCounts[convoyId] ?? 0) + 1;
        if (currentUserId != null && memberUserId == currentUserId) {
          joinedConvoyIds.add(convoyId);
        }
      }
    }

    return convoyRows
        .map((row) {
          final convoyId = row['id'].toString();
          final map = <String, dynamic>{
            'name': row['name'],
            'leaderId': row['leader_id'],
            'memberCount': memberCounts[convoyId] ?? 0,
            'createdAt': row['created_at'],
            'isJoined': joinedConvoyIds.contains(convoyId),
            'visibility': row['visibility'],
            'meetup_lat': row['meetup_lat'],
            'meetup_lng': row['meetup_lng'],
            'meetup_label': row['meetup_label'],
            'starts_at': row['starts_at'],
            'ends_at': row['ends_at'],
          };
          return ConvoyModel.fromMap(id: convoyId, map: map);
        })
        .toList(growable: false);
  }

  Future<List<ConvoyModel>> _withoutBlockedGatherings(
    List<ConvoyModel> convoys,
  ) async {
    final blockedIds = await blockedGatheringIds();
    return convoys
        .where((convoy) => !blockedIds.contains(convoy.id))
        .toList(growable: false);
  }

  Future<Set<String>> blockedGatheringIds() async {
    if (!SupabaseService.instance.isEnabled) {
      return Set<String>.from(_localBlockedGatheringIds);
    }
    final userId = AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) return <String>{};
    final rows = await SupabaseService.instance.client
        .from('convoy_blocks')
        .select('gathering_id')
        .eq('blocker_id', userId)
        .eq('target_type', 'gathering');
    return rows
        .map<String>((row) => row['gathering_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> blockedParticipantIds() async {
    if (!SupabaseService.instance.isEnabled) {
      return Set<String>.from(_localBlockedParticipantIds);
    }
    final userId = AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) return <String>{};
    final rows = await SupabaseService.instance.client
        .from('convoy_blocks')
        .select('blocked_user_id')
        .eq('blocker_id', userId)
        .eq('target_type', 'participant');
    return rows
        .map<String>((row) => row['blocked_user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> createConvoy({
    required String name,
    bool isPublic = false,
    LatLng? meetupPosition,
    String meetupLabel = '',
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final now = DateTime.now();
    final userId = SupabaseService.instance.isEnabled
        ? (AuthService.instance.userId.value ?? 'guest')
        : (AuthService.instance.userName.value ?? 'guest');

    if (!SupabaseService.instance.isEnabled) {
      final convoyId = now.microsecondsSinceEpoch.toString();
      _localConvoys.insert(
        0,
        ConvoyModel(
          id: convoyId,
          name: name,
          leaderId: userId,
          memberCount: 1,
          createdAt: now,
          isJoined: true,
          isPublic: isPublic,
          meetupLat: meetupPosition?.latitude,
          meetupLng: meetupPosition?.longitude,
          meetupLabel: meetupLabel,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
      );
      _localJoinedConvoyIds.add(convoyId);
      _localStreamController.add(_buildLocalConvoysForCurrentUser());
      return;
    }

    final inserted = await SupabaseService.instance.client
        .from('convoys')
        .insert({
          'name': name,
          'leader_id': userId,
          'created_at': now.toIso8601String(),
          'visibility': isPublic ? 'public' : 'private',
          'meetup_lat': meetupPosition?.latitude,
          'meetup_lng': meetupPosition?.longitude,
          'meetup_label': meetupLabel.trim(),
          'starts_at': (startsAt ?? now).toIso8601String(),
          'ends_at': endsAt?.toIso8601String(),
        })
        .select('id')
        .single();

    await SupabaseService.instance.client.from('convoy_members').insert({
      'convoy_id': inserted['id'],
      'user_id': userId,
    });
  }

  Future<void> joinConvoy({required ConvoyModel convoy}) async {
    if (!SupabaseService.instance.isEnabled) {
      _localJoinedConvoyIds.add(convoy.id);
      final index = _localConvoys.indexWhere((item) => item.id == convoy.id);
      if (index == -1) {
        return;
      }

      final current = _localConvoys[index];
      _localConvoys[index] = ConvoyModel(
        id: current.id,
        name: current.name,
        leaderId: current.leaderId,
        memberCount: current.memberCount + 1,
        createdAt: current.createdAt,
        isJoined: true,
        isPublic: current.isPublic,
        meetupLat: current.meetupLat,
        meetupLng: current.meetupLng,
        meetupLabel: current.meetupLabel,
        startsAt: current.startsAt,
        endsAt: current.endsAt,
      );
      _localStreamController.add(_buildLocalConvoysForCurrentUser());
      return;
    }

    final userId = AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) {
      return;
    }

    await SupabaseService.instance.client.from('convoy_members').upsert({
      'convoy_id': convoy.id,
      'user_id': userId,
    }, onConflict: 'convoy_id,user_id');
  }

  Future<void> leaveConvoy({required ConvoyModel convoy}) async {
    if (!SupabaseService.instance.isEnabled) {
      _localJoinedConvoyIds.remove(convoy.id);
      final index = _localConvoys.indexWhere((item) => item.id == convoy.id);
      if (index != -1 && _localConvoys[index].memberCount > 1) {
        final current = _localConvoys[index];
        _localConvoys[index] = ConvoyModel(
          id: current.id,
          name: current.name,
          leaderId: current.leaderId,
          memberCount: current.memberCount - 1,
          createdAt: current.createdAt,
          isJoined: false,
          isPublic: current.isPublic,
          meetupLat: current.meetupLat,
          meetupLng: current.meetupLng,
          meetupLabel: current.meetupLabel,
          startsAt: current.startsAt,
          endsAt: current.endsAt,
        );
      }
      _localStreamController.add(_buildLocalConvoysForCurrentUser());
      return;
    }

    final userId = AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) {
      return;
    }

    await clearMyLocation(convoyId: convoy.id);

    await SupabaseService.instance.client
        .from('convoy_members')
        .delete()
        .eq('convoy_id', convoy.id)
        .eq('user_id', userId);
  }

  Future<void> endGathering({required String convoyId}) async {
    final endedAt = DateTime.now();
    final startedAt = endedAt.subtract(const Duration(seconds: 1));
    if (!SupabaseService.instance.isEnabled) {
      final index = _localConvoys.indexWhere((item) => item.id == convoyId);
      if (index == -1) return;
      final current = _localConvoys[index];
      _localConvoys[index] = ConvoyModel(
        id: current.id,
        name: current.name,
        leaderId: current.leaderId,
        memberCount: current.memberCount,
        createdAt: current.createdAt,
        isJoined: current.isJoined,
        isPublic: current.isPublic,
        meetupLat: current.meetupLat,
        meetupLng: current.meetupLng,
        meetupLabel: current.meetupLabel,
        startsAt:
            current.startsAt != null && current.startsAt!.isBefore(endedAt)
            ? current.startsAt
            : startedAt,
        endsAt: endedAt,
      );
      _localStreamController.add(_buildLocalConvoysForCurrentUser());
      return;
    }
    await SupabaseService.instance.client
        .from('convoys')
        .update({
          'starts_at': startedAt.toIso8601String(),
          'ends_at': endedAt.toIso8601String(),
        })
        .eq('id', convoyId);
  }

  Future<void> deleteGathering({required String convoyId}) async {
    if (!SupabaseService.instance.isEnabled) {
      _localConvoys.removeWhere((item) => item.id == convoyId);
      _localJoinedConvoyIds.remove(convoyId);
      _localStreamController.add(_buildLocalConvoysForCurrentUser());
      return;
    }
    await SupabaseService.instance.client
        .from('convoys')
        .delete()
        .eq('id', convoyId);
  }

  Future<void> reportGathering({
    required String convoyId,
    required String reason,
  }) => _report(convoyId: convoyId, targetType: 'gathering', reason: reason);

  Future<void> reportParticipant({
    required String convoyId,
    required String participantId,
    required String reason,
  }) => _report(
    convoyId: convoyId,
    targetType: 'participant',
    targetUserId: participantId,
    reason: reason,
  );

  Future<void> _report({
    required String convoyId,
    required String targetType,
    required String reason,
    String? targetUserId,
  }) async {
    if (!SupabaseService.instance.isEnabled) return;
    final userId = AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) return;
    await SupabaseService.instance.client.from('convoy_reports').insert({
      'reporter_id': userId,
      'target_type': targetType,
      'gathering_id': convoyId,
      'target_user_id': targetUserId,
      'reason': reason,
    });
  }

  Future<void> blockGathering({required String convoyId}) async {
    if (!SupabaseService.instance.isEnabled) {
      _localBlockedGatheringIds.add(convoyId);
      _localStreamController.add(_buildLocalConvoysForCurrentUser());
      return;
    }
    final userId = AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) return;
    try {
      await SupabaseService.instance.client.from('convoy_blocks').insert({
        'blocker_id': userId,
        'target_type': 'gathering',
        'gathering_id': convoyId,
      });
    } catch (error) {
      if (!error.toString().contains('23505')) rethrow;
    }
  }

  Future<void> blockParticipant({required String participantId}) async {
    if (!SupabaseService.instance.isEnabled) {
      _localBlockedParticipantIds.add(participantId);
      return;
    }
    final userId = AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) return;
    try {
      await SupabaseService.instance.client.from('convoy_blocks').insert({
        'blocker_id': userId,
        'target_type': 'participant',
        'blocked_user_id': participantId,
      });
    } catch (error) {
      if (!error.toString().contains('23505')) rethrow;
    }
  }

  Future<void> clearMyLocation({required String convoyId}) async {
    final userId = AuthService.instance.userId.value;
    if (!SupabaseService.instance.isEnabled ||
        userId == null ||
        userId.isEmpty) {
      return;
    }

    await SupabaseService.instance.client
        .from('convoy_locations')
        .delete()
        .eq('convoy_id', convoyId)
        .eq('user_id', userId);
  }

  Stream<List<ConvoyMessage>> watchMessages({required String convoyId}) {
    if (!SupabaseService.instance.isEnabled) {
      return const Stream<List<ConvoyMessage>>.empty();
    }

    return SupabaseService.instance.client
        .from('convoy_messages')
        .stream(primaryKey: ['id'])
        .eq('convoy_id', convoyId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .map((row) => ConvoyMessage.fromMap(row))
              .toList(growable: false),
        );
  }

  Future<ConvoyMessage> sendMessage({
    required String convoyId,
    required String text,
  }) async {
    if (!SupabaseService.instance.isEnabled) {
      throw StateError('realtime_backend_missing');
    }

    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'message_is_empty');
    }

    final client = SupabaseService.instance.client;
    final user = client.auth.currentUser;
    final userId = user?.id ?? AuthService.instance.userId.value;
    if (userId == null || userId.isEmpty) {
      throw StateError('authenticated_user_missing');
    }

    final row = await client
        .from('convoy_messages')
        .insert({
          'convoy_id': convoyId,
          'user_id': userId,
          'user_label':
              AuthService.instance.userName.value ??
              user?.userMetadata?['display_name']?.toString() ??
              'Rider',
          'text': normalizedText,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single()
        .timeout(const Duration(seconds: 12));
    return ConvoyMessage.fromMap(row);
  }

  Stream<List<ConvoyMemberLocation>> watchMemberLocations({
    required String convoyId,
  }) {
    if (!SupabaseService.instance.isEnabled) {
      return const Stream<List<ConvoyMemberLocation>>.empty();
    }

    return SupabaseService.instance.client
        .from('convoy_locations')
        .stream(primaryKey: ['convoy_id', 'user_id'])
        .eq('convoy_id', convoyId)
        .order('updated_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => ConvoyMemberLocation.fromMap(row))
              .toList(growable: false),
        );
  }

  Future<void> updateMyLocation({
    required String convoyId,
    required LatLng position,
  }) async {
    final userId = AuthService.instance.userId.value;
    if (!SupabaseService.instance.isEnabled ||
        userId == null ||
        userId.isEmpty) {
      return;
    }

    await SupabaseService.instance.client.from('convoy_locations').upsert({
      'convoy_id': convoyId,
      'user_id': userId,
      'user_label': AuthService.instance.userName.value ?? 'Rider',
      'lat': position.latitude,
      'lng': position.longitude,
      'updated_at': DateTime.now().toIso8601String(),
      'vehicle_style':
          UserPreferencesService.instance.mapMarkerStyle.value.name,
    }, onConflict: 'convoy_id,user_id');
  }

  Stream<List<ConvoyPin>> watchPins({required String convoyId}) {
    if (!SupabaseService.instance.isEnabled) {
      return const Stream<List<ConvoyPin>>.empty();
    }

    return SupabaseService.instance.client
        .from('convoy_pins')
        .stream(primaryKey: ['id'])
        .eq('convoy_id', convoyId)
        .order('created_at', ascending: false)
        .map(
          (rows) =>
              rows.map((row) => ConvoyPin.fromMap(row)).toList(growable: false),
        );
  }

  Future<void> addPin({
    required String convoyId,
    required LatLng position,
    required String label,
    String pinType = 'custom',
  }) async {
    final userId = AuthService.instance.userId.value;
    if (!SupabaseService.instance.isEnabled ||
        userId == null ||
        userId.isEmpty) {
      return;
    }

    final payload = {
      'convoy_id': convoyId,
      'user_id': userId,
      'user_label': AuthService.instance.userName.value ?? 'Rider',
      'label': label.trim().isEmpty ? 'Pin' : label.trim(),
      'type': pinType,
      'lat': position.latitude,
      'lng': position.longitude,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await SupabaseService.instance.client.from('convoy_pins').insert(payload);
    } catch (_) {
      final fallbackPayload = Map<String, dynamic>.from(payload)
        ..remove('type');
      await SupabaseService.instance.client
          .from('convoy_pins')
          .insert(fallbackPayload);
    }
  }

  void dispose() {
    _localStreamController.close();
  }
}
