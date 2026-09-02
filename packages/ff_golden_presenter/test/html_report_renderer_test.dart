import 'package:ff_golden_presenter/ff_golden_presenter.dart';
import 'package:test/test.dart';

void main() {
  test('renders a semantic report with portable image paths and escaped text',
      () {
    final catalog = GoldenCatalog(
      scenarios: [
        GoldenScenario(
          pathSegments: const ['auth', 'sign_in'],
          images: const [
            GoldenImage(
              fileName: 'iphone_15[dark](en-US).png',
              path:
                  '/project/test/auth/golden/sign_in/iphone_15[dark](en-US).png',
              device: 'iphone_15',
              theme: 'dark',
              locale: 'en-US',
              captureName: 'empty',
              textScale: 1.5,
              direction: 'rtl',
              directionMode: 'rtl',
              platform: 'iOS',
              brightness: 'dark',
              highContrast: true,
              status: GoldenImageStatus.failed,
              durationMs: 12.5,
              failurePhase: 'capture',
              error: 'Mismatch <unsafe>',
              extension: 'png',
            ),
          ],
        ),
      ],
    );

    final result = HtmlReportRenderer(
      outputPath: '/project/report.html',
      title: 'App <goldens>',
    ).render(catalog);

    expect(result.html, startsWith('<!doctype html>'));
    expect(result.html, contains('<main class="report-shell">'));
    expect(result.html, contains('App &lt;goldens&gt;'));
    expect(
      result.html,
      contains(
        '<meta name="description" content="Browse 1 golden test image across 1 scenario in a searchable FF Golden Presenter report.">',
      ),
    );
    expect(
      result.html,
      contains('<meta property="og:type" content="website">'),
    );
    expect(
      result.html,
      contains(
        '<meta property="og:site_name" content="FF Golden Presenter">',
      ),
    );
    expect(
      result.html,
      contains(
        '<meta property="og:title" content="App &lt;goldens&gt;">',
      ),
    );
    expect(
      result.html,
      contains(
        '<meta property="og:description" content="Browse 1 golden test image across 1 scenario in a searchable FF Golden Presenter report.">',
      ),
    );
    expect(
      result.html,
      contains('<meta name="twitter:card" content="summary">'),
    );
    expect(
      result.html,
      contains(
        '<meta name="twitter:title" content="App &lt;goldens&gt;">',
      ),
    );
    expect(result.html, contains('auth / sign_in'));
    expect(result.html, contains('data-device="iphone_15"'));
    expect(result.html, contains('data-theme="dark"'));
    expect(result.html, contains('data-capture="empty"'));
    expect(result.html, contains('data-text-scale="1.5"'));
    expect(result.html, contains('data-direction="rtl"'));
    expect(result.html, contains('data-platform="iOS"'));
    expect(result.html, contains('data-brightness="dark"'));
    expect(result.html, contains('data-contrast="high"'));
    expect(result.html, contains('data-status="failed"'));
    expect(result.html, contains('id="status-filter"'));
    expect(result.html, contains('data-custom-select'));
    expect(result.html, contains('aria-haspopup="listbox"'));
    expect(result.html, contains('role="listbox"'));
    expect(result.html, contains('class="select-popover"'));
    expect(result.html, contains('function updateFilterOptions(query)'));
    expect(result.html, contains('cardMatches(card, query, key)'));
    expect(result.html, contains('.select-option[hidden] { display: none; }'));
    expect(result.html, contains('Failed during capture'));
    expect(result.html, contains('Mismatch &lt;unsafe&gt;'));
    expect(result.html, contains('test/auth/golden/sign_in/'));
    expect(result.html, contains('iphone_15%5Bdark%5D'));
    expect(result.html, isNot(contains('/project/test')));
    expect(result.html, contains('id="lightbox"'));
    expect(result.html, contains('id="search"'));
    expect(result.html, contains('id="theme-toggle"'));
    expect(result.html, contains('ff-golden-presenter-theme'));
    expect(result.html, contains('Made by the'));
    expect(result.html, contains('ASO.dev team'));
    expect(
      result.html,
      contains(
        'https://github.com/asodevapp/golden/tree/master/packages/ff_golden_presenter',
      ),
    );
    expect(
      result.html,
      contains(
        'href="https://aso.dev/?utm_source=ff_golden&amp;utm_medium=referral"',
      ),
    );
    expect(result.html, contains('rel="sponsored noopener"'));
    expect(result.html, contains('target="_blank"'));
    expect(RegExp(r'[ \t]+$', multiLine: true).hasMatch(result.html), isFalse);
  });

  test('can omit ASO.dev support attribution while retaining generator credit',
      () {
    final result = HtmlReportRenderer(
      outputPath: '/project/report.html',
      showSupportAttribution: false,
    ).render(GoldenCatalog(scenarios: const []));

    expect(result.html, isNot(contains('aso.dev')));
    expect(result.html, isNot(contains('Made by the')));
    expect(result.html, contains('Generated by'));
    expect(result.html, contains('FF Golden Presenter'));
  });

  test('builds every dropdown exclusively from rendered image metadata', () {
    final catalog = GoldenCatalog(
      scenarios: [
        GoldenScenario(
          pathSegments: const ['filters'],
          images: const [
            GoldenImage(
              fileName: 'iphone.png',
              path: '/project/iphone.png',
              device: 'iphone_15',
              extension: 'png',
              captureName: 'empty',
              theme: 'dark',
              locale: 'en-US',
              textScale: 1.5,
              direction: 'rtl',
              platform: 'iOS',
              brightness: 'dark',
              highContrast: true,
              status: GoldenImageStatus.failed,
            ),
            GoldenImage(
              fileName: 'pixel.png',
              path: '/project/pixel.png',
              device: 'pixel_8',
              extension: 'png',
              captureName: 'loaded',
              theme: 'light',
              locale: 'de-DE',
              textScale: 1,
              direction: 'ltr',
              platform: 'Android',
              brightness: 'light',
              highContrast: false,
              status: GoldenImageStatus.passed,
            ),
          ],
        ),
      ],
    );

    final html = HtmlReportRenderer(
      outputPath: '/project/report.html',
    ).render(catalog).html;
    const expectedValues = <String, Set<String>>{
      'capture': {'empty', 'loaded'},
      'device': {'iphone_15', 'pixel_8'},
      'theme': {'dark', 'light'},
      'locale': {'de-DE', 'en-US'},
      'textScale': {'1', '1.5'},
      'direction': {'ltr', 'rtl'},
      'platform': {'Android', 'iOS'},
      'brightness': {'dark', 'light'},
      'contrast': {'high', 'normal'},
      'status': {'failed', 'passed'},
    };

    for (final MapEntry(key: id, value: expected) in expectedValues.entries) {
      expect(
        html,
        contains("['$id', document.getElementById('$id-filter')]"),
        reason: '$id dropdown must participate in runtime filtering',
      );
      expect(
        _nonEmptyOptionValues(html, id),
        unorderedEquals(expected),
        reason: '$id options must come from rendered cards',
      );
      expect(
        _nonEmptyDataValues(html, _dataAttributeName(id)),
        unorderedEquals(expected),
        reason: '$id card metadata must match its options',
      );
    }
  });

  test('omits dropdowns for axes absent from every image', () {
    final result = HtmlReportRenderer(
      outputPath: '/project/report.html',
    ).render(
      GoldenCatalog(
        scenarios: [
          GoldenScenario(
            pathSegments: const ['plain'],
            images: [_image('plain')],
          ),
        ],
      ),
    );

    expect(result.html, contains('id="device-filter"'));
    for (final id in const [
      'capture',
      'theme',
      'locale',
      'textScale',
      'direction',
      'platform',
      'brightness',
      'contrast',
      'status',
    ]) {
      expect(result.html, isNot(contains('id="$id-filter"')));
    }
  });

  test('renders project branding and safe header navigation', () {
    final result = HtmlReportRenderer(
      outputPath: '/project/report.html',
      customization: GoldenReportCustomization(
        primaryColor: '0xFF18BFFB',
        faviconHref: 'data:image/png;base64,AQID',
        headerLinks: [
          GoldenReportLink(
            label: 'Home & project',
            url: 'https://aso.dev/?from=golden&view=report',
          ),
          GoldenReportLink(label: 'Blog', url: '/blog/'),
        ],
      ),
    ).render(GoldenCatalog(scenarios: const []));

    expect(
      result.html,
      contains('<link rel="icon" href="data:image/png;base64,AQID">'),
    );
    expect(result.html, contains('--accent: #18BFFB;'));
    expect(result.html, contains('aria-label="Project links"'));
    expect(result.html, contains('Home &amp; project'));
    expect(
      result.html,
      contains(
        'href="https://aso.dev/?from=golden&amp;view=report" target="_blank" rel="noopener"',
      ),
    );
    expect(
      result.html,
      contains('<a class="header-link" href="/blog/">Blog</a>'),
    );
    expect(
      result.html,
      contains('hero__topline hero__topline--with-links'),
    );
  });

  test('rejects unsafe report customization values', () {
    expect(
      () => GoldenReportCustomization(primaryColor: 'blue'),
      throwsFormatException,
    );
    expect(
      () => GoldenReportLink(label: 'Unsafe', url: 'javascript:alert(1)'),
      throwsFormatException,
    );
    expect(
      () => GoldenReportLink(label: 'Protocol relative', url: '//example.com'),
      throwsFormatException,
    );
  });

  test('renders a useful empty report', () {
    final result = HtmlReportRenderer(
      outputPath: '/project/report.html',
    ).render(GoldenCatalog(scenarios: const []));

    expect(result.html, contains('No images were found'));
    expect(result.html, contains('<dd>0</dd>'));
  });

  test('groups scenarios by their first path segment', () {
    final catalog = GoldenCatalog(
      scenarios: [
        GoldenScenario(
          pathSegments: const ['app_info', 'init'],
          images: [_image('init')],
        ),
        GoldenScenario(
          pathSegments: const ['app_info', 'loaded'],
          images: [_image('loaded')],
        ),
        GoldenScenario(
          pathSegments: const ['settings', 'language', 'loaded'],
          images: [_image('language')],
        ),
        GoldenScenario(
          pathSegments: const ['Root'],
          images: [_image('root')],
        ),
      ],
    );

    final result = HtmlReportRenderer(
      outputPath: '/project/report.html',
    ).render(catalog);

    expect(
      result.html,
      contains('data-scenario-nav-group="scenario-group-0"'),
    );
    expect(
      result.html,
      contains('<h2 id="scenario-group-0-title">app_info</h2>'),
    );
    expect(result.html, contains('<h3>init</h3>'));
    expect(result.html, contains('<h3>loaded</h3>'));
    expect(result.html, contains('<h3>language &#47; loaded</h3>'));
    expect(result.html, contains('2 images · 2 scenarios'));
    expect(result.html, contains('Ungrouped'));
    expect(result.html, contains('group.hidden = groupCount === 0;'));
  });

  test('renders centered lightbox controls without font glyphs', () {
    final result = HtmlReportRenderer(
      outputPath: '/project/report.html',
    ).render(GoldenCatalog(scenarios: const []));

    expect(
      RegExp(r'class="lightbox__icon"').allMatches(result.html),
      hasLength(3),
    );
    expect(
      result.html,
      contains(
        '.lightbox__close, .lightbox__nav { display: grid; place-items: center; padding: 0;',
      ),
    );
    expect(result.html, isNot(contains('>×</button>')));
    expect(result.html, isNot(contains('>‹</button>')));
    expect(result.html, isNot(contains('>›</button>')));
  });
}

GoldenImage _image(String name) {
  return GoldenImage(
    fileName: '$name.png',
    path: '/project/$name.png',
    device: 'desktop',
    extension: 'png',
  );
}

Set<String> _nonEmptyOptionValues(String html, String id) {
  final select = RegExp(
    '<select id="$id-filter"[^>]*>(.*?)</select>',
    dotAll: true,
  ).firstMatch(html);
  expect(select, isNotNull, reason: 'Missing $id dropdown');
  return RegExp('<option value="([^"]*)"')
      .allMatches(select!.group(1)!)
      .map((match) => match.group(1)!)
      .where((value) => value.isNotEmpty)
      .toSet();
}

Set<String> _nonEmptyDataValues(String html, String attribute) {
  return RegExp('data-$attribute="([^"]*)"')
      .allMatches(html)
      .map((match) => match.group(1)!)
      .where((value) => value.isNotEmpty)
      .toSet();
}

String _dataAttributeName(String id) => switch (id) {
      'textScale' => 'text-scale',
      _ => id,
    };
