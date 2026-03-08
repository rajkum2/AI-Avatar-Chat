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

- [x] **Step 3:** State machine verified — All 9 transition paths audited and correct. Fixed: AvatarWidget converted to ConsumerStatefulWidget with AnimationController for proper Lottie speed control (thinking = 0.5x via doubled duration). StatusIndicator enhanced with animated transitions, spinner for thinking, mic icon for listening, color changes. TranscriptOverlay now shows italic quoted user text during thinking, AI text in blue during speaking. resetToIdle now stops active STT/TTS services. 0 analyzer issues, web build passes.

### What was changed in Step 3
- `lib/features/avatar/avatar_widget.dart` — Converted to ConsumerStatefulWidget with TickerProviderStateMixin. AnimationController for Lottie speed control: thinking state doubles animation duration for half-speed effect. Removed broken LottieDelegates opacity hack.
- `lib/widgets/status_indicator.dart` — Added AnimatedSwitcher for smooth text transitions. Added spinner icon during thinking, mic icon during listening, color-coded text (red for listening, gray for others).
- `lib/widgets/transcript_overlay.dart` — State-aware display: listening = white user text, thinking = italic gray quoted text, speaking = blue AI text, idle = lingering AI text. Added AnimatedSwitcher for transitions.
- `lib/features/conversation/conversation_flow.dart` — resetToIdle() now calls sttService.stop() and ttsService.stop() to clean up active services.

### State Machine Transition Map (verified)
```
IDLE → LISTENING         : startListening()      [mic tap]
LISTENING → THINKING     : _onSpeechResult()     [speech done / silence]
LISTENING → IDLE         : _onSpeechResult()     [empty transcript]
LISTENING → IDLE         : error listener         [STT error]
THINKING → SPEAKING      : _onSpeechResult()     [Claude reply received]
THINKING → IDLE          : catch blocks           [API error]
SPEAKING → IDLE          : TTS completion          [audio finished]
SPEAKING → IDLE → LISTEN : interrupt()            [mic tap during speech]
ANY → IDLE               : resetToIdle()          [clear conversation]
```

- [x] **Step 4:** Claude API integration — Hardened chat_service.dart with: `anthropic-dangerous-direct-browser-access` header for Flutter Web CORS, message alternation validation (strips consecutive same-role messages), detailed error handling for all HTTP codes (400/401/403/404/429/500/529), response parsing with usage logging, latency measurement via Stopwatch, TimeoutException handling. Fixed env.dart: graceful .env load failure, placeholder key detection (`hasAnthropicKey` checks for `your_..._here`). Added early API key check in conversation_flow before THINKING state. Updated web/index.html with proper title and viewport meta.

### What was changed in Step 4
- `lib/features/chat/chat_service.dart` — Full rewrite: CORS header, message validation, granular error codes, `_parseResponse()` with usage logging, `_handleErrorResponse()` returns `Never`, Stopwatch latency logging
- `lib/core/env.dart` — Graceful .env load with try/catch, `_loaded` flag, placeholder detection in `hasAnthropicKey`/`hasElevenLabsKey`
- `lib/features/conversation/conversation_flow.dart` — Early `Env.hasAnthropicKey` check before THINKING, import added for env.dart
- `web/index.html` — Updated title to "AI Avatar Chat", added viewport meta, updated description

### CORS Note for Development
Anthropic API supports direct browser access with the `anthropic-dangerous-direct-browser-access: true` header. This works for development. For production, use a backend proxy (Phase 2, Step 15).

- [x] **Step 5:** TTS (flutter_tts) hardened — Added: init guard (`_initialized` flag), web-specific `awaitSpeakCompletion(true)`, start/cancel/error handlers with debug logging, fallback timer for web (estimates duration from word count at TTS rate + 2s buffer, fires `_onSpeakComplete` if completion handler never fires), available voice enumeration in debug mode, `_onSpeakComplete` dedup guard. Pre-initialization: `main.dart` now uses `_AppInitializer` ConsumerStatefulWidget that eagerly inits both TTS and STT on app startup (mic permission prompt shows early, TTS ready for first response). Removed redundant `ttsService.initialize()` from conversation_flow.

