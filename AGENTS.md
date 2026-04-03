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
6. Run `scripts/agent-helpers/post-implementation-checks.sh HEAD` and fix all reported issues.

## Rule references (authoritative detail)

- `.cursor/rules/01-master-design.mdc`
- `.cursor/rules/20-mobile-vocabulary.mdc`
- `.cursor/rules/30-riverpod.md`
- `.cursor/rules/35-testing-tdd.mdc`
- `.cursor/rules/50-indexing-address-flow.mdc`

## Definition of done

A task is complete only when:

1. `scripts/agent-helpers/post-implementation-checks.sh HEAD` completes cleanly and every issue it reports has been fixed. Treat this script as a release gate, not a best-effort signal.
2. The review pool, sized to match the implementation complexity of the full diff against `main`, concludes with **Verdict: accept** after all valid findings have been addressed. Reviewer count should be based on the actual implementation complexity only, not inflated by test-only, doc-only, workflow-only, or dependency-only changes.

## Review workflow (implement → review loop → commit/push/PR)

After implementation, run a **review loop** until the reviewers qualify the change. Only after the review pool says **Verdict: accept** is the change available for you to commit, push, or create a PR.

1. **Create a compact handoff** — Include the master purpose of the work, the recent change being reviewed, files changed, key decisions and tradeoffs.

2. **Generate the review diff from `main`** — Always generate the diff by comparing the current change against the `main` branch so reviewers see the full branch delta, not only the most recent commit or latest local change after many commits.

3. **Invoke the reviewer sub-agents** — Spawn 2-3 fresh-context reviewers in parallel based on the implementation complexity of the full diff against `main`. Do not increase reviewer count because of test-only, doc-only, workflow-only, or dependency-only changes. Give each reviewer the handoff, the diff against `main`, and any test/lint output. Every reviewer follows `prompts/code-review.md` and ends with **Verdict: accept** or **Verdict: revise**. Close each reviewer sub-agent after it finishes its review.

4. **If any reviewer says Verdict: revise** — The main agent must collect all reports from all reviewer sub-agents, merge the findings into one action list, fix every valid issue raised across the full review pool, re-run tests and post-implementation checks, update the handoff, and send the updated branch diff against `main` to a newly spawned set of reviewer sub-agents for another round. Do not reuse prior reviewer sessions.

Do not commit, push, or create a PR (if requested) before the reviewers have accepted. The master agent owns collecting all reviewer feedback, resolving the combined findings, and repeating the loop until the change is qualified.

## Commit message format

Use Conventional Commits:

- `<type>(<optional-scope>): <description>`
- Types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `build`, `ci`, `perf`, `style`
- Use `!` for breaking changes.

## Review guidelines

The single source of truth for review priority, posture, hindsight, tests/docs, and output format is **`prompts/code-review.md`**. All reviewers (human or agent) should follow it. AGENTS.md does not duplicate that content; see the prompt file for the full contract.
