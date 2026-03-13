/**
 * AI Avatar Chat - REST API Backend
 * 
 * Provides secure proxy to:
 * - Kimi Chat API (Moonshot AI)
 * - ElevenLabs TTS API
 * 
 * Features:
 * - JWT session management
 * - Rate limiting per user
 * - Streaming response support
 * - Request logging
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const winston = require('winston');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Configure logging
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Validate required environment variables
const requiredEnvVars = ['KIMI_API_KEY', 'JWT_SECRET'];
const missingVars = requiredEnvVars.filter(v => !process.env[v]);
if (missingVars.length > 0) {
  logger.error(`Missing required environment variables: ${missingVars.join(', ')}`);
  process.exit(1);
}

// Middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:8080', 'http://localhost:3000'],
  credentials: true
}));
app.use(express.json({ limit: '1mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.RATE_LIMIT_MAX || 100,
  message: { error: 'Too many requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.userId || req.ip
});
app.use(limiter);

// Stricter rate limit for chat endpoints
const chatLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: process.env.CHAT_RATE_LIMIT_MAX || 20,
  message: { error: 'Chat rate limit exceeded, please slow down' }
});

// JWT middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    // Generate anonymous session
    req.userId = `anon:${req.ip}`;
    req.sessionId = uuidv4();
    return next();
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired session' });
    }
    req.userId = user.userId;
    req.sessionId = user.sessionId;
    next();
  });
};

// Apply auth middleware
app.use(authenticateToken);

// In-memory session store (use Redis in production)
const sessions = new Map();
const MAX_HISTORY_MESSAGES = 20;

/**
 * GET /api/health
 * Health check endpoint
 */
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

/**
 * POST /api/auth/session
 * Create a new anonymous session
 */
app.post('/api/auth/session', (req, res) => {
  const sessionId = uuidv4();
  const userId = `user:${uuidv4()}`;
  
  const token = jwt.sign(
    { userId, sessionId, createdAt: Date.now() },
    process.env.JWT_SECRET,
    { expiresIn: '24h' }
  );

  sessions.set(sessionId, {
    userId,
    createdAt: Date.now(),
    history: []
  });

  logger.info(`New session created: ${userId}`);
  
  res.json({
    token,
    expiresIn: 86400 // 24 hours in seconds
  });
});

/**
 * POST /api/chat
 * Proxy chat requests to Kimi API with streaming support
 */
app.post('/api/chat', chatLimiter, async (req, res) => {
  const startTime = Date.now();
  const { message, stream = true } = req.body;

  if (!message || typeof message !== 'string') {
    return res.status(400).json({ error: 'Message is required' });
  }

  // Get or create session history
  let session = sessions.get(req.sessionId);
  if (!session) {
    session = { userId: req.userId, createdAt: Date.now(), history: [] };
    sessions.set(req.sessionId, session);
  }

  // Build messages array with history
  const messages = [
    {
      role: 'system',
      content: process.env.SYSTEM_PROMPT || 
        'You are a friendly, warm AI assistant. Keep responses to 2-3 sentences maximum.'
    },
    ...session.history,
    { role: 'user', content: message }
  ];

  try {
    logger.info(`Chat request from ${req.userId}: "${message.substring(0, 50)}..."`);

    const response = await fetch('https://api.moonshot.cn/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.KIMI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: process.env.KIMI_MODEL || 'moonshot-v1-8k',
        messages,
        max_tokens: parseInt(process.env.KIMI_MAX_TOKENS) || 300,
        temperature: 0.7,
        stream
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error(`Kimi API error: ${response.status} - ${errorText}`);
      
      if (response.status === 429) {
        return res.status(429).json({ error: 'AI service is busy, please try again' });
      }
      if (response.status === 401) {
        return res.status(500).json({ error: 'AI service configuration error' });
      }
      
      return res.status(502).json({ error: 'AI service error' });
    }

    if (stream) {
      // Handle streaming response
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      const reader = response.body.getReader();
      let fullResponse = '';

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          const chunk = new TextDecoder().decode(value);
          const lines = chunk.split('\n');

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.slice(6);
              if (data === '[DONE]') continue;

              try {
                const parsed = JSON.parse(data);
                const content = parsed.choices?.[0]?.delta?.content;
                if (content) {
                  fullResponse += content;
                  res.write(`data: ${JSON.stringify({ chunk: content })}\n\n`);
                }
              } catch (e) {
                // Ignore parse errors for malformed chunks
              }
            }
          }
        }

        // Store in history
        session.history.push({ role: 'user', content: message });
        session.history.push({ role: 'assistant', content: fullResponse });
        
        // Trim history if too long
        if (session.history.length > MAX_HISTORY_MESSAGES * 2) {
          session.history = session.history.slice(-MAX_HISTORY_MESSAGES * 2);
        }

        const duration = Date.now() - startTime;
        logger.info(`Chat completed in ${duration}ms, response length: ${fullResponse.length}`);

        res.write('data: [DONE]\n\n');
        res.end();

      } catch (error) {
        logger.error('Stream error:', error);
        res.write(`data: ${JSON.stringify({ error: 'Stream interrupted' })}\n\n`);
        res.end();
      }

    } else {
      // Non-streaming response
      const data = await response.json();
      const reply = data.choices?.[0]?.message?.content || '';

      // Store in history
      session.history.push({ role: 'user', content: message });
      session.history.push({ role: 'assistant', content: reply });

      const duration = Date.now() - startTime;
      logger.info(`Chat completed in ${duration}ms`);

      res.json({
        response: reply,
        usage: data.usage,
        duration
      });
    }

  } catch (error) {
    logger.error('Chat request failed:', error);
    res.status(500).json({ error: 'Failed to process request' });
  }
});

