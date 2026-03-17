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

### Review priority
1. Riverpod correctness and best practices per https://riverpod.dev/docs/root/do_dont
2. UI/error copy voice compliance per `.cursor/rules/05-engineering-voice.mdc`
3. Flutter performance best practices per https://docs.flutter.dev/perf/best-practices
4. Master-flow integrity against `docs/project_spec.md` and `docs/app_flows.md`
5. Principle compliance with `.cursor/rules/01-master-design.mdc`

### Required expanded review posture
- Do not review only for local correctness of the submitted diff.
- Read the PR description first, infer the real product/flow goal, then review whether the chosen implementation is the right solution for that goal.
- Because this app does not require backward-compatibility or migration-safe edits by default, do not bias toward minimal-change solutions during review.
- Consider stronger alternatives, including larger refactors, responsibility re-allocation, API reshaping, deleting obsolete abstractions, or breaking changes, but only mention them when they are obviously better and materially improve the outcome.
- Do not speculate or brainstorm in review comments. If an alternative is not clearly superior, skip it.

### Hindsight and refactor review
Only add hindsight or refactor feedback when the review revealed a concrete architectural problem or an obviously better structure.
If there is no clear, actionable hindsight insight, omit this section entirely.

### Tests and docs sufficiency review
For substantial reviews, assess only real gaps:
1. Do we have enough unit tests for the logic introduced or changed?
2. Do we have enough integration coverage for the affected flow?
3. Are current tests verifying the intended behavior rather than implementation details?
4. Does the change require updates to `docs/project_spec.md`, `docs/app_flows.md`, or other developer docs?
5. If documentation is missing, specify exactly what should be documented.
If there is no meaningful test or documentation gap, skip this commentary.

### Preferred review output shape
Keep review comments concise and focused on high-signal findings.
For non-trivial PRs, use only the sections that have real content:
1. Critical correctness issues
2. Architecture / flow issues
3. Better alternative designs
4. Hindsight refactors
5. Test gaps
6. Documentation gaps
If a section has no meaningful comment, omit it.
If there are no meaningful findings, better alternatives, or gaps, say nothing beyond a brief approval-style summary.
Include an explicit "recommended alternative approach" only when it is obviously better than the submitted design.
