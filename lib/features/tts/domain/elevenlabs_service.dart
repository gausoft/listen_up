import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';

/// Service for ElevenLabs cloud text-to-speech
class ElevenLabsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  double _speed = 1.0;
  double get speed => _speed;

  String? _currentAudioPath;

  void Function(ElevenLabsState state)? onStateChanged;

  Future<void> init() async {
    if (_isInitialized) return;

    // Configure audio session for playback
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _isPaused = false;
        onStateChanged?.call(ElevenLabsState.stopped);
      } else if (state.playing) {
        _isPlaying = true;
        _isPaused = false;
        onStateChanged?.call(ElevenLabsState.playing);
      } else if (!state.playing &&
          state.processingState == ProcessingState.ready) {
        _isPlaying = false;
        _isPaused = true;
        onStateChanged?.call(ElevenLabsState.paused);
      }
    });

    _isInitialized = true;
  }

  Future<void> speak(String text, {String? voiceId}) async {
    if (text.isEmpty) return;

    await stop();

    try {
      // Fetch audio from ElevenLabs API
      final audioBytes = await _fetchAudio(text, voiceId: voiceId);

      if (audioBytes == null) {
        throw Exception('Failed to fetch audio from ElevenLabs');
      }

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/elevenlabs_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await tempFile.writeAsBytes(audioBytes);
      _currentAudioPath = tempFile.path;

      // Play audio
      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.setSpeed(_speed);
      await _audioPlayer.play();

      _isPlaying = true;
      onStateChanged?.call(ElevenLabsState.playing);
    } catch (e) {
      _isPlaying = false;
      onStateChanged?.call(ElevenLabsState.error);
      rethrow;
    }
  }

  Future<Uint8List?> _fetchAudio(String text, {String? voiceId}) async {
    final voice = voiceId ?? AppConstants.elevenLabsDefaultVoiceId;
    final url = Uri.parse(
      '${AppConstants.elevenLabsBaseUrl}/text-to-speech/$voice',
    );

    final response = await http.post(
      url,
      headers: {
        'xi-api-key': AppConstants.elevenLabsApiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body:
          '''
{
  "text": ${_escapeJson(text)},
  "model_id": "${AppConstants.elevenLabsModel}",
  "voice_settings": {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.0,
    "use_speaker_boost": true
  }
}
''',
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception(
        'ElevenLabs API error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  String _escapeJson(String text) {
    return '"${text.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t')}"';
  }

  Future<void> pause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _isPlaying = false;
      _isPaused = true;
      onStateChanged?.call(ElevenLabsState.paused);
    }
  }

  Future<void> resume() async {
    if (_isPaused) {
      await _audioPlayer.play();
      _isPlaying = true;
      _isPaused = false;
      onStateChanged?.call(ElevenLabsState.playing);
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _isPaused = false;
    onStateChanged?.call(ElevenLabsState.stopped);

    // Clean up temp file
    if (_currentAudioPath != null) {
      try {
        final file = File(_currentAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      _currentAudioPath = null;
    }
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    await _audioPlayer.setSpeed(_speed);
  }

  void dispose() {
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
  }
}

enum ElevenLabsState { stopped, playing, paused, error }
