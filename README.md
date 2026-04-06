# Feral File Mobile App

Canonical Flutter mobile controller and library app for FF1 and The Digital Art System.

This repository is the canonical source for the Feral File mobile app. The app is a Band 4 presentation surface in the broader Feral File stack: it browses DP-1 Channels, Playlists, and Works, helps users build a personal collection, pairs and controls FF1 devices, and sends play and control requests into the rest of the system.

## How It Fits FF1 And The Digital Art System

- `FF1` is the art computer that plays art on a screen.
- `FFP` is the reference panel for the full system experience.
- This mobile app is the handheld setup, library, and remote-control surface.
- The app consumes discovery, indexing, and device-control services, but it does not own publication backoffice, device runtime, or private operational policy.

In product terms: FF1 is the engine, the mobile app is setup plus remote control plus library, and DP-1 is the compatibility layer that keeps Channels, Playlists, and Works portable.

## Scope And Vocabulary

- Domain vocabulary is locked to `Channel`, `Playlist`, and `Work`.
- The app is offline-first: a local seed database is the default read path.
- The app focuses on browsing, personal collection, pairing, and playback control.
- Exhibitions and programs are expressed through channel and playlist presentation, not new protocol object types.

## Public Repo Boundary

This repo is prepared to be the public, canonical app repository.

- Public here: Flutter source, tests, public contributor docs, example configuration, and CI workflows.
- Not public here: secrets, production credentials, private strategy docs, unpublished operational runbooks, or internal service data.
- If a change depends on private infrastructure, document the interface and expected contract without committing secret values or private documents.

## Prerequisites

- Flutter stable
- Xcode for iOS builds
- Android Studio and Android SDK for Android builds
- Optional FF1 hardware for end-to-end pairing and playback checks

## Local Setup

```bash
git clone https://github.com/feral-file/ff-app.git
cd ff-app
cp .env.example .env
flutter pub get
```

Run the app:

```bash
# Android (development flavor)
flutter run --flavor development

# iOS
flutter run
```

For iOS CocoaPods setup:

```bash
cd ios
pod install --repo-update
cd ..
```

## Environment Variable Contract

Copy `.env.example` to `.env` and fill only the values needed for your workflow.

Required for app startup:

- `INDEXER_API_URL`
- `INDEXER_API_KEY`
- `FF1_RELAYER_URL`
- `FF1_RELAYER_API_KEY`

Optional runtime integrations:

- `DP1_FEED_URL` and `DP1_FEED_API_KEY` for feed-backed or integration flows
- `DOMAIN_RESOLVER_URL` and `DOMAIN_RESOLVER_API_KEY` for ENS and TNS resolution
- `REMOTE_CONFIG_URL` to override the default remote-config document
- `RELEASE_NOTES_MARKDOWN_URL` or `PUBDOC_URL` to load release notes
- `FERALFILE_DOCS_URL` to override the default public legal-docs base
- `SUPPORT_API_KEY`, `SENTRY_DSN`, `ASSET_URL`, `INDEXER_ENRICHMENT_MAX_THREADS`

Integration and seed-database tests:

- `S3_BUCKET`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`
- `S3_REGION`
- `S3_SEED_DATABASE_OBJECT_KEY`

Legacy aliases still supported by the app:

- `TV_NOTIFICATION_URL`
- `TV_API_KEY`

If the required startup keys are missing, the app will show a configuration error screen instead of booting into a broken state.

## Basic Setup Verification

Run the quick local verification script:

```bash
./scripts/verify_local_setup.sh
```

That script runs:

- `flutter pub get`
- `flutter test test/unit/infra/services/release_notes_service_test.dart`

It is intentionally a lightweight smoke test for public contributors: dependency resolution plus a public-safe unit-test path that does not require private credentials or hardware.

Hardware-dependent FF1 flows, S3-backed seed tests, and broader integration checks need additional environment variables and are not part of the default public setup verification.

## Contributing

- Keep terminology aligned with `Channel`, `Playlist`, and `Work`.
- Keep changes scoped; this repo is the canonical mobile app repo, not a place for speculative system rewrites.
- Add or update tests for behavior changes.
- Keep `README.md` and `.env.example` in sync when setup or configuration changes.
- Do not commit `.env`, secrets, private planning docs, or generated artifacts.
- Use the GitHub issue and pull-request templates when opening work.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the lightweight contributor checklist.

## Related Repositories

- [display-protocol/dp1](https://github.com/display-protocol/dp1) for the protocol and schemas
- [feral-file/docs](https://github.com/feral-file/docs) for public product and legal reference material
- [feral-file/ff-indexer-v2](https://github.com/feral-file/ff-indexer-v2) for indexing and enrichment
- [feral-file/ff-relayer](https://github.com/feral-file/ff-relayer) for device relay and connectivity

## License

Released under the BSD 2-Clause License. See [LICENSE](LICENSE).
