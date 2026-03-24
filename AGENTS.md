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

## ExecPlans

When writing a big feature, major flow change, significant refactor, or handling a vague command with unclear requirements, use an execution plan as described in `PLANS.md`.

Use `PLANS.md` only when the work is large enough or vague enough that it needs research, branching design exploration, and staged delivery. Do not use `PLANS.md` for small direct code changes, narrow fixes, isolated test updates, or when the user already provided a detailed plan with concrete steps and TODOs.

When `PLANS.md` is activated, follow it exactly:
1. Read `PLANS.md` before proposing the plan.
2. Read `docs/project_spec.md` and `docs/app_flows.md`.
3. Summarize the current relevant flow, responsibilities, and invariants.
4. If requirements are unclear or repository docs feel incomplete, stale, contradictory, or too low-level, stop and ask the user for clarification or higher-level context such as internal docs, Figma, or API references.
5. For big or vague work, branch into multiple designs with trade-offs, constraints, and risks.
6. Define test cases first for every option, following `.cursor/rules/35-testing-tdd.mdc`.
7. Ask the user to choose when the surviving branches differ materially in behavior, architecture, scope, risk, or rollout.
8. Prefer multi-pass milestones that can land as small PRs instead of one large implementation.

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
