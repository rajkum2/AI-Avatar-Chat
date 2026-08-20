# AI Avatar Chat - Quick Start Guide

## Running Locally with Kimi API

### 1. Get Your Kimi API Key

1. Go to https://platform.moonshot.cn (Kimi/Moonshot AI Platform)
2. Sign up or log in to your account
3. Navigate to **API Keys** section
4. Create a new API key
5. Copy the key (starts with `sk-`)

### 2. Configure the App

Create a `.env` file in the project root:

```bash
cd /Users/kirankumaralugonda/Documents/GitHub/AI-Avatar-Chat

# Create the .env file
cat > .env << 'ENVFILE'
# LLM Provider Selection
LLM_PROVIDER=kimi

# Kimi API Key (REQUIRED - replace with your actual key)
KIMI_API_KEY=sk-your-actual-api-key-here

# Optional: ElevenLabs for better TTS
ELEVENLABS_API_KEY=your_elevenlabs_key_here
ELEVENLABS_VOICE_ID=21m00Tcm4TlvDq8ikWAM
ENVFILE
```

**⚠️ IMPORTANT**: Replace `sk-your-actual-api-key-here` with your real Kimi API key!

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

**Option A: Web (Chrome)**
```bash
flutter run -d chrome --web-port 8080
```

**Option B: macOS Desktop**
```bash
flutter run -d macos
```

**Option C: iOS Simulator (macOS only)**
```bash
flutter run -d ios
```

### 5. Testing the App

Once running:

1. **Wait for initialization** - You'll see a loading spinner, then a message "Using Kimi API"
2. **Allow microphone access** when prompted
3. **Tap the mic button** to start speaking
4. **Say something** like "Hello, how are you?"
5. **Wait for the AI response** - The avatar will animate while speaking

### 6. Troubleshooting

#### "API key not set" error
- Check your `.env` file exists and has the correct format
- Verify the API key starts with `sk-`
- Run `flutter clean` and `flutter pub get` then try again

#### Microphone not working
- **Web**: Use Chrome or Edge (Safari has limited support)
- **Mobile**: Check mic permissions in Settings > Privacy > Microphone
- **macOS**: Grant mic permission in System Preferences > Security & Privacy

#### Connection errors
- Check your internet connection
- Verify the API key is valid at https://platform.moonshot.cn
- Check browser console (F12) for detailed error messages

#### Switching to Ollama (Free, Local)
If you want to test without using API credits:

1. Install Ollama: https://ollama.com
2. Run: `ollama pull llama3.2:3b`
3. Change `.env`:
   ```
   LLM_PROVIDER=ollama
   OLLAMA_MODEL=llama3.2:3b
   ```
4. Restart the app

### 7. Quick Test Checklist

- [ ] App loads without errors
- [ ] Shows "Using Kimi API" message
- [ ] Microphone permission granted
- [ ] Tap mic → status changes to "Listening..."
- [ ] Speak → transcript appears
- [ ] AI responds with voice
- [ ] Avatar animates during speech

### 8. Open Admin Dashboard

Tap the **⚙️ Settings icon** in the top-right corner to:
- Switch between providers
- Adjust temperature and max tokens
- Test connections
- View current configuration

---

## Production Build

```bash
# Web
flutter build web --release

# macOS
flutter build macos --release

# iOS
flutter build ios --release
```
