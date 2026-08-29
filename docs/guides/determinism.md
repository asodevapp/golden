---
title: Deterministic rendering
description: Stabilize fonts, time, data, animation, platform services, and capture timing before accepting Flutter golden baselines.
---

# Deterministic rendering

Golden comparison is useful only when the same product state renders the same
pixels. Stabilize the inputs before adding tolerance or accepting regenerated
images.

## Determinism checklist

- [ ] Application fonts are loaded from committed assets.
- [ ] Dates, clocks, IDs, ordering, and random values are fixed.
- [ ] Network, filesystem, platform channels, and persistent state are replaced.
- [ ] Images and icons come from local deterministic fixtures.
- [ ] Streams and timers are bounded and disposed.
- [ ] The selected locale, platform, direction, brightness, and contrast are explicit.
- [ ] Animations are frozen or advanced to an intentional checkpoint.
- [ ] The real application wrapper supplies deterministic DI and localization.
- [ ] The first run happens without `--update-goldens`.

## Fonts

Use `loadFfGoldenFonts()` in `test/flutter_test_config.dart`. Do not accept a
large baseline rewrite before verifying that the production font loaded. Font
fallback changes line breaks and glyph positions while leaving application
widget code untouched.

## Time and asynchronous work

Inject a fixed clock into application code and represent server responses with
local fixtures. Prefer Flutter test virtual time:

```dart
await context.tester.pump(const Duration(milliseconds: 300));
```

Use `context.pumpUntilFound` for a bounded condition. Avoid real sleeps,
uncontrolled retry loops, and background timers that survive the test.

## Animations and shadows

`freezeAnimations` defaults to `true` by placing the captured application below
a disabled `TickerMode`. If animation is the state under test, disable freezing
and advance a fixed duration before capture.

Material shadows are rendered as deterministic boxes by default. Enable real
shadows only when shadow rendering belongs to the visual contract:

```dart
configuration: const GoldenRunConfiguration(
  renderShadows: true,
  tolerance: GoldenTolerance(maxDiffRate: 0.0001),
),
```

Keep any tolerance smaller than the regression the suite must detect.

## Capture timing

Capture only after all user-visible state is ready. A common flaky sequence is:

1. a tap starts async work;
2. `pumpAndSettle()` returns because no animation remains;
3. an external future completes later;
4. the test captures either loading or loaded state depending on timing.

Replace the external future with a controlled fixture or wait for a specific
rendered condition. Do not solve this with a longer real delay.

## Platform consistency

Golden pixels can differ across Flutter versions, host operating systems, and
renderers. Keep the Flutter SDK locked in CI and choose one authoritative
baseline-generation environment. Other environments can still build and run
non-golden tests or publish the resulting report.

An SDK upgrade that intentionally changes rendering should be reviewed as a
separate baseline operation, not mixed with unrelated UI changes.

## When a screenshot changes unexpectedly

Compare, in order:

1. PNG dimensions and capture scale;
2. logical size, DPR, safe area, and platform;
3. loaded fonts and text scale;
4. locale, direction, brightness, contrast, and theme;
5. fixture data and ordering;
6. captured interaction moment;
7. changed-pixel count, bounding box, and Flutter failure images.

Only after the cause is understood should the suite configuration, application
code, tolerance, or baseline change.
