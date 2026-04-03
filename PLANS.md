# Execution Plans for Feral File Mobile

An execution plan in this repository is a living design-and-delivery document for a large feature, a major flow change, a significant refactor, or a vague request whose scope cannot be implemented safely without first turning it into a concrete spec.

The plan must be self-contained. Assume the next contributor only has the current working tree and the plan file. The plan must explain enough context, constraints, design choices, test expectations, and milestones for a new contributor to continue the work safely.

## When a plan is required

Use a plan only when at least one of these is true:

- The request is a big feature, a major behavior change, or an architectural refactor.
- The user request is vague, underspecified, or could be satisfied by multiple materially different designs.
- The work touches multiple layers or flows and needs a staged rollout.
- The work has non-obvious product, FF1, offline-first, or indexing implications.

Do not require a plan for small, well-scoped fixes, simple copy changes, isolated test updates, or narrow refactors with obvious constraints.

If a request starts vague but can be clarified quickly, stop and clarify first. Only create a plan if the work still qualifies as large or ambiguous after clarification.

## Repository-first planning inputs

Before writing or updating any plan for a major feature, flow change, or architectural refactor, read these sources in this order:

1. `docs/project_spec.md`
2. `docs/app_flows.md`
3. `.cursor/rules/01-master-design.mdc`
4. `.cursor/rules/35-testing-tdd.mdc`

When relevant, also read the supporting repository rules that apply to the changed area, especially:

- `.cursor/rules/20-mobile-vocabulary.mdc`
- `.cursor/rules/30-riverpod.md`
- `AGENTS.md`

Every plan must summarize the current relevant flow, the affected screens or services, and the constraints or invariants taken from these files before proposing changes.

## Non-negotiable repository constraints

Every plan must preserve and explicitly restate the constraints below when they matter to the feature:

- Prefer replacing or deleting flawed code paths over local band-aids.
- Do not preserve legacy compatibility paths unless the user explicitly asks for them.
- Prefer stateless, testable services and helpers by default.
- Prefer deleting or refactoring complex code over adding more code to an already complex source file or flow.
- Prefer simple, atomic, idempotent, stateless flows over complex, high-cyclomatic designs.

If a candidate design conflicts with `.cursor/rules/01-master-design.mdc`, reject it in the plan and explain why.

## Ambiguity and missing context

This repository does not allow silent assumption-making for unclear product or system constraints.

If requirements are unclear, conflicting, or underspecified, stop and ask the user targeted questions before finalizing the plan or starting implementation.

If `docs/project_spec.md`, `docs/app_flows.md`, or other local docs appear incomplete, stale, contradictory, or too low-level for the requested change, do not guess. Ask the user for higher-level context such as:

- an internal company document
- a higher-level project or product spec
- Figma designs
- API or server reference docs
- acceptance criteria from product or design

If something does not feel aligned with the master design in `/docs` or the current request would force a suspicious architectural compromise, call that out explicitly and ask for clarification. The correct behavior is to pause and resolve ambiguity, not to optimize for momentum by inventing constraints.

## Design exploration is mandatory for big or vague work

For large features and vague commands, do not jump to a single design immediately. Use a tree-of-thought style exploration inside the plan.

That means:

- Start by evaluating whether the problem can be solved by deletion, simplification, or refactoring before proposing additive designs.
- Branch into multiple plausible designs.
- State the key constraint each branch optimizes for.
- State the trade-offs, failure modes, and architectural consequences of each branch.
- Eliminate branches that violate repository rules or product invariants.
- Eliminate branches that add complexity to already-complex code when a simpler delete/refactor path exists.
- Present the surviving options to the user and ask them to choose when the choice affects behavior, scope, risk, or rollout.

Do not ask the user to choose between trivial implementation details. Ask for a choice only when branches lead to meaningfully different product, architecture, or delivery outcomes.

Before presenting options to the user, rank them with a strong bias toward:

- deletion before addition
- refactor before layering more code into a complex area
- atomic and idempotent behavior before stateful orchestration
- stateless services before mutable service objects
- lower cyclomatic complexity before cleverness or feature density

## Tests come first in every option

Every design option presented to the user must define tests before implementation details.

For each option, list:

- unit-level test cases for the smallest pure functions or services
- integration test cases for behavior that crosses module or boundary lines
- required fixtures, `.env` assumptions, and expected outputs where applicable
- acceptance behavior that proves the option works in the app

Do not propose UI-first implementation. Follow `.cursor/rules/35-testing-tdd.mdc`:

1. Write small, testable functions first.
2. Add unit tests.
3. Add integration tests for cross-boundary behavior.
4. Provision `.env` for integration tests when needed.
5. Implement app-flow wiring only after the tested units exist.

If an option cannot be explained with concrete test cases up front, it is not ready to present.

## Favor staged delivery and small PRs

Plans for big work should prefer a multi-pass roadmap rather than a single large implementation blast.

Break the work into independently reviewable milestones that can land as small PRs when possible. Each milestone should leave the app in a coherent, testable state and avoid half-migrated architecture.

Good milestones usually look like:

- specification and flow alignment
- pure domain or service primitives plus unit tests
- boundary-crossing integration coverage
- provider or orchestration wiring
- UI composition and route integration
- cleanup, verification, and review loop

If a large feature can be split into additive slices, say so explicitly in the plan and recommend the smaller rollout path.

## Living document requirements

