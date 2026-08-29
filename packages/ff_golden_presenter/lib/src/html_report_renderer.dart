import 'dart:convert';

import 'package:path/path.dart' as path;

import 'model.dart';

/// Turns a [GoldenCatalog] into one searchable, dependency-free HTML page.
final class HtmlReportRenderer {
  HtmlReportRenderer({
    required this.outputPath,
    this.title = 'Golden test report',
    this.showSupportAttribution = true,
  });

  final String outputPath;
  final String title;
  final bool showSupportAttribution;

  GoldenPresenterResult render(GoldenCatalog catalog) {
    final document = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('  <meta charset="utf-8">')
      ..writeln(
        '  <meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln('  <meta name="generator" content="ff_golden_presenter">')
      ..writeln('  <title>${_escape(title)}</title>')
      ..writeln(_initialThemeScript)
      ..writeln(_styles)
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln(_renderHero(catalog))
      ..writeln(_renderControls(catalog))
      ..writeln('<main class="report-shell">')
      ..writeln(_renderNavigation(catalog))
      ..writeln('<div class="scenario-list" id="scenario-list">')
      ..writeln(_renderScenarios(catalog))
      ..writeln('</div>')
      ..writeln('</main>')
      ..writeln(_renderEmptyState(catalog))
      ..writeln(_lightbox)
      ..writeln(_renderFooter())
      ..writeln(_scripts)
      ..writeln('</body>')
      ..writeln('</html>');

    final html = document.toString().replaceAll(
          RegExp(r'[ \t]+$', multiLine: true),
          '',
        );
    return GoldenPresenterResult(html: html, catalog: catalog);
  }

  String _renderHero(GoldenCatalog catalog) {
    return '''
<header class="hero">
  <div class="hero__content">
    <div class="hero__topline">
      <p class="eyebrow">Visual test catalog</p>
      <button class="theme-toggle" id="theme-toggle" type="button" aria-label="Switch color theme">
        <span class="theme-toggle__icon" id="theme-toggle-icon" aria-hidden="true">◐</span>
        <span id="theme-toggle-label">Change theme</span>
      </button>
    </div>
    <h1>${_escape(title)}</h1>
    <p class="hero__description">Browse every captured state, then narrow the catalog by scenario, capture, device, matrix axis, or run status.</p>
    <dl class="summary" aria-label="Report summary">
      ${_stat('Images', catalog.imageCount)}
      ${_stat('Scenarios', catalog.scenarios.length)}
      ${_stat('Devices', catalog.devices.length)}
      ${_stat('Themes', catalog.themes.length)}
      ${_stat('Failures', catalog.failedCount)}
    </dl>
  </div>
</header>''';
  }

  String _stat(String label, int value) {
    return '<div class="summary__item"><dt>$label</dt><dd>$value</dd></div>';
  }

  String _renderControls(GoldenCatalog catalog) {
    return '''
<section class="controls" aria-label="Golden image filters">
  <div class="controls__content">
    <label class="search-field">
      <span>Search</span>
      <input id="search" type="search" placeholder="Scenario, file, or variant" autocomplete="off">
    </label>
    ${_selectIfPresent('capture', 'Capture', catalog.captures)}
    ${_select('device', 'Device', catalog.devices)}
    ${_select('theme', 'Theme', catalog.themes)}
    ${_select('locale', 'Locale', catalog.locales)}
    ${_selectIfPresent('textScale', 'Text scale', catalog.textScales)}
    ${_selectIfPresent('direction', 'Direction', catalog.directions)}
    ${_selectIfPresent('platform', 'Platform', catalog.platforms)}
    ${_selectIfPresent('brightness', 'Brightness', catalog.brightnesses)}
    ${_selectIfPresent('contrast', 'Contrast', catalog.contrasts)}
    ${_selectIfPresent('status', 'Status', catalog.statuses)}
    <button class="reset-button" id="reset-filters" type="button">Reset</button>
    <p class="result-count" aria-live="polite"><strong id="visible-count">${catalog.imageCount}</strong> of ${catalog.imageCount} images</p>
  </div>
</section>''';
  }

  String _selectIfPresent(String id, String label, List<String> values) =>
      values.isEmpty ? '' : _select(id, label, values);

  String _select(String id, String label, List<String> values) {
    final plural = switch (label) {
      'Status' => 'statuses',
      'Brightness' => 'brightness levels',
      _ => '${label.toLowerCase()}s',
    };
    final options = StringBuffer('<option value="">All $plural</option>');
    for (final value in values) {
      options.write(
        '<option value="${_escapeAttribute(value)}">${_escape(value)}</option>',
      );
    }
    return '''
<label class="select-field">
  <span>$label</span>
  <select id="$id-filter">$options</select>
</label>''';
  }

  String _renderNavigation(GoldenCatalog catalog) {
    if (catalog.scenarios.isEmpty) {
      return '';
    }
    final links = StringBuffer();
    for (var index = 0; index < catalog.scenarios.length; index++) {
      final scenario = catalog.scenarios[index];
      links.writeln('''
<a href="#scenario-$index" data-scenario-link="scenario-$index">
  <span>${_escape(scenario.breadcrumb)}</span>
  <strong>${scenario.images.length}</strong>
</a>''');
    }
    return '''
<nav class="scenario-nav" aria-label="Scenarios">
  <p class="scenario-nav__title">Scenarios</p>
  $links
</nav>''';
  }

  String _renderScenarios(GoldenCatalog catalog) {
    final scenarios = StringBuffer();
    var imageIndex = 0;
    for (var scenarioIndex = 0;
        scenarioIndex < catalog.scenarios.length;
        scenarioIndex++) {
      final scenario = catalog.scenarios[scenarioIndex];
      final cards = StringBuffer();
      for (final image in scenario.images) {
        cards.writeln(_renderImageCard(scenario, image, imageIndex));
        imageIndex++;
      }
      scenarios.writeln('''
<section class="scenario" id="scenario-$scenarioIndex" data-scenario>
  <header class="scenario__header">
    <div>
      <p class="eyebrow">Scenario ${(scenarioIndex + 1).toString().padLeft(2, '0')}</p>
      <h2>${_escape(scenario.breadcrumb)}</h2>
    </div>
    <span class="scenario__count" data-scenario-count>${scenario.images.length} images</span>
  </header>
  <div class="gallery">
    $cards
  </div>
</section>''');
    }
    return scenarios.toString();
  }

  String _renderImageCard(
    GoldenScenario scenario,
    GoldenImage image,
    int imageIndex,
  ) {
    final source = _imageSource(image.path);
    final theme = image.theme ?? '';
    final locale = image.locale ?? '';
    final capture = image.captureName ?? '';
    final textScale = image.textScaleLabel ?? '';
    final direction = image.direction ?? '';
    final platform = image.platform ?? '';
    final brightness = image.brightness ?? '';
    final contrast = image.contrastLabel ?? '';
    final status =
        image.status == GoldenImageStatus.unknown ? '' : image.status.name;
    final searchText =
        '${scenario.breadcrumb} ${image.searchText}'.toLowerCase();
    return '''
<article class="golden-card"
  data-golden-card
  data-capture="${_escapeAttribute(capture)}"
  data-device="${_escapeAttribute(image.device)}"
  data-theme="${_escapeAttribute(theme)}"
  data-locale="${_escapeAttribute(locale)}"
  data-text-scale="${_escapeAttribute(textScale)}"
  data-direction="${_escapeAttribute(direction)}"
  data-platform="${_escapeAttribute(platform)}"
  data-brightness="${_escapeAttribute(brightness)}"
  data-contrast="${_escapeAttribute(contrast)}"
  data-status="${_escapeAttribute(status)}"
  data-search="${_escapeAttribute(searchText)}">
  <button class="image-button" type="button" data-lightbox-index="$imageIndex" data-source="${_escapeAttribute(source)}" aria-label="Open ${_escapeAttribute(image.fileName)}">
    <img src="${_escapeAttribute(source)}" alt="${_escapeAttribute(scenario.breadcrumb)} — ${_escapeAttribute(image.fileName)}" loading="lazy" decoding="async">
    <span class="image-button__hint">View full size</span>
  </button>
  <div class="golden-card__body">
    <h3>${_escape(image.device)}</h3>
    <p class="file-name">${_escape(image.fileName)}</p>
    <div class="badges">
      ${_badge(image.captureName, 'capture')}
      ${_badge(image.theme, 'theme')}
      ${_badge(image.locale, 'locale')}
      ${_badge(image.textScaleLabel == null ? null : '${image.textScaleLabel}x text', 'text-scale')}
      ${_badge(image.direction, 'direction')}
      ${_badge(image.platform, 'platform')}
      ${_badge(image.brightness, 'brightness')}
      ${_badge(image.contrastLabel, 'contrast')}
      ${_badge(status, 'status-$status')}
      ${_badge(image.overflowCount == null || image.overflowCount == 0 ? null : '${image.overflowCount} overflows', 'overflow')}
      ${_badge(image.durationMs == null ? null : '${image.durationMs!.toStringAsFixed(1)} ms', 'duration')}
      ${_badge(image.extension.toUpperCase(), 'format')}
    </div>
    ${_failureDetails(image)}
  </div>
</article>''';
  }

  String _failureDetails(GoldenImage image) {
    if (image.status != GoldenImageStatus.failed) return '';
    final phase = image.failurePhase == null
        ? 'Golden comparison failed'
        : 'Failed during ${image.failurePhase}';
    final details = image.error ?? 'No failure message was recorded.';
    return '''
<details class="failure-details">
  <summary>${_escape(phase)}</summary>
  <pre>${_escape(details)}</pre>
</details>''';
  }

  String _badge(String? value, String kind) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return '<span class="badge badge--$kind">${_escape(value)}</span>';
  }

