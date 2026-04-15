### Review priority
1. Principle compliance with `.cursor/rules/01-master-design.mdc`
2. Master-flow integrity against `docs/project_spec.md` and `docs/app_flows.md`
3. Flutter performance best practices per https://docs.flutter.dev/perf/best-practices and Riverpod correctness and best practices per https://riverpod.dev/docs/root/do_dont

### Required expanded review posture
- Do not review only for local correctness of the submitted diff.
- Read the PR description first, infer the real product/flow goal, then review whether the chosen implementation is the right solution for that goal.
- Because this app does not require backward-compatibility or migration-safe edits by default, do not bias toward minimal-change solutions during review.
- Consider stronger alternatives, including larger refactors, responsibility re-allocation, API reshaping, deleting obsolete abstractions, or breaking changes, but only mention them when they are obviously better and materially improve the outcome.
- Do not speculate or brainstorm in review comments. If an alternative is not clearly superior, skip it.
- When reviewing a fix to reviewer feedback, separate in-scope defects from scope-expanding asks. If a comment would broaden the PR beyond the branch purpose or the product/spec context, call that out explicitly instead of asking the author to implement it.

### Hindsight and refactor review
After reading the PR description and implementation, step back and consider the underlying product or architectural goal, referencing the project spec and app flows for broader context. Suggest a clearer or structurally better alternative only if the review reveals a concrete architectural issue or an obviously improved approach. Provide hindsight or refactor feedback only when actionable—omit this section entirely if no clear, valuable insight exists.

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

### Verdict
End your review with a single line: **Verdict: accept** or **Verdict: revise**. Use **accept** only when there are no critical or architecture/flow issues and no blocking test or documentation gaps. Use **revise** when the author should address one or more findings before the change is qualified.
