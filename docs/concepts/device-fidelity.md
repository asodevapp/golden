---
title: Device fidelity
description: Model Flutter layout geometry, device pixel ratio, safe areas, platform behavior, and capture resolution without conflating logical and physical pixels.
---

# Device fidelity

FF Golden separates layout geometry from raster density. This prevents a common
failure mode where a test produces a smaller PNG by changing the environment
that the widget actually observes.

## The three independent values

| Value | Controls | Observed by the app |
| --- | --- | --- |
| `logicalSize` | Flutter layout viewport | `MediaQuery.size` |
| `devicePixelRatio` | Logical-to-physical conversion and density behavior | `MediaQuery.devicePixelRatio` |
| `captureScale` | PNG raster resolution only | Not exposed as device geometry |

For a `390 × 844` logical device at `3×`, the native physical view and default
baseline are `1170 × 2532` pixels. Setting `captureScale: 1` reduces the PNG to
logical resolution, but the application still observes the original DPR.

!!! warning "Do not set DPR to 1 as a performance shortcut"
    DPR can influence asset selection, painting, pixel snapping, and application
    code. Reduce the coverage set with an explicit sampling policy or set
    `captureScale` only when raster fidelity is outside the test contract.

## Use a built-in device

```dart
coverage: GoldenCoverage(
  devices: const [
    GoldenDevice.iPhone11,
    GoldenDevice.iPhone15Pro,
    GoldenDevice.iPad,
    GoldenDevice.macOS,
  ],
),
```

Built-in presets contain logical size, DPR, target platform, and known safe
areas. Landscape variants are available for common presets, or can be derived
with `device.landscape()`.

## Define a custom device

```dart
const checkoutPhone = GoldenDevice(
  name: 'checkout_phone',
  logicalSize: Size(390, 844),
  devicePixelRatio: 3,
  platform: TargetPlatform.iOS,
  safeArea: EdgeInsets.only(top: 47, bottom: 34),
);
```

Keep all geometry in logical pixels. `physicalSize` is derived as
`logicalSize × devicePixelRatio`.

## Device defaults and coverage overrides

A device supplies defaults for platform, brightness, contrast, and text scale.
Independent coverage axes override them for a selected variant:

```dart
GoldenCoverage(
  devices: const [GoldenDevice.iPhone15Pro],
  platforms: const [TargetPlatform.iOS, TargetPlatform.android],
  brightnesses: const [Brightness.light, Brightness.dark],
  highContrasts: const [false, true],
  textScales: const [1, 1.5, 2],
)
```

Use a platform override only when the product intentionally supports that
combination. Otherwise prefer separate device definitions or a coverage rule.

## Capture at a different scale

```dart
configuration: const GoldenRunConfiguration(
  captureScale: 1,
),
```

The default `null` preserves native device DPR. An explicit lower scale is most
appropriate for layout-only catalogs where density-specific raster behavior is
not part of the visual contract. Record that decision near the suite.

## Migrating physical-pixel devices

The old `golden` package's custom `Device.size` represented physical pixels.
Convert custom definitions by dividing width and height by DPR:

```diff
- const Device(name: 'phone', size: Size(1170, 2532), devicePixelRatio: 3)
+ const GoldenDevice(
+   name: 'phone',
+   logicalSize: Size(390, 844),
+   devicePixelRatio: 3,
+   platform: TargetPlatform.iOS,
+ )
```

Do not divide the dimensions of built-in FF Golden presets. Their logical
geometry is already corrected.
