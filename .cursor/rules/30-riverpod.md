---
description: Riverpod provider design and usage rules for ff-app
globs:
  - "lib/app/**/*.dart"
  - "lib/ui/**/*.dart"
  - "lib/widgets/**/*.dart"
  - "lib/main.dart"
  - "test/**/*.dart"
alwaysApply: true
---

# Riverpod Rule

This rule governs provider usage and state-flow mechanics only.

## 1) Provider usage
- Use `ref.watch` for reactive state dependencies.
- Use `ref.read` for imperative actions.
- Use `ref.listen` for side effects (navigation, toasts, logging), not for state derivation.

## 2) Provider design
- Prefer `NotifierProvider` / `AsyncNotifierProvider` for new shared state.
- Keep providers small and composable.
- Use `family` for parameterized state.
- Use `select`/`selectAsync` for narrow rebuilds.
- Represent async state explicitly (`AsyncValue` patterns).

## 3) Side-effect discipline
- Execute IO through injected services from providers/notifiers.
- Avoid one-shot side effects in widget `build`.
- Clean up provider resources via `ref.onDispose`.

## 4) Testing requirements for provider changes
- Use `ProviderContainer.test()` with provider overrides.
- Use fresh containers per test.
- Keep auto-dispose providers alive during assertions via `container.listen` when needed.
- Validate state transitions and outputs, not internal implementation details.
