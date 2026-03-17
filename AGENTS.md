# AGENTS.md — Feral File Mobile (Flutter) Contract

This file defines repository-level constraints for coding agents. Detailed implementation behavior remains in `.cursor/rules/`.

## Repository overview
- Project: Feral File Mobile app (Flutter) for The Digital Art System.
- Domain lock: `Channel`, `Playlist`, `Work` only.
- Architecture posture: offline-first local DP-1 read model + FF1 controller.

## Non-negotiables
- Prefer replacing or deleting flawed code paths over narrow local tweaks when solving an issue. If a broader rewrite produces a clearer design, choose it.
- Do not preserve legacy behavior, compatibility shims, migrations, or transitional paths unless explicitly requested.
- Prefer stateless, testable services/utilities by default; use stateful services only when lifecycle/orchestration/session behavior truly requires state.
- For non-obvious logic, add code comments that preserve intent and context for later fixes, especially around functions, flows, state transitions, and important variables.
- Those comments should explain `why` the code exists, the constraints/invariants it must preserve, failure or edge cases, trade-offs, and when useful the pros/cons of the chosen approach versus alternatives. Do not waste comments on restating obvious syntax.

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
6. Run `scripts/agent-helpers/post-implementation-checks HEAD` and fix all reported issues.

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

## Review workflow (implement → review loop → commit/push/PR)

After implementation, run a **review loop** until the reviewer qualifies the change. Only after the reviewer says **Verdict: accept** do you commit, push, or create a PR.

1. **Create a compact handoff** — Goal, files changed, key decisions and tradeoffs, checks run (e.g. lint, tests, post-implementation script).

2. **Invoke the reviewer sub-agent** — Run a fresh-context review. Give it the handoff, the diff, and any test/lint output. The reviewer follows `prompts/code-review.md` and ends with **Verdict: accept** or **Verdict: revise**.

3. **If Verdict: revise** — Address the reviewer’s findings (fix issues, add tests/docs as needed), re-run tests and post-implementation checks, update the handoff, and invoke the reviewer again. Repeat until **Verdict: accept**.

Do not commit, push, or create a PR (if requested) before the reviewer has accepted. The master agent and reviewer sub-agent work in this loop until the change is qualified.

## Commit message format
Use Conventional Commits:
- `<type>(<optional-scope>): <description>`
- Types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `build`, `ci`, `perf`, `style`
- Use `!` for breaking changes.

## Review guidelines

The single source of truth for review priority, posture, hindsight, tests/docs, and output format is **`prompts/code-review.md`**. All reviewers (human or agent) should follow it. AGENTS.md does not duplicate that content; see the prompt file for the full contract.