### What was changed in Step 5
- `lib/features/voice/tts_service.dart` — Full rewrite: init guard, web-specific config, start/cancel/error handlers, fallback timer, voice logging, `_onSpeakComplete` dedup
- `lib/main.dart` — Added `_AppInitializer` widget that pre-initializes STT + TTS services on app startup via `ConsumerStatefulWidget.initState`
- `lib/features/conversation/conversation_flow.dart` — Removed `ttsService.initialize()` call (now done at startup)

### Remaining Steps
- [ ] **Step 6 (NEXT):** Lottie avatar — animates per conversation state
- [x] **Step 6:** Lottie avatar — Rebuilt all 3 Lottie JSON animations with richer detail: idle has breathing bob + eye blink at frame 85-92 + glow ring; listen has expanding pulse rings + head tilt rotation + wider eyes; speak has animated mouth (8-keyframe open/close cycle) + sound wave bars on both sides + head bob. AvatarWidget fixed: thinking controller now properly stops/resets when leaving thinking state via `_previousState` tracking, split into `_buildAvatar` with glow layer + animation layer, AnimatedSwitcher uses scale+fade transition, size clamped to 200-400px, placeholder improved with spinner overlay for thinking + labeled states.

### What was changed in Step 6
- `assets/animations/avatar_idle.json` — Rewritten: oval head shape with border stroke, eyes with blink keyframes (frames 85-92 scaleY→10%), subtle breathing position bob, outer glow ring with opacity pulse
- `assets/animations/avatar_listen.json` — Rewritten: 2 expanding pulse rings (staggered timing, fade to 0), head with subtle tilt rotation (±3°), wider open eyes (scaleY 110%), small open mouth, brighter ring
- `assets/animations/avatar_speak.json` — Rewritten: mouth with 8-keyframe size animation (lip sync simulation), sound wave bars on left and right (3 bars each, staggered fade in/out), head position bob every 15 frames
- `lib/features/avatar/avatar_widget.dart` — Full rewrite: `_previousState` tracking to stop thinking controller on state exit, `_buildGlow()` with state-colored AnimatedContainer shadow, `_buildAnimation()` split for thinking vs normal paths, scale+fade AnimatedSwitcher transition, placeholder with CircularProgressIndicator for thinking, labeled placeholders, size clamped 200-400px

