import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/services/user_preferences_service.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static const String _enabledKey = 'tts_enabled';
  static const String _hintShownKey = 'tts_voice_hint_shown';
  SharedPreferences? _prefs;
  bool _initialized = false;
  String _lastSpokenText = '';

  static const Map<String, String> _langMap = {
    'sv': 'sv-SE',
    'en': 'en-US',
    'fr': 'fr-FR',
    'nb': 'nb-NO',
    'da': 'da-DK',
    'fi': 'fi-FI',
    'es': 'es-ES',
    'it': 'it-IT',
  };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _prefs = await SharedPreferences.getInstance();
    enabled.value = _prefs?.getBool(_enabledKey) ?? false;

    // iOS: use playback category with duckOthers so nav voice is clear
    // and lowers background audio (music/podcasts) during announcements.
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.duckOthers,
    ]);

    await _applyLanguage();
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    enabled.addListener(_persistEnabled);
    UserPreferencesService.instance.languageCode.addListener(
      _onLanguageChanged,
    );
  }

  Future<void> _applyLanguage() async {
    final code = UserPreferencesService.instance.languageCode.value;
    final lang = _langMap[code] ?? 'sv-SE';
    await _tts.setLanguage(lang);

    // Try to pick the best available voice (premium > enhanced > default)
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final matching = voices
            .whereType<Map>()
            .where(
              (v) =>
                  v['locale']?.toString().toLowerCase() == lang.toLowerCase(),
            )
            .toList();

        if (matching.isNotEmpty) {
          // Score voices: premium = 2, enhanced = 1, default = 0
          int score(Map v) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            if (name.contains('premium')) return 2;
            if (name.contains('enhanced')) return 1;
            return 0;
          }

          matching.sort((a, b) => score(b).compareTo(score(a)));
          final best = matching.first;
          await _tts.setVoice({
            'name': best['name'].toString(),
            'locale': best['locale'].toString(),
          });
          debugPrint('TTS voice selected: ${best['name']} (${best['locale']})');
        }
      }
    } catch (e) {
      debugPrint('TTS voice selection failed, using default: $e');
    }
  }

  void _onLanguageChanged() => _applyLanguage();

  Future<void> speak(String text) async {
    if (!enabled.value || text.isEmpty) return;
    if (text == _lastSpokenText) return; // already speaking this
    _lastSpokenText = text;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void _persistEnabled() {
    _prefs?.setBool(_enabledKey, enabled.value);
  }

  /// Returns true the first time TTS is enabled (for showing a voice hint).
  bool consumeVoiceHint() {
    if (_prefs?.getBool(_hintShownKey) ?? false) return false;
    _prefs?.setBool(_hintShownKey, true);
    return true;
  }
}
