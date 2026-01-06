## Description
Show a visual progress bar and highlight the currently spoken text during playback.

## User Story
As a user, I want to see my reading progress so that I know how much content remains and can follow along visually.

## Acceptance Criteria
- [ ] Progress bar shows current position in audio
- [ ] Progress bar is seekable (tap to jump to position)
- [ ] Current word or sentence is highlighted in text view
- [ ] Time elapsed and time remaining displayed
- [ ] Progress syncs with actual TTS position

## Technical Notes
- Local TTS: Use onProgress callback (provides word boundaries)
- ElevenLabs: Track audio player position vs total duration
- May need to implement word-level timing for text highlighting
- Consider sentence-level highlighting as simpler alternative

## Priority
P1 - Enhances reading experience significantly