  String _renderEmptyState(GoldenCatalog catalog) {
    final message = catalog.imageCount == 0
        ? 'No images were found inside a “golden” directory.'
        : 'No images match the current filters.';
    final hidden = catalog.imageCount == 0 ? '' : ' hidden';
    return '''
<section class="empty-state" id="empty-state"$hidden>
  <strong>Nothing to show</strong>
  <p>${_escape(message)}</p>
</section>''';
  }

  String _imageSource(String imagePath) {
    final reportDirectory = path.dirname(path.absolute(outputPath));
    final relative = path.relative(imagePath, from: reportDirectory);
    if (path.isAbsolute(relative)) {
      return Uri.file(imagePath).toString();
    }
    return path.split(relative).map(Uri.encodeComponent).join('/');
  }

  static String _escape(String value) => const HtmlEscape().convert(value);

  static String _escapeAttribute(String value) {
    return const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
  }

  String _renderFooter() {
    const presenterAttribution =
        'Generated by <a href="https://github.com/Gorniv/golden/tree/master/packages/ff_golden_presenter">FF Golden Presenter</a>';
    if (!showSupportAttribution) {
      return '<footer>$presenterAttribution</footer>';
    }
    return '''
<footer>
  Made with support from <a href="https://aso.dev/?utm_source=ff_golden&amp;utm_medium=referral" rel="sponsored noopener" target="_blank">ASO.dev</a>
  <span aria-hidden="true">·</span>
  $presenterAttribution
</footer>''';
  }
}

