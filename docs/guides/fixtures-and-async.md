---
title: Fixtures and asynchronous state
description: Build deterministic fake repositories, install typed per-scenario fixtures, and wait for observable UI or state with bounded Flutter virtual time.
---

# Fixtures and asynchronous state

Golden tests should control when data arrives and capture a named product state.
They should not depend on network timing or an arbitrary number of pumped
frames.

## Keep fakes local and typed

FF Golden does not depend on Mockito, Mocktail, GetIt, or a state-management
library. Implement the smallest fake for the application boundary and keep its
data immutable:

```dart
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this.response);

  final Future<Profile> response;

  @override
  Future<Profile> load() => response;
}
```

Use a `Completer` when the test must choose the exact frame at which a response
arrives. This models a controlled server response without real time or I/O.

## Install a fixture per scenario

`GoldenScenario<T>.prepare` runs before the widget is built for every selected
variant. `dispose` always runs after capture or failure. This is the right place
to install and release DI overrides:

```dart
final fixture = ProfileFixture();

testFfGoldenScenarios<ProfileFixture>(
  'profile states',
  scenarios: [
    GoldenScenario(
      name: 'profile/loaded',
      state: fixture,
      prepare: (_, fixture) => fixture.install(),
      interact: (context, fixture) async {
        fixture.complete(const Profile(name: 'Ada'));
        await context.pumpUntilFound(
          find.byKey(const Key('profile-loaded')),
        );
      },
      dispose: (_, fixture) => fixture.uninstall(),
    ),
  ],
  build: (_, fixture) => ProfilePage(repository: fixture.repository),
);
```

Avoid mutable global mode flags shared by multiple scenarios. If an application
DI container requires global registration, save the previous registration in
`prepare` and restore it in `dispose`.

## Wait for an observable condition

Use the helpers on `GoldenTestContext`:

```dart
await context.pumpUntil(
  () => bloc.state.hasData && !bloc.state.isLoading,
  description: 'profile bloc to finish loading',
);

await context.pumpUntilFound(find.text('Payment complete'));
await context.pumpUntilGone(find.byType(CircularProgressIndicator));
```

Each wait advances Flutter virtual time in bounded steps. A timeout reports the
condition, scenario, and active variant. Use `pumpFrames` only when a fixed
number of rendered frames is itself the contract, and use `elapse` for a known
timer or animation checkpoint:

```dart
await context.pumpFrames(3);
await context.elapse(const Duration(milliseconds: 300));
```

The same helpers are available from `GoldenTesterBase` in legacy
`testDeviceGoldens` suites, so adopting deterministic waits does not rename or
regenerate existing baselines.

## Do not nest fake async zones

`testWidgets` already executes in Flutter's fake asynchronous environment.
Creating another `FakeAsync`, starting an unawaited future, or calling a real
sleep can hide exceptions and leave work pending after assertions pass.

Advance virtual time with FF Golden's pump helpers. Use
`WidgetTester.runAsync` only for unavoidable real filesystem or network I/O,
and replace that I/O with a local fixture whenever possible.

The repository's
[complete example](https://github.com/asodevapp/golden/blob/master/packages/ff_golden/example/example.dart)
contains loading, loaded, and error captures driven by a controlled fake
repository.
