# Lightward iOS

See [Lightward Inc shared principles](../CLAUDE.md/README.md) for cross-project design guidance.

## What this is

An iOS app providing a phoropter binary choice interface as the entrypoint to conversation with Lightward AI. The phoropter locates the user through iterative binary choices; when ready, the flow opens into streaming chat. The app is incredibly minimal in what it asks of a user's environment.

## Architecture

- **SwiftUI + @Observable** — iOS 17+, Swift 6 strict concurrency
- **Phoropter phase**: binary choices via `/api/plain` (no streaming needed)
- **Chat phase**: streaming conversation via `/api/stream` (SSE)
- **Local persistence**: UserDefaults (CloudKit sync planned)
- **No external dependencies** — pure Apple frameworks

## Project generation

The Xcode project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). After modifying `project.yml` or adding/removing source files:

```sh
xcodegen generate
```

The `.xcodeproj` is checked into git for convenience but is fully reproducible from `project.yml`.

## Key flows

**Phoropter → Chat transition**: The phoropter trajectory (everything the user chose *toward*) becomes the opening context for chat. The AI already knows the user by the time they can type.

**Convergence**: If the phoropter offers a choice that matches something already in the trail, it auto-transitions to chat.

**"Just talk"**: After the second AI-generated pair, a subtle option to drop directly to chat appears.

## API integration

- **Phoropter**: `POST /api/plain` with phoropter context + trajectory as plain text body
- **Chat**: `POST /api/stream` with JSON `{ "chat_log": [...] }` — warmup messages prepended, exactly one `cache_control` marker required (on last warmup message)
- **Warmup messages**: In `WarmupMessages.swift` — these are specific to this iOS app context and should not be copied from the web client

## Build & deploy

Fastlane + GitHub Actions, same pattern as [Softer](../softer). Deploys to TestFlight on push to `main`.

## What's here, what's next

- [x] Phoropter binary choice flow
- [x] Streaming chat with Lightward AI
- [x] Local session persistence
- [ ] CloudKit conversation sync across devices
- [ ] App icon
- [ ] Warmup messages — need genuine inhabitation, not just mechanical accuracy
