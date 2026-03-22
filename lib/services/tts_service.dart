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
  SharedPreferences? _prefs;
  bool _initialized = false;

  static const Map<String, String> _langMap = {'sv': 'sv-SE', 'en': 'en-US'};

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _prefs = await SharedPreferences.getInstance();
    enabled.value = _prefs?.getBool(_enabledKey) ?? false;

    // iOS: configure audio session so TTS works alongside other audio
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.ambient, [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,
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
  }

  void _onLanguageChanged() => _applyLanguage();

  Future<void> speak(String text) async {
    if (!enabled.value || text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void _persistEnabled() {
    _prefs?.setBool(_enabledKey, enabled.value);
  }
}
