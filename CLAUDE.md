# AI Avatar Chat - Project Guide

## Project Overview
Flutter Web AI Avatar app: user speaks into mic → STT transcribes → Claude API replies → TTS speaks reply → Lottie avatar animates in sync. Target < 3s end-to-end latency.

## Tech Stack
- **Flutter** 3.41.4 / **Dart** 3.11.1 (installed via `brew install --cask flutter`)
- **State management:** flutter_riverpod 2.6.1
- **Voice input:** speech_to_text 6.6.2 (wraps Chrome Web Speech API)
- **Voice output:** flutter_tts 4.2.5 (Phase 1), ElevenLabs API (Phase 2)
- **AI:** Claude API — model `claude-sonnet-4-20250514`, endpoint `POST https://api.anthropic.com/v1/messages`
- **Avatar:** Lottie 3.3.2 (Phase 1), Ready Player Me 3D (Phase 2)
- **HTTP:** http 1.6.0, dio 5.9.2
- **Audio:** audioplayers 6.6.0
- **Environment:** flutter_dotenv 5.2.1

## Architecture

### State Machine (4 states — single source of truth)
```
IDLE → (tap mic) → LISTENING → (silence/tap) → THINKING → (API reply) → SPEAKING → (audio ends) → IDLE
                                                                          ↓ (tap mic = interrupt)
                                                                        LISTENING
```

### Provider Graph
- `conversationStateProvider` — holds current ConversationState enum, drives everything
- `transcriptProvider` — current STT text or AI reply text
- `aiResponseProvider` — last AI response
- `chatHistoryProvider` — message history (max 20, auto-trims oldest)
- `avatarStateProvider` — mirrors conversation state for avatar animations
- `sttServiceProvider` — singleton STTService
- `ttsServiceProvider` — singleton TTSService
- `chatServiceProvider` — singleton ChatService
- `audioPlayerServiceProvider` — singleton AudioPlayerService

### Key Orchestration
`ConversationFlow` (`conversation_flow.dart`) orchestrates the full pipeline:
1. Start STT → stream partial transcript → get final text
2. Send to Claude API with history → get reply
3. Play reply via TTS → avatar animates → completion → back to IDLE

## Folder Structure
```
lib/
├── main.dart                              # ProviderScope + MaterialApp + Env.load()
├── core/
│   ├── constants.dart                     # API URLs, model, timeouts, TTS settings
│   ├── theme.dart                         # Dark theme, AppColors, AppTheme
│   └── env.dart                           # flutter_dotenv wrapper
├── features/
│   ├── avatar/
│   │   ├── avatar_state.dart              # Enum: idle, listening, speaking, thinking
│   │   ├── avatar_controller.dart         # StateNotifier synced to conversation state
│   │   └── avatar_widget.dart             # Lottie renderer with AnimatedSwitcher + placeholder fallback
│   ├── voice/
│   │   ├── stt_service.dart               # speech_to_text wrapper with streams
│   │   ├── tts_service.dart               # flutter_tts wrapper with completion stream
│   │   └── audio_player_service.dart      # audioplayers for ElevenLabs bytes (Phase 2)
│   ├── chat/
│   │   ├── chat_message.dart              # Data model (role, content, timestamp)
│   │   ├── chat_service.dart              # Claude API POST + error handling (429 retry, 500 fail)
│   │   └── chat_provider.dart             # Chat history StateNotifier (max 20 messages)
│   └── conversation/
│       ├── conversation_state.dart        # Enum: idle, listening, thinking, speaking
│       └── conversation_flow.dart         # Main orchestrator + ConversationNotifier
├── widgets/
│   ├── mic_button.dart                    # Animated mic with pulse (listening), spinner (thinking)
│   ├── transcript_overlay.dart            # Shows live STT text (white) or AI reply (blue)
│   └── status_indicator.dart              # "Tap mic to start" / "Listening..." / etc.
└── screens/
    └── home_screen.dart                   # Full-screen dark layout: title → avatar → status → transcript → mic

assets/animations/                         # Lottie JSON files (placeholder, replace with better ones)
├── avatar_idle.json                       # Breathing circle with face
├── avatar_listen.json                     # Pulsing circle with attentive face
└── avatar_speak.json                      # Circle with animated mouth

.env                                       # API keys (NEVER commit — in .gitignore)
.env.example                               # Template for API keys
```

