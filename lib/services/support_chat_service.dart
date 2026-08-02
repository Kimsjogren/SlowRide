import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/models/support_message.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/supabase_service.dart';

class SupportChatService {
  SupportChatService._();

  static final SupportChatService instance = SupportChatService._();

  static const String _guestTokenKey = 'support_guest_token_v1';
  static const Duration _guestPollInterval = Duration(seconds: 6);
  final http.Client _httpClient = http.Client();

  String? get _userId => AuthService.instance.userId.value;

  bool get isGuest => _userId == null || _userId!.isEmpty;

  bool get isAvailable => isGuest
      ? BackendConfig.supportGuestUrl.trim().isNotEmpty
      : SupabaseService.instance.isEnabled;

  Stream<List<SupportMessage>> watchMessages() {
    final userId = _userId;
    if (!isAvailable) {
      return Stream.value(const <SupportMessage>[]);
    }

    if (userId == null) return _watchGuestMessages();

    return SupabaseService.instance.client
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => SupportMessage.fromMap(row))
              .toList(growable: false),
        );
  }

  Stream<List<SupportMessage>> _watchGuestMessages() async* {
    while (true) {
      yield await _loadGuestMessages();
      await Future<void>.delayed(_guestPollInterval);
    }
  }

  Future<List<SupportMessage>> _loadGuestMessages() async {
    final token = await _guestToken();
    final response = await _httpClient.get(
      Uri.parse(BackendConfig.supportGuestUrl),
      headers: {'X-CruizX-Guest-Token': token},
    );
    if (response.statusCode != 200) {
      throw StateError('support_chat_unavailable_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = decoded['messages'];
    if (rows is! List) return const <SupportMessage>[];
    return rows
        .whereType<Map>()
        .map((row) => SupportMessage.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> sendMessage({
    required String body,
    required String languageCode,
  }) async {
    final userId = _userId;
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw ArgumentError.value(body, 'body', 'invalid_message_length');
    }

    if (!isAvailable) throw StateError('support_chat_unavailable');

    if (userId == null) {
      final token = await _guestToken();
      final response = await _httpClient.post(
        Uri.parse(BackendConfig.supportGuestUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-CruizX-Guest-Token': token,
        },
        body: jsonEncode({'body': trimmed, 'language_code': languageCode}),
      );
      if (response.statusCode != 201) {
        throw StateError('support_chat_send_failed_${response.statusCode}');
      }
      return;
    }

    await SupabaseService.instance.client.from('support_messages').insert({
      'user_id': userId,
      'sender': 'user',
      'body': trimmed,
      'language_code': languageCode,
    });
  }

  Future<void> markSupportMessagesRead() async {
    final userId = _userId;
    if (!isAvailable || userId == null) return;

    await SupabaseService.instance.client.rpc('mark_support_messages_read');
  }

  Future<String> _guestToken() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_guestTokenKey);
    if (existing != null &&
        RegExp(r'^[A-Za-z0-9_-]{43,128}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    await preferences.setString(_guestTokenKey, token);
    return token;
  }
}
