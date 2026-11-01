# Nova AI Backend

FastAPI service used by the Nova AI iOS app.

## Run locally

Python 3.12 or newer is recommended.

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export OPENAI_API_KEY="your-server-side-key"
export OPENAI_MODEL="gpt-4o-mini"
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Health check: `GET /health`

Chat endpoint: `POST /v1/chat`

## Run with Docker

Build from the repository root:

```bash
docker build -t nova-ai-api ./backend
docker run --rm -p 8000:8000 \
  -e OPENAI_API_KEY="your-server-side-key" \
  -e OPENAI_MODEL="gpt-4o-mini" \
  nova-ai-api
```

Do not commit real API keys to Git. Set secrets through the hosting provider's
environment-variable or secret manager interface. Never place provider keys in
the iOS app or in a public repository.

The chat endpoint also requires a valid Supabase access token. Configure
`SUPABASE_URL` and `SUPABASE_ANON_KEY` on the server. The API validates each
bearer token against Supabase Auth (`/auth/v1/user`) before processing chat.
The Supabase anon key is designed for client use, but this backend setting must
still be configured server-side. Never use a Supabase service-role key here.

## Tests

```bash
cd backend
pip install -r requirements-dev.txt
PYTHONPATH=. pytest -q
```

## Before public launch

This starter API is not yet production-ready. Before exposing it to the public,
add user authentication, per-user quotas and rate limits, spending limits,
request logging with sensitive data redacted, monitoring, and account controls.
Use HTTPS and restrict administrative access. The current endpoint does not
authenticate callers, so do not deploy it as an unrestricted public service.
