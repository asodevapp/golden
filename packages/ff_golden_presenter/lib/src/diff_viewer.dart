/// Self-contained local UI. Repository strings are inserted only via textContent.
String renderDiffViewer(String token) =>
    _page.replaceAll('__SESSION_TOKEN__', token);

const _page = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>FF Golden · Changes</title>
<style>
:root { color-scheme: dark; font: 14px/1.45 system-ui, -apple-system, sans-serif; --bg:#111418; --panel:#191e24; --line:#303842; --muted:#96a3b2; --accent:#75dcce; }
* { box-sizing:border-box; } body { margin:0; background:var(--bg); color:#edf1f5; height:100vh; display:flex; flex-direction:column; }
button,input,select { font:inherit; } button,select { color:inherit; background:#222a33; border:1px solid var(--line); border-radius:6px; padding:7px 11px; }
button { cursor:pointer; } button:hover:not(:disabled) { border-color:var(--accent); } button:disabled { opacity:.4; cursor:default; }
button:focus-visible,input:focus-visible,select:focus-visible,a:focus-visible { outline:2px solid var(--accent); outline-offset:2px; }
header { display:flex; align-items:center; gap:20px; padding:16px 22px; border-bottom:1px solid var(--line); }
.brand { font-weight:700; font-size:17px; white-space:nowrap; } .brand span { color:var(--accent); } .repo { color:var(--muted); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; flex:1; }
.brand-credit { display:inline-block; margin-left:10px; color:var(--muted); font-size:11px; font-weight:400; text-decoration:none; border-radius:3px; } .brand-credit strong { color:#4da3ff; font-weight:600; } .brand-credit:hover strong { color:#7abdff; }
.local { color:var(--accent); font-size:12px; white-space:nowrap; } main { display:grid; grid-template-columns:320px minmax(0,1fr); min-height:0; flex:1; overflow:hidden; }
aside { display:flex; flex-direction:column; border-right:1px solid var(--line); background:var(--panel); min-height:0; }
.filters { padding:8px 10px; display:grid; gap:6px; border-bottom:1px solid var(--line); }
.file-search,.file-tools { display:flex; align-items:center; gap:6px; min-width:0; }
input[type=search] { width:100%; min-width:0; height:30px; color:inherit; background:var(--bg); padding:5px 8px; border:1px solid var(--line); border-radius:5px; font-size:12px; }
.file-search input { flex:1; } .file-tools select { flex:1; width:0; min-width:0; height:30px; padding:3px 6px; font-size:12px; border-radius:5px; }
.file-layout { display:flex; gap:2px; } .file-layout button,.file-tools>button { display:grid; place-items:center; width:30px; height:30px; padding:0; border-radius:5px; flex-shrink:0; color:var(--muted); background:transparent; border-color:transparent; }
.file-layout svg { width:16px; height:16px; fill:none; stroke:currentColor; stroke-width:1.5; stroke-linecap:round; stroke-linejoin:round; }
.file-tools>button { font-size:20px; } .file-layout [aria-pressed=true],[aria-pressed=true] { color:var(--accent); border-color:var(--accent); background:#213d3b; }
#ignored-active { height:30px; padding:3px 7px; font-size:11px; white-space:nowrap; color:var(--accent); border-color:#397f69; background:#213d3b; } .ignored-label { color:var(--muted); font-size:10px; }
.file-count { display:flex; min-width:0; padding-top:2px; color:var(--muted); font-size:10px; } .file-count span { flex:1; min-width:0; text-align:center; white-space:nowrap; } .file-count span+span { border-left:1px solid var(--line); } .file-count strong { margin-right:3px; color:#cbd5df; font-size:11px; font-variant-numeric:tabular-nums; }
#files { flex:1; overflow:auto; padding:6px 8px 16px; } .group-title { margin:14px 8px 6px; display:flex; justify-content:space-between; color:var(--muted); font-size:11px; font-weight:650; letter-spacing:.08em; text-transform:uppercase; }
.folder { margin:4px 0; } .folder summary { display:flex; align-items:center; gap:6px; padding:7px 5px; cursor:pointer; color:#bdcbd7; font-size:12px; list-style:none; }
.folder summary::-webkit-details-marker { display:none; } .folder summary::before { content:'▸'; width:10px; flex-shrink:0; color:var(--muted); } .folder[open]>summary::before { content:'▾'; }
.folder-name { flex:1; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; } .folder-count { color:var(--muted); font-size:10px; }
.difference-value { min-width:48px; flex-shrink:0; color:#9fd9d1; font:600 10px ui-monospace,monospace; text-align:right; white-space:nowrap; } .difference-value.pending,.difference-value.unavailable { color:var(--muted); }
.folder input { accent-color:var(--accent); } .folder-children { margin-left:12px; padding-left:6px; border-left:1px solid var(--line); } .folder-children .file { padding-right:2px; }
.file { display:flex; align-items:center; gap:8px; padding:3px 7px; border-radius:6px; margin:2px 0; } .file.active { background:#283b41; } .file:hover { background:#242f38; }
.file input { accent-color:var(--accent); flex-shrink:0; } .file button { flex:1; min-width:0; background:none; border:0; text-align:left; padding:7px 0; display:flex; gap:9px; align-items:center; }
.file-name { display:block; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font-size:12px; } .file-dir { display:block; color:var(--muted); font-size:10px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.file-text { min-width:0; flex:1; } .badge { font:700 11px ui-monospace,monospace; color:#edc984; border:1px solid #64563b; border-radius:4px; width:22px; text-align:center; padding:2px; }
.badge.added { color:#91d9b1; border-color:#3d634f; } .badge.deleted { color:#f6a6a6; border-color:#744747; }
.selection { border-top:1px solid var(--line); padding:10px; display:grid; grid-template-columns:repeat(3,minmax(0,1fr)) 28px 28px; gap:6px; } .selection button { font-size:12px; padding:7px 4px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.selection .icon-button { padding:4px; font-size:17px; } .context-target { outline:1px solid var(--accent); outline-offset:-1px; border-radius:6px; }
.failure-selection { border-top:1px solid var(--line); padding:10px; } .failure-selection button { width:100%; font-size:12px; }
.danger { color:#ffc2c2; border-color:#744747; background:#482a2e; } button.danger:hover:not(:disabled) { border-color:#e78383; }
.context-menu { position:fixed; z-index:10; width:250px; max-width:calc(100vw - 16px); max-height:calc(100vh - 16px); overflow:auto; padding:6px; border:1px solid #46525f; border-radius:10px; background:#20272f; box-shadow:0 12px 36px #0008; }
.context-title { padding:7px 9px 9px; font-size:11px; color:var(--muted); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.context-menu button { display:flex; align-items:center; justify-content:space-between; gap:20px; width:100%; border:0; padding:8px 9px; background:transparent; text-align:left; font-size:13px; border-radius:5px; }
.context-menu button:hover:not(:disabled),.context-menu button:focus-visible { background:#30434a; outline:none; } .context-menu .menu-count { font-size:11px; color:var(--muted); }
.context-menu button.danger { color:#ffc2c2; background:transparent; } .context-menu button.danger:hover:not(:disabled),.context-menu button.danger:focus-visible { background:#482a2e; }
.context-menu [role=separator] { height:1px; background:var(--line); margin:5px 4px; }
.review { display:flex; flex-direction:column; min-width:0; min-height:0; } .detail { padding:15px 20px; border-bottom:1px solid var(--line); display:flex; gap:16px; align-items:center; }
.detail-text { flex:1; min-width:0; } h1 { font-size:15px; margin:0 0 3px; overflow-wrap:anywhere; } #context { font-size:12px; color:var(--muted); }
.primary { background:#254b43; color:#a5f4d4; border-color:#397f69; }
.toolbar { display:flex; gap:10px; align-items:center; flex-wrap:wrap; padding:10px 20px; border-bottom:1px solid var(--line); } .toolbar label { display:flex; gap:7px; align-items:center; color:var(--muted); font-size:12px; }
.toolbar select { color:#edf1f5; } #mix-control { flex:1; min-width:200px; } #mix { width:150px; accent-color:var(--accent); } #metrics { color:var(--muted); font-size:12px; padding:8px 20px; min-height:34px; }
.highlight-control input { accent-color:#ff529e; } #highlight-strength { width:80px; } .zoom-bar { display:flex; align-items:center; gap:6px; padding:8px 20px; border-bottom:1px solid var(--line); flex-wrap:wrap; }
.zoom-bar button { padding:5px 9px; font-size:12px; } .zoom-value { display:flex; align-items:center; gap:3px; color:var(--muted); font-size:12px; }
#zoom-percent { width:66px; color:inherit; background:var(--bg); border:1px solid var(--line); border-radius:5px; padding:5px; text-align:right; }
.zoom-hint { margin-left:auto; font-size:10px; color:var(--muted); } #zoom-changes { border-color:#744362; color:#f3b6d5; }
#viewer { flex:1; min-height:0; position:relative; margin:0 16px 16px; border:1px solid var(--line); border-radius:8px; overflow:hidden; background:#14191f; }
#empty { position:absolute; inset:0; display:grid; place-content:center; text-align:center; padding:30px; color:var(--muted); gap:8px; } #empty strong { color:#e1e8ef; font-size:20px; font-weight:550; }
.panels { height:100%; display:grid; grid-template-columns:1fr 1fr; gap:1px; background:var(--line); } .pane { display:flex; flex-direction:column; min-width:0; min-height:0; background:var(--bg); }
.pane-label { padding:9px 12px; color:var(--muted); font-size:11px; background:var(--panel); display:flex; justify-content:space-between; }
.viewport { flex:1; min-height:0; overflow:auto; padding:16px; overscroll-behavior:contain; } .viewport canvas { display:block; max-width:none; margin-inline:auto; box-shadow:0 0 0 1px #39414b; background-color:#20262c; background-image:conic-gradient(#2b333c 25%, transparent 0 50%, #2b333c 0 75%, transparent 0); background-size:16px 16px; cursor:grab; touch-action:none; user-select:none; }
.viewport.dragging canvas { cursor:grabbing; }
#combined { height:100%; display:flex; flex-direction:column; } #combined .viewport { min-width:0; }
footer { padding:8px 20px; border-top:1px solid var(--line); color:var(--muted); font-size:11px; display:flex; gap:20px; } #connection { margin-left:auto; }
#message { padding:10px 20px; background:#223b35; color:#b1e6ce; font-size:12px; } #message.error { background:#482a2e; color:#ffc2c2; } #warnings { color:#edc984; padding:8px 16px; font-size:11px; white-space:pre-wrap; max-height:100px; overflow:auto; }
.empty-list { padding:24px 12px; color:var(--muted); font-size:12px; text-align:center; } [hidden] { display:none!important; }
.tests-panel { height:360px; flex-shrink:0; min-height:160px; display:flex; flex-direction:column; background:var(--panel); }
.tests-resize { height:8px; flex-shrink:0; cursor:ns-resize; touch-action:none; border-top:1px solid #49625f; background:#202b30; position:relative; }
.tests-resize::after { content:''; position:absolute; width:44px; height:2px; background:#6c8987; top:2px; left:calc(50% - 22px); border-radius:2px; }
.tests-resize:hover,.tests-resize:focus-visible { background:#35504f; outline:1px solid var(--accent); outline-offset:-1px; } body.resizing-tests { cursor:ns-resize; user-select:none; }
.tests-heading { display:flex; align-items:center; gap:10px; padding:9px 16px; border-bottom:1px solid var(--line); }
.tests-heading strong { font-size:13px; } #test-status { flex:1; font-size:12px; color:var(--muted); } #test-status[data-status=passed] { color:#a5f4d4; } #test-status[data-status=failed] { color:#ffa6ad; }
.tests-heading button { font-size:12px; padding:5px 10px; } .tests-body { display:grid; grid-template-columns:420px minmax(0,1fr); flex:1; min-height:0; }
.test-settings { overflow:auto; border-right:1px solid var(--line); padding:12px 16px; } #test-fields { border:0; margin:0; padding:0; min-width:0; }
.test-fields-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:8px; } .test-wide { grid-column:1/-1; }
.test-settings label { display:flex; flex-direction:column; gap:3px; min-width:0; font-size:11px; color:var(--muted); }
.test-scope-row { display:flex; gap:8px; align-items:flex-end; margin-bottom:8px; } .test-scope-row label { flex:1; } .test-scope-row button { padding:6px 9px; font-size:11px; white-space:nowrap; }
.test-settings input,.test-settings select { min-width:0; width:100%; color:#edf1f5; background:var(--bg); padding:6px; border:1px solid var(--line); border-radius:5px; font-size:12px; }
.test-settings details { margin-top:10px; } .test-settings summary { color:var(--muted); font-size:12px; cursor:pointer; margin-bottom:8px; }
.test-note { font-size:11px; color:var(--muted); margin:8px 0 0; } #test-error { color:#ffc2c2; white-space:pre-wrap; } #test-command { margin:8px 0 0; white-space:pre-wrap; overflow-wrap:anywhere; font:10px/1.5 ui-monospace,monospace; color:#c5d9d4; }
#test-scope-summary { color:#a5d9cf; } #test-included { font-size:11px; padding-left:18px; overflow-wrap:anywhere; color:var(--muted); } #test-included li { margin-bottom:5px; } #test-included button { border:0; background:none; color:#a5d9cf; padding:2px 0; text-align:left; font:inherit; overflow-wrap:anywhere; text-decoration:underline; text-underline-offset:3px; }
.test-output { display:flex; flex-direction:column; min-width:0; min-height:0; background:#101418; } .test-output-bar { padding:7px 12px; display:flex; flex-wrap:wrap; gap:8px; align-items:center; color:var(--muted); font-size:11px; border-bottom:1px solid var(--line); } .test-output-actions { display:flex; gap:6px; align-items:center; margin-left:auto; } .test-output-bar button { padding:4px 7px; font-size:11px; white-space:nowrap; }
#test-log-hint { flex:1; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; } .test-output-bar label { display:flex; gap:5px; align-items:center; white-space:nowrap; } #test-logs { flex:1; min-height:0; overflow:auto; overflow-anchor:none; white-space:pre-wrap; overflow-wrap:anywhere; padding:12px; margin:0; font:11px/1.6 ui-monospace,SFMono-Regular,monospace; }
#test-copy-dialog { color:#edf1f5; background:var(--panel); border:1px solid var(--line); border-radius:10px; width:min(800px,85vw); padding:18px; } #test-copy-dialog::backdrop { background:#0009; } #test-copy-dialog h2 { margin:0 0 8px; font-size:16px; } #test-copy-text { box-sizing:border-box; width:100%; height:50vh; margin:12px 0; background:var(--bg); color:#edf1f5; border:1px solid var(--line); padding:12px; font:12px/1.5 ui-monospace,monospace; }
#revert-dialog,#delete-failures-dialog { color:#edf1f5; background:var(--panel); border:1px solid #744747; border-radius:10px; width:min(520px,85vw); padding:20px; } #revert-dialog::backdrop,#delete-failures-dialog::backdrop { background:#0009; } #revert-dialog h2,#delete-failures-dialog h2 { margin:0 0 10px; font-size:17px; } #revert-dialog p,#delete-failures-dialog p { color:var(--muted); } .dialog-actions { display:flex; justify-content:flex-end; gap:8px; margin-top:18px; }
@media(max-width:850px) { .tests-body { grid-template-columns:310px minmax(0,1fr); } .test-settings { padding:10px; } }
@media(max-width:1050px) { #test-log-hint { flex-basis:100%; } .test-output-actions { margin-left:0; } }
@media(max-width:850px) { main { grid-template-columns:240px minmax(0,1fr); } header { padding:12px; } .local { display:none; } .toolbar,.detail { padding:10px; } .detail { flex-wrap:wrap; } #viewer { margin:0 8px 8px; } }
</style>
</head>
<body>
<header><div class="brand"><span>FF Golden</span> / Changes<a class="brand-credit" href="https://aso.dev/?utm_source=ff_golden&amp;utm_medium=referral" target="_blank" rel="noopener noreferrer">by <strong>aso.dev</strong></a></div><div class="repo" id="repository">Loading repository…</div><span class="local">● Local image review</span><button id="show-tests" aria-expanded="false" aria-controls="tests-panel">Tests</button><button id="refresh">Refresh</button></header>
<main>
<aside aria-label="Review images">
  <div class="filters">
    <div class="file-search"><input id="search" type="search" aria-label="Search changed images" placeholder="Search files or scenarios…"><button id="ignored-active" title="Ignored files are visible. Click to hide them." aria-label="Hide ignored files" hidden>+ ignored ×</button></div>
    <div class="file-tools"><select id="file-scope" aria-label="Image review filter"><option value="all">All changes</option><option value="unstaged">Unstaged</option><option value="staged">Staged</option><option value="failures">Failures</option></select>
      <div class="file-layout" role="group" aria-label="File layout"><button data-layout="tree" aria-label="Tree" title="Tree view" aria-pressed="true"><svg viewBox="0 0 20 20" aria-hidden="true"><path d="M4 3v12h5M4 7h5M10 5h6v4h-6zM10 13h6v4h-6z"/></svg></button><button data-layout="list" aria-label="List" title="List view" aria-pressed="false"><svg viewBox="0 0 20 20" aria-hidden="true"><path d="M3 5h1m3 0h10M3 10h1m3 0h10M3 15h1m3 0h10"/></svg></button></div>
      <button id="file-view-options" aria-label="File view options" title="File view options · folders and ignored files" aria-haspopup="menu" aria-expanded="false" aria-controls="action-menu">⋯</button>
    </div>
    <div id="file-count" class="file-count" role="status"><span><strong id="shown-count">0</strong>shown</span><span><strong id="unstaged-count">0</strong>unstaged</span><span><strong id="staged-count">0</strong>staged</span><span><strong id="failure-count">0</strong>failures</span></div>
  </div>
  <div id="files"></div><div id="warnings" hidden></div>
  <div id="git-selection" class="selection"><button id="stage-selected" disabled>Stage (0)</button><button id="unstage-selected" disabled>Unstage (0)</button><button id="revert-selected" class="danger" disabled>Revert (0)</button><button id="clear-selected" class="icon-button" aria-label="Clear selection" title="Clear selection" disabled>×</button><button id="selection-actions" class="icon-button" aria-label="Selection actions" title="Selection actions" aria-haspopup="menu" aria-expanded="false" aria-controls="action-menu" disabled>⋯</button></div>
  <div id="failure-selection" class="failure-selection" hidden><button id="delete-failures" class="danger" disabled>Delete all failure images</button></div>
</aside>
<section class="review" aria-label="Image comparison">
  <div class="detail"><div class="detail-text"><h1 id="filename">Image changes</h1><div id="context">Choose an image to compare</div></div><button id="previous" aria-label="Previous image" disabled>←</button><button id="next" aria-label="Next image" disabled>→</button><button id="toggle-stage" class="primary" disabled>Stage file</button><button id="revert-file" class="danger" disabled>Revert changes</button><button id="file-actions" aria-label="File actions" title="File actions · also available with right-click" aria-haspopup="menu" aria-expanded="false" aria-controls="action-menu" disabled>⋯</button></div>
  <div class="toolbar">
    <label>View <select id="mode"><option value="side">Side by side</option><option value="split">Swipe</option><option value="overlay">Overlay</option><option value="diff">Pixel diff</option></select></label>
    <label id="highlight-control" class="highlight-control" title="Highlight changed pixels on the new version only"><input id="highlight" type="checkbox">Highlight changes</label>
    <label id="highlight-strength-control" class="highlight-control" hidden>Intensity <input id="highlight-strength" type="range" min="10" max="100" value="55" aria-label="Highlight intensity"></label>
    <label id="mix-control" hidden><span id="mix-label">Position</span><input id="mix" type="range" min="0" max="100" value="50" aria-label="Comparison mix"><span id="mix-value">50%</span></label>
  </div>
  <div class="zoom-bar" role="group" aria-label="Image zoom">
    <button id="zoom-out" aria-label="Zoom out" title="Zoom out (−)">−</button><label class="zoom-value"><input id="zoom-percent" type="number" min="1" max="800" step="10" value="100" aria-label="Zoom percent">%</label><button id="zoom-in" aria-label="Zoom in" title="Zoom in (+)">+</button>
    <button id="zoom-fit" title="Fit whole image (0)" aria-pressed="true">Fit</button><button id="zoom-width" title="Fit image width" aria-pressed="false">Width</button><button id="zoom-actual" title="Original pixel size (1)" aria-pressed="false">100%</button><button id="zoom-changes" title="Zoom to the bounding area of changed pixels">Changes</button>
    <span class="zoom-hint">Ctrl/⌘ + wheel to zoom · drag to pan · double-click for 100%</span>
  </div>
  <div id="metrics"></div>
  <div id="viewer">
    <div id="empty"><strong>No image selected</strong><span>Changes appear here automatically.</span></div>
    <div id="side" class="panels" hidden>
      <div class="pane"><div class="pane-label"><span id="before-label">Before</span><span id="before-size"></span></div><div class="viewport" id="before-viewport"><canvas id="before-canvas"></canvas></div></div>
      <div class="pane"><div class="pane-label"><span id="after-label">After</span><span id="after-size"></span></div><div class="viewport" id="after-viewport"><canvas id="after-canvas"></canvas></div></div>
    </div>
    <div id="combined" hidden><div class="pane-label"><span id="combined-label">Before / After</span><span>Top-left aligned · original pixels</span></div><div class="viewport" id="combined-viewport"><canvas id="combined-canvas"></canvas></div></div>
  </div>
</section>
</main>
<section id="tests-panel" class="tests-panel" aria-label="Golden tests" hidden>
  <div id="tests-resize" class="tests-resize" role="separator" aria-label="Resize tests panel" aria-orientation="horizontal" aria-controls="tests-panel" tabindex="0" title="Drag to resize · ↑/↓ adjust height · double-click to reset"></div>
  <div class="tests-heading"><strong>Golden tests</strong><span id="test-status" role="status">Ready</span><button id="reload-tests" title="Refresh discovered golden test files">↻ Files</button><button id="run-test" class="primary" disabled>▶ Run</button><button id="stop-test" disabled>Stop</button><button id="close-tests" aria-label="Close tests panel" title="Hide panel (the test keeps running)">×</button></div>
  <div class="tests-body">
    <div class="test-settings">
      <div class="test-scope-row"><label>Run scope<select id="test-scope"><option value="">Choose a scope…</option></select></label><button id="open-selected-test" title="Open the selected test in the system's default application for .dart files" disabled>Open test ↗</button></div>
      <fieldset id="test-fields" aria-label="Test configuration">
        <div class="test-fields-grid">
          <label>Device<select id="test-device"><option value="">All devices</option></select></label>
          <label>Theme<select id="test-theme"><option value="">All themes</option></select></label>
          <label>Locale<select id="test-locale"><option value="">All locales</option></select></label>
        </div>
        <p class="test-note"><button id="discover-tests" type="button" title="Load actual variants using Flutter. Runs test initialization and shared setup hooks, but no golden callbacks or comparisons.">Load variants</button></p>
        <p id="test-options-note" class="test-note">Choose a scope, then load its actual variants.</p>
        <details><summary>More filters</summary><div class="test-fields-grid">
          <label class="test-wide">Test name contains<input id="test-name" placeholder="Any name (literal text)" list="test-names" autocomplete="off"><datalist id="test-names"></datalist></label>
          <label>Text scale<select id="test-textScale"><option value="">All</option></select></label>
          <label>Direction<select id="test-direction"><option value="">All</option></select></label>
          <label>Platform<select id="test-platform"><option value="">All</option></select></label>
          <label>High contrast<select id="test-highContrast"><option value="">All</option></select></label>
        </div><p class="test-note">Name matches literal test-name text, not capture names or a regex. Advanced axes are available only for coverage tests. Lists reflect the last loaded configuration; reload after changing shared config.</p></details>
      </fieldset>
      <p id="test-mapping" class="test-note"></p><p id="test-error" class="test-note" role="alert" hidden></p>
      <p id="test-scope-summary" class="test-note"></p><details id="test-plan-details"><summary>Included tests &amp; commands</summary><ul id="test-included"></ul><pre id="test-command">Choose a scope to preview the commands.</pre></details>
      <p class="test-note">Runs code from this project. Golden tag only · no baseline updates · .golden_ignore does not skip tests. Device, theme and locale are exact names.</p>
    </div>
    <div class="test-output"><div class="test-output-bar"><span id="test-log-hint">Live stdout + stderr</span><div class="test-output-actions"><button id="open-running-test" aria-label="Open test from log" title="Open the current or last test file" disabled>↗</button><button id="copy-test-log" title="Copy the full retained log, commands, filters and results for AI. Earlier output beyond the log limit is marked as truncated." disabled>Copy log</button><button id="copy-test-errors" title="Copy detected error blocks with test context and stack traces for AI" disabled>Copy errors</button><label title="Pauses when you scroll up; resumes at the end or when checked"><input id="test-follow" type="checkbox" checked>Follow logs</label></div></div><pre id="test-logs" role="log" aria-label="Test output" aria-live="off" tabindex="0">Test output will appear here.</pre></div>
  </div>
</section>
<dialog id="test-copy-dialog" aria-labelledby="test-copy-title"><h2 id="test-copy-title">Copy for AI</h2><p class="test-note">Clipboard access is unavailable. Press ⌘C / Ctrl+C to copy the selected report. Nothing is sent automatically; review logs for secrets before sharing.</p><textarea id="test-copy-text" aria-label="Test report to copy" readonly></textarea><button id="close-test-copy">Close copy preview</button></dialog>
<dialog id="revert-dialog" aria-labelledby="revert-title"><h2 id="revert-title">Revert working-tree changes?</h2><p><strong id="revert-count"></strong> Modified or deleted tracked images will be restored from the Git index. <span id="revert-untracked"></span></p><p>Staged changes remain staged. FF Golden cannot undo this action.</p><div class="dialog-actions"><button id="cancel-revert">Cancel</button><button id="confirm-revert" class="danger">Revert changes</button></div></dialog>
<dialog id="delete-failures-dialog" aria-labelledby="delete-failures-title"><h2 id="delete-failures-title">Delete generated failure images?</h2><p id="delete-failures-summary"></p><p>Only image files below directories named exactly <code>failures</code> will be deleted. Git baselines and the index are not changed.</p><div class="dialog-actions"><button id="cancel-delete-failures">Cancel</button><button id="confirm-delete-failures" class="danger">Delete all</button></div></dialog>
<div id="action-menu" class="context-menu" role="menu" aria-label="Image actions" tabindex="-1" hidden></div>
<div id="message" role="status" hidden></div>
<footer><span>Git actions affect only changes. Failure cleanup deletes generated images only from exact failures directories.</span><span id="connection">Connecting…</span></footer>
<script nonce="__SESSION_TOKEN__">
(() => {
  const token = '__SESSION_TOKEN__';
  const $ = (id) => document.getElementById(id);
  let changes = [], failures = [], failureSummary = {caseCount:0,fileCount:0,totalBytes:0,scanning:true,warnings:[]};
  let activeId = null, scope = 'all', selected = new Map();
  let fileLayout = 'tree', showIgnored = false, selectionControls = [], collapsedFolders = new Set();
  let menuState = null, pendingRevert = [];
  let before = null, after = null, loadedRevision = null, loadingRevision = null, loadSequence = 0;
  let polling = false, mutating = false, diffImage = null, diffMask = null, diffBounds = null, diffSummary = '', diffAttempted = false;
  let zoomMode = 'fit', manualScale = 1, renderedScale = 1, renderedMode = 'side', paintKey = null, synchronizing = false;
  const reviewItems = () => scope === 'failures' ? failures : changes;
  const current = () => reviewItems().find(c => c.id === activeId);
  const visible = () => reviewItems().filter(c =>
    (c.failure || !c.ignored || showIgnored) &&
    (c.failure || scope === 'all' || (scope === 'staged') === c.staged) &&
    c.path.toLocaleLowerCase().includes($('search').value.trim().toLocaleLowerCase()));

  function message(text, error = false) {
    $('message').textContent = text; $('message').classList.toggle('error', error); $('message').hidden = !text;
  }
  async function request(path, body) {
    const response = await fetch(path, {
      method: body ? 'POST' : 'GET',
      headers: { 'X-FF-Golden-Token': token, ...(body ? {'Content-Type':'application/json'} : {}) },
      ...(body ? {body:JSON.stringify(body)} : {}),
    });
    if (!response.ok) {
      const data = await response.json(); throw new Error(data.error || 'Request failed.');
    }
    return response;
  }
  const testAxes=['device','theme','locale','name','textScale','direction','platform','highContrast'];
  const testDefaults={device:'All devices',theme:'All themes',locale:'All locales',textScale:'All',direction:'All',platform:'All',highContrast:'All'};
  let testsHeight=360, testsResize=null;
  try { testsHeight=Number(localStorage.getItem('ff-golden-tests-height')) || 360; } catch (_) {}
  function resizeTests(height,save=false) {
    const max=Math.max(100,innerHeight-document.querySelector('header').offsetHeight-document.querySelector('footer').offsetHeight-100);
    const min=Math.min(180,max), actual=Math.round(Math.min(max,Math.max(min,height)));
    $('tests-panel').style.height=actual+'px'; $('tests-panel').style.minHeight=min+'px';
    for(const [key,value] of Object.entries({valuemin:min,valuemax:max,valuenow:actual})) $('tests-resize').setAttribute('aria-'+key,value);
    if(save) {testsHeight=actual;try {localStorage.setItem('ff-golden-tests-height',String(actual));} catch (_) {}}
    restoreTestLogScroll();
  }
  $('tests-resize').addEventListener('pointerdown',event=>{
    if(event.button!==0) return; event.preventDefault();
    testsResize={y:event.clientY,height:$('tests-panel').getBoundingClientRect().height};
    $('tests-resize').setPointerCapture(event.pointerId); document.body.classList.add('resizing-tests');
  });
  const moveTestsResize=event=>{if(testsResize) resizeTests(testsResize.height+testsResize.y-event.clientY,true);};
  const endTestsResize=()=>{testsResize=null;document.body.classList.remove('resizing-tests');};
  for(const type of ['pointermove','mousemove']) window.addEventListener(type,moveTestsResize);
  for(const type of ['pointerup','pointercancel','mouseup','blur']) window.addEventListener(type,endTestsResize);
  $('tests-resize').addEventListener('lostpointercapture',endTestsResize);
  $('tests-resize').addEventListener('dblclick',()=>resizeTests(360,true));
  $('tests-resize').addEventListener('keydown',event=>{
    const height=$('tests-panel').getBoundingClientRect().height, step=event.shiftKey ? 80 : 20;
    if(['ArrowUp','ArrowDown','Home','End'].includes(event.key)) {
      event.preventDefault(); resizeTests(event.key==='Home' ? 0 : event.key==='End' ? innerHeight : height+(event.key==='ArrowUp' ? step : -step),true);
    }
  });
  window.addEventListener('resize',()=>resizeTests(testsHeight));
  let testRun=null, testCursor=0, testPolling=false, testsLoaded=false, testLoading=false, testStarting=false;
  let testPlan=null, testPlanSequence=0, testPlanTimer=null, testLogText='', testGeneration=0, testContextScopeIds=[];
  let testCatalog=null, testOpening=false, testCopying=false;
  let testLogTop=0, testLogLeft=0, testFollowPaused=false;
  const testLogAtEnd=()=>$('test-logs').scrollHeight-$('test-logs').clientHeight-$('test-logs').scrollTop<=4;
  function restoreTestLogScroll() {
    const log=$('test-logs'); if(!log.clientHeight) return;
    log.scrollTop=$('test-follow').checked ? log.scrollHeight : testLogTop;
    log.scrollLeft=testLogLeft;
  }
  $('test-logs').addEventListener('scroll',()=>{
    const log=$('test-logs'); if(!log.clientHeight) return;
    testLogTop=log.scrollTop; testLogLeft=log.scrollLeft;
    if($('test-follow').checked && !testLogAtEnd()) {
      $('test-follow').checked=false; testFollowPaused=true;
    } else if(testFollowPaused && testLogAtEnd()) {
      $('test-follow').checked=true; testFollowPaused=false;
    }
  });
  $('test-follow').addEventListener('change',()=>{
    testFollowPaused=false;
    if($('test-follow').checked) restoreTestLogScroll();
  });
  function updateTestLogs(data,reset,previousCursor) {
    const log=$('test-logs'), visible=!!log.clientHeight;
    if(visible) {
      testLogTop=log.scrollTop; testLogLeft=log.scrollLeft;
      // A scroll event may still be queued when a polling response arrives.
      if(!reset && $('test-follow').checked && !testLogAtEnd()) {
        $('test-follow').checked=false; testFollowPaused=true;
      }
    }
    if(reset || data.truncated) {
      testLogText=data.truncated ? '[Earlier output was truncated]\n' : '';
      log.textContent=testLogText; testLogTop=0; testLogLeft=0;
      testFollowPaused=false;
    }
    let added='';
    for(const entry of data.logs) if(entry.sequence>previousCursor) added+=entry.text.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g,'').replace(/\r\n/g,'\n').replace(/\r/g,'\n');
    if(testLogText.length+added.length>512*1024) {
      const remove=testLogText.length+added.length-500*1024, oldLength=testLogText.length, oldHeight=log.scrollHeight;
      testLogText='[Earlier output was truncated]\n'+testLogText.slice(remove);
      added=added.slice(Math.max(0,remove-oldLength));
      log.textContent=testLogText;
      if(visible) testLogTop=Math.max(0,testLogTop+log.scrollHeight-oldHeight);
    }
    if(added) {
      testLogText+=added;
      if(log.firstChild) log.firstChild.appendData(added);
      else log.append(document.createTextNode(added));
    }
    // Status-only polls leave the DOM, selection and scroll position alone.
    if(reset || data.truncated || added) restoreTestLogScroll();
  }
  const testActive=()=>testStarting || !!testRun?.active;
  const testScopeIds=()=>$('test-scope').value==='__context__' ? testContextScopeIds : [$('test-scope').value];
  function selectedTestId() {
    const ids=testScopeIds().map(id=>testCatalog?.scopes.find(scope=>scope.id===id)?.testId);
    return ids.length && ids.every(id=>id && id===ids[0]) ? ids[0] : null;
  }
  const logTest=()=>testRun?.plan?.commands[testRun.currentIndex];
  async function openTestFile(id) {
    if(!id || testOpening) return;
    testOpening=true; testButtons();
    try {
      const data=await (await request('/api/test-open',{testId:id})).json();
      message('Opened '+data.file+' in the default application.');
    } catch(error) {message(error.message,true);}
    finally {testOpening=false; testButtons();}
  }
  async function copyTestLog(part) {
    if(!testRun?.id || testCopying) return;
    testCopying=true; testButtons();
    try {
      const data=await (await request('/api/test-log',{runId:testRun.id,part})).json();
      try {
        await navigator.clipboard.writeText(data.text);
        message((part==='errors' ? 'Errors with context' : 'Log with run context')+' copied. Review for secrets before sharing with AI.');
      } catch(_) {
        $('test-copy-text').value=data.text; $('test-copy-dialog').showModal(); $('test-copy-text').focus(); $('test-copy-text').select();
      }
    } catch(error) {message(error.message,true);}
    finally {testCopying=false; testButtons();}
  }
  $('open-selected-test').addEventListener('click',()=>openTestFile(selectedTestId()));
  $('open-running-test').addEventListener('click',()=>openTestFile(logTest()?.testId));
  $('copy-test-log').addEventListener('click',()=>copyTestLog('all'));
  $('copy-test-errors').addEventListener('click',()=>copyTestLog('errors'));
  $('close-test-copy').addEventListener('click',()=>$('test-copy-dialog').close());
  function setTestValue(key,value) {
    const field=$('test-'+key);
    if(field.tagName==='SELECT' && value && !Array.from(field.options).some(option=>option.value===value)) field.add(new Option(value,value));
    field.value=value;
  }
  function showTestOptions(data) {
    for(const [key,label] of Object.entries(testDefaults)) {
      const field=$('test-'+key), value=field.value, choices=data.options[key] || [];
      field.replaceChildren(new Option(label,''));
      for(const choice of choices) field.add(new Option(key==='highContrast' ? (choice==='true' ? 'On' : 'Off') : choice,choice));
      if(value && !choices.includes(value)) field.add(new Option(value+(data.complete ? ' (no match)' : ' (not loaded)'),value));
      field.value=value; field.disabled=!choices.length && !value;
    }
    $('test-names').replaceChildren(...data.names.map(name=>new Option(name,name)));
    $('test-options-note').textContent=data.customTests
      ? 'Some files declare custom golden-tagged tests. Lists cover ff_golden variants only; Name and Run remain available for custom tests.'
      : data.complete
      ? data.matching+' of '+data.total+' variants match'+(!data.coverage ? ' · legacy API: device/theme/locale only.' : '.')
      : (data.loadedFiles ? 'Variants loaded for '+data.loadedFiles+'/'+data.fileCount+' files. ' : '')+'Load variants to fill the lists from the test configuration.';
  }
  function testError(text='') { $('test-error').textContent=text; $('test-error').hidden=!text; }
  function testButtons() {
    $('test-scope').disabled=testActive() || testLoading;
    $('open-selected-test').disabled=testOpening || testLoading || !selectedTestId();
    $('open-selected-test').title=selectedTestId() ? 'Open the selected test in the system\'s default application for .dart files' : 'Choose one test file or use a file link in Included tests & commands';
    $('open-running-test').disabled=testOpening || !logTest()?.testId;
    $('open-running-test').title=logTest() ? 'Open '+logTest().file : 'Open the current or last test file';
    for(const id of ['copy-test-log','copy-test-errors']) $(id).disabled=testCopying || !testRun?.id || !testCursor;
    $('run-test').disabled=testActive() || testLoading || !testPlan;
    $('stop-test').disabled=!testRun?.active || testRun.status==='stopping';
    $('test-fields').disabled=testActive() || testLoading;
    $('reload-tests').disabled=testActive() || testLoading;
    $('discover-tests').disabled=testActive() || testLoading || !$('test-scope').value;
    $('show-tests').textContent=testActive() ? 'Tests · running' : 'Tests';
  }
  async function openTests(context=null) {
    $('tests-panel').hidden=false; $('show-tests').setAttribute('aria-expanded','true');
    resizeTests(testsHeight);
    await pollTest();
    if(!testActive() && !testLoading && (context || !testsLoaded)) await loadTests(context);
  }
  async function loadTests(context=null) {
    testLoading=true; testPlan=null; ++testPlanSequence; testButtons(); testError();
    const previous=$('test-scope').value;
    try {
      const data=await (await request('/api/tests')).json();
      testCatalog=data;
      const select=$('test-scope'); select.replaceChildren(new Option('Choose a scope…',''));
      for(const [kind,label] of [['project','Project'],['folder','Folders'],['file','Test files'],['scenario','Scenarios']]) {
        const group=document.createElement('optgroup'); group.label=label;
        for(const scope of data.scopes.filter(scope=>scope.kind===kind)) {
          const title=kind==='project' ? 'All golden test files under --project' : scope.path;
          group.append(new Option(title+(kind==='project'||kind==='folder' ? ' ('+scope.fileCount+' files)' : ''),scope.id));
        }
        if(group.children.length) select.append(group);
      }
      if(context) {
        const mapped=await (await request('/api/test-context',{
          imageIds:context.items.map(image=>image.id),
          ...(context.folder ? {folder:context.folder} : {}), ...(context.wholeFiles ? {wholeFiles:true} : {}),
        })).json();
        testContextScopeIds=mapped.scopeIds;
        if(mapped.scopeIds.length===1) select.value=mapped.scopeIds[0];
        else if(mapped.scopeIds.length) {select.add(new Option('Selection · '+mapped.scopeIds.length+' scopes','__context__'));select.value='__context__';}
        $('test-mapping').textContent=mapped.mapping;
        for(const key of testAxes) if(mapped.filters[key]) setTestValue(key,mapped.filters[key]);
      } else {
        if(previous==='__context__' && testContextScopeIds.every(id=>data.scopes.some(scope=>scope.id===id))) {
          select.add(new Option('Selection · '+testContextScopeIds.length+' scopes','__context__'));select.value=previous;
        } else select.value=data.scopes.some(scope=>scope.id===previous) ? previous : '';
        if(!select.value && data.tests.length===1) select.value=data.tests[0].id;
        $('test-mapping').textContent=data.tests.length ? data.tests.length+' golden test file(s). Scenario discovery uses static declarations and run manifests; dynamic scenarios can be selected with the name filter.' : 'No golden test files found under --project.';
      }
      if(data.warnings.length) testError(data.warnings.join('\n'));
      testsLoaded=true;
    } catch(error) {testError(error.message);}
    finally {testLoading=false; testButtons(); scheduleTestPlan();}
  }
  function scheduleTestPlan() {
    clearTimeout(testPlanTimer); const sequence=++testPlanSequence; testPlan=null; testButtons();
    $('test-included').replaceChildren(); $('test-scope-summary').textContent='';
    if(!$('test-scope').value) { $('test-command').textContent='Choose a scope to preview the commands.'; return; }
    $('test-command').textContent='Preparing command…';
    testPlanTimer=setTimeout(async()=>{
      const body={scopeIds:testScopeIds(), filters:Object.fromEntries(testAxes.map(key=>[key,$('test-'+key).value]))};
      try {
        const options=await (await request('/api/test-options',body)).json();
        if(sequence!==testPlanSequence) return;
        showTestOptions(options);
        const plan=await (await request('/api/test-plan',body)).json();
        if(sequence!==testPlanSequence) return;
        testPlan=body; $('test-command').textContent=plan.commands.map((command,i)=>'['+(i+1)+'/'+plan.fileCount+'] '+command.directory+'\n$ '+command.command).join('\n\n');
        $('test-scope-summary').textContent=plan.fileCount+' file(s) · sequential queue · filters apply to every file';
        for(const command of plan.commands) {
          const item=document.createElement('li'), link=document.createElement('button'); link.type='button'; link.textContent=command.file+' ↗'; link.title='Open test in the default application'; link.addEventListener('click',()=>openTestFile(command.testId));
          item.append(link,document.createTextNode(' — '+(command.scenarios.length ? command.scenarios.join(', ') : 'all golden tests'))); $('test-included').append(item);
        }
        testError();
      } catch(error) {if(sequence===testPlanSequence) {testError(error.message); $('test-command').textContent='Command unavailable.';}}
      finally {if(sequence===testPlanSequence) testButtons();}
    },180);
  }
  function showTestRun(data) {
    const changed=data.id!==testRun?.id, finished=!!testRun?.active && !data.active;
    if(changed) testCursor=0;
    const previousCursor=testCursor;
    testRun=data; testCursor=Math.max(testCursor,data.cursor);
    if(data.id) {
      updateTestLogs(data,changed,previousCursor);
      const seconds=Math.max(0,Math.floor(((data.finished ? Date.parse(data.finished) : Date.now())-Date.parse(data.started))/1000));
      const status=data.plan.discovery ? (data.status==='passed' ? 'Variants loaded' : 'Variants · '+data.status) : data.status[0].toUpperCase()+data.status.slice(1);
      $('test-status').textContent=status+' · '+data.completed+'/'+data.total+' files · '+seconds+'s'+(data.exitCode!==null ? ' · exit '+data.exitCode : '');
      $('test-status').dataset.status=data.status;
      const job=data.plan.commands[data.currentIndex];
      $('test-log-hint').textContent=$('test-log-hint').title=job ? '['+(data.currentIndex+1)+'/'+data.total+'] '+job.file : 'Preparing queue…';
    }
    testButtons(); if(finished) {refresh();scheduleTestPlan();}
  }
  async function pollTest() {
    if(testPolling) return; testPolling=true; const generation=testGeneration;
    try {
      const data=await (await request('/api/test-run?after='+testCursor+'&runId='+encodeURIComponent(testRun?.id || ''))).json();
      if(generation===testGeneration) showTestRun(data);
    } catch(error) {testError('Test status unavailable: '+error.message);}
    finally {testPolling=false;}
  }
  $('show-tests').addEventListener('click',()=>openTests());
  $('close-tests').addEventListener('click',()=>{
    $('tests-panel').hidden=true; $('show-tests').setAttribute('aria-expanded','false'); $('show-tests').focus();
  });
  $('reload-tests').addEventListener('click',()=>loadTests());
  $('test-scope').addEventListener('change',()=>{
    $('test-mapping').textContent='Scope changed. Existing variant filters are preserved.'; scheduleTestPlan();
  });
  for(const key of testAxes) $('test-'+key).addEventListener('input',scheduleTestPlan);
  $('discover-tests').addEventListener('click',async()=>{
    if(!$('test-scope').value || testActive()) return;
    ++testGeneration; testStarting=true; testButtons(); testError();
    try {showTestRun(await (await request('/api/test-discover',{scopeIds:testScopeIds(),filters:{}})).json());}
    catch(error) {testError(error.message); await pollTest();}
    finally {testStarting=false; testButtons();}
  });
  $('run-test').addEventListener('click',async()=>{
    if(!testPlan || testActive()) return;
    ++testGeneration; testStarting=true; testButtons(); testError();
    try {showTestRun(await (await request('/api/test-run',testPlan)).json());}
    catch(error) {testError(error.message); await pollTest();}
    finally {testStarting=false; testButtons();}
  });
  $('stop-test').addEventListener('click',async()=>{
    if(!testRun?.active) return;
    $('stop-test').disabled=true;
    try { await request('/api/test-stop',{runId:testRun.id}); await pollTest(); }
    catch(error) {testError(error.message); testButtons();}
  });
  setInterval(()=>{if(testRun?.active || !$('tests-panel').hidden) pollTest();},500);
  pollTest();
  function updateButtons() {
    const failureMode = scope === 'failures';
    const values = [...selected.values()];
    const included = values.filter(c => !c.ignored);
    const unstaged = included.filter(c => !c.staged).length, staged = included.filter(c => c.staged).length;
    const revertable = values.filter(c => !c.staged).length;
    $('stage-selected').textContent = $('stage-selected').title = 'Stage (' + unstaged + ')';
    $('unstage-selected').textContent = $('unstage-selected').title = 'Unstage (' + staged + ')';
    $('revert-selected').textContent = $('revert-selected').title = 'Revert (' + revertable + ')';
    $('stage-selected').disabled = !unstaged || mutating;
    $('unstage-selected').disabled = !staged || mutating;
    $('revert-selected').disabled = !revertable || mutating;
    $('clear-selected').disabled = !values.length || mutating;
    $('selection-actions').disabled = !values.length || mutating;
    const item = current();
    $('git-selection').hidden = failureMode;
    $('failure-selection').hidden = !failureMode;
    $('toggle-stage').hidden = $('revert-file').hidden = $('file-actions').hidden = failureMode;
    $('delete-failures').textContent = 'Delete all failure images (' + failureSummary.fileCount + ')';
    $('delete-failures').title = testActive() ? 'Stop the running golden tests before cleanup' : $('delete-failures').textContent;
    $('delete-failures').disabled = !failureSummary.fileCount || failureSummary.scanning || mutating || testActive();
    $('toggle-stage').textContent = item?.staged ? 'Unstage file' : 'Stage file';
    $('toggle-stage').disabled = failureMode || !item || item.ignored || loadedRevision !== item.revision || mutating;
    $('revert-file').disabled = failureMode || !item || item.staged || loadedRevision !== item.revision || mutating;
    $('file-actions').disabled = failureMode || !item || mutating;
    if (item) $('context').textContent = item.failure
      ? 'Generated failure · Expected → Actual · ' + item.artifactCount + ' artifact' + (item.artifactCount===1 ? '' : 's')
      : (item.staged ? 'Staged · HEAD → Index' : 'Unstaged · Index → Working tree') + (item.ignored ? ' · Ignored by .golden_ignore' : '');
    $('previous').disabled = $('next').disabled = visible().length < 2;
    document.querySelectorAll('.zoom-bar button, #zoom-percent, #highlight, #highlight-strength').forEach(control => { control.disabled = !loadedRevision; });
    syncSelectionControls();
  }
  function syncSelectionControls() {
    for (const {check,items} of selectionControls) {
      const count = items.filter(item => selected.has(item.id)).length;
      check.checked = count === items.length;
      check.indeterminate = count > 0 && count < items.length;
      check.disabled = mutating;
    }
  }
  function selectionCheckbox(items,label) {
    const check = document.createElement('input'); check.type = 'checkbox'; check.setAttribute('aria-label',label);
    selectionControls.push({check,items});
    check.addEventListener('click',event => event.stopPropagation());
    check.addEventListener('change',() => {
      for (const item of items) { if(check.checked) selected.set(item.id,item); else selected.delete(item.id); }
      updateButtons();
    });
    return check;
  }
  function closeMenu(restoreFocus=false) {
    if (!menuState) return;
    const {origin} = menuState; menuState=null;
    $('action-menu').hidden=true;
    document.querySelectorAll('.context-target').forEach(el=>el.classList.remove('context-target'));
    document.querySelectorAll('[aria-controls=action-menu]').forEach(el=>el.setAttribute('aria-expanded','false'));
    if (restoreFocus) (origin?.isConnected && !origin.disabled ? origin : $('search')).focus({preventScroll:true});
  }
  function positionMenu(origin,x,y) {
    const menu=$('action-menu'); menu.hidden=false;
    const box=origin.getBoundingClientRect();
    const left=x ?? (origin.hasAttribute('aria-controls') ? box.right-menu.offsetWidth : box.left);
    const top=y ?? (box.bottom+5+menu.offsetHeight<=innerHeight-8 ? box.bottom+5 : box.top-menu.offsetHeight-5);
    menu.style.left=Math.max(8,Math.min(left,innerWidth-menu.offsetWidth-8))+'px';
    menu.style.top=Math.max(8,Math.min(top,innerHeight-menu.offsetHeight-8))+'px';
    const first=menu.querySelector('button[role^=menuitem]:not(:disabled)');
    if(first) {first.tabIndex=0;first.focus({preventScroll:true});}
  }
  function openViewOptions() {
    closeMenu();
    const origin=$('file-view-options'),menu=$('action-menu');menu.replaceChildren();
    menuState={origin};origin.setAttribute('aria-expanded','true');menu.setAttribute('aria-label','File view options');
    function command(id,label,run,{disabled=false,checked}={}) {
      const button=document.createElement('button');button.id=id;button.tabIndex=-1;button.disabled=disabled;
      button.setAttribute('role',checked===undefined ? 'menuitem' : 'menuitemcheckbox');
      if(checked!==undefined) button.setAttribute('aria-checked',String(checked));
      button.textContent=label;button.addEventListener('click',()=>{closeMenu(true);run();});menu.append(button);
    }
    const noFolders=fileLayout!=='tree' || !document.querySelector('details.folder');
    command('collapse-folders','Collapse all folders',()=>document.querySelectorAll('details.folder').forEach(folder=>{collapsedFolders.add(folder.dataset.folderKey);folder.open=false;}),{disabled:noFolders});
    command('expand-folders','Expand all folders',()=>{collapsedFolders.clear();document.querySelectorAll('details.folder').forEach(folder=>{folder.open=true;});},{disabled:noFolders});
    if(scope!=='failures') {
      const separator=document.createElement('div');separator.setAttribute('role','separator');menu.append(separator);
      command('show-ignored','',()=>setShowIgnored(!showIgnored),{checked:showIgnored});
    }
    updateViewOptions();positionMenu(origin);
  }
  function updateViewOptions() {
    const count=new Set(changes.filter(c=>c.ignored).map(c=>c.path)).size;
    $('ignored-active').hidden=scope==='failures' || !showIgnored;$('ignored-active').textContent='+ ignored ('+count+') ×';
    $('file-view-options').title=scope==='failures' ? 'File view options · folders' : 'File view options · '+count+' ignored file(s)'+(showIgnored ? ' shown' : ' hidden');
    if($('show-ignored')) {
      $('show-ignored').textContent=(showIgnored ? '✓ ' : '')+'Show ignored ('+count+')';
      $('show-ignored').setAttribute('aria-checked',String(showIgnored));
    }
    for(const id of ['collapse-folders','expand-folders']) if($(id)) $(id).disabled=fileLayout!=='tree' || !document.querySelector('details.folder');
  }
  function setShowIgnored(value) {
    showIgnored=value;
    if(!showIgnored) for(const [id,item] of selected) if(item.ignored) selected.delete(id);
    const items=visible();if(!items.some(c=>c.id===activeId)) choose(items[0]?.id || null);else renderList();
  }
  function openMenu(items,{origin,title,selection=false,folder,x,y}) {
    closeMenu();
    if (mutating || !items.length) return;
    // Keep the reviewed revisions captured here; mutations still reject stale data.
    const menu=$('action-menu'); menu.replaceChildren();
    menuState={origin}; origin.classList.add('context-target');
    if(origin.hasAttribute('aria-expanded')) origin.setAttribute('aria-expanded','true');
    menu.setAttribute('aria-label',title);
    const heading=document.createElement('div'); heading.className='context-title'; heading.textContent=title; heading.title=title; heading.setAttribute('aria-hidden','true'); menu.append(heading);
    function command(label,count,run,hint,danger=false) {
      const button=document.createElement('button'); button.setAttribute('role','menuitem'); button.tabIndex=-1;
      if(danger) button.classList.add('danger');
      const text=document.createElement('span'); text.textContent=label; button.append(text);
      if(count!==null) { const badge=document.createElement('span'); badge.className='menu-count'; badge.textContent='('+count+')'; button.append(badge); }
      if(hint) button.title=hint;
      button.addEventListener('click',()=>{closeMenu(true);run();}); menu.append(button);
    }
    function separator() { const line=document.createElement('div'); line.setAttribute('role','separator'); menu.append(line); }
    const staged=items.filter(c=>c.staged && !c.ignored), unstaged=items.filter(c=>!c.staged && !c.ignored);
    const revertable=items.filter(c=>!c.staged);
    const included=items.filter(c=>!c.ignored), excluded=items.filter(c=>c.ignored);
    command('Run tests…',null,()=>openTests({items,folder}),'Choose scenario, folder or project scope and preview the queue');
    if(!folder) command('Run test file(s)…',null,()=>openTests({items,wholeFiles:true}),'Run entire source test files with the selected variant filters');
    separator();
    if(unstaged.length) command('Stage',unstaged.length,()=>mutate('stage',unstaged));
    if(staged.length) command('Unstage',staged.length,()=>mutate('unstage',staged));
    if(staged.length || unstaged.length) separator();
    if(revertable.length) { command('Revert changes',revertable.length,()=>confirmRevert(revertable),'Restore tracked files from the index and delete untracked files',true); separator(); }
    if(included.length) command('Ignore',new Set(included.map(c=>c.path)).size,()=>mutate('ignore',included),'Add exact paths to .golden_ignore');
    if(excluded.length) command('Stop ignoring',new Set(excluded.map(c=>c.path)).size,()=>mutate('unignore',excluded),'Remove exact paths from .golden_ignore');
    separator();
    if(selection) command('Clear selection',null,()=>{selected.clear();renderList();});
    else {
      const allSelected=items.every(c=>selected.has(c.id));
      command(allSelected ? 'Deselect' : 'Select',items.length,()=>{
        for(const item of items) {if(allSelected) selected.delete(item.id); else selected.set(item.id,item);}
        updateButtons();
      });
    }
    positionMenu(origin,x,y);
  }
  function bindContextMenu(element,getContext,origin=element) {
    function open(event,keyboard=false) {
      const context=getContext(); if(!context.items.length) return;
      event.preventDefault(); event.stopPropagation();
      openMenu(context.items,{...context,origin,...(!keyboard ? {x:event.clientX,y:event.clientY} : {})});
    }
    element.addEventListener('contextmenu',event=>open(event,event.clientX===0 && event.clientY===0));
    element.addEventListener('keydown',event=>{if(event.key==='ContextMenu' || (event.shiftKey && event.key==='F10')) open(event,true);});
  }
  function selectionContext() {
    const items=[...selected.values()]; return {items,title:'Selection · '+items.length+' changes',selection:true};
  }
  function differenceSummary(items) {
    const differences=items.map(item=>item.difference);
    if(differences.some(value=>!value || value.status==='pending')) return {text:'…',className:'pending',title:'Calculating pixel difference in Dart…'};
    const unavailable=differences.find(value=>value.status!=='ready');
    if(unavailable) return {text:'—',className:'unavailable',title:unavailable.error || 'Pixel difference is unavailable.'};
    const changed=differences.reduce((sum,value)=>sum+value.changedPixels,0);
    const total=differences.reduce((sum,value)=>sum+value.totalPixels,0);
    const percent=total ? changed/total*100 : 0;
    const text=percent===0 ? '0%' : percent===100 ? '100%' : percent<.01 ? '<0.01%' : percent.toFixed(2)+'%';
    return {text,className:'ready',title:'Pixel difference: '+changed.toLocaleString()+' / '+total.toLocaleString()+' pixels ('+text+')'};
  }
  function differenceValue(items) {
    const summary=differenceSummary(items), value=document.createElement('span');
    value.className='difference-value '+summary.className; value.textContent=summary.text; value.title=summary.title;
    value.setAttribute('aria-label',summary.title); return value;
  }
  function fileRow(item) {
    const row = document.createElement('div'); row.className = 'file' + (item.id === activeId ? ' active' : '');
    const check = item.failure ? null : selectionCheckbox([item],'Select ' + item.path + (item.staged ? ' staged' : ' unstaged'));
    const button = document.createElement('button'); button.title = item.path;
    const badge = document.createElement('span'); badge.className = 'badge' + (item.status === 'D' ? ' deleted' : ['A','?'].includes(item.status) ? ' added' : '');
    if(item.failure) badge.classList.add('deleted');
    badge.textContent = item.failure ? 'F' : item.status;
    const text = document.createElement('span'); text.className = 'file-text';
    const name = document.createElement('span'); name.className = 'file-name'; name.textContent = item.path.split('/').pop(); text.append(name);
    if (fileLayout === 'list') {
      const directory = document.createElement('span'); directory.className = 'file-dir'; directory.textContent = item.path.includes('/') ? item.path.slice(0,item.path.lastIndexOf('/')) : '/';
      text.append(directory);
    }
    if (item.ignored) { const ignored = document.createElement('span'); ignored.className='ignored-label'; ignored.textContent='Ignored'; text.append(ignored); }
    button.append(badge,text,differenceValue([item])); button.addEventListener('click',() => choose(item.id));
    if(check) row.append(check); row.append(button);
    if(!item.failure) bindContextMenu(row,()=>selected.has(item.id) ? selectionContext() : {items:[item],title:(item.staged ? 'Staged · ' : 'Unstaged · ')+item.path},button);
    return row;
  }
  function fileTree(items,staged) {
    const failure = !!items[0]?.failure;
    const node = (path='') => ({path,folders:new Map(),files:[],items:[]});
    const root = node();
    for (const item of items) {
      let branch = root; branch.items.push(item);
      const parts = item.path.split('/'); parts.pop();
      for (const part of parts) {
        if (!branch.folders.has(part)) branch.folders.set(part,node(branch.path ? branch.path+'/'+part : part));
        branch = branch.folders.get(part); branch.items.push(item);
      }
      branch.files.push(item);
    }
    function children(branch,parent) {
      for (const [name,original] of [...branch.folders].sort(([a],[b]) => a.localeCompare(b,undefined,{numeric:true}))) {
        let folder = original, label = name;
        // Compact single-child folders, while retaining the complete literal path.
        while (!folder.files.length && folder.folders.size === 1) {
          const [nextName,next] = folder.folders.entries().next().value; label += ' / ' + nextName; folder = next;
        }
        const key = (failure ? 'failures:' : staged ? 'staged:' : 'unstaged:') + folder.path;
        const details = document.createElement('details'); details.className = 'folder'; details.dataset.folderKey = key;
        details.open = !!$('search').value.trim() || !collapsedFolders.has(key);
        const summary = document.createElement('summary'); summary.title = folder.path;
        const check = failure ? null : selectionCheckbox(folder.items,'Select folder ' + folder.path + (staged ? ' staged' : ' unstaged'));
        const text = document.createElement('span'); text.className = 'folder-name'; text.textContent = label;
        const count = document.createElement('span'); count.className = 'folder-count'; count.textContent = folder.items.length;
        if(check) summary.append(check); summary.append(text,count,differenceValue(folder.items));
        if(!failure) bindContextMenu(summary,()=>({items:folder.items,folder:folder.path,title:folder.path+' · '+folder.items.length+' image(s)'}));
        const content = document.createElement('div'); content.className = 'folder-children'; children(folder,content);
        details.append(summary,content);
        details.addEventListener('toggle',() => {
          if (!details.isConnected || $('search').value.trim()) return;
          if(details.open) collapsedFolders.delete(key); else collapsedFolders.add(key);
        });
        parent.append(details);
      }
      for (const item of branch.files) parent.append(fileRow(item));
    }
    const fragment = document.createDocumentFragment(); children(root,fragment); return fragment;
  }
  function renderList() {
    closeMenu();
    const fragment = document.createDocumentFragment(), items = visible();
    const available = changes.filter(c=>!c.ignored || showIgnored);
    const counts = [items.length,available.filter(c=>!c.staged).length,available.filter(c=>c.staged).length,failures.length];
    for(const [id,value] of [['shown-count',counts[0]],['unstaged-count',counts[1]],['staged-count',counts[2]],['failure-count',counts[3]]]) {
      if($(id).textContent!==String(value)) $(id).textContent=String(value);
    }
    const countLabel=scope==='failures'
      ? 'Showing '+counts[0]+' of '+failures.length+' generated failure comparisons from '+failureSummary.fileCount+' image files.'
      : 'Showing '+counts[0]+' of '+available.length+' changes: '+counts[1]+' unstaged and '+counts[2]+' staged. '+counts[3]+' failure comparisons are available.';
    if($('file-count').getAttribute('aria-label')!==countLabel) $('file-count').setAttribute('aria-label',countLabel);
    const ignoredCount = new Set(changes.filter(c=>c.ignored).map(c=>c.path)).size;
    selectionControls = [];
    for (const staged of (scope==='failures' ? [false] : [false, true])) {
      const group = scope==='failures' ? items : items.filter(c => c.staged === staged);
      if (!group.length) continue;
      const title = document.createElement('div'); title.className = 'group-title';
      title.textContent = (scope==='failures' ? 'Failure artifacts' : staged ? 'Staged' : 'Unstaged') + ' · ' + group.length; fragment.append(title);
      if(scope!=='failures') {title.tabIndex=0; bindContextMenu(title,()=>({items:group,title:(staged ? 'Staged' : 'Unstaged')+' · '+group.length+' images'}));}
      if (fileLayout === 'tree') fragment.append(fileTree(group,staged));
      else for (const item of group) fragment.append(fileRow(item));
    }
    if (!items.length) {
      const empty = document.createElement('div'); empty.className = 'empty-list';
      empty.textContent = scope==='failures'
        ? (failureSummary.scanning ? 'Scanning generated failure images…' : failures.length ? 'No failure comparisons match this search.' : 'No generated Flutter golden failure images found.')
        : changes.length ? 'No images match this filter.' + (ignoredCount && !showIgnored ? ' Use ⋯ → Show ignored to review excluded files.' : '') : 'No changed PNG, JPEG or WebP images. Regenerate your goldens to start reviewing.';
      fragment.append(empty);
    }
    $('files').replaceChildren(fragment);
    updateViewOptions();
    updateButtons();
  }
  function applyData(data) {
    const previousPath = current()?.path;
    $('repository').textContent = data.repository + (data.input === '.' ? '' : ' / ' + data.input);
    $('repository').title = $('repository').textContent;
    const warnings=[...data.warnings,...(data.failures?.warnings || [])];
    $('warnings').textContent = warnings.join('\n'); $('warnings').hidden = !warnings.length;
    const changed = JSON.stringify(changes) !== JSON.stringify(data.changes) || JSON.stringify(failures) !== JSON.stringify(data.failures?.items || []) || JSON.stringify(failureSummary) !== JSON.stringify(data.failures || {});
    changes = data.changes;
    failureSummary = data.failures || {items:[],caseCount:0,fileCount:0,totalBytes:0,scanning:false,warnings:[]};
    failures = failureSummary.items || [];
    for (const [id, item] of selected) {
      if (!changes.some(c => c.id === id && c.revision === item.revision && c.ignored === item.ignored)) selected.delete(id);
    }
    const items = visible();
    if (!items.some(c => c.id === activeId)) activeId = items.find(c => c.path === previousPath)?.id || items[0]?.id || null;
    if (changed) renderList();
    if (current()?.revision !== loadedRevision && current()?.revision !== loadingRevision) loadCurrent();
    if (!current()) clearImage();
    $('connection').textContent = 'Live · refreshes every 2s';
  }
  async function refresh() {
    if (polling || mutating) return;
    polling = true;
    try { applyData(await (await request('/api/changes' + (scope==='failures' ? '?failures=true' : ''))).json()); }
    catch (error) { $('connection').textContent = 'Disconnected'; message(error.message + ' Is the CLI still running?', true); }
    finally { polling = false; }
  }
  function choose(id) {
    activeId = id;
    const item = current();
    if (item) for (const key of collapsedFolders) {
      const prefix = item.failure ? 'failures:' : item.staged ? 'staged:' : 'unstaged:';
      if (key.startsWith(prefix) && item.path.startsWith(key.slice(prefix.length)+'/')) collapsedFolders.delete(key);
    }
    renderList(); loadCurrent();
  }
  function clearImage() {
    loadSequence++; loadedRevision = loadingRevision = null; before = after = diffImage = diffMask = diffBounds = null; paintKey = null;
    $('filename').textContent = scope==='failures' ? 'Failure artifacts' : 'Image changes'; $('context').textContent = 'Choose an image to compare';
    $('metrics').textContent = ''; $('side').hidden = $('combined').hidden = true; $('empty').hidden = false;
    $('empty').firstElementChild.textContent = 'No image selected'; $('empty').lastElementChild.textContent = scope==='failures' ? 'Generated failures appear here automatically.' : 'Changes appear here automatically.';
    updateButtons();
  }
  async function loadImage(item, side) {
    if (!item[side === 'before' ? 'hasBefore' : 'hasAfter']) return null;
    const params = new URLSearchParams({id:item.id, revision:item.revision, side, ...(item.failure ? {failure:'true'} : {})});
    const blob = await (await request('/api/image?' + params)).blob();
    const url = URL.createObjectURL(blob);
    try {
      const image = new Image(); image.src = url; await image.decode();
      return image;
    } finally { URL.revokeObjectURL(url); }
  }
  async function loadCurrent() {
    const item = current(); if (!item) return clearImage();
    const sequence = ++loadSequence; loadedRevision = null; loadingRevision = item.revision; updateButtons();
    $('filename').textContent = item.path;
    $('empty').firstElementChild.textContent = 'Loading comparison…'; $('empty').lastElementChild.textContent = '';
    $('empty').hidden = false; $('side').hidden = $('combined').hidden = true;
    try {
      const pair = await Promise.all([loadImage(item,'before'),loadImage(item,'after')]);
      if (sequence !== loadSequence) return;
      [before,after] = pair; diffImage = diffMask = diffBounds = null; diffSummary = ''; diffAttempted = false; paintKey = null;
      if (Math.max(before?.naturalWidth || 0,after?.naturalWidth || 0) * Math.max(before?.naturalHeight || 0,after?.naturalHeight || 0) > 16000000) {
        throw new Error('Preview exceeds the 16 megapixel limit. Open this image in an external viewer.');
      }
      loadedRevision = item.revision; loadingRevision = null;
      $('before-label').textContent = item.failure ? 'Expected' : item.staged ? 'HEAD' : 'Index';
      $('after-label').textContent = item.failure ? 'Actual' : item.staged ? 'Index' : 'Working tree';
      $('before-size').textContent = dimensions(before); $('after-size').textContent = dimensions(after);
      $('empty').hidden = true; render(); updateButtons();
    } catch (error) {
      if (sequence !== loadSequence) return;
      loadingRevision = null;
      $('empty').firstElementChild.textContent = 'Preview unavailable';
      $('empty').lastElementChild.textContent = error.message || 'Unable to decode image.';
      $('metrics').textContent = ''; updateButtons();
    }
  }
  function dimensions(image) { return image ? image.naturalWidth + ' × ' + image.naturalHeight : 'Not present'; }
  function sizeCanvas(canvas,width,height) { if (canvas.width !== width) canvas.width = width; if (canvas.height !== height) canvas.height = height; }
  function pixels(image,width,height) {
    const canvas = document.createElement('canvas'); canvas.width = width; canvas.height = height;
    const ctx = canvas.getContext('2d',{willReadFrequently:true}); if (image) ctx.drawImage(image,0,0);
    return ctx.getImageData(0,0,width,height);
  }
  function buildDiff(width,height) {
    if (diffAttempted) return;
    diffAttempted = true;
    const old = pixels(before,width,height).data, now = pixels(after,width,height).data;
    diffImage = new ImageData(width,height); const mask = new ImageData(width,height);
    let changed = 0, total = 0, minX = width, minY = height, maxX = -1, maxY = -1;
    for (let y=0; y<height; y++) for (let x=0; x<width; x++) {
      const oldPresent = !!before && x<before.naturalWidth && y<before.naturalHeight;
      const newPresent = !!after && x<after.naturalWidth && y<after.naturalHeight;
      if (!oldPresent && !newPresent) continue;
      total++; const i=(y*width+x)*4;
      const different = oldPresent !== newPresent || old[i] !== now[i] || old[i+1] !== now[i+1] || old[i+2] !== now[i+2] || old[i+3] !== now[i+3];
      if (different) {
        changed++; minX=Math.min(minX,x); minY=Math.min(minY,y); maxX=Math.max(maxX,x); maxY=Math.max(maxY,y);
        diffImage.data[i]=mask.data[i]=255; diffImage.data[i+1]=mask.data[i+1]=82;
        diffImage.data[i+2]=mask.data[i+2]=158; diffImage.data[i+3]=mask.data[i+3]=255;
      } else {
        diffImage.data[i]=now[i]; diffImage.data[i+1]=now[i+1]; diffImage.data[i+2]=now[i+2]; diffImage.data[i+3]=Math.round(now[i+3]*.3);
      }
    }
    diffBounds = changed ? {x:minX,y:minY,width:maxX-minX+1,height:maxY-minY+1} : null;
    diffMask = document.createElement('canvas'); diffMask.width=width; diffMask.height=height;
    diffMask.getContext('2d').putImageData(mask,0,0);
    diffSummary = ' · ' + changed.toLocaleString() + ' / ' + total.toLocaleString() + ' pixels changed (' + (total ? changed/total*100 : 0).toFixed(2) + '%) · browser diagnostic';
  }
  function imageSize() { return {width:Math.max(before?.naturalWidth || 0,after?.naturalWidth || 0),height:Math.max(before?.naturalHeight || 0,after?.naturalHeight || 0)}; }
  function viewports(mode=renderedMode) { return mode==='side' ? [$('before-viewport'),$('after-viewport')] : [$('combined-viewport')]; }
  function captureAnchor(viewport=viewports()[0],clientX,clientY) {
    if (!loadedRevision) return null;
    const box=viewport.getBoundingClientRect(), canvas=viewport.querySelector('canvas').getBoundingClientRect();
    const x=clientX ?? box.left+viewport.clientWidth/2, y=clientY ?? box.top+viewport.clientHeight/2;
    return {viewport,x:(x-canvas.left)/renderedScale,y:(y-canvas.top)/renderedScale,fx:(x-box.left)/viewport.clientWidth,fy:(y-box.top)/viewport.clientHeight};
  }
  function syncViewports(source) {
    if (renderedMode!=='side' || !viewports().includes(source)) return;
    synchronizing=true;
    for (const target of viewports()) if(target!==source) { target.scrollLeft=source.scrollLeft; target.scrollTop=source.scrollTop; }
    requestAnimationFrame(()=>{synchronizing=false;});
  }
  function restoreAnchor(anchor) {
    if (!anchor || !loadedRevision) return;
    const viewport=viewports().includes(anchor.viewport) ? anchor.viewport : viewports()[0];
    const box=viewport.getBoundingClientRect(), canvas=viewport.querySelector('canvas').getBoundingClientRect();
    viewport.scrollLeft += canvas.left+anchor.x*renderedScale-(box.left+anchor.fx*viewport.clientWidth);
    viewport.scrollTop += canvas.top+anchor.y*renderedScale-(box.top+anchor.fy*viewport.clientHeight);
    syncViewports(viewport);
  }
  function setZoom(scale,anchor=captureAnchor()) {
    if (!loadedRevision || !Number.isFinite(scale)) return;
    zoomMode='manual'; manualScale=Math.max(.01,Math.min(8,scale)); render(); restoreAnchor(anchor);
  }
  function fitZoom(mode='fit') {
    zoomMode=mode; render();
    for (const viewport of viewports()) { viewport.scrollLeft=0; viewport.scrollTop=0; }
  }
  function zoomToChanges() {
    if (!loadedRevision) return;
    const {width,height}=imageSize(); buildDiff(width,height);
    if (!diffBounds) { message('No changed pixels in this comparison.'); render(); return; }
    const viewport=viewports()[0], bounds=diffBounds;
    setZoom(Math.min((viewport.clientWidth-48)/(bounds.width+48),(viewport.clientHeight-48)/(bounds.height+48),8),
      {viewport,x:bounds.x+bounds.width/2,y:bounds.y+bounds.height/2,fx:.5,fy:.5});
  }
  function renderPreservingPosition() { const anchor=captureAnchor(); render(); restoreAnchor(anchor); }
  function render() {
    if (!loadedRevision) return;
    const {width,height}=imageSize();
    const mode = $('mode').value, side = mode === 'side', mix = Number($('mix').value)/100;
    const highlight=side && $('highlight').checked, intensity=Number($('highlight-strength').value)/100;
    $('side').hidden = !side; $('combined').hidden = side;
    $('highlight-control').hidden = !side; $('highlight-strength-control').hidden = !highlight;
    $('mix-control').hidden = mode !== 'split' && mode !== 'overlay';
    $('mix-label').textContent = mode === 'split' ? 'Position' : 'Opacity'; $('mix-value').textContent = $('mix').value + '%';
    const viewport = $(side ? 'before-viewport' : 'combined-viewport');
    const fit = Math.min((viewport.clientWidth-32)/width,(viewport.clientHeight-32)/height,1);
    const scale = zoomMode==='manual' ? manualScale : Math.max(.01,zoomMode==='width' ? Math.min((viewport.clientWidth-32)/width,8) : fit);
    const nextPaintKey=[loadedRevision,mode,mix,highlight,intensity,mode==='split' ? scale : ''].join('|');
    const repaint=paintKey!==nextPaintKey;
    if ((mode==='diff' || highlight) && repaint) buildDiff(width,height);
    const canvases = side ? [$('before-canvas'),$('after-canvas')] : [$('combined-canvas')];
    canvases.forEach((canvas,index) => {
      sizeCanvas(canvas,width,height); canvas.style.width = width*scale + 'px'; canvas.style.height = height*scale + 'px';
      canvas.style.imageRendering = scale>=1 ? 'pixelated' : 'auto';
      if (!repaint) return;
      const ctx = canvas.getContext('2d'); ctx.clearRect(0,0,width,height);
      if (side) {
        const image = index === 0 ? before : after; if (image) ctx.drawImage(image,0,0);
        if (highlight && index === 1) { ctx.save(); ctx.globalAlpha=intensity; ctx.drawImage(diffMask,0,0); ctx.restore(); }
      }
      else if (mode === 'diff') { ctx.putImageData(diffImage,0,0); }
      else {
        if (before) ctx.drawImage(before,0,0);
        ctx.save();
        if (mode === 'split') { ctx.beginPath(); ctx.rect(width*mix,0,width*(1-mix),height); ctx.clip(); ctx.clearRect(0,0,width,height); }
        else ctx.globalAlpha = mix;
        if (after) ctx.drawImage(after,0,0); ctx.restore();
        if (mode === 'split') { ctx.strokeStyle='#75dcce'; ctx.lineWidth=1/scale; ctx.beginPath(); ctx.moveTo(width*mix,0); ctx.lineTo(width*mix,height); ctx.stroke(); }
      }
    });
    renderedMode=mode; renderedScale=scale; paintKey=nextPaintKey;
    if(document.activeElement!==$('zoom-percent')) $('zoom-percent').value=Number((scale*100).toFixed(1));
    $('zoom-fit').setAttribute('aria-pressed',String(zoomMode==='fit'));
    $('zoom-width').setAttribute('aria-pressed',String(zoomMode==='width'));
    $('zoom-actual').setAttribute('aria-pressed',String(zoomMode==='manual' && scale===1));
    const failure=!!current()?.failure;
    $('combined-label').textContent = mode === 'diff' ? 'Changed pixels in pink' : mode === 'split' ? (failure ? 'Expected ← | → Actual' : 'Before ← | → After') : (failure ? 'Actual over Expected' : 'After over Before');
    $('metrics').textContent = dimensions(before) + ' → ' + dimensions(after) + (before && after && (before.naturalWidth!==after.naturalWidth || before.naturalHeight!==after.naturalHeight) ? ' · Dimensions changed' : '') + (mode === 'diff' || highlight ? diffSummary : '');
  }
  function confirmRevert(items) {
    pendingRevert=items.filter(item=>!item.staged);
    if(!pendingRevert.length || mutating) return;
    const paths=new Set(pendingRevert.map(item=>item.path)), untracked=new Set(pendingRevert.filter(item=>item.status==='?').map(item=>item.path));
    $('revert-count').textContent='Revert '+paths.size+' '+(paths.size===1 ? 'image' : 'images')+'.';
    $('revert-untracked').textContent=untracked.size ? untracked.size+' untracked '+(untracked.size===1 ? 'file will' : 'files will')+' be permanently deleted.' : 'No untracked files will be deleted.';
    $('revert-dialog').showModal();
  }
  function formatBytes(bytes) {
    if(bytes<1024) return bytes+' B';
    const units=['KiB','MiB','GiB']; let value=bytes/1024,index=0;
    while(value>=1024 && index<units.length-1) {value/=1024;index++;}
    return value.toFixed(value>=10 ? 1 : 2)+' '+units[index];
  }
  function confirmDeleteFailures() {
    if(mutating || testActive() || !failureSummary.fileCount || failureSummary.scanning) return;
    $('delete-failures-summary').textContent='Delete '+failureSummary.fileCount+' generated image '+(failureSummary.fileCount===1 ? 'file' : 'files')+' ('+formatBytes(failureSummary.totalBytes)+') across '+failureSummary.caseCount+' failure '+(failureSummary.caseCount===1 ? 'comparison' : 'comparisons')+'.';
    $('delete-failures-dialog').showModal();
  }
  async function deleteFailures() {
    if(mutating || testActive() || !failureSummary.fileCount) return;
    const count=failureSummary.fileCount;
    mutating=true; updateButtons();
    message('Deleting '+count+' generated failure '+(count===1 ? 'image' : 'images')+'…');
    try {
      const data=await (await request('/api/failures/delete',{})).json();
      applyData(data);
      const deleted=data.deletedFailureFiles || 0;
      message('Deleted '+deleted+' generated failure '+(deleted===1 ? 'image' : 'images')+'. Git baselines and the index were not changed.');
    } catch(error) {message(error.message,true);}
    finally {mutating=false;renderList();await refresh();}
  }
  async function mutate(action, items) {
    if (mutating || !items.length || items.some(item=>item.failure)) return;
    closeMenu();
    mutating = true; updateButtons();
    const imageCount = items.length + ' ' + (items.length === 1 ? 'image' : 'images');
    if (action === 'stage' || action === 'unstage') {
      message((action === 'stage' ? 'Staging ' : 'Unstaging ') + imageCount + '…');
    } else if(action === 'revert') message('Reverting '+imageCount+'…');
    try {
      const revisions = Object.fromEntries(items.map(c => [c.id,c.revision]));
      const data = await (await request('/api/' + action,{revisions})).json();
      items.forEach(c => selected.delete(c.id)); applyData(data);
      if (action === 'ignore' || action === 'unignore') {
        message((action === 'ignore' ? 'Added ' : 'Removed ') + new Set(items.map(c=>c.path)).size + ' file(s) ' + (action === 'ignore' ? 'to' : 'from') + ' .golden_ignore. Git and golden tests were not changed.');
      } else if(action === 'revert') {
        const restored=data.restoredWorkingFiles || 0, deleted=data.deletedUntrackedFiles || 0;
        message('Reverted '+(restored+deleted)+' '+(restored+deleted===1 ? 'image' : 'images')+'. '+(deleted ? 'Deleted '+deleted+' untracked '+(deleted===1 ? 'file' : 'files')+'. ' : '')+'Staged changes were preserved.');
      } else message((data.removedStaleIndexLock ? 'Removed stale Git index.lock and retried. ' : '') + (action === 'stage' ? 'Staged ' : 'Unstaged ') + imageCount + '. Working files were not rewritten.');
    } catch (error) { message(error.message,true); }
    finally { mutating = false; renderList(); await refresh(); }
  }
  function step(direction) {
    const items = visible(); if (!items.length) return;
    const index = items.findIndex(c => c.id === activeId); choose(items[(index+direction+items.length)%items.length].id);
  }
  $('refresh').addEventListener('click',refresh);
  $('search').addEventListener('input',() => { const items=visible(); if (!items.some(c=>c.id===activeId)) choose(items[0]?.id || null); else renderList(); });
  $('ignored-active').addEventListener('click',()=>setShowIgnored(false));
  $('file-view-options').addEventListener('click',()=>{if(menuState?.origin===$('file-view-options')) closeMenu(true);else openViewOptions();});
  $('file-view-options').addEventListener('keydown',event=>{if(event.key==='ArrowDown'){event.preventDefault();openViewOptions();}});
  $('file-scope').addEventListener('change',() => {
    scope=$('file-scope').value;
    closeMenu();
    const items=visible(); if (!items.some(c=>c.id===activeId)) choose(items[0]?.id || null); else renderList();
    refresh();
  });
  document.querySelectorAll('[data-layout]').forEach(button=>button.addEventListener('click',()=>{
    fileLayout=button.dataset.layout; document.querySelectorAll('[data-layout]').forEach(b=>b.setAttribute('aria-pressed',String(b===button))); renderList();
  }));
  $('mode').addEventListener('change',renderPreservingPosition); $('mix').addEventListener('input',render);
  $('highlight').addEventListener('change',renderPreservingPosition); $('highlight-strength').addEventListener('input',render);
  $('zoom-in').addEventListener('click',()=>setZoom(renderedScale*1.25)); $('zoom-out').addEventListener('click',()=>setZoom(renderedScale/1.25));
  $('zoom-fit').addEventListener('click',()=>fitZoom()); $('zoom-width').addEventListener('click',()=>fitZoom('width')); $('zoom-actual').addEventListener('click',()=>setZoom(1));
  $('zoom-changes').addEventListener('click',zoomToChanges);
  function commitZoom() { setZoom(Number($('zoom-percent').value)/100); $('zoom-percent').value=Number((renderedScale*100).toFixed(1)); }
  $('zoom-percent').addEventListener('change',commitZoom); $('zoom-percent').addEventListener('keydown',event=>{if(event.key==='Enter') {commitZoom();$('zoom-percent').blur();}});
  $('previous').addEventListener('click',()=>step(-1)); $('next').addEventListener('click',()=>step(1));
  $('toggle-stage').addEventListener('click',()=>{const item=current(); if(item && !item.ignored) mutate(item.staged ? 'unstage' : 'stage',[item]);});
  $('revert-file').addEventListener('click',()=>{const item=current(); if(item && !item.staged) confirmRevert([item]);});
  $('stage-selected').addEventListener('click',()=>mutate('stage',[...selected.values()].filter(c=>!c.staged && !c.ignored)));
  $('unstage-selected').addEventListener('click',()=>mutate('unstage',[...selected.values()].filter(c=>c.staged && !c.ignored)));
  $('revert-selected').addEventListener('click',()=>confirmRevert([...selected.values()].filter(c=>!c.staged)));
  $('clear-selected').addEventListener('click',()=>{selected.clear();renderList();});
  $('cancel-revert').addEventListener('click',()=>{$('revert-dialog').close();pendingRevert=[];});
  $('confirm-revert').addEventListener('click',()=>{const items=pendingRevert;pendingRevert=[];$('revert-dialog').close();mutate('revert',items);});
  $('revert-dialog').addEventListener('cancel',()=>{pendingRevert=[];});
  $('delete-failures').addEventListener('click',confirmDeleteFailures);
  $('cancel-delete-failures').addEventListener('click',()=>$('delete-failures-dialog').close());
  $('confirm-delete-failures').addEventListener('click',()=>{$('delete-failures-dialog').close();deleteFailures();});
  function fileContext() { const item=current(); return {items:item && !item.failure ? [item] : [],title:item && !item.failure ? (item.staged ? 'Staged · ' : 'Unstaged · ')+item.path : 'Image actions'}; }
  for(const [id,getContext] of [['file-actions',fileContext],['selection-actions',selectionContext]]) {
    const button=$(id);
    const open=()=>{const context=getContext();openMenu(context.items,{...context,origin:button});};
    button.addEventListener('click',()=>{if(menuState?.origin===button) closeMenu(true); else open();});
    button.addEventListener('keydown',event=>{if(event.key==='ArrowDown'){event.preventDefault();open();}});
  }
  bindContextMenu($('viewer'),fileContext,$('file-actions'));
  bindContextMenu($('git-selection'),selectionContext,$('selection-actions'));
  $('action-menu').addEventListener('contextmenu',event=>event.preventDefault());
  $('action-menu').addEventListener('keydown',event=>{
    event.stopPropagation();
    if(event.key==='Escape') {event.preventDefault();closeMenu(true);return;}
    if(event.key==='Tab') {closeMenu(true);return;}
    const items=[...$('action-menu').querySelectorAll('button[role^=menuitem]:not(:disabled)')];
    if(!items.length) return;
    let index=items.indexOf(document.activeElement);
    if(event.key==='ArrowDown') index=(index+1)%items.length;
    else if(event.key==='ArrowUp') index=(index-1+items.length)%items.length;
    else if(event.key==='Home') index=0;
    else if(event.key==='End') index=items.length-1;
    else return;
    event.preventDefault();items.forEach((item,i)=>item.tabIndex=i===index ? 0 : -1);items[index].focus();
  });
  document.addEventListener('pointerdown',event=>{
    if(menuState && !$('action-menu').contains(event.target) && !menuState.origin.contains(event.target)) closeMenu();
  },true);
  document.addEventListener('scroll',event=>{if(menuState && !$('action-menu').contains(event.target)) closeMenu();},true);
  window.addEventListener('resize',()=>closeMenu());
  window.addEventListener('blur',()=>closeMenu());
  for (const [source,target] of [['before-viewport','after-viewport'],['after-viewport','before-viewport']]) {
    $(source).addEventListener('scroll',()=>{
      if(!synchronizing) syncViewports($(source));
    });
  }
  for(const viewport of document.querySelectorAll('.viewport')) {
    viewport.tabIndex=0;
    viewport.addEventListener('wheel',event=>{
      if (!(event.ctrlKey || event.metaKey) || !loadedRevision) return;
      event.preventDefault();
      const delta=event.deltaY*(event.deltaMode===1 ? 16 : event.deltaMode===2 ? viewport.clientHeight : 1);
      setZoom(renderedScale*Math.exp(-delta*.002),captureAnchor(viewport,event.clientX,event.clientY));
    },{passive:false});
    viewport.addEventListener('dblclick',event=>{
      if(!loadedRevision || event.target.tagName!=='CANVAS') return;
      if(Math.abs(renderedScale-1)<.01) fitZoom(); else setZoom(1,captureAnchor(viewport,event.clientX,event.clientY));
    });
    let drag=null;
    viewport.addEventListener('pointerdown',event=>{
      if(event.button!==0 || event.target.tagName!=='CANVAS' || !loadedRevision) return;
      drag={x:event.clientX,y:event.clientY,left:viewport.scrollLeft,top:viewport.scrollTop};
      viewport.setPointerCapture(event.pointerId); viewport.classList.add('dragging'); viewport.focus({preventScroll:true});
    });
    viewport.addEventListener('pointermove',event=>{
      if(!drag)return;
      viewport.scrollLeft=drag.left+drag.x-event.clientX; viewport.scrollTop=drag.top+drag.y-event.clientY; syncViewports(viewport);
    });
    const endDrag=()=>{drag=null;viewport.classList.remove('dragging');};
    viewport.addEventListener('pointerup',endDrag); viewport.addEventListener('pointercancel',endDrag); viewport.addEventListener('lostpointercapture',endDrag);
  }
  document.addEventListener('keydown',event=>{
    if (event.ctrlKey || event.metaKey || event.altKey || $('tests-panel').contains(event.target) || ['INPUT','SELECT','TEXTAREA','BUTTON','SUMMARY'].includes(event.target.tagName)) return;
    if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();step(event.key==='ArrowLeft'?-1:1);}
    if(event.key==='+' || event.key==='=') {event.preventDefault();setZoom(renderedScale*1.25);}
    if(event.key==='-') {event.preventDefault();setZoom(renderedScale/1.25);}
    if(event.key==='0') {event.preventDefault();fitZoom();}
    if(event.key==='1') {event.preventDefault();setZoom(1);}
  });
  new ResizeObserver(renderPreservingPosition).observe($('viewer'));
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh(); else closeMenu();});
  setInterval(()=>{if(!document.hidden)refresh();},2000); refresh();
})();
</script>
</body></html>''';
