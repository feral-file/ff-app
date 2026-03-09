# AGENTS.md — Feral File Mobile (Flutter) Contract

This file defines repository-level constraints for coding agents. Detailed implementation behavior remains in `.cursor/rules/`.

## Repository overview
- Project: Feral File Mobile app (Flutter) for The Digital Art System.
- Mission: reliable daily digital-art playback and FF1 control.
- Domain lock: `Channel`, `Playlist`, `Work` only.
- Architecture posture: offline-first local DP-1 read model + FF1 controller.

## Important directories
- Runtime entrypoints:
  - `lib/main.dart`
  - `lib/app/app.dart`
- Routing/deeplinks:
  - `lib/app/routing/router_provider.dart`
  - `lib/app/routing/deeplink_handler.dart`
  - `lib/app/routing/routes.dart`
- Provider composition and app orchestration:
  - `lib/app/providers/`
- UI screens:
  - `lib/ui/screens/`
- Core infrastructure:
  - `lib/infra/database/`
  - `lib/infra/services/`
  - `lib/infra/ff1/`
  - `lib/infra/graphql/`
- Domain model source of truth:
  - `lib/domain/models/`
- Specs and flow docs:
  - `docs/project_spec.md`
  - `docs/app_flows.md`

## Non-negotiables
- Deletion before optimization.
- Riverpod is the single flow driver for shared app state and FF1 external events.
- No hidden singleton business-flow state.
- No legacy support by default. If migration is required, ask first.
- Keep FF1 layering separated: `transport` / `protocol` / `control`.
- Prefer stateless, testable services/utilities by default; use stateful services only when lifecycle/orchestration/session behavior truly requires state.
- Prefer dependency injection (providers/constructors) over singleton-held mutable state.
- Preserve offline-first behavior (Drift local model remains primary read path).
- Preserve seed-database gate/bootstrap behavior and pending-address migration semantics.

## Spec-driven workflow (required)
Before implementing any major feature, flow change, or architectural refactor:
1. Read `docs/project_spec.md`.
2. Read `docs/app_flows.md`.
3. Summarize the relevant current flow(s), screen responsibilities, and constraints/invariants.
4. Propose a feature spec and task plan.
5. Only then begin implementation.

Canonical large-feature sequence:
`spec -> design -> tasks -> implementation -> verification`

If work is large/architectural and no feature spec exists, do not proceed directly to implementation.

## Required development sequence (behavior changes)
1. Write small, testable unit functions first.
2. Write unit tests for those functions.
3. Write integration tests next, with `.env` provisioned, and define expected integration outputs before implementation.
4. Run tests and ensure they all pass.
5. Implement/compose app flow that uses the tested functions.
6. Run post-implementation checks and fix all reported issues.
7. Run `flutter build` to verify.

## Important commands (build, lint, test)
- Install deps: `flutter pub get`
- Post-implementation checks (lint + test):
  - `scripts/agent-helpers/post-implementation-checks HEAD`

## Rule references (authoritative detail)
- `.cursor/rules/01-master-design.mdc`
- `.cursor/rules/20-mobile-vocabulary.mdc`
- `.cursor/rules/30-riverpod.md`
- `.cursor/rules/35-testing-tdd.mdc`
- `.cursor/rules/50-indexing-address-flow.mdc`

## Definition of done
A task is complete only when:
1. Post-implementation checks are clean.
2. Architecture/layering and DP-1 terminology constraints remain intact.
3. Riverpod remains the flow driver; side effects stay out of widgets.

## Sentry issue fix workflow
When fixing a Sentry issue from short-id:
1. Run `scripts/agent-helpers/sentry_issue_report.sh --issue-id <short-id>` first.
2. Implement fix (tests updated only when needed).
3. Include in PR: issue URL, summary, root cause, solution.

## Commit message format
Use Conventional Commits:
- `<type>(<optional-scope>): <description>`
- Types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `build`, `ci`, `perf`, `style`
- Use `!` for breaking changes.

## Review guidelines
Follow these guidelines for all PR reviews and change requests.

- Review priority:
  1. Riverpod correctness and best practices per https://riverpod.dev/docs/root/do_dont
  2. UI/error copy voice compliance per `.cursor/rules/05-engineering-voice.mdc`
  3. Flutter performance best practices per https://docs.flutter.dev/perf/best-practices
  4. Master-flow integrity against `docs/project_spec.md` and `docs/app_flows.md`
  5. Principle compliance with `.cursor/rules/01-master-design.mdc`
- Riverpod reviews must aggressively flag anti-patterns from the Riverpod do/don't guide (provider misuse, hidden mutable flow state, widget-driven side effects, or architecture drift away from Riverpod as the flow driver).
- UI text and error messages must strictly follow the engineering voice document (`.cursor/rules/05-engineering-voice.mdc`). If copy violates voice/clarity/tone rules, explicitly recommend replacement text in review comments.
- For Flutter code, check for violations of the Flutter performance guide and flag regressions as high-priority findings.
- For every newly added dependency in `pubspec.yaml`, run `scripts/pub_dependency_report.sh`, verify whether each added package is on the latest version, and recommend upgrading to the latest stable version by default.
- Review flow impact explicitly: read `docs/project_spec.md` and `docs/app_flows.md`, map the change to current master flows, and comment on any invariant/responsibility violation.