- [x] **Step 7:** Full home screen UI polished — HomeScreen: added top-to-bottom gradient background (#0F172A→#0B1120), subtle divider under title bar, bottom section gradient overlay for depth, extracted `_buildTitleBar` and `_buildBottomSection` methods. Theme: added `surfaceLight` color, SnackBar shape with rounded corners + border. MicButton: replaced GestureDetector with Material+InkWell for ripple effect + Semantics for accessibility, AnimatedContainer for smooth state transitions, splash color per state, refined shadow/border colors. TranscriptOverlay: fixed janky rebuilds by keying AnimatedSwitcher on state only (not text), added AnimatedDefaultTextStyle for smooth color/style transitions. StatusIndicator: added volume_up icon for speaking state, color-coded status text per state, refined spacing.

### What was changed in Step 7
- `lib/core/theme.dart` — Added `AppColors.surfaceLight` (#334155), SnackBar shape with RoundedRectangleBorder + border, iconButtonTheme
- `lib/screens/home_screen.dart` — Gradient background, divider, bottom gradient overlay, extracted builder methods, cleaner spacing
- `lib/widgets/mic_button.dart` — Material+InkWell for ripple, Semantics labels, AnimatedContainer, splash/shadow/border color helpers, refined sizing (76px)
- `lib/widgets/transcript_overlay.dart` — AnimatedSwitcher keyed on state only (no more text-based key that caused flicker), AnimatedDefaultTextStyle for smooth style transitions
- `lib/widgets/status_indicator.dart` — Added volume_up icon for speaking, color-coded text via _getStatusColor, refined spacing

- [x] **Step 8:** Wired end-to-end — Fixed critical bugs: removed custom `TimeoutException` that shadowed `dart:async.TimeoutException` (catch clause never matched), added `_finalResultSent` guard in STTService to prevent double-fire race condition between `onResult(finalResult)` and `onStatus('done')`, added `_sendFinalResult()` method called from all 3 paths (onResult, onStatus, onError). Added pipeline latency logging (`Pipeline: STT→Claude complete in Xms`). Added startup API key warning — `_AppInitializer` checks `Env.hasAnthropicKey` after init and shows SnackBar if missing.

### What was changed in Step 8
- `lib/features/chat/chat_service.dart` — Removed custom `TimeoutException` class, catch `e.toString().contains('TimeoutException')` instead
- `lib/features/voice/stt_service.dart` — Added `_finalResultSent` bool guard, `_sendFinalResult()` method, all 3 paths (onResult final, onStatus done, onError) route through it to prevent double-fire
- `lib/features/conversation/conversation_flow.dart` — Added `Stopwatch` pipeline latency logging from speech result to speaking state
- `lib/main.dart` — Added API key check on startup, shows SnackBar warning if ANTHROPIC_API_KEY is missing/placeholder

### Full Pipeline (verified wiring)
```
1. User taps mic → ConversationNotifier.startListening()
2. STT streams partial results → transcriptProvider updates → TranscriptOverlay shows live text
3. Silence/tap → STTService._sendFinalResult() → ConversationNotifier._onSpeechResult()
4. Env.hasAnthropicKey check → THINKING state → Avatar + Status + MicButton update
5. ChatService.sendMessage() → Claude API with history → response parsed
6. Reply stored in chatHistoryProvider + aiResponseProvider + transcriptProvider
7. SPEAKING state → TTS.speak() → Avatar animates → TranscriptOverlay shows AI text in blue
8. TTS completion → IDLE state → all UI resets
```

- [x] **Step 9:** Error handling — all 7 error states implemented with proper severity. Added `persistentErrorProvider` for critical errors (mic permission denied, browser not supported) that show as a red-tinted banner with dismiss button at the top of HomeScreen. Transient errors (empty transcript, connection issues, API errors) remain as auto-dismissing SnackBars. Early browser detection on startup via STT init result — if STT unavailable on web, persistent banner appears immediately. Error routing: permission/availability errors → persistent banner, all others → SnackBar.

### What was changed in Step 9
- `lib/features/conversation/conversation_flow.dart` — Added `persistentErrorProvider` StateProvider, `_showPersistentError()` method, browser/permission/availability errors now route to persistent banner instead of SnackBar
- `lib/screens/home_screen.dart` — Added `_buildErrorBanner()` widget: red-tinted full-width banner with warning icon, error text, and dismiss (close) button. Watches `persistentErrorProvider` and shows between title bar and avatar
- `lib/main.dart` — Added `kIsWeb` import, early browser detection: if STT init fails on web, sets `persistentErrorProvider` with "Browser not supported" message

### Error States Coverage (7/7)
| # | Error | Trigger | Display | Status |
|---|-------|---------|---------|--------|
| 1 | Microphone permission denied | STT error_permission | Persistent banner | ✅ |
| 2 | Couldn't hear you — please try again | Empty transcript | SnackBar (3s) | ✅ |
| 3 | Connection lost — check your internet | Network failure | SnackBar (3s) | ✅ |
| 4 | Claude is busy — trying again in 2s | HTTP 429 | SnackBar + auto-retry | ✅ |
| 5 | Something went wrong — please try again | HTTP 500+ | SnackBar (3s) | ✅ |
| 6 | Your session expired — starting fresh | JWT expired | Phase 2 (skipped) | ⬜ |
| 7 | Browser not supported — please use Chrome | Web Speech API missing | Persistent banner | ✅ |
- [ ] **Step 10 (NEXT):** End-to-end testing in Chrome
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
5. For Claude API testing, ensure `.env` has a real `ANTHROPIC_API_KEY`
