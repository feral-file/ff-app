# Feral File — Mobile App (Flutter)

The Feral File mobile app is the controller for the **Feral File Art System**:
- **FF1** (art computer) + any screen, or **FF1 + FFP** (full system)
- Setup, pairing, remote control, and library/discovery surfaces

Product goal: make it *silly-easy* to live with digital art every day.

---

## What the app does

Core concepts are aligned with **DP-1** (Display Protocol 1). The app is a **presentation surface** that browses and controls DP-1 objects (Channels, Playlists, Works) and sends explicit play commands to a paired device.

### Primary surfaces

- **Channels** (with pinned **My Collection**)
  - Sub-sections: **Me / Curated / Global**
- **Playlists**
  - Sub-sections: **Me / Curated / Global**
- **Works**
  - Sub-sections: **Me / Curated / Global**
- **Explore**
  - Conversational search + Faceted search over the same DP-1 scopes and facets

### Core actions (DP-1-rooted)

- **Play** — “Play on FF1 now” (or queue)
- **Follow**
- **Add to Collection** — saves to the user’s personal Channel (**My Collection**)
- **Share**
- **Star** — curator endorsement used for discovery “bubbling” (Feral File/commissioned curators)

> Terminology lock: **Channels** and **Playlists** are DP-1 objects. “Exhibitions/Seasons/Programs” are **playlist roles** surfaced with curated chrome inside the Feral File channel (not new protocol object types).

---

## Trust & security model (high level)

The app participates in the **trust path**: pairing, authentication, and (by Orbit) increasingly verifiable authorship/endorsement and licensing—without breaking earlier content. Non‑negotiables: the trust path is **vendor‑neutral**, **portable**, and **key‑controlled**.

Key concepts:
- **Passkey** — device-based auth used during onboarding/pairing
- **DeviceKey** — device identity anchor (Ed25519)
- **Multi-signature DP-1 envelopes** — roll out Orbit-by-Orbit (additive, forward compatible)

---

## Architecture (conceptual)

Feral File uses “bands” to reason about the system. The mobile app lives in **Band 4: Presentation Apps** and talks to:
- **Band 3: Discovery & Content APIs** (read/search)
- **Band 5: Display Protocol** (play/control semantics)
- **Band 8: Ownership & Identity** (passkeys, address indexing, verification)

---

## Design & engineering principles

We default to:
- **Deletion-first**
- **Reality-first**
- **Reliability before novelty**

If a flow feels complex, assume the constraints are wrong and simplify until the core path is obvious and reversible.

---

## Getting started

### Prerequisites
- Flutter SDK (stable)
- Xcode (iOS) / Android Studio (Android)
- A dev/test backend environment
- Optional: an **FF1** device for full end-to-end testing

### Clone & install
```bash
git clone <REPO_URL>
cd ff-app
flutter pub get
```

### Run (dev)
```bash
# Android (development flavor)
flutter run --flavor development

# iOS
flutter run
```

### Build
```bash
# Android (production)
flutter build apk --flavor production --release

# Android (development)
flutter build apk --flavor development --release

# iOS
flutter build ios --release
```

---

## Configuration

> **Note:** Keep secrets out of git. Use per-environment configs.

Required keys (ask team for dev/staging values):
- `DP1_FEED_URL`
- `INDEXER_API_URL`
- `DP1_FEED_API_KEY`
- `INDEXER_API_KEY`
- `FF1_RELAYER_API_KEY` (or `TV_API_KEY`)

If any required key is missing, the app will show a configuration error screen on launch.

Starter template: copy `.env.example` to `.env` and fill in values.

Typical values (names are illustrative—use your repo’s actual config system):
- `API_BASE_URL` — Discovery/Content API base URL
- `DP1_BASE_URL` — DP-1 endpoints (e.g., play)
- `FEATURE_FLAGS` — enable/disable Orbit features (e.g., curator Star tools)
- `LOG_LEVEL` — debug/info/warn/error

### Local dev quickstart
1) Create `.env` with the required keys above (do not commit).
2) `flutter pub get`
3) `flutter run --flavor development`

---

## Key flows to test

### Gold Path
A new person should go from power-on → pairing → playing a meaningful artwork quickly, with obvious success and reversible steps. (Exact readiness thresholds live in business gates.)

### Pairing & device management (FF1 / FFP)
- Pair FF1 via QR (and recovery reconnect flows)
- Control path validation for FFP (sleep/wake + brightness, with documented behavior)

### Collection & indexing
- “Add Address” and large-wallet indexing behavior (progress is clear; no stalls/loops)

### Sleep/resume
- FF1 sleep/resume acceptance tests across real installs

---

## Testing

Recommended layers:
- Unit tests for core state and parsing
- Widget tests for navigation + key screens
- **Golden tests** for visual regressions (mobile quality guardrail)
- Integration tests against a test backend and (when possible) real FF1 hardware

Run:
```bash
flutter test
```

---

## Contributing

- Keep changes aligned with DP-1 concepts and terminology (Channel / Playlist / Work).
- Prefer fewer surfaces and fewer states over adding new flows.
- Document user-visible changes in release notes conventions when applicable.

---

## Support & feedback

- File reproducible bugs as Known Issues (if applicable in your org workflow)
- Include device + OS versions, steps to reproduce, and screen recordings when possible
