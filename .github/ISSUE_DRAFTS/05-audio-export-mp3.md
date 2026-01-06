## Description
Allow users to download and save the generated audio as an MP3 file to their device.

## User Story
As a user, I want to save audio files so that I can listen offline without regenerating the audio.

## Acceptance Criteria
- [ ] Download button available after audio generation
- [ ] Audio saved to device storage (Downloads folder)
- [ ] User notified when download completes
- [ ] Support for ElevenLabs generated audio (already MP3)
- [ ] Option to convert local TTS to audio file
- [ ] Filename based on content title or first words

## Technical Notes
- ElevenLabs already generates MP3 files (stored in temp)
- Move from temp to permanent storage instead of deleting
- For local TTS, use flutter_tts synthesizeToFile method
- Use path_provider and permission_handler for file access

## Priority
P1 - High value feature for offline use
