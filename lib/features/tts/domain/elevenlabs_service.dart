import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';

/// Service for ElevenLabs cloud text-to-speech with streaming and chunking
class ElevenLabsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  http.Client? _httpClient;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  double _speed = 1.0;
  double get speed => _speed;

  final List<String> _audioFilePaths = [];

  // Callbacks
  void Function(ElevenLabsState state)? onStateChanged;

  /// Called when ElevenLabs fails and fallback to local TTS is needed
  /// Returns the remaining text that needs to be spoken
  void Function(String remainingText, String error)? onFallbackNeeded;

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
        _cleanupAudioFiles();
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

  /// Speak text using streaming API with chunking for long texts
  /// Falls back to local TTS via callback if ElevenLabs fails
  Future<void> speak(String text, {String? voiceId}) async {
    if (text.isEmpty) return;

    await stop();

    final chunks = _splitIntoChunks(text);
    debugPrint('ElevenLabs: Speaking ${chunks.length} chunk(s)');

    try {
      if (chunks.length == 1) {
        // Single chunk - use streaming for faster response
        await _speakSingleChunk(chunks.first, voiceId: voiceId);
      } else {
        // Multiple chunks - stream and concatenate
        await _speakMultipleChunks(chunks, voiceId: voiceId);
      }
    } catch (e) {
      debugPrint('ElevenLabs error: $e');
      _isPlaying = false;
      onStateChanged?.call(ElevenLabsState.error);

      // Trigger fallback with the full text
      if (onFallbackNeeded != null) {
        onFallbackNeeded!(text, e.toString());
        // Don't rethrow - fallback callback handles continuation
      } else {
        rethrow;
      }
    }
  }

  /// Split text into chunks at sentence boundaries
  List<String> _splitIntoChunks(String text) {
    final maxSize = AppConstants.elevenLabsMaxChunkSize;

    // If text is small enough, return as single chunk
    if (text.length <= maxSize) {
      return [text];
    }

    final chunks = <String>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      if (remaining.length <= maxSize) {
        chunks.add(remaining);
        break;
      }

      // Find the best split point (sentence boundary)
      var splitIndex = _findSplitIndex(remaining, maxSize);
      chunks.add(remaining.substring(0, splitIndex).trim());
      remaining = remaining.substring(splitIndex).trim();
    }

    return chunks;
  }

  /// Find the best index to split text (prefer sentence boundaries)
  int _findSplitIndex(String text, int maxSize) {
    // Look for sentence endings within the allowed range
    final searchRange = text.substring(0, maxSize);

    // Priority: . then ! then ? then ; then , then space
    final sentenceEnders = ['. ', '! ', '? ', '.\n', '!\n', '?\n'];
    for (final ender in sentenceEnders) {
      final lastIndex = searchRange.lastIndexOf(ender);
      if (lastIndex > AppConstants.elevenLabsMinChunkSize) {
        return lastIndex + ender.length;
      }
    }

    // Fall back to semicolon or comma
    final lastSemicolon = searchRange.lastIndexOf('; ');
    if (lastSemicolon > AppConstants.elevenLabsMinChunkSize) {
      return lastSemicolon + 2;
    }

    final lastComma = searchRange.lastIndexOf(', ');
    if (lastComma > AppConstants.elevenLabsMinChunkSize) {
      return lastComma + 2;
    }

    // Last resort: split at space
    final lastSpace = searchRange.lastIndexOf(' ');
    if (lastSpace > AppConstants.elevenLabsMinChunkSize) {
      return lastSpace + 1;
    }

    // Worst case: hard split at maxSize
    return maxSize;
  }

  /// Speak a single chunk using streaming API
  Future<void> _speakSingleChunk(String text, {String? voiceId}) async {
    final audioBytes = await _fetchAudioStreaming(text, voiceId: voiceId);

    if (audioBytes.isEmpty) {
      throw Exception('Failed to fetch audio from ElevenLabs');
    }

    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/elevenlabs_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await tempFile.writeAsBytes(audioBytes);
    _audioFilePaths.add(tempFile.path);

    // Play audio
    await _audioPlayer.setFilePath(tempFile.path);
    await _audioPlayer.setSpeed(_speed);
    await _audioPlayer.play();

    _isPlaying = true;
    onStateChanged?.call(ElevenLabsState.playing);
  }

  /// Speak multiple chunks, concatenating audio files
  Future<void> _speakMultipleChunks(
    List<String> chunks, {
    String? voiceId,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final chunkFilePaths = <String>[];

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final previousText = i > 0 ? _getContextText(chunks[i - 1]) : null;
      final nextText =
          i < chunks.length - 1 ? _getContextText(chunks[i + 1]) : null;

      debugPrint('ElevenLabs: Fetching chunk ${i + 1}/${chunks.length}');

      try {
        final audioBytes = await _fetchAudioStreaming(
          chunk,
          voiceId: voiceId,
          previousText: previousText,
          nextText: nextText,
        );

        if (audioBytes.isEmpty) {
          throw Exception('Empty audio response for chunk ${i + 1}');
        }

        // Save chunk to temp file
        final chunkFile = File(
          '${tempDir.path}/elevenlabs_chunk_${DateTime.now().millisecondsSinceEpoch}_$i.mp3',
        );
        await chunkFile.writeAsBytes(audioBytes);
        _audioFilePaths.add(chunkFile.path);
        chunkFilePaths.add(chunkFile.path);
      } catch (e) {
        debugPrint('ElevenLabs: Error on chunk ${i + 1}: $e');

        // Calculate remaining text for fallback
        final remainingChunks = chunks.sublist(i);
        final remainingText = remainingChunks.join(' ');

        // If we have some audio already, play it first
        if (chunkFilePaths.isNotEmpty) {
          await _playAudioFiles(chunkFilePaths);
          // Wait for current audio to finish, then trigger fallback
          _audioPlayer.playerStateStream
              .firstWhere(
                  (state) => state.processingState == ProcessingState.completed)
              .then((_) {
            onFallbackNeeded?.call(remainingText, e.toString());
          });
          return;
        }

        // No audio yet, immediate fallback
        if (onFallbackNeeded != null) {
          onFallbackNeeded!(remainingText, e.toString());
          return;
        }
        rethrow;
      }
    }

    // Play all chunks as concatenated audio
    await _playAudioFiles(chunkFilePaths);
  }

  /// Play a list of audio files as a playlist
  Future<void> _playAudioFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    if (filePaths.length == 1) {
      await _audioPlayer.setFilePath(filePaths.first);
    } else {
      // Create a playlist from the audio files
      await _audioPlayer.setAudioSource(
        // ignore: deprecated_member_use
        ConcatenatingAudioSource(
          children: filePaths.map((p) => AudioSource.file(p)).toList(),
        ),
      );
    }

    await _audioPlayer.setSpeed(_speed);
    await _audioPlayer.play();

    _isPlaying = true;
    onStateChanged?.call(ElevenLabsState.playing);
  }

  /// Get context text (last/first ~100 chars) for prosody continuity
  String _getContextText(String text) {
    const contextLength = 100;
    if (text.length <= contextLength) return text;
    return text.substring(0, contextLength);
  }

  /// Fetch audio using streaming endpoint
  Future<Uint8List> _fetchAudioStreaming(
    String text, {
    String? voiceId,
    String? previousText,
    String? nextText,
  }) async {
    final voice = voiceId ?? AppConstants.elevenLabsDefaultVoiceId;
    // Use optimize_streaming_latency=3 for faster first byte (balance quality/speed)
    final url = Uri.parse(
      '${AppConstants.elevenLabsBaseUrl}/text-to-speech/$voice/stream?optimize_streaming_latency=3',
    );

    // Build request body
    final bodyMap = <String, dynamic>{
      'text': text,
      'model_id': AppConstants.elevenLabsModel,
      'voice_settings': {
        'stability': 0.5,
        'similarity_boost': 0.75,
        'style': 0.0,
        'use_speaker_boost': true,
      },
    };

    // Add context for prosody continuity
    if (previousText != null) {
      bodyMap['previous_text'] = previousText;
    }
    if (nextText != null) {
      bodyMap['next_text'] = nextText;
    }

    // Use streaming request
    _httpClient?.close();
    _httpClient = http.Client();

    final request = http.Request('POST', url);
    request.headers['xi-api-key'] = AppConstants.elevenLabsApiKey;
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'audio/mpeg';
    request.body = jsonEncode(bodyMap);

    final response = await _httpClient!.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception(
        'ElevenLabs API error: ${response.statusCode} - $errorBody',
      );
    }

    // Collect all bytes from the stream
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }

    return Uint8List.fromList(bytes);
  }

  /// Clean up temporary audio files
  Future<void> _cleanupAudioFiles() async {
    for (final path in _audioFilePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    _audioFilePaths.clear();
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
    _httpClient?.close();
    _httpClient = null;

    await _audioPlayer.stop();
    _isPlaying = false;
    _isPaused = false;
    onStateChanged?.call(ElevenLabsState.stopped);

    await _cleanupAudioFiles();
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    await _audioPlayer.setSpeed(_speed);
  }

  void dispose() {
    _httpClient?.close();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _cleanupAudioFiles();
  }
}

enum ElevenLabsState { stopped, playing, paused, error }
