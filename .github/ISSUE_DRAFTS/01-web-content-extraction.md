## Description
Allow users to paste a URL and automatically extract the main text content from the webpage for TTS playback.

## User Story
As a user, I want to paste a URL so that I can listen to web articles without manually copying the text.

## Acceptance Criteria
- [ ] User can paste a URL in the input field
- [ ] App detects if input is a URL (regex validation)
- [ ] App fetches and parses the webpage content
- [ ] Main article content is extracted (remove ads, navigation, etc.)
- [ ] Extracted text is displayed and ready for TTS playback
- [ ] Loading indicator shown during fetch
- [ ] Error handling for invalid URLs or failed requests

## Technical Notes
- Consider using packages like `html` for parsing
- Implement a backend proxy or use a service like Mercury/Readability API for better extraction
- Handle rate limiting and timeouts gracefully

## Priority
P0 - Core feature from original vision
