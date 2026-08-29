import 'package:flutter/widgets.dart';

/// A device definition expressed in logical pixels.
///
/// Flutter lays widgets out in [logicalSize]. The test view is configured with
/// [physicalSize] and [devicePixelRatio], so MediaQuery observes the same
/// logical geometry and density as the target device.
@immutable
class GoldenDevice {
  const GoldenDevice({
    required this.name,
    required this.logicalSize,
    this.devicePixelRatio = 1,
    this.platform = TargetPlatform.android,
    this.safeArea = EdgeInsets.zero,
    this.brightness = Brightness.light,
    this.highContrast = false,
    this.textScale = 1,
  })  : assert(devicePixelRatio > 0),
        assert(textScale > 0);

  final String name;
  final Size logicalSize;
  final double devicePixelRatio;
  final TargetPlatform platform;
  final EdgeInsets safeArea;
  final Brightness brightness;
  final bool highContrast;

  /// Legacy per-device default. Prefer the independent `textScales` matrix
  /// axis for new tests.
  final double textScale;

  Size get physicalSize => Size(
        logicalSize.width * devicePixelRatio,
        logicalSize.height * devicePixelRatio,
      );

  @Deprecated('Use logicalSize or physicalSize explicitly.')
  Size get size => physicalSize;

  bool get isLandscape => logicalSize.width > logicalSize.height;

  GoldenDevice copyWith({
    String? name,
    Size? logicalSize,
    double? devicePixelRatio,
    TargetPlatform? platform,
    EdgeInsets? safeArea,
    Brightness? brightness,
    bool? highContrast,
    double? textScale,
  }) =>
      GoldenDevice(
        name: name ?? this.name,
        logicalSize: logicalSize ?? this.logicalSize,
        devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
        platform: platform ?? this.platform,
        safeArea: safeArea ?? this.safeArea,
        brightness: brightness ?? this.brightness,
        highContrast: highContrast ?? this.highContrast,
        textScale: textScale ?? this.textScale,
      );

  GoldenDevice landscape({String? name}) => copyWith(
        name: name ?? '${this.name}_Landscape',
        logicalSize: Size(logicalSize.height, logicalSize.width),
        safeArea: EdgeInsets.fromLTRB(
          safeArea.top,
          safeArea.left,
          safeArea.bottom,
          safeArea.right,
        ),
      );

  GoldenDevice toTheme({
    String? name,
    Brightness? brightness,
    bool? highContrast,
  }) =>
      copyWith(
        name: name,
        brightness: brightness,
        highContrast: highContrast,
      );

  static const iPhone5S = GoldenDevice(
    name: 'iPhone5S',
    logicalSize: Size(320, 568),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPhone5SLandscape = GoldenDevice(
    name: 'iPhone5S_Landscape',
    logicalSize: Size(568, 320),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPhone11 = GoldenDevice(
    name: 'iphone11',
    logicalSize: Size(414, 896),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(top: 44, bottom: 34),
  );
  static const iPhone11Landscape = GoldenDevice(
    name: 'iphone11_Landscape',
    logicalSize: Size(896, 414),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(left: 44, right: 34),
  );
  static const iPhone11Pro = GoldenDevice(
    name: 'iphone11Pro',
    logicalSize: Size(375, 812),
    devicePixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(top: 44, bottom: 34),
  );
  static const iPhone11ProLandscape = GoldenDevice(
    name: 'iphone11Pro_Landscape',
    logicalSize: Size(812, 375),
    devicePixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(left: 44, right: 34),
  );
  static const iPhone11ProMax = GoldenDevice(
    name: 'iphone11ProMax',
    logicalSize: Size(414, 896),
    devicePixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(top: 44, bottom: 34),
  );
  static const iPhone11ProMaxLandscape = GoldenDevice(
    name: 'iphone11ProMax_Landscape',
    logicalSize: Size(896, 414),
    devicePixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(left: 44, right: 34),
  );
  static const iPhone14 = GoldenDevice(
    name: 'iphone14',
    logicalSize: Size(390, 844),
    devicePixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(top: 47, bottom: 34),
  );
  static const iPhone14Plus = GoldenDevice(
    name: 'iphone14Plus',
    logicalSize: Size(428, 926),
    devicePixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(top: 47, bottom: 34),
  );
  static const iPhone15Pro = GoldenDevice(
    name: 'iphone15Pro',
    logicalSize: Size(393, 852),
    devicePixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(top: 59, bottom: 34),
  );
  static const iPhone15ProMax = GoldenDevice(
    name: 'iphone15ProMax',
    logicalSize: Size(430, 932),
    devicePixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeArea: EdgeInsets.only(top: 59, bottom: 34),
  );
  static const iPad = GoldenDevice(
    name: 'iPad',
    logicalSize: Size(768, 1024),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPadLandscape = GoldenDevice(
    name: 'iPadLandscape',
    logicalSize: Size(1024, 768),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPadPro129 = GoldenDevice(
    name: 'iPadPro12.9',
    logicalSize: Size(1024, 1366),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPadPro129Landscape = GoldenDevice(
    name: 'iPadPro12.9Landscape',
    logicalSize: Size(1366, 1024),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPadAirGen5 = GoldenDevice(
    name: 'iPad_Air_Gen5',
    logicalSize: Size(820, 1180),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPadAirGen5Landscape = GoldenDevice(
    name: 'iPad_Air_Gen5_Landscape',
    logicalSize: Size(1180, 820),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPad7102 = GoldenDevice(
    name: 'iPad_7_10.2',
    logicalSize: Size(810, 1080),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const iPad7102Landscape = GoldenDevice(
    name: 'iPad_7_10.2_Landscape',
    logicalSize: Size(1080, 810),
    devicePixelRatio: 2,
    platform: TargetPlatform.iOS,
  );
  static const tabletPortrait = GoldenDevice(
    name: 'tablet_portrait',
    logicalSize: Size(1024, 1366),
    devicePixelRatio: 2,
  );
  static const tabletLandscape = GoldenDevice(
    name: 'tablet_landscape',
    logicalSize: Size(1366, 1024),
    devicePixelRatio: 2,
  );
  static const fullHd = GoldenDevice(
    name: 'FullHd',
    logicalSize: Size(1920, 1080),
    platform: TargetPlatform.windows,
  );
  static const macOS = GoldenDevice(
    name: 'macOS',
    logicalSize: Size(1440, 900),
    devicePixelRatio: 2,
    platform: TargetPlatform.macOS,
  );
  static const uHD4k = GoldenDevice(
    name: 'UHD4k',
    logicalSize: Size(3840, 2160),
    platform: TargetPlatform.windows,
  );

  @override
  String toString() =>
      'GoldenDevice($name, ${logicalSize.width}x${logicalSize.height} @ ${devicePixelRatio}x, ${platform.name})';
}

@Deprecated('Use GoldenDevice. The alias will be removed in ff_golden 2.0.')
typedef Device = GoldenDevice;
