/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Audipod';

  // TTS defaults
  static const double defaultSpeechRate = 0.467; // 1.2x display speed
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;

  // TTS limits
  static const double minSpeechRate = 0.0;
  static const double maxSpeechRate = 1.0;
  static const double minPitch = 0.5;
  static const double maxPitch = 2.0;

  // ElevenLabs API
  // TODO: Move to secure storage or environment variables
  static const String elevenLabsApiKey =
      'sk_ec8df64487c2c0df6bc18ca5a589496913543d95369e61fb';
  static const String elevenLabsBaseUrl = 'https://api.elevenlabs.io/v1';
  static const String elevenLabsDefaultVoiceId =
      'JBFqnCBsd6RMkjVDRZzb'; // Default voice
  static const String elevenLabsModel = 'eleven_multilingual_v2';

  // ElevenLabs Streaming
  static const int elevenLabsMaxChunkSize = 5000; // Safe margin vs 10k limit
  static const int elevenLabsMinChunkSize = 100; // Minimum for good prosody
}
