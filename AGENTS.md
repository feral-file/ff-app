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
