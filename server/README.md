# Self-Hosted LLM Server

Production-ready Docker setup for running open-source LLMs with GPU acceleration.

## Quick Start

```bash
# 1. Configure
cp .env.example .env
# Edit .env with your settings

# 2. Start vLLM (default)
docker-compose up -d vllm

# 3. Test
curl http://localhost:8000/v1/models
```

## Hardware Requirements

### Minimum (3B models)
- **GPU**: NVIDIA with 4GB+ VRAM (GTX 1650, RTX 3050)
- **RAM**: 8GB
- **Storage**: 10GB for model files

### Recommended (8B models)
- **GPU**: NVIDIA with 8GB+ VRAM (RTX 3070, RTX 4070)
- **RAM**: 16GB
- **Storage**: 20GB SSD

### High-End (70B models)
- **GPU**: 48GB+ VRAM (A6000, A100, or 2x RTX 4090)
- **RAM**: 64GB
- **Storage**: 100GB NVMe SSD

## Server Options

### Option 1: vLLM (Recommended)
Best performance with PagedAttention and continuous batching.

```bash
docker-compose up -d vllm

# With custom model
docker-compose run -e MODEL_NAME=meta-llama/Llama-3.1-8B-Instruct vllm
```

### Option 2: Text Generation Inference (TGI)
HuggingFace's production server.

```bash
docker-compose --profile tgi up -d tgi
```

### Option 3: llama.cpp (CPU-friendly)
For systems without NVIDIA GPU.

```bash
# Download GGUF model first
mkdir -p models
curl -L -o models/llama-3.2-3b-q4_K_M.gguf \
  "https://huggingface.co/TheBloke/Llama-3.2-3B-Instruct-GGUF/resolve/main/llama-3.2-3b-instruct.Q4_K_M.gguf"

# Start server
docker-compose --profile llama-cpp up -d llama-cpp
```

## Downloading Models

### Automatic (vLLM/TGI)
Models are downloaded automatically on first run to `./models` directory.

### Manual (GGUF for llama.cpp)

```bash
# Create models directory
mkdir -p models

# Download quantized model
curl -L -o models/llama-3.2-3b-q4_K_M.gguf \
  "https://huggingface.co/TheBloke/Llama-3.2-3B-Instruct-GGUF/resolve/main/llama-3.2-3b-instruct.Q4_K_M.gguf"
```

### Recommended Models

| Model | Size | VRAM | Speed | Quality |
|-------|------|------|-------|---------|
| Llama 3.2 1B | 1.3GB | 2GB | ⚡⚡⚡⚡⚡ | ⭐⭐ |
| Llama 3.2 3B | 2.8GB | 4GB | ⚡⚡⚡⚡ | ⭐⭐⭐ |
| Llama 3.1 8B | 5GB | 8GB | ⚡⚡⚡ | ⭐⭐⭐⭐ |
| Llama 3.1 70B | 40GB | 48GB | ⚡ | ⭐⭐⭐⭐⭐ |
| Mixtral 8x7B | 48GB | 56GB | ⚡⚡ | ⭐⭐⭐⭐⭐ |

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MODEL_NAME` | HuggingFace model ID | `meta-llama/Llama-3.2-3B-Instruct` |
| `QUANTIZATION` | Quantization type (awq, gptq, squeezellm) | `awq` |
| `API_KEY` | Optional API key for security | (none) |
| `CUDA_VISIBLE_DEVICES` | Which GPUs to use | `all` |

### Performance Tuning

```bash
# For 24GB VRAM (RTX 3090/4090)
docker-compose run -e GPU_MEMORY_UTILIZATION=0.95 vllm

# Multi-GPU (2x GPUs)
docker-compose run -e TENSOR_PARALLEL_SIZE=2 vllm

# Higher throughput (batching)
docker-compose run -e MAX_NUM_SEQS=256 vllm
```

## Security

### API Key Authentication

```bash
# Set in .env
API_KEY=your-secret-key-here

# Restart
docker-compose restart vllm
```

Flutter app should send header:
```
Authorization: Bearer your-secret-key-here
```

### SSL/HTTPS

```bash
# Place certificates in nginx/ssl/
mkdir -p nginx/ssl
cp your-cert.pem nginx/ssl/cert.pem
cp your-key.pem nginx/ssl/key.pem

# Start with nginx
docker-compose --profile production up -d nginx
```

## Monitoring

### Check GPU Usage
```bash
watch -n 1 nvidia-smi
```

### Server Logs
```bash
# All logs
docker-compose logs -f

# Just vLLM
docker-compose logs -f vllm
```

### Health Check
```bash
curl http://localhost:8000/health
```

## Troubleshooting

### Out of Memory
```bash
# Use smaller model
MODEL_NAME=meta-llama/Llama-3.2-1B

# Or reduce GPU memory fraction
GPU_MEMORY_UTILIZATION=0.85
```

### Model Download Fails
```bash
# Pre-download with huggingface-cli
pip install huggingface-hub
huggingface-cli download meta-llama/Llama-3.2-3B-Instruct
```

### CUDA Errors
```bash
# Check NVIDIA Docker runtime
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker

# Test GPU access
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

## Production Deployment

### Cloud GPU Providers

| Provider | GPU Type | Price/Hour | Link |
|----------|----------|------------|------|
| RunPod | RTX 4090 | ~$0.69 | runpod.io |
| Vast.ai | RTX 4090 | ~$0.40 | vast.ai |
| Lambda | A100 | ~$1.99 | lambdalabs.com |
| Paperspace | A6000 | ~$1.89 | paperspace.com |

### Deployment Script

```bash
#!/bin/bash
# deploy.sh

# Update and install Docker
sudo apt update && sudo apt install -y docker.io docker-compose

# Install NVIDIA Container Toolkit
sudo apt install -y nvidia-docker2
sudo systemctl restart docker

# Clone and start
git clone <your-repo>
cd server
cp .env.example .env
# Edit .env
docker-compose up -d vllm
```

## Flutter Integration

Set these URLs in your Flutter app:

```bash
# For local testing
SELF_HOSTED_URL=http://localhost:8000/v1

# For LAN testing
SELF_HOSTED_URL=http://192.168.1.100:8000/v1

# For production server
SELF_HOSTED_URL=https://your-domain.com/v1
```

## API Compatibility

All servers provide OpenAI-compatible API:

```bash
# List models
curl http://localhost:8000/v1/models

# Chat completion
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

## Backup & Restore

```bash
# Backup models
tar -czf models-backup.tar.gz models/

# Restore
mkdir -p models
tar -xzf models-backup.tar.gz -C models/
```

## License

Model licenses apply. Respect terms of:
- Llama models: Meta License
- Other models: Their respective licenses
