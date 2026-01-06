import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../domain/elevenlabs_service.dart';
import '../../domain/tts_service.dart';

/// Controller that manages TTS state and UI interactions
/// Uses ElevenLabs when online, flutter_tts when offline
class TtsController extends ChangeNotifier {
  final TtsService _localTtsService = TtsService();
  final ElevenLabsService _cloudTtsService = ElevenLabsService();
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool get isOnline => _connectivityService.isOnline;

  // Unified state management
  bool _isPlaying = false;
  bool _isPaused = false;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isStopped => !_isPlaying && !_isPaused;

  // For backward compatibility with local TTS state
  TtsState get state {
    if (_isPlaying) return TtsState.playing;
    if (_isPaused) return TtsState.paused;
    return TtsState.stopped;
  }

  double _speechRate = AppConstants.defaultSpeechRate;
  double get speechRate => _speechRate;
  double get pitch => _localTtsService.pitch;
  double get volume => _localTtsService.volume;

  List<Map<String, String>> _availableVoices = [];
  List<Map<String, String>> get availableVoices => _availableVoices;

  String? get currentVoice => _localTtsService.currentVoice;

  String _currentText = '';
  String get currentText => _currentText;

  // Track which service is currently active
  bool _usingCloudTts = false;
  bool get usingCloudTts => _usingCloudTts;

  // Loading state for cloud TTS
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error handling
  String? _lastError;
  String? get lastError => _lastError;

  // Word highlighting progress (for local TTS only)
  int? _currentWordStart;
  int? _currentWordEnd;
  int _textOffset = 0; // Offset when resuming from middle of text

  /// Get adjusted word positions (accounting for resume offset)
  int? get currentWordStart =>
      _currentWordStart != null ? _currentWordStart! + _textOffset : null;
  int? get currentWordEnd =>
      _currentWordEnd != null ? _currentWordEnd! + _textOffset : null;

  /// Callback when word progress changes
  Function(int start, int end)? onWordProgress;

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Initialize the TTS engine and connectivity service
  Future<void> init() async {
    if (_isInitialized) return;

    // Initialize connectivity service
    await _connectivityService.init();
    _connectivitySubscription = _connectivityService.onlineStream.listen((_) {
      notifyListeners();
    });

    // Initialize local TTS
    await _localTtsService.init();
    _localTtsService.onStateChanged = (state) {
      if (!_usingCloudTts) {
        _updateStateFromLocal(state);
      }
    };
    _localTtsService.onProgress = (start, end) {
      _currentWordStart = start;
      _currentWordEnd = end;
      onWordProgress?.call(start, end);
      notifyListeners();
    };

    // Initialize cloud TTS
    await _cloudTtsService.init();
    _cloudTtsService.onStateChanged = (state) {
      if (_usingCloudTts) {
        _updateStateFromCloud(state);
      }
    };

    // Load voices (for local TTS)
    _loadVoices();

    _isInitialized = true;
    notifyListeners();
  }

  void _updateStateFromLocal(TtsState state) {
    _isPlaying = state == TtsState.playing || state == TtsState.continued;
    _isPaused = state == TtsState.paused;
    notifyListeners();
  }

  void _updateStateFromCloud(ElevenLabsState state) {
    _isPlaying = state == ElevenLabsState.playing;
    _isPaused = state == ElevenLabsState.paused;
    notifyListeners();
  }

  void _loadVoices() {
    final allVoices = _localTtsService.voices;
    _availableVoices = allVoices
        .map((voice) => Map<String, String>.from(voice as Map))
        .toList();
    _availableVoices.sort((a, b) {
      final localeCompare = (a['locale'] ?? '').compareTo(b['locale'] ?? '');
      if (localeCompare != 0) return localeCompare;
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });
  }

