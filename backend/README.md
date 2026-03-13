# AI Avatar Chat Backend

REST API backend for the AI Avatar Chat Flutter app. Provides secure proxying to Kimi (Moonshot AI) and ElevenLabs APIs with session management and rate limiting.

## Features

- **Secure API Proxy**: API keys are never exposed to the frontend
- **JWT Session Management**: Anonymous sessions with 24h expiration
- **Streaming Support**: Real-time chat streaming from Kimi API
- **Rate Limiting**: Per-user limits to prevent abuse
- **Conversation History**: Server-side chat history persistence
- **TTS Proxy**: ElevenLabs text-to-speech with voice settings

## Quick Start

```bash
# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your API keys

# Start development server
npm run dev

# Or production
npm start
```

## API Endpoints

### Authentication

#### POST /api/auth/session
Create a new anonymous session.

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 86400
}
```

### Chat

#### POST /api/chat
Send a message to the AI with streaming response.

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Body:**
```json
{
  "message": "Hello!",
  "stream": true
}
```

**Response (streaming):**
```
data: {"chunk": "Hello"}
data: {"chunk": " there"}
data: {"chunk": "!"}
data: [DONE]
```

### Text-to-Speech

#### POST /api/tts
Convert text to speech using ElevenLabs.

**Body:**
```json
{
  "text": "Hello world",
  "voiceId": "21m00Tcm4TlvDq8ikWAM"
}
```

**Response:** `audio/mpeg` stream

### History

#### GET /api/history
Get conversation history for current session.

#### DELETE /api/history
Clear conversation history.

### Health

#### GET /api/health
Health check endpoint.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No | Server port (default: 3000) |
| `JWT_SECRET` | Yes | Secret for JWT signing |
| `KIMI_API_KEY` | Yes | Kimi/Moonshot AI API key |
| `ELEVENLABS_API_KEY` | No | ElevenLabs API key |
| `ELEVENLABS_VOICE_ID` | No | Default voice ID |
| `RATE_LIMIT_MAX` | No | General rate limit per 15min |
| `CHAT_RATE_LIMIT_MAX` | No | Chat rate limit per minute |

## Deployment

### Railway/Render/Heroku

1. Push code to GitHub
2. Connect repository to platform
3. Set environment variables
4. Deploy

### VPS/Dedicated Server

```bash
# Install PM2 for process management
npm install -g pm2

# Start with PM2
pm2 start server.js --name "ai-avatar-backend"
pm2 save
pm2 startup
```

### Docker

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

## Architecture

```
Flutter App          Backend              External APIs
     │                  │                       │
     ├─ POST /chat ───►├─────── Kimi API ─────►│
     │◄─ SSE stream ───├◄───── SSE stream ─────┤
     │                  │                       │
     ├─ POST /tts ────►├────── ElevenLabs ────►│
     │◄─ audio/mpeg ───├◄──── audio/mpeg ──────┤
     │                  │                       │
```

## Production Considerations

1. **Use Redis** for session storage instead of in-memory Map
2. **Enable HTTPS** with valid SSL certificates
3. **Set strong JWT_SECRET** (256-bit random string)
4. **Configure CORS** to only allow your domain
5. **Monitor logs** with Winston or external service
6. **Set up alerts** for error rates and latency
