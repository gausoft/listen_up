## Description
Enable audio playback to continue when the app is in the background or the screen is locked.

## User Story
As a user, I want to lock my phone and continue listening so that I can save battery and avoid accidental touches.

## Acceptance Criteria
- [ ] Audio continues playing when app goes to background
- [ ] Audio continues when screen is locked
- [ ] Works with both ElevenLabs (cloud) and local TTS
- [ ] Proper audio session configuration for iOS and Android
- [ ] App resumes correctly when brought back to foreground

## Technical Notes
- audio_session package is already included
- Verify iOS AVAudioSessionCategory.playback is properly configured
- Android: may need foreground service for reliable background playback
- Test with Bluetooth headphones and car audio

## Priority
P0 - Critical for user experience
