# Nova AI

Nova AI is a bilingual iOS AI assistant starter project with a FastAPI backend.

## Repository layout

- `ios/`: SwiftUI iOS app (generated as an Xcode project with XcodeGen)
- `backend/`: FastAPI service; provider credentials stay on the server
- `.env.example`: backend configuration template

## Build the iOS app

On a Mac with Xcode and XcodeGen installed:

```sh
cd ios
xcodegen generate
open NovaAI.xcodeproj
```

Select an iOS 17+ simulator or device and build.

## Run the backend

```sh
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Set OPENAI_API_KEY in .env
uvicorn app.main:app --reload
```

The backend reads the API key from its environment. Never put provider keys in the iOS app or commit a real `.env` file.

## Current status

This is the initial application scaffold. Configure a backend URL in the iOS app before testing chat on a physical device.


## Unsigned device IPA

A GitHub Actions workflow can build an unsigned iOS device IPA for authorized re-signing with a compatible signing profile. An unsigned IPA is not directly installable; it must be signed by a tool such as E.sign with a profile that permits the selected bundle identifier.
