# AGENTS.md — Feral File Mobile (Flutter) Contract

This file is the high-level contract. Detailed coding constraints live in `.cursor/rules/` and are authoritative for day-to-day implementation behavior.

## 0) Non-negotiables
- Deletion before optimization: remove legacy/duplicate surfaces before adding new ones.
- DP-1-first domain lock: only `Channel`, `Playlist`, `Work` as domain nouns.
- Riverpod is the single flow driver for shared app state and FF1 external events.
- No hidden singleton state for business flow.
- No legacy support by default. If migration is required, ask first. Default stance: no migration.

## 1) Architecture boundary
- Offline-first client. Always cache if you could.
- Reads DP-1 entities from local store and/or read-only APIs.
- Controls FF1 via separated `transport` / `protocol` / `control` layers.

## 2) Rule references (source of detail)
Use these rule files for concrete implementation behavior:
- `.cursor/rules/01-master-design.mdc`: architecture, layering, DP-1, FF1 layering, DoD.
- `.cursor/rules/20-mobile-vocabulary.mdc`: naming consistency for files/classes/variables/IDs.
- `.cursor/rules/30-riverpod.md`: Riverpod watch/read/listen and provider design/testing.
- `.cursor/rules/04-coding-style.mdc`: Flutter style, comments, and Dartdoc comment policy.
- `.cursor/rules/35-testing-tdd.mdc`: mandatory TDD order, test execution flow, and post-implementation validation (§4).
- `.cursor/rules/07-no-legacy.mdc`: explicit no-legacy/no-migration-by-default policy.

Avoid duplicating lower-level guidance here; update the rule files above when behavior changes.

## 3) Required development sequence (always)
For any feature/refactor touching behavior:
1. Write small, testable unit functions first.
2. Write unit tests for those functions.
3. Write integration tests next, with `.env` provisioned, and define expected integration outputs before implementation.
4. Run tests and ensure they all pass.
5. Implement/compose app flow that uses the tested functions.
6. **Run post-implementation checks** — see `.cursor/rules/35-testing-tdd.mdc` §4.

No exception path for skipping the above sequence.

## 4) Definition of done
A task is complete only when:
1. Post-implementation script clean and build succeeds (`.cursor/rules/35-testing-tdd.mdc` §4).
2. Architecture/layering and DP-1 terminology constraints remain intact.
3. Riverpod remains the flow driver; side effects stay out of widgets.
