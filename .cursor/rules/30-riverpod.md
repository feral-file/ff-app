---
description: Riverpod coding practices for ff-app (scoped to files that currently use Riverpod).
globs:
  # Riverpod flow-driver layer and its consumers (exclude lib/domain/**).
  - "lib/app/**/*.dart"
  - "lib/infra/**/*.dart"
  - "lib/ui/**/*.dart"
  - "lib/widgets/**/*.dart"
  - "lib/main.dart"
  - "test/app/**/*.dart"
alwaysApply: true
---

# Riverpod coding practices (ff-app)

These rules apply only to the files listed in `globs` above.

## Architecture first

- Do not call transports/adapters directly from UI; route through `app/providers` and injected services.
- Keep DP-1 nouns locked to `Channel` / `Playlist` / `Work` in domain models and storage naming.
- Riverpod is the only shared flow driver for new app flow logic; do not introduce BLoC/get_it/singleton flow paths.

## `watch` / `read` / `listen` rules

- Use `ref.watch(...)` to declare reactive dependencies and derive state.
- Use `ref.read(...)` only for imperative actions (e.g., button tap → `ref.read(x.notifier).doThing()`).
- Use `ref.listen(...)` only for side-effects in reaction to state changes (navigation/snackbars/logging/analytics).
- Do not use `listen` to derive state; that belongs in a provider/notifier with `watch`.

## Provider design

- Prefer immutable state objects with explicit transitions (reducers / Notifier methods).
- Keep providers small and composable; avoid “god providers”.
- Prefer `NotifierProvider` / `AsyncNotifierProvider` patterns for new state (match existing `app/providers` style).
- Use `family` for parameterized state; do not encode parameters into global mutable variables.
- Use `select`/`selectAsync` when only a slice should trigger rebuilds.
- Represent async state explicitly (prefer `AsyncValue` patterns where applicable); keep error/loading states testable.
- Do not push ephemeral widget-local state (controllers/focus/transient form text) into providers unless shared or business-critical.

## Side-effects and IO

- Keep network/database/device IO behind providers (repositories/services) and call them from Notifier/AsyncNotifier methods.
- Keep widgets declarative: avoid doing IO in `build`, and avoid kicking off “one-shot” side-effects from build.
- When reacting to state changes in UI, use `ref.listen` (or `ref.listenManual`) and keep handlers idempotent.
- Use `ref.onDispose(...)` for cleanup (streams/subscriptions/timers) in providers; do not leak resources.

## Refreshing and invalidation

- Use `ref.invalidate(provider)` (or notifier refresh methods) for explicit refresh flows; avoid reaching into caches from UI.
- Prefer invalidation/refresh to “recreating containers” or adding hidden global flags.

## Testing rules for providers

- Use a fresh `ProviderContainer.test()` per test.
- Override dependencies via provider overrides (repositories, transports/adapters, clocks, randomness).
- For auto-dispose providers, keep them alive during assertions using `container.listen(...)`.
- Assert state transitions/outputs (and interactions with fakes), not internal implementation details.

## Provider testing patterns

Reference: https://riverpod.dev/docs/how_to/testing

### Default expectation: provider-backed code is testable

- Avoid hidden singleton state. Dependencies must be injectable via providers/constructors.
- Prefer pure logic in `domain/` and test it without Flutter.
- Put side effects behind repositories/services and inject them via providers so tests can override them.

### Minimal provider unit test pattern

```dart
test('provider returns expected value', () {
  final container = ProviderContainer.test(
    overrides: [
      // someDependencyProvider.overrideWithValue(fakeDependency),
    ],
  );
  addTearDown(container.dispose);

  expect(container.read(someProvider), equals('expected'));
});
```

### Widget tests that use providers

- Wrap widgets with `ProviderScope` in `pumpWidget`.
- Use `tester.container()` if you need to read/listen to providers from the test.

```dart
testWidgets('widget reacts to provider state', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // someDependencyProvider.overrideWithValue(fakeDependency),
      ],
      child: const MyWidget(),
    ),
  );

  final container = tester.container();
  expect(container.read(someProvider), isNotNull);
});
```

### Mocking guidance

- Prefer fakes/stubs via provider overrides over mocking Notifiers.
- If you must isolate complex behavior, introduce an abstraction (e.g., repository) and fake/mock that.

### Definition of done for provider changes

- Add/update unit tests for the notifier/provider behavior.
- Follow `.cursor/rules/35-testing-tdd.mdc` sequence before shipping provider-backed feature flow.
- Ensure `flutter test` passes.
- Ensure `flutter analyze` passes (`very_good_analysis`).