Every execution plan must be a living document and must contain these sections:

- `Purpose / Big Picture`
- `Current Context`
- `Constraints and Invariants`
- `Open Questions`
- `Design Branches`
- `Chosen Direction`
- `Test Plan`
- `Milestones`
- `Progress`
- `Surprises & Discoveries`
- `Decision Log`
- `Validation and Acceptance`
- `Risks and Recovery`
- `Outcomes & Retrospective`

Keep these sections current as work progresses. If the design changes, update the plan immediately and record the reason in `Decision Log`.

## Required plan authoring flow

When creating a plan, use this sequence:

1. Summarize the user request in repository terms.
2. Summarize the current relevant flow from `docs/project_spec.md` and `docs/app_flows.md`.
3. Restate the applicable architecture and testing constraints from the repository rules.
4. Write the open questions that block safe implementation.
5. Explore multiple design branches for big or vague work.
6. First evaluate whether deletion or refactoring can solve the problem more cleanly than adding code.
7. For each branch, define test cases first.
8. Compare branches with trade-offs, explicitly calling out simplicity, idempotence, statelessness, and complexity costs, and identify what must be decided by the user.
9. Ask the user to choose when the surviving branches differ materially.
10. After the user chooses, expand the chosen direction into milestones and concrete steps.
11. Implement milestone by milestone, keeping the plan updated as a living document.

## Required plan implementation flow

Once the user has answered open questions and chosen a direction, implementation should follow this order unless the plan explicitly justifies a safer variant:

1. Add or adjust small pure functions and services.
2. Add unit tests.
3. Add integration tests with concrete expected outputs.
4. Run tests and fix failures.
5. Wire providers and orchestration.
6. Compose UI and route-level behavior.
7. Run `scripts/agent-helpers/post-implementation-checks.sh HEAD`.
8. Run the relevant `flutter` validation, including `flutter build`.
9. Run the review loop described in `AGENTS.md` and `prompts/code-review.md`.

Do not skip directly from plan to UI wiring for behavior changes.

## Writing style for plans

Plans should be explicit, concrete, and written for a new contributor who knows nothing about this repository.

- Define repository-specific terms the first time they appear.
- Name files by repository path.
- Explain why a change is needed, not only what to edit.
- Prefer prose over giant bullet dumps, except where structure is required.
- Use checkboxes only in the `Progress` section.
- Keep examples short and focused on proof.

## Plan template

Use the following skeleton when authoring a repository execution plan.

```md
# <Short action-oriented title>

This plan is a living document and must be maintained in accordance with `PLANS.md`.

## Purpose / Big Picture

Explain what the user gains after this change and how to observe it working.

## Current Context

Summarize the relevant current behavior from `docs/project_spec.md`, `docs/app_flows.md`, and the affected code paths. Name the relevant files and screens.

## Constraints and Invariants

List the repository rules, flow invariants, and architecture boundaries that must remain true.
Also state where deletion, simplification, or refactoring should be preferred over additive implementation.

## Open Questions

List the missing requirements, contradictions, or external references still needed. If any question is unresolved, stop and ask the user before implementation.

## Design Branches

### Branch A - <name>

Explain the design goal.
State whether this branch primarily deletes, refactors, or adds code.

Test cases first:
- Unit:
- Integration:
- Acceptance:

Trade-offs:

Constraints:

Risks:

Complexity assessment:

### Branch B - <name>

Explain the design goal.
State whether this branch primarily deletes, refactors, or adds code.

Test cases first:
- Unit:
- Integration:
- Acceptance:

Trade-offs:

Constraints:

Risks:

Complexity assessment:

## Chosen Direction

Record the selected branch and why it was chosen. If user confirmation is required, say that implementation is blocked pending the user decision.

## Test Plan

State the exact tests to add first, where they will live, any `.env` requirements, and the expected outputs before wiring UI flows.

## Milestones

Describe a multi-pass roadmap. Prefer milestones that can land as small PRs:

1. Spec alignment and narrow interfaces.
2. Pure logic and unit tests.
3. Integration tests and fixtures.
4. Provider or orchestration wiring.
5. UI composition.
6. Verification, cleanup, and review loop.

## Progress

- [ ] Example pending step.
- [ ] Example pending step.

## Surprises & Discoveries

- Observation:
  Evidence:

## Decision Log

- Decision:
  Rationale:
  Date/Author:

## Validation and Acceptance

State the commands to run, what success looks like, and the exact user-visible behavior to verify.

## Risks and Recovery

Describe safe retry, rollback, or scope-reduction paths for risky stages.

## Outcomes & Retrospective

Summarize what shipped, what remains, and lessons learned.
```

## Quality bar

A plan is ready only when all of the following are true:

- It is being used for the right class of task: big feature, major refactor, or vague command.
- It summarizes the current flow and constraints from the repository docs.
- It surfaces ambiguities instead of guessing.
- It presents multiple design branches when the solution is not obvious.
- It defines tests before implementation details in every branch shown to the user.
- It shows that delete/refactor options were considered before additive options in complex areas.
- It favors simple, atomic, idempotent, stateless flows over complex high-cyclomatic ones when presenting options.
- It recommends a staged roadmap with reviewable milestones and preferably small PRs.
- It preserves `.cursor/rules/01-master-design.mdc` and `.cursor/rules/35-testing-tdd.mdc`.

If any item above is missing, the plan is incomplete and should not be used to drive implementation.
