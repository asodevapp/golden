import 'dart:async';

import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testFfGoldens(
    'counter after one tap',
    scenario: 'counter/incremented',
    coverage: GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
      locales: const [Locale('en'), Locale('ar')],
      themes: [GoldenTheme.light, GoldenTheme.dark],
      textScales: const [1, 1.5],
      sampling: GoldenSampling.pairwise,
      maxCombinations: 12,
    ),
    build: (_) => const _CounterCard(),
    interact: (context) => context.tester.tap(find.byIcon(Icons.add)),
  );

  final loadedFixture = _ProfileFixture();
  final errorFixture = _ProfileFixture();
  testFfGoldenScenarios<_ProfileFixture>(
    'profile states',
    scenarios: <GoldenScenario<_ProfileFixture>>[
      GoldenScenario<_ProfileFixture>(
        name: 'profile/loading',
        state: _ProfileFixture(),
        prepare: (_, fixture) => fixture.prepare(),
        dispose: (_, fixture) => fixture.dispose(),
      ),
      GoldenScenario<_ProfileFixture>(
        name: 'profile/loaded',
        state: loadedFixture,
        prepare: (_, fixture) => fixture.prepare(),
        interact: (context, fixture) async {
          fixture.complete(
            const _Profile(name: 'Ada', plan: 'Pro'),
          );
          await context.pumpUntilFound(
            find.byKey(const Key('profile-loaded')),
          );
        },
        dispose: (_, fixture) => fixture.dispose(),
      ),
      GoldenScenario<_ProfileFixture>(
        name: 'profile/error',
        state: errorFixture,
        prepare: (_, fixture) => fixture.prepare(),
        interact: (context, fixture) async {
          fixture.completeError(StateError('fixture failure'));
          await context.pumpUntilFound(
            find.byKey(const Key('profile-error')),
          );
        },
        dispose: (_, fixture) => fixture.dispose(),
      ),
    ],
    build: (_, fixture) => _ProfileCard(repository: fixture.repository),
  );
}

class _CounterCard extends StatefulWidget {
  const _CounterCard();

  @override
  State<_CounterCard> createState() => _CounterCardState();
}

class _CounterCardState extends State<_CounterCard> {
  var count = 0;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Count: $count'),
              IconButton(
                onPressed: () => setState(() => count++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      );
}

class _ProfileFixture {
  late Completer<_Profile> _response;
  late _FakeProfileRepository repository;

  void prepare() {
    _response = Completer<_Profile>();
    repository = _FakeProfileRepository(_response.future);
  }

  void complete(_Profile profile) => _response.complete(profile);

  void completeError(Object error) => _response.completeError(error);

  void dispose() {
    if (!_response.isCompleted) {
      _response.complete(const _Profile(name: 'Disposed', plan: 'Fixture'));
    }
  }
}

class _FakeProfileRepository {
  const _FakeProfileRepository(this.response);

  final Future<_Profile> response;

  Future<_Profile> load() => response;
}

class _Profile {
  const _Profile({required this.name, required this.plan});

  final String name;
  final String plan;
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.repository});

  final _FakeProfileRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<_Profile>(
        future: repository.load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Could not load profile',
                key: Key('profile-error'));
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const CircularProgressIndicator(key: Key('profile-loading'));
          }
          return Text(
            '${profile.name} · ${profile.plan}',
            key: const Key('profile-loaded'),
          );
        },
      );
}
