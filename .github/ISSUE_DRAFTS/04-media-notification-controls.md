## Description
Display playback controls in the system notification/control center for easy access without opening the app.

## User Story
As a user, I want to control playback from my lock screen or notification shade so that I do not have to unlock and open the app.

## Acceptance Criteria
- [ ] Notification shows current reading title/preview
- [ ] Play/Pause button in notification
- [ ] Stop button in notification
- [ ] Notification updates when playback state changes
- [ ] Works on both iOS (Control Center) and Android (notification)
- [ ] Notification dismissed when playback stops

## Technical Notes
- Use audio_service or just_audio_background package
- Integrate with existing TtsController
- Handle notification actions to control TtsController
- Consider adding skip forward/backward (30 seconds)

## Priority
P1 - Important for background playback experience
