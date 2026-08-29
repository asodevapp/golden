---
title: Stateful and multi-shot tests
description: Drive deterministic Flutter interactions, wait with bounded virtual time, capture named checkpoints, and reuse typed state tables across shared golden coverage.
---

# Stateful and multi-shot tests

A useful golden usually captures a product state, not merely the first frame of
a widget. FF Golden keeps interaction and capture inside the same isolated
variant test.

## Interact before the automatic capture

```dart
testFfGoldens(
  'invalid email validation',
  scenario: 'authentication/invalid-email',
  build: (_) => const SignInPage(),
  interact: (context) async {
    await context.tester.enterText(
      find.byKey(const Key('email')),
      'not-an-email',
    );
    await context.tester.tap(find.text('Continue'));
  },
);
```

After `interact`, the default pump settles the widget and FF Golden captures the
result. Supply a custom `pump` only when the screen has a known settling
contract that `pumpAndSettle()` cannot express.

## Wait with bounded virtual time

```dart
await context.pumpUntilFound(
  find.text('Payment complete'),
  timeout: const Duration(seconds: 2),
);
```

`pumpUntilFound` advances Flutter test time in bounded steps. A timeout includes
the active variant in its diagnostic instead of leaving a real timer or
unbounded settle operation pending.

For a BLoC, notifier, or repository state that has no unique widget yet, wait
for a descriptive predicate:

```dart
await context.pumpUntil(
  () => bloc.state.hasData && !bloc.state.isLoading,
  description: 'profile bloc to finish loading',
);
```

Use `pumpUntilGone` for a loading surface, `pumpFrames` only for an intentional
frame-count contract, and `elapse` for a fixed timer or animation checkpoint.

## Capture multiple checkpoints

Disable the automatic capture when a workflow needs several named moments:

```dart
testFfGoldens(
  'checkout flow',
  scenario: 'checkout',
  build: (_) => const CheckoutPage(),
  configuration: const GoldenRunConfiguration(autoCapture: false),
  interact: (context) async {
    await context.capture(testName: 'empty');

    await context.tester.tap(find.text('Add item'));
    await context.tester.pumpAndSettle();
    await context.capture(testName: 'with-item');

    await context.tester.tap(find.text('Checkout'));
    await context.tester.pumpAndSettle();
    await context.capture(testName: 'confirmation');
  },
);
```

Each capture becomes a separate baseline and a named entry in the schema-v2
run manifest. Presenter uses manifest data to distinguish a capture name from
dots that legitimately belong to a device name.

## Reuse a typed state table

For loading, loaded, empty, and error states that share one coverage definition:

```dart
enum ProfileState { loading, loaded, empty, error }

testFfGoldenScenarios<ProfileState>(
  'profile states',
  scenarios: const [
    GoldenScenario(name: 'profile/loading', state: ProfileState.loading),
    GoldenScenario(name: 'profile/loaded', state: ProfileState.loaded),
    GoldenScenario(name: 'profile/empty', state: ProfileState.empty),
    GoldenScenario(name: 'profile/error', state: ProfileState.error),
  ],
  coverage: profileCoverage,
  build: (variant, state) => ProfilePage(initialState: state),
);
```

The state type remains compile-time checked. Scenario names must stay stable
because they are part of the baseline path and report identity.

## Setup and teardown

`before` and `after` run inside each generated variant case. Prefer immutable
fixtures passed through `build` or the application wrapper; use hooks for
resources that genuinely need per-case lifecycle.

Typed scenarios also provide `prepare` and `dispose`. They receive the active
`GoldenTestContext` and typed state, so each case can install and restore its
own fake repository or DI override without a shared mutable mode flag.

The execution order is:

1. apply the variant test view;
2. run `before`, then the scenario fixture `prepare`;
3. build and pump the wrapped widget;
4. run `interact` and the configured pump;
5. capture automatically, unless disabled;
6. run the scenario fixture `dispose`, then `after`;
7. restore Flutter view and shadow settings.

Failures record the active phase in the run manifest for presenter and CI.
