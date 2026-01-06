## Description
Save previously read texts locally so users can revisit and replay them later.

## User Story
As a user, I want to see my reading history so that I can easily replay articles I have listened to before.

## Acceptance Criteria
- [ ] Each text/URL is saved after playback starts
- [ ] History screen displays list of previous readings
- [ ] Each history item shows: title/preview, date, source (text/URL)
- [ ] User can tap to replay any history item
- [ ] User can delete individual items or clear all history
- [ ] History persists across app restarts
- [ ] Maximum history limit (e.g., 100 items) with auto-cleanup

## Technical Notes
- Use hive, isar, or sqflite for local storage
- Store metadata: id, title, content, sourceUrl, createdAt, lastPlayedAt
- Consider lazy loading for large history lists

## UI/UX
- Add history icon in app bar or bottom navigation
- Swipe-to-delete gesture for history items
- Empty state with helpful message

## Priority
P0 - Essential for user retention