/**
 * POST /api/tts
 * Proxy TTS requests to ElevenLabs
 */
app.post('/api/tts', async (req, res) => {
  const { text, voiceId } = req.body;

  if (!text || typeof text !== 'string') {
    return res.status(400).json({ error: 'Text is required' });
  }

  if (!process.env.ELEVENLABS_API_KEY) {
    return res.status(503).json({ error: 'TTS service not configured' });
  }

  const targetVoiceId = voiceId || process.env.ELEVENLABS_VOICE_ID;
  if (!targetVoiceId) {
    return res.status(400).json({ error: 'Voice ID is required' });
  }

  try {
    logger.info(`TTS request from ${req.userId}: ${text.length} chars`);

    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${targetVoiceId}/stream`,
      {
        method: 'POST',
        headers: {
          'xi-api-key': process.env.ELEVENLABS_API_KEY,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg'
        },
        body: JSON.stringify({
          text,
          model_id: process.env.ELEVENLABS_MODEL || 'eleven_turbo_v2',
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.75,
            style: 0.3,
            use_speaker_boost: true
          },
          optimize_streaming_latency: 3
        })
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      logger.error(`ElevenLabs API error: ${response.status}`);
      return res.status(502).json({ error: 'TTS service error' });
    }

    // Stream the audio response
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Transfer-Encoding', 'chunked');

    const reader = response.body.getReader();
    
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      res.write(Buffer.from(value));
    }
    
    res.end();

  } catch (error) {
    logger.error('TTS request failed:', error);
    res.status(500).json({ error: 'Failed to generate speech' });
  }
});

/**
 * GET /api/history
 * Get conversation history for current session
 */
app.get('/api/history', (req, res) => {
  const session = sessions.get(req.sessionId);
  if (!session) {
    return res.json({ history: [] });
  }
  res.json({ history: session.history });
});

/**
 * DELETE /api/history
 * Clear conversation history
 */
app.delete('/api/history', (req, res) => {
  const session = sessions.get(req.sessionId);
  if (session) {
    session.history = [];
  }
  res.json({ cleared: true });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Cleanup old sessions periodically
setInterval(() => {
  const now = Date.now();
  const maxAge = 24 * 60 * 60 * 1000; // 24 hours
  let cleaned = 0;
  
  for (const [sessionId, session] of sessions.entries()) {
    if (now - session.createdAt > maxAge) {
      sessions.delete(sessionId);
      cleaned++;
    }
  }
  
  if (cleaned > 0) {
    logger.info(`Cleaned up ${cleaned} expired sessions`);
  }
}, 60 * 60 * 1000); // Run every hour

app.listen(PORT, () => {
  logger.info(`AI Avatar Chat backend running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;
