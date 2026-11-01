import os

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Nova AI API", version="0.1.0")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
OPENAI_URL = "https://api.openai.com/v1/chat/completions"


class Message(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=12000)


class ChatRequest(BaseModel):
    messages: list[Message] = Field(min_length=1, max_length=40)


class ChatResponse(BaseModel):
    reply: str


@app.get("/health")
async def health():
    return {"status": "ok", "service": "nova-ai-api"}


@app.post("/v1/chat", response_model=ChatResponse)
async def chat(payload: ChatRequest):
    if not OPENAI_API_KEY or OPENAI_API_KEY == "replace_me":
        raise HTTPException(status_code=503, detail="AI provider is not configured")

    messages = [
        {"role": "system", "content": "You are Nova, a helpful multilingual AI assistant. Reply in the user's language."},
        *[message.model_dump() for message in payload.messages],
    ]

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(
                OPENAI_URL,
                headers={"Authorization": f"Bearer {OPENAI_API_KEY}"},
                json={"model": OPENAI_MODEL, "messages": messages},
            )
            response.raise_for_status()
            data = response.json()
            reply = data["choices"][0]["message"]["content"]
            return ChatResponse(reply=reply)
    except httpx.HTTPStatusError as exc:
        raise HTTPException(status_code=502, detail="AI provider request failed") from exc
    except (httpx.HTTPError, KeyError, IndexError, TypeError) as exc:
        raise HTTPException(status_code=502, detail="AI provider unavailable") from exc