const _lightbox = '''
<dialog class="lightbox" id="lightbox">
  <div class="lightbox__surface">
    <button class="lightbox__close" type="button" id="lightbox-close" aria-label="Close image">×</button>
    <button class="lightbox__nav lightbox__nav--previous" type="button" id="lightbox-previous" aria-label="Previous image">‹</button>
    <img id="lightbox-image" alt="Selected golden image">
    <button class="lightbox__nav lightbox__nav--next" type="button" id="lightbox-next" aria-label="Next image">›</button>
    <p id="lightbox-caption"></p>
  </div>
</dialog>''';

const _initialThemeScript = r'''
  <script>
    (() => {
      let savedTheme;
      try {
        savedTheme = localStorage.getItem('ff-golden-presenter-theme');
      } catch (_) {
        // Storage can be unavailable for local files in privacy-focused browsers.
      }
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      document.documentElement.dataset.theme =
        savedTheme === 'dark' || savedTheme === 'light'
          ? savedTheme
          : (prefersDark ? 'dark' : 'light');
    })();
  </script>''';

const _styles = r'''
  <style>
    :root {
      color-scheme: dark;
      --page: #0b0d12;
      --panel: #131722;
      --panel-soft: #191e2a;
      --border: #293142;
      --muted: #96a0b5;
      --text: #f3f5f9;
      --accent: #8ee3c5;
      --accent-strong: #55cfa7;
      --purple: #b8a8ff;
      --shadow: 0 24px 70px rgba(0, 0, 0, .28);
      --hero-background:
        radial-gradient(circle at 12% 20%, rgba(85, 207, 167, .18), transparent 30%),
        radial-gradient(circle at 88% 15%, rgba(184, 168, 255, .14), transparent 28%),
        #10141d;
      --summary-background: rgba(11, 13, 18, .55);
      --controls-background: rgba(11, 13, 18, .9);
      --image-background: linear-gradient(145deg, #202634, #11151f);
      --badge-background: #263042;
      --badge-text: #cbd4e5;
      --theme-badge-background: rgba(184, 168, 255, .14);
      --theme-badge-text: #cbbfff;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    :root[data-theme="light"] {
      color-scheme: light;
      --page: #f5f7fb;
      --panel: #ffffff;
      --panel-soft: #eef1f6;
      --border: #d9dfE9;
      --muted: #657084;
      --text: #151923;
      --accent: #137a5a;
      --accent-strong: #0b6549;
      --purple: #6f5bd3;
      --shadow: 0 18px 48px rgba(37, 49, 72, .12);
      --hero-background:
        radial-gradient(circle at 12% 20%, rgba(44, 188, 139, .2), transparent 32%),
        radial-gradient(circle at 88% 15%, rgba(126, 101, 224, .13), transparent 30%),
        #f7fafc;
      --summary-background: rgba(255, 255, 255, .72);
      --controls-background: rgba(247, 249, 252, .92);
      --image-background: linear-gradient(145deg, #eef2f7, #e3e8f0);
      --badge-background: #e8edf4;
      --badge-text: #4b586d;
      --theme-badge-background: #eeeafd;
      --theme-badge-text: #5d49bd;
    }

    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body { margin: 0; background: var(--page); color: var(--text); min-width: 320px; transition: background-color .2s ease, color .2s ease; }
    button, input, select { font: inherit; }
    button, select { cursor: pointer; }
    [hidden] { display: none !important; }

    .hero {
      overflow: hidden;
      border-bottom: 1px solid var(--border);
      background: var(--hero-background);
    }
    .hero__content { width: min(1440px, calc(100% - 48px)); margin: auto; padding: 64px 0 48px; }
    .hero__topline { display: flex; align-items: center; justify-content: space-between; gap: 24px; margin-bottom: 10px; }
    .eyebrow { margin: 0 0 10px; color: var(--accent); font-size: 12px; font-weight: 800; letter-spacing: .14em; text-transform: uppercase; }
    .hero__topline .eyebrow { margin: 0; }
    .theme-toggle { display: inline-flex; min-height: 40px; align-items: center; gap: 8px; padding: 0 13px; border: 1px solid var(--border); border-radius: 999px; background: var(--summary-background); color: var(--text); font-size: 12px; font-weight: 750; }
    .theme-toggle:hover { border-color: var(--accent); color: var(--accent); }
    .theme-toggle__icon { display: grid; width: 20px; height: 20px; place-items: center; color: var(--accent); font-size: 17px; line-height: 1; }
    h1 { max-width: 920px; margin: 0; font-size: clamp(38px, 7vw, 76px); line-height: .98; letter-spacing: -.055em; }
    .hero__description { max-width: 720px; margin: 24px 0 36px; color: var(--muted); font-size: 17px; line-height: 1.6; }
    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(110px, 170px)); gap: 12px; margin: 0; }
    .summary__item { padding: 16px 18px; border: 1px solid var(--border); border-radius: 14px; background: var(--summary-background); }
    .summary dt { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: .08em; }
    .summary dd { margin: 4px 0 0; font-size: 28px; font-weight: 800; }

    .controls { position: sticky; top: 0; z-index: 20; border-bottom: 1px solid var(--border); background: var(--controls-background); backdrop-filter: blur(16px); }
    .controls__content { width: min(1440px, calc(100% - 48px)); margin: auto; padding: 14px 0; display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 10px; align-items: end; }
    .search-field { grid-column: span 2; }
    .search-field, .select-field { display: grid; gap: 6px; color: var(--muted); font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }
    input, select, .reset-button { min-height: 42px; border: 1px solid var(--border); border-radius: 10px; background: var(--panel); color: var(--text); }
    input, select { width: 100%; padding: 0 12px; }
    input:focus, select:focus, button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    .reset-button { padding: 0 16px; font-weight: 700; }
    .reset-button:hover { border-color: var(--accent); color: var(--accent); }
    .result-count { margin: 0 0 12px 4px; color: var(--muted); white-space: nowrap; font-size: 13px; }
    .result-count strong { color: var(--text); }

    .report-shell { width: min(1440px, calc(100% - 48px)); margin: 0 auto; padding: 36px 0 72px; display: grid; grid-template-columns: 230px minmax(0, 1fr); gap: 40px; align-items: start; }
    .scenario-nav { position: sticky; top: 96px; display: grid; gap: 4px; max-height: calc(100vh - 120px); overflow: auto; padding-right: 8px; }
    .scenario-nav__title { margin: 0 0 10px; color: var(--muted); font-size: 12px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
    .scenario-nav a { display: flex; justify-content: space-between; gap: 12px; padding: 9px 10px; border-radius: 9px; color: var(--muted); text-decoration: none; font-size: 13px; line-height: 1.35; }
    .scenario-nav a:hover { background: var(--panel); color: var(--text); }
    .scenario-nav strong { color: var(--accent); font-variant-numeric: tabular-nums; }
    .scenario-list { display: grid; gap: 64px; min-width: 0; }
    .scenario { scroll-margin-top: 100px; }
    .scenario__header { display: flex; justify-content: space-between; align-items: end; gap: 24px; margin-bottom: 18px; }
    .scenario h2 { margin: 0; font-size: clamp(24px, 4vw, 40px); letter-spacing: -.035em; overflow-wrap: anywhere; }
    .scenario__count { flex: none; padding: 7px 10px; border: 1px solid var(--border); border-radius: 999px; color: var(--muted); font-size: 12px; }
    .gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 16px; }

    .golden-card { min-width: 0; overflow: hidden; border: 1px solid var(--border); border-radius: 16px; background: var(--panel); box-shadow: var(--shadow); transition: border-color .2s ease, transform .2s ease; }
    .golden-card:hover { transform: translateY(-2px); border-color: #465166; }
    .image-button { position: relative; display: grid; width: 100%; height: 320px; place-items: center; overflow: hidden; padding: 18px; border: 0; border-bottom: 1px solid var(--border); background: var(--image-background); }
    .image-button img { display: block; max-width: 100%; max-height: 100%; object-fit: contain; filter: drop-shadow(0 14px 22px rgba(0, 0, 0, .32)); transition: transform .25s ease; }
    .image-button:hover img { transform: scale(1.025); }
    .image-button__hint { position: absolute; right: 10px; bottom: 10px; padding: 6px 8px; border-radius: 8px; background: rgba(5, 7, 10, .78); color: #fff; font-size: 11px; opacity: 0; transform: translateY(4px); transition: .2s ease; }
    .image-button:hover .image-button__hint, .image-button:focus-visible .image-button__hint { opacity: 1; transform: none; }
    .golden-card__body { padding: 15px 16px 17px; }
    .golden-card h3 { margin: 0; font-size: 16px; }
    .file-name { overflow: hidden; margin: 5px 0 13px; color: var(--muted); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }
    .badges { display: flex; flex-wrap: wrap; gap: 6px; min-height: 24px; }
    .badge { padding: 5px 8px; border-radius: 999px; background: var(--badge-background); color: var(--badge-text); font-size: 10px; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; }
    .badge--theme { background: var(--theme-badge-background); color: var(--theme-badge-text); }
    .badge--locale { background: rgba(142, 227, 197, .12); color: var(--accent); }
    .badge--status-failed { background: rgba(255, 99, 132, .16); color: #ff8da8; }
    .badge--status-passed { background: rgba(85, 207, 167, .14); color: var(--accent); }
    .failure-details { margin-top: 12px; border-top: 1px solid var(--border); padding-top: 10px; color: #ff8da8; font-size: 11px; }
    .failure-details summary { cursor: pointer; font-weight: 800; }
    .failure-details pre { overflow: auto; max-height: 180px; margin: 8px 0 0; padding: 9px; border-radius: 8px; background: var(--panel-soft); color: var(--text); font: 10px/1.45 ui-monospace, SFMono-Regular, Menlo, monospace; white-space: pre-wrap; }

    .empty-state { width: min(680px, calc(100% - 48px)); margin: 64px auto; padding: 48px; border: 1px dashed var(--border); border-radius: 18px; text-align: center; }
    .empty-state strong { font-size: 22px; }
    .empty-state p { margin-bottom: 0; color: var(--muted); }

    .lightbox { width: 100vw; max-width: none; height: 100vh; max-height: none; margin: 0; padding: 0; border: 0; background: rgba(5, 7, 10, .94); color: #f3f5f9; }
    .lightbox::backdrop { background: rgba(5, 7, 10, .94); }
    .lightbox__surface { position: relative; display: grid; width: 100%; height: 100%; grid-template-columns: 70px minmax(0, 1fr) 70px; grid-template-rows: minmax(0, 1fr) auto; place-items: center; padding: 32px; }
    .lightbox img { grid-column: 2; width: 100%; height: 100%; object-fit: contain; }
    .lightbox__close, .lightbox__nav { border: 1px solid #293142; border-radius: 999px; background: rgba(19, 23, 34, .85); color: #f3f5f9; }
    .lightbox__close { position: absolute; top: 20px; right: 20px; z-index: 2; width: 44px; height: 44px; font-size: 26px; }
    .lightbox__nav { width: 48px; height: 48px; font-size: 34px; line-height: 1; }
    .lightbox__nav--previous { grid-column: 1; grid-row: 1; }
    .lightbox__nav--next { grid-column: 3; grid-row: 1; }
    #lightbox-caption { grid-column: 1 / -1; margin: 18px 0 0; color: #96a0b5; font-size: 13px; }

    footer { display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; padding: 24px; border-top: 1px solid var(--border); color: var(--muted); text-align: center; font-size: 12px; }
    footer a { color: var(--accent); }

    @media (max-width: 980px) {
      .controls { position: static; }
      .controls__content { grid-template-columns: repeat(3, 1fr); }
      .search-field { grid-column: 1 / -1; }
      .result-count { justify-self: end; }
      .report-shell { grid-template-columns: 1fr; }
      .scenario-nav { position: static; display: flex; max-height: none; overflow-x: auto; padding: 0 0 8px; }
      .scenario-nav__title { display: none; }
      .scenario-nav a { flex: 0 0 auto; border: 1px solid var(--border); }
    }
    @media (max-width: 640px) {
      .hero__content, .controls__content, .report-shell { width: min(100% - 28px, 1440px); }
      .hero__content { padding: 48px 0 36px; }
      .hero__topline { align-items: flex-start; }
      .theme-toggle { min-height: 36px; padding: 0 10px; }
      .theme-toggle__icon { width: 18px; height: 18px; }
      .summary { grid-template-columns: repeat(2, 1fr); }
      .controls__content { grid-template-columns: 1fr 1fr; }
      .search-field { grid-column: 1 / -1; }
      .result-count { justify-self: start; margin-left: 0; }
      .scenario__header { align-items: start; flex-direction: column; gap: 12px; }
      .gallery { grid-template-columns: 1fr; }
      .image-button { height: 360px; }
      .lightbox__surface { grid-template-columns: 48px minmax(0, 1fr) 48px; padding: 18px 8px; }
      .lightbox__nav { width: 40px; height: 40px; }
    }
    @media print {
      .controls, .scenario-nav, .image-button__hint, .lightbox, footer { display: none; }
      body, .hero, .golden-card { background: #fff; color: #111; }
      .report-shell { display: block; width: 100%; }
      .scenario { break-before: page; }
      .golden-card { break-inside: avoid; box-shadow: none; }
    }
  </style>''';

