import 'dart:io' show Platform;

import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/constants/app_constants.dart';

/// Represents the current state of TTS playback
enum TtsState { playing, stopped, paused, continued }

/// Service that handles Text-to-Speech operations
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsState _state = TtsState.stopped;
  TtsState get state => _state;

  List<dynamic> _voices = [];
  List<dynamic> get voices => _voices;

  String? _currentVoice;
  String? get currentVoice => _currentVoice;

  double _speechRate = AppConstants.defaultSpeechRate;
  double get speechRate => _speechRate;

  double _pitch = AppConstants.defaultPitch;
  double get pitch => _pitch;

  double _volume = AppConstants.defaultVolume;
  double get volume => _volume;

  // Callbacks
  Function(TtsState)? onStateChanged;
  Function(int, int)? onProgress;

  /// Initialize TTS engine
  Future<void> init() async {
    // Initialize language detection
    await langdetect.initLangDetect();

    await _flutterTts.setSharedInstance(true);

    // Set default values
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setVolume(_volume);

    // iOS specific - use playback category for reliable audio output
    if (Platform.isIOS) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }

    // Set default language
    await _flutterTts.setLanguage('fr-FR');

    // Android specific
    if (Platform.isAndroid) {
      await _flutterTts.setQueueMode(1); // Queue mode for continuous speech
    }

    // Load available voices
    _voices = await _flutterTts.getVoices;

    // Set up handlers
    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      onStateChanged?.call(_state);
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.paused;
      onStateChanged?.call(_state);
    });

    _flutterTts.setContinueHandler(() {
      _state = TtsState.continued;
      onStateChanged?.call(_state);
    });

    _flutterTts.setProgressHandler((text, start, end, word) {
      onProgress?.call(start, end);
    });

    _flutterTts.setErrorHandler((message) {
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
    });
  }

  /// Speak the given text with auto language detection
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    await stop();

    // Auto-detect language and set appropriate TTS language
    try {
      final detectedLang = langdetect.detect(text);
      final ttsLocale = _mapLanguageToLocale(detectedLang);
      await _flutterTts.setLanguage(ttsLocale);
    } catch (e) {
      // Fallback to French if detection fails
      await _flutterTts.setLanguage('fr-FR');
    }

    await _flutterTts.speak(text);
  }

  /// Map detected language code to TTS locale
  String _mapLanguageToLocale(String langCode) {
    const languageMap = {
      'en': 'en-US',
      'fr': 'fr-FR',
      'es': 'es-ES',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-PT',
      'nl': 'nl-NL',
      'ru': 'ru-RU',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'zh-cn': 'zh-CN',
      'zh-tw': 'zh-TW',
      'ar': 'ar-SA',
      'hi': 'hi-IN',
      'tr': 'tr-TR',
      'pl': 'pl-PL',
      'vi': 'vi-VN',
      'th': 'th-TH',
      'sv': 'sv-SE',
      'da': 'da-DK',
      'fi': 'fi-FI',
      'no': 'nb-NO',
      'cs': 'cs-CZ',
      'el': 'el-GR',
      'he': 'he-IL',
      'id': 'id-ID',
      'ms': 'ms-MY',
      'ro': 'ro-RO',
      'sk': 'sk-SK',
      'uk': 'uk-UA',
    };
    return languageMap[langCode] ?? 'en-US';
  }

  /// Stop speaking
  Future<void> stop() async {
    await _flutterTts.stop();
    _state = TtsState.stopped;
    onStateChanged?.call(_state);
  }

  /// Pause speaking (iOS and Android 24+)
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(
      AppConstants.minSpeechRate,
      AppConstants.maxSpeechRate,
    );
    await _flutterTts.setSpeechRate(_speechRate);
  }

  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(AppConstants.minPitch, AppConstants.maxPitch);
    await _flutterTts.setPitch(_pitch);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
  }

  /// Set voice by name
  Future<void> setVoice(Map<String, String> voice) async {
    // Set language first, then voice
    final locale = voice['locale'];
    if (locale != null) {
      await _flutterTts.setLanguage(locale);
    }
    await _flutterTts.setVoice(voice);
    _currentVoice = voice['name'];
  }

  /// Get voices filtered by language
  List<Map<String, String>> getVoicesForLanguage(String languageCode) {
    return _voices
        .where((voice) => voice['locale']?.startsWith(languageCode) ?? false)
        .map((voice) => Map<String, String>.from(voice as Map))
        .toList();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}
