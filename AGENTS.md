# AGENTS.md — Feral File Mobile (Flutter) Master Code Design

This document is the **contract** for humans + AI agents working in this repo.

## 0) Non-negotiables (system principles)
- **Deletion before optimization.** Prefer removing surfaces and legacy baggage over “improving” them.  
- **DP-1 is the spine. Data model must be rooted in DP-1 objects + terms:
  - **Channel / Playlist / Work** (no custom “Exhibition/Season/Program” object types; those are *playlist roles* in UI only).  
- **OSS-first posture* Data paths: portable, auditable, minimal vendor lock. 

## 1) Architectural boundaries (Flutter)
### 1.1 Bands alignment (for reasoning about ownership)
This repo is a **Presentation App** (Band 4). It must:
- Read DP-1 entities (Channels/Playlists/Works) from local store and/or read-only APIs.
- Control FF1 via a dedicated comms stack (transport + protocol + control separation).
- Never become the source of truth for trust-path cryptographic correctness.  

### 1.2 Layering

Hard rules:
- UI cannot call transports directly.
- Protocol messages cannot depend on Flutter widgets.
- Storage schema & naming must be DP-1-first (no bespoke object graph “because it’s easier”).

## 2) Riverpod is the master flow driver (required)
We use **Riverpod** as the *single* master state/flow driver:
- App “truth” lives in Riverpod providers / notifiers.
- Screens are reactive views over providers; no hidden singleton state.
- External FF1 events must fan-in through a provider-driven event pipeline so **any screen** can show global status (e.g., FF1 internet down) without hacks.

Guidelines:
- Prefer immutable state models + explicit reducers/Notifiers.
- Keep “side effects” behind providers (repositories/services), never in widgets.
- Provide test seams: override providers in tests; use fakes for transport/protocol layers.
- **Write testable code when applicable**: favor pure `domain/` logic, dependency injection via providers, and no hidden singletons.

## 3) Data model: DP-1 normalization + offline-first
### 3.1 DP-1 terminology locks
Use only:
- `Channel`, `Playlist`, `Work`
- IDs like `ch_*`, `pl_*`, `wk_*` (do not introduce parallel ID schemes).  

### 3.2 Offline store -end simple” v1 store:
- Local tables/collections reflect DP-1 entities and relationships only.
- Personal playlists and curated playlists are both **DP-1 Playlists** (no custom “CuratedPlaylist” object).
- “My Collection” is treated as pinned personal **Channel** (DP-1 concept), not a separate domain object.
- Other user preferences: Store as a key-value database using Objectbox.

## 4) FF1 communicati protocol/control split)
### 4.1 Split layers (required)
- **Transport**: Bluetooth / Wi-Fi (LAN and relayer). Handles connect/retry/disconnect.
- **Protocol**: message definitions, versioning, serialization.
- **Control**: state machine + commands (play, queue, device status), uses Protocol via interfaces.

Rule: you must be able to change **Protocol** without rewriting **Control** (and vice versa).

### 4.2 Adapter pattern for Wi-Fi
- Provide at least two adapters: `LanAdapter` and `RelayerAdapter`.
- Keep protocol independent from transport; transport just carries bytes/messages.

## 5) Global external events (screen-independent)
Requirement: Any “FF1 status change” must be visible from anywhere:
- Connection lost / FF1 internet disconnected / pairing required / update needed
Implementation constraint:
- Events funnel through Riverpod → global notice model → UI overlay/banner component shared across screens.

## 6) Design tokens / Master Theme
- Centralize typography scale, spacing, radii, colors as a single **Master Theme** module.
- Structure tokens so we can update from Figma token exports with minimal refactor (no scattered magic numbers).
- Theme access via Riverpod where appropriate (e.g., runtime theme switching later), but keep primitives in one place.  

## 7) Testing and qua Provider-level unit tests for:
  - DP-1 normalization
  - playlist persistence (personal + curated)
  - comms control state machine (with fake protocol/transport)
- Integration tests should be able to run without a real FF1 by swapping adapters.

### 7.1 Unit testing best practices (Flutter + Riverpod)
- **Isolate state**: create a fresh `ProviderContainer` per test (prefer `ProviderContainer.test()`).
- **Override dependencies**: use provider overrides to inject fakes/stubs (repositories, transports, clocks, randomness).
- **Avoid global state**: no singletons that can’t be swapped in tests; route side effects through providers.
- **Prefer unit tests first**: test `domain/` and `app/` (notifiers/controllers) without Flutter widgets.
- **Auto-dispose providers**: when needed, use `container.listen(...)` in tests to keep providers alive while asserting behavior.

## 8) Out of scope (do not sneak in)
- Localization
- Performance benchmarks
- Authentication / passkeys / wallets
- Per-exhibition / per-artwork hacks
- Any non-DP-1 custom object types

## 9) PR checklist (must answer)
- Did you **delete** something instead of adding another layer?  
- Are all domain nouns l/Playlist/Work)?  
- Does Riverpod remain er (no hidden state)?
- Are Protocol and Control separated (different modules/interfaces)?
- Are theme tokens centralized (no scattered constants)?

## 10) Definition of Done (DoD)
A task is considered complete when:
1. **Buildable** — `flutter build` succeeds without errors on both Android and iOS targets.
2. **Code lint passes** — `flutter analyze` reports zero lint violations (must pass `very_good_analysis` rules).
3. **Unit tests pass** — `flutter test` succeeds (no failing tests).
4. **No pre-existing lints introduced** — New code does not add additional lints; fixes existing ones if trivial.
5. **Architecture respected** — Follows layering (ui/ → app/ → domain/ → infra/), no violations of separation rules.
6. **DP-1 terminology locked** — Only Channel/Playlist/Work as domain objects; playlist roles expressed via fields/enums.
7. **Riverpod flow maintained** — All side effects routed through providers; no hidden singleton state.
8. **Testable code (if applicable)** — Dependencies are injectable (providers/constructors), critical logic has unit tests (use fakes via overrides).
9. **Commit message clear** — Describes the *why*, not just the *what*; references task/issue if applicable.