  /// Speak the given text using appropriate TTS service
  Future<void> speak(String text) async {
    _currentText = text;
    _lastError = null;
    _resetWordProgress();

    if (isOnline) {
      // Use ElevenLabs cloud TTS
      _usingCloudTts = true;
      _isLoading = true;
      notifyListeners();

      await _localTtsService.stop(); // Stop local if playing

      // Convert speechRate (0.0-1.0) to ElevenLabs speed (0.5-2.0)
      final elevenLabsSpeed = 0.5 + (_speechRate * 1.5);
      await _cloudTtsService.setSpeed(elevenLabsSpeed);

      try {
        await _cloudTtsService.speak(text);
      } catch (e) {
        // Fallback to local TTS on error
        debugPrint('ElevenLabs error: $e, falling back to local TTS');
        _lastError = 'ElevenLabs indisponible, utilisation de la voix locale';
        _usingCloudTts = false;
        await _localTtsService.speak(text);
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      // Use local flutter_tts
      _usingCloudTts = false;
      await _cloudTtsService.stop(); // Stop cloud if playing
      await _localTtsService.speak(text);
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    if (_usingCloudTts) {
      await _cloudTtsService.stop();
    } else {
      await _localTtsService.stop();
    }
    _isPlaying = false;
    _isPaused = false;
    _resetWordProgress();
    notifyListeners();
  }

  /// Reset word highlighting progress
  void _resetWordProgress() {
    _currentWordStart = null;
    _currentWordEnd = null;
    _textOffset = 0;
  }

  /// Pause speaking
  Future<void> pause() async {
    if (_usingCloudTts) {
      await _cloudTtsService.pause();
    } else {
      await _localTtsService.pause();
    }
  }

  /// Resume speaking from where we paused
  Future<void> resume() async {
    if (_usingCloudTts) {
      // ElevenLabs supports real pause/resume
      await _cloudTtsService.resume();
    } else {
      // Local TTS: continue from saved position
      // Use the adjusted position (with offset already applied)
      final pausePosition = currentWordStart;
      if (_currentText.isNotEmpty && pausePosition != null) {
        // Set offset to current pause position for correct highlighting
        _textOffset = pausePosition;
        _currentWordStart = null;
        _currentWordEnd = null;

        // Speak remaining text from pause position
        final remainingText = _currentText.substring(pausePosition);
        if (remainingText.isNotEmpty) {
          await _localTtsService.speak(remainingText);
        }
      } else if (_currentText.isNotEmpty) {
        // No position saved, restart from beginning
        _textOffset = 0;
        await _localTtsService.speak(_currentText);
      }
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause(String text) async {
    if (isPlaying) {
      await pause();
    } else if (isPaused && text == _currentText) {
      // Resume from where we paused (works for both cloud and local TTS)
      await resume();
    } else {
      await speak(text);
    }
  }

  /// Set speech rate
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _localTtsService.setSpeechRate(rate);

    // Convert to ElevenLabs speed and apply
    final elevenLabsSpeed = 0.5 + (rate * 1.5);
    await _cloudTtsService.setSpeed(elevenLabsSpeed);

    notifyListeners();
  }

  /// Set pitch (local TTS only)
  Future<void> setPitch(double pitch) async {
    await _localTtsService.setPitch(pitch);
    notifyListeners();
  }

  /// Set volume (local TTS only)
  Future<void> setVolume(double volume) async {
    await _localTtsService.setVolume(volume);
    notifyListeners();
  }

  /// Set voice (local TTS only)
  Future<void> setVoice(Map<String, String> voice) async {
    await _localTtsService.setVoice(voice);
    notifyListeners();
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    _speechRate = AppConstants.defaultSpeechRate;
    await _localTtsService.setSpeechRate(AppConstants.defaultSpeechRate);
    await _localTtsService.setPitch(AppConstants.defaultPitch);
    await _localTtsService.setVolume(AppConstants.defaultVolume);
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityService.dispose();
    _localTtsService.dispose();
    _cloudTtsService.dispose();
    super.dispose();
  }
}
