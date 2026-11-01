import os

import httpx
from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field, model_validator

app = FastAPI(title="Nova AI API", version="0.3.0")
bearer_scheme = HTTPBearer(auto_error=False)

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
OPENAI_URL = "https://api.openai.com/v1/chat/completions"
SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

MAX_TOTAL_MESSAGE_CHARS = 24000
MAX_COMPLETION_TOKENS = 1200


class Message(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=8000)


class ChatRequest(BaseModel):
    messages: list[Message] = Field(min_length=1, max_length=30)

    @model_validator(mode="after")
    def limit_total_message_length(self):
        total_chars = sum(len(message.content) for message in self.messages)
        if total_chars > MAX_TOTAL_MESSAGE_CHARS:
            raise ValueError(
                f"Combined message content must not exceed {MAX_TOTAL_MESSAGE_CHARS} characters"
            )
        return self


class ChatResponse(BaseModel):
    reply: str


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
):
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Authentication required")

    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        raise HTTPException(status_code=503, detail="Authentication service is not configured")

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(
                f"{SUPABASE_URL}/auth/v1/user",
                headers={
                    "apikey": SUPABASE_ANON_KEY,
                    "Authorization": f"Bearer {credentials.credentials}",
                },
            )
            if response.status_code in (401, 403):
                raise HTTPException(status_code=401, detail="Invalid or expired access token")
            response.raise_for_status()
            user = response.json()
            if not isinstance(user, dict) or not user.get("id"):
                raise HTTPException(status_code=401, detail="Invalid authentication response")
            return {"id": str(user["id"])}
    except HTTPException:
        raise
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="Authentication service unavailable") from exc
    except ValueError as exc:
        raise HTTPException(status_code=503, detail="Authentication service unavailable") from exc


@app.get("/health")
async def health():
    return {"status": "ok", "service": "nova-ai-api"}


@app.post("/v1/chat", response_model=ChatResponse)
async def chat(payload: ChatRequest, current_user=Depends(get_current_user)):
    if not OPENAI_API_KEY or OPENAI_API_KEY == "replace_me":
        raise HTTPException(status_code=503, detail="AI provider is not configured")

    messages = [
        {
            "role": "system",
            "content": "You are Nova, a helpful multilingual AI assistant. Reply in the user's language.",
        },
        *[message.model_dump() for message in payload.messages],
    ]

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(
                OPENAI_URL,
                headers={"Authorization": f"Bearer {OPENAI_API_KEY}"},
                json={
                    "model": OPENAI_MODEL,
                    "messages": messages,
                    "max_completion_tokens": MAX_COMPLETION_TOKENS,
                },
            )
            response.raise_for_status()
            data = response.json()
            reply = data["choices"][0]["message"]["content"]
            if not isinstance(reply, str) or not reply.strip():
                raise ValueError("AI provider returned an empty response")
            return ChatResponse(reply=reply)
    except httpx.HTTPStatusError as exc:
        raise HTTPException(status_code=502, detail="AI provider request failed") from exc
    except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="AI provider unavailable") from exc
