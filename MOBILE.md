# AI Avatar Chat - Mobile Build Guide

This guide covers building and deploying the AI Avatar Chat app for iOS and Android.

## Prerequisites

- Flutter SDK 3.41.4 or later
- For iOS: macOS, Xcode 15+, iOS 12+ device/simulator
- For Android: Android Studio, Android SDK 21+ (Android 5.0+)

## Project Structure

```
android/          # Android platform-specific code
ios/              # iOS platform-specific code
lib/              # Flutter app code (shared)
backend/          # Optional: REST API backend
```

## Configuration

### Environment Variables

The app uses the same `.env` file for all platforms:

```bash
# Required: API configuration
KIMI_API_KEY=your_kimi_api_key_here

# Optional: Backend API (recommended for production)
USE_BACKEND=true
BACKEND_URL=https://your-backend-url.com

# Optional: ElevenLabs for high-quality TTS
ELEVENLABS_API_KEY=your_elevenlabs_key
ELEVENLABS_VOICE_ID=21m00Tcm4TlvDq8ikWAM
```

### iOS Permissions

The following permissions are pre-configured in `ios/Runner/Info.plist`:

- **Microphone**: For speech recognition
- **Speech Recognition**: For voice-to-text conversion

### Android Permissions

The following permissions are pre-configured in `android/app/src/main/AndroidManifest.xml`:

- **RECORD_AUDIO**: For speech recognition
- **INTERNET**: For API communication

## Building for iOS

### Development Build (Simulator)

```bash
# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Or specify a simulator
flutter run -d "iPhone 15 Pro"
```

### Physical Device (Development)

1. Connect your iOS device
2. Open `ios/Runner.xcworkspace` in Xcode
3. Select your device and team in Signing & Capabilities
4. Run from Xcode or use:

```bash
flutter run -d <device-id>
```

### Production Build (App Store)

```bash
# Build release IPA
flutter build ios --release

# Or build for distribution
flutter build ipa --export-method=app-store

# The IPA will be at:
# build/ios/ipa/ai_avatar_chat.ipa
```

Upload the IPA to App Store Connect using Xcode or Transporter.

## Building for Android

### Development Build

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run -d android

# Or run on specific device
flutter run -d <device-id>
```

### Production Build (APK)

```bash
# Build release APK
flutter build apk --release

# The APK will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

### Production Build (App Bundle - Google Play)

```bash
# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# The AAB will be at:
# build/app/outputs/bundle/release/app-release.aab
```

### Signing Configuration

For release builds, configure signing in `android/app/build.gradle`:

```kotlin
android {
    // ...
    
    signingConfigs {
        release {
            keyAlias 'your-alias'
            keyPassword 'your-password'
            storeFile file('your-keystore.jks')
            storePassword 'your-store-password'
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            // ...
        }
    }
}
```

## Mobile-Specific Features

### Speech Recognition

- **iOS**: Uses native `SFSpeechRecognizer`
- **Android**: Uses native `SpeechRecognizer`
- **Web**: Uses Web Speech API

The `speech_to_text` package automatically selects the appropriate implementation.

### Text-to-Speech

- **iOS/Android**: Uses native TTS engines via `flutter_tts`
- **ElevenLabs**: High-quality neural TTS (requires network)

### Network Configuration

#### iOS (NSAppTransportSecurity)

Already configured in `Info.plist` to allow arbitrary loads for development. For production, restrict to your backend domain only.

#### Android (Cleartext Traffic)

By default, Android 9+ blocks cleartext HTTP traffic. For local development with `http://localhost`, this is already configured. For production, always use HTTPS.

## Testing

### Unit Tests

```bash
flutter test
```

### Integration Tests

```bash
# iOS
flutter test integration_test -d ios

# Android
flutter test integration_test -d android
```

## Platform-Specific Considerations

### iOS

1. **Minimum Version**: iOS 12.0
2. **Device Orientation**: Portrait recommended
3. **Dark Mode**: Fully supported
4. **Background Audio**: Not required (short responses)

### Android

1. **Minimum SDK**: API 21 (Android 5.0)
2. **Target SDK**: API 34 (Android 14)
3. **Permissions**: Runtime microphone permission handled by `speech_to_text`
4. **Battery Optimization**: Consider requesting exemption for voice apps

## Deployment Checklist

### Pre-Release

- [ ] Update version in `pubspec.yaml`
- [ ] Test on physical devices (not just simulators)
- [ ] Verify all API keys are production-ready
- [ ] Test with backend URL (not direct API)
- [ ] Check microphone permissions on fresh install
- [ ] Verify TTS works in both system and ElevenLabs modes
- [ ] Test conversation flow end-to-end

### App Store (iOS)

- [ ] App icon (all required sizes)
- [ ] Screenshots for iPhone and iPad
- [ ] App description and keywords
- [ ] Privacy policy URL
- [ ] Demo account (if applicable)
- [ ] Export compliance documentation

### Google Play (Android)

- [ ] App icon (512x512 PNG)
- [ ] Feature graphic (1024x500)
- [ ] Screenshots (phone, tablet, TV)
- [ ] App description and keywords
- [ ] Privacy policy URL
- [ ] Content rating questionnaire

## Troubleshooting

### iOS

**Build fails with "Could not find included module"**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter clean
flutter pub get
```

**Microphone permission not working**
- Check `ios/Runner/Info.plist` has `NSMicrophoneUsageDescription`
- Clean build folder in Xcode

### Android

**Build fails with "Duplicate class"**
```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
```

**Speech recognition not working**
- Ensure device has Google Speech Recognition enabled
- Check internet connectivity (required for cloud recognition)

## Backend Considerations

For mobile production apps, **always use the backend** (`USE_BACKEND=true`):

1. **Security**: API keys never exposed in app bundle
2. **Rate Limiting**: Control usage per user
3. **Session Management**: Cross-device conversation sync
4. **Updates**: Update AI model without app update

See `backend/README.md` for backend deployment instructions.
