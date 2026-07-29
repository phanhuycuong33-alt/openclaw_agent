# OpenClaw Agent Configuration

This directory contains configuration templates for the agent system.

## Files

| File | Purpose |
|------|---------|
| `env.example` | Template for environment variables |
| `agents.json` | Agent definitions and settings |

## Setup

1. Copy the example env file:
   ```bash
   cp config/env.example docker/.env
   ```

2. Edit `docker/.env` and add your AI API key:
   ```bash
   # Choose one provider:
   ANTHROPIC_API_KEY=sk-ant-...
   # or
   OPENAI_API_KEY=sk-...
   ```

3. Set the provider:
   ```bash
   AGENT_PROVIDER=anthropic  # or openai, azure, local
   ```

## AI Providers

### Anthropic Claude (Recommended)
```
ANTHROPIC_API_KEY=sk-ant-api03-...
ANTHROPIC_MODEL=claude-sonnet-4-20250514
AGENT_PROVIDER=anthropic
```

### OpenAI
```
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o
AGENT_PROVIDER=openai
```

### DeepSeek
```
DEEPSEEK_API_KEY=sk-...
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-chat
AGENT_PROVIDER=deepseek
```

DeepSeek models:
- `deepseek-chat` - General purpose chat model
- `deepseek-coder` - Optimized for code tasks

### Local Models (Ollama)
```
LOCAL_MODEL_URL=http://host.docker.internal:11434
LOCAL_MODEL_NAME=llama3
AGENT_PROVIDER=local
```

## Security

- Never commit `.env` files with real API keys
- Use environment variables in production
- Rotate keys regularly