## Build & Run Commands
```bash
flutter pub get                            # Install dependencies
flutter analyze                            # Check for errors (must show 0 issues)
flutter build web --release                # Production build → build/web/
flutter run -d chrome --web-port 8080      # Dev server on localhost:8080
```

## Known Gotchas
- Flutter 3.41.4 removed `--web-renderer` flag; canvaskit is the default renderer
- speech_to_text 6.6.2 uses `SpeechListenOptions` class instead of direct params on `listen()`
- Lottie 3.3.2 doesn't have a `speed` parameter; use AnimationController for speed control
- Wasm warnings exist for speech_to_text and flutter_tts (JS interop) — non-blocking for JS builds
- `.env` must be listed in pubspec.yaml assets for flutter_dotenv to load it
- API keys in .env are only for development; production MUST proxy through backend

## Color Palette
- Background: `#0F172A` (dark navy)
- Surface: `#1E293B` (card backgrounds)
- Primary: `#3B82F6` (blue — active states)
- Active: `#EF4444` (red — mic recording)
- Text primary: `#F8FAFC` (near white)
- Text secondary: `#94A3B8` (gray — status)
- Accent: `#60A5FA` (light blue — AI text)

## API Key Setup
Add real keys to `.env`:
```
ANTHROPIC_API_KEY=sk-ant-...
ELEVENLABS_API_KEY=...
ELEVENLABS_VOICE_ID=...
```

## Development Progress

### Completed
- [x] **Step 1:** Project scaffold — Flutter web project created, all 10 packages added, full folder structure, all 20 source files, 3 Lottie animations, dark theme, Riverpod providers, conversation state machine, Claude API integration, STT/TTS services, home screen UI. `flutter analyze` = 0 issues, `flutter build web` = success.
- [x] **Step 2:** STT service hardened + mic button working — Added: error stream for STT errors, browser compatibility detection (Chrome check), proper edge case handling (no_match, speech_timeout, permission denied, network error), `_lastPartialResult` tracking so silence after partial speech still captures text, `_processingResult` guard to prevent double-processing, `errorMessageProvider` for SnackBar error display in HomeScreen, TTS initialization in conversation flow. All files compile clean, 0 analyzer issues.

### What was changed in Step 2
- `lib/features/voice/stt_service.dart` — Added error stream, error message mapping, partial result tracking, double-init guard, debug logging
- `lib/features/conversation/conversation_flow.dart` — Added `errorMessageProvider`, STT error subscription, TTS init call, `_processingResult` guard, browser detection for error messages
- `lib/screens/home_screen.dart` — Added `ref.listen` for errorMessageProvider → SnackBar display, clear conversation also resets state

### Remaining Steps
- [ ] **Step 3:** Conversation state machine — verify states switch correctly via UI
- [ ] **Step 4:** Claude API integration — test real API calls, verify response parsing
- [ ] **Step 5:** TTS (flutter_tts) — AI reply spoken aloud
- [ ] **Step 6:** Lottie avatar — animates per conversation state
- [ ] **Step 7:** Full home screen UI — polish dark theme layout
- [ ] **Step 8:** Wire ConversationFlow end-to-end
- [ ] **Step 9:** Error handling — all 7 error states with SnackBar messages
- [ ] **Step 10:** End-to-end testing in Chrome
- [ ] **Step 11:** Interrupt handling — tap mic during speaking
- [ ] **Step 12:** Performance optimization — measure latency, streaming
- [ ] **Step 13:** Firebase Hosting deploy
- [ ] **Step 14:** ElevenLabs TTS upgrade
- [ ] **Step 15:** REST API backend (Phase 2)
- [ ] **Step 16:** Flutter mobile app (Phase 3)

## Resuming Work
When resuming this project in a new session:
1. Run `flutter analyze` to verify no regressions
2. Check this file's "Development Progress" section for current step
3. Run `flutter run -d chrome --web-port 8080` to see current state
4. Continue from the next unchecked step