const _scripts = r'''
<script>
  (() => {
    const cards = Array.from(document.querySelectorAll('[data-golden-card]'));
    const scenarios = Array.from(document.querySelectorAll('[data-scenario]'));
    const search = document.getElementById('search');
    const filters = [
      ['capture', document.getElementById('capture-filter')],
      ['device', document.getElementById('device-filter')],
      ['theme', document.getElementById('theme-filter')],
      ['locale', document.getElementById('locale-filter')],
      ['textScale', document.getElementById('textScale-filter')],
      ['direction', document.getElementById('direction-filter')],
      ['platform', document.getElementById('platform-filter')],
      ['brightness', document.getElementById('brightness-filter')],
      ['contrast', document.getElementById('contrast-filter')],
      ['status', document.getElementById('status-filter')],
    ].filter((entry) => entry[1]);
    const reset = document.getElementById('reset-filters');
    const visibleCount = document.getElementById('visible-count');
    const emptyState = document.getElementById('empty-state');
    const lightbox = document.getElementById('lightbox');
    const lightboxImage = document.getElementById('lightbox-image');
    const lightboxCaption = document.getElementById('lightbox-caption');
    const themeToggle = document.getElementById('theme-toggle');
    const themeToggleIcon = document.getElementById('theme-toggle-icon');
    const themeToggleLabel = document.getElementById('theme-toggle-label');

    const visibleButtons = () => cards
      .filter((card) => !card.hidden)
      .map((card) => card.querySelector('[data-lightbox-index]'));

    function applyFilters() {
      const query = search.value.trim().toLocaleLowerCase();
      let count = 0;
      cards.forEach((card) => {
        const matches = (!query || card.dataset.search.includes(query)) &&
          filters.every(([key, control]) =>
            !control.value || card.dataset[key] === control.value);
        card.hidden = !matches;
        if (matches) count++;
      });

      scenarios.forEach((scenario) => {
        const scenarioCards = Array.from(scenario.querySelectorAll('[data-golden-card]'));
        const scenarioCount = scenarioCards.filter((card) => !card.hidden).length;
        scenario.hidden = scenarioCount === 0;
        scenario.querySelector('[data-scenario-count]').textContent =
          scenarioCount + (scenarioCount === 1 ? ' image' : ' images');
        const link = document.querySelector('[data-scenario-link="' + scenario.id + '"]');
        if (link) link.hidden = scenarioCount === 0;
      });

      visibleCount.textContent = String(count);
      emptyState.hidden = count !== 0;
    }

    function show(button) {
      lightboxImage.src = button.dataset.source;
      const card = button.closest('[data-golden-card]');
      lightboxCaption.textContent = card.querySelector('.file-name').textContent;
      lightbox.dataset.index = button.dataset.lightboxIndex;
      if (!lightbox.open) lightbox.showModal();
    }

    function step(direction) {
      const buttons = visibleButtons();
      if (!buttons.length) return;
      const current = buttons.findIndex(
        (button) => button.dataset.lightboxIndex === lightbox.dataset.index,
      );
      const next = (current + direction + buttons.length) % buttons.length;
      show(buttons[next]);
    }

    function updateThemeToggle() {
      const currentTheme = document.documentElement.dataset.theme;
      const targetTheme = currentTheme === 'dark' ? 'light' : 'dark';
      themeToggleIcon.textContent = targetTheme === 'light' ? '☀' : '☾';
      themeToggleLabel.textContent =
        targetTheme.charAt(0).toUpperCase() + targetTheme.slice(1) + ' theme';
      themeToggle.setAttribute('aria-label', 'Switch to ' + targetTheme + ' theme');
    }

    [search, ...filters.map((entry) => entry[1])].forEach((control) => {
      control.addEventListener(control === search ? 'input' : 'change', applyFilters);
    });
    reset.addEventListener('click', () => {
      search.value = '';
      filters.forEach((entry) => entry[1].value = '');
      applyFilters();
      search.focus();
    });
    themeToggle.addEventListener('click', () => {
      document.documentElement.dataset.theme =
        document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
      try {
        localStorage.setItem(
          'ff-golden-presenter-theme',
          document.documentElement.dataset.theme,
        );
      } catch (_) {
        // The selected theme still applies for the current page session.
      }
      updateThemeToggle();
    });
    document.querySelectorAll('[data-lightbox-index]').forEach((button) => {
      button.addEventListener('click', () => show(button));
    });
    document.getElementById('lightbox-close').addEventListener('click', () => lightbox.close());
    document.getElementById('lightbox-previous').addEventListener('click', () => step(-1));
    document.getElementById('lightbox-next').addEventListener('click', () => step(1));
    lightbox.addEventListener('click', (event) => {
      if (event.target === lightbox) lightbox.close();
    });
    document.addEventListener('keydown', (event) => {
      if (!lightbox.open) return;
      if (event.key === 'ArrowLeft') step(-1);
      if (event.key === 'ArrowRight') step(1);
    });
    updateThemeToggle();
  })();
</script>''';
