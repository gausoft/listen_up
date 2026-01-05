# Listen Up - Project Guidelines

## Project Overview

**Listen Up** is a cross-platform mobile application that converts text and web content into audio.

### Vision
- Paste any public URL → Extract content → Convert to audio
- Paste any text → Convert to audio
- Listen with playback controls (play, pause, resume, speed control)

### Current Version: v0.0.1 (Offline MVP)
- Text-to-Speech using native device engines (offline)
- User pastes text → App converts to audio → User listens with controls

## Tech Stack

- **Framework**: Flutter 3.38.5
- **Language**: Dart 3.10.4
- **Version Manager**: FVM (Flutter Version Manager)
- **TTS Package**: flutter_tts (uses native Android/iOS TTS engines)
- **Platforms**: Android, iOS

## Commands

```bash
# Use FVM prefix for all Flutter commands
fvm flutter pub get          # Install dependencies
fvm flutter analyze          # Run static analysis
fvm flutter test             # Run tests
fvm flutter run              # Run app in debug mode
fvm flutter build apk        # Build Android APK
fvm flutter build ios        # Build iOS app
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app/                      # App configuration
│   └── app.dart              # MaterialApp setup
├── core/                     # Core utilities
│   ├── constants/            # App constants
│   ├── theme/                # Theme configuration
│   └── utils/                # Utility functions
├── features/                 # Feature modules
│   └── tts/                  # Text-to-Speech feature
│       ├── data/             # Data layer
│       ├── domain/           # Business logic
│       └── presentation/     # UI layer
└── shared/                   # Shared widgets
```

## Architecture

- **Clean Architecture** with feature-based structure
- **Separation of concerns**: UI, Business Logic, Data
- **State Management**: To be determined based on complexity (start simple)

## Coding Conventions

### Dart Style
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `dart format` for consistent formatting
- Prefer `const` constructors when possible
- Use named parameters for clarity

### Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/Functions: `camelCase`
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE` for truly constant values
- Private members: prefix with `_`

### Imports
- Order: dart → package → relative
- Use relative imports within features
- Use package imports for cross-feature dependencies

## Guidelines

### Do
- Keep widgets small and focused
- Extract reusable widgets to `shared/`
- Write descriptive commit messages
- Test business logic
- Handle errors gracefully with user feedback

### Don't
- Don't over-engineer for future features
- Don't add packages without justification
- Don't ignore analyzer warnings
- Don't hardcode strings (prepare for i18n later)

## Version Roadmap

### v0.x - Offline MVP
- [x] Project setup
- [ ] Basic UI with text input
- [ ] TTS integration with flutter_tts
- [ ] Playback controls (play, pause, resume)
- [ ] Speech rate control
- [ ] Voice selection

### v1.x - URL Support (Future)
- URL paste and content extraction
- HTML to text conversion
- Background playback

### v2.x - Cloud Features (Future)
- Cloud TTS for better voice quality
- History/Favorites
- User accounts
