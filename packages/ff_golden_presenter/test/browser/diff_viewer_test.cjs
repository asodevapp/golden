const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');

// Exercise the exact self-contained page served by renderDiffViewer.
const source = fs.readFileSync(path.join(__dirname, '../../lib/src/diff_viewer.dart'), 'utf8');
const html = source.match(/const _page = r'''([\s\S]*)''';/)[1].replaceAll('__SESSION_TOKEN__', 'test');
const pixel = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==', 'base64');
const ready = (changedPixels, totalPixels=100) => ({status:'ready',changedPixels,totalPixels,percent:changedPixels/totalPixels*100});
const item = (id, folder='screens/alpha') => ({id,path:`${folder}/${id}.png`,revision:`${id}-v1`,status:'M',staged:false,ignored:false,hasBefore:true,hasAfter:true,difference:{status:'pending'}});
let browser;
before(async () => {browser = await chromium.launch({headless:true, ...(process.env.CHROME_PATH ? {executablePath:process.env.CHROME_PATH} : {})});});
after(async () => {await browser?.close();});

async function viewer(t, changes=[item('a'),item('b'),item('c','screens/beta')]) {
  const context = await browser.newContext({viewport:{width:1280,height:800}});
  t.after(() => context.close());
  const page = await context.newPage(), errors=[], actions=[];
  page.on('pageerror', error => errors.push(error.message));
  t.after(() => assert.deepEqual(errors, []));
  const data={repository:'/fixture',input:'.',warnings:[],changes,failures:{items:[],caseCount:0,fileCount:0,totalBytes:0,scanning:false,warnings:[]}};
  let imageReads=0;
  await page.route('http://review.test/**', async route => {
    const url=new URL(route.request().url());
    if(url.pathname==='/') return route.fulfill({contentType:'text/html',body:html});
    if(url.pathname==='/api/changes') return route.fulfill({json:data});
    if(url.pathname==='/api/image') {imageReads++;return route.fulfill({contentType:'image/png',body:pixel});}
    if(url.pathname==='/api/test-run') return route.fulfill({json:{id:null,active:false,cursor:0}});
    if(url.pathname==='/api/stage') {actions.push(route.request().postDataJSON());return route.fulfill({json:data});}
    throw new Error(`Unexpected request: ${url}`);
  });
  await page.goto('http://review.test/');
  await page.locator('.file').first().waitFor();
  await page.waitForFunction(() => !document.getElementById('zoom-in').disabled);
  const refresh = async update => {
    update?.(data);
    await Promise.all([page.waitForResponse(r=>new URL(r.url()).pathname==='/api/changes'),page.evaluate(()=>document.getElementById('refresh').click())]);
    await page.evaluate(() => new Promise(requestAnimationFrame));
  };
  return {page,refresh,actions,data,get imageReads(){return imageReads;}};
}
async function rememberUI(page) {
  await page.evaluate(() => {
    window.saved={row:document.querySelector('.file'),folder:document.querySelector('details.folder'),focus:document.activeElement,menu:document.querySelector('#action-menu button'),top:document.getElementById('files').scrollTop};
    window.treeChanges=[];
    new MutationObserver(records=>treeChanges.push(...records.filter(record=>record.type==='childList' && [...record.addedNodes,...record.removedNodes].some(node=>node.nodeType===1 && (node.matches('.file,details,.group-title') || node.querySelector('.file,details,.group-title')))))).observe(document.getElementById('files'),{subtree:true,childList:true});
  });
}
async function assertUI(page, unchangedTree=true) {
  assert.deepEqual(await page.evaluate(() => ({menuOpen:!document.getElementById('action-menu').hidden,sameMenu:saved.menu===document.querySelector('#action-menu button'),focus:saved.focus===document.activeElement,row:saved.row.isConnected,folder:!saved.folder || saved.folder.isConnected,top:document.getElementById('files').scrollTop===saved.top})),
    {menuOpen:true,sameMenu:true,focus:true,row:true,folder:true,top:true});
  if(unchangedTree) assert.equal(await page.evaluate(()=>treeChanges.length),0);
}

test('metric and failure-status polls preserve file menu, focus, selection and tree', async t => {
  const v=await viewer(t), {page}=v;
  await page.locator('.file input').first().check();
  await page.locator('.file button').first().click({button:'right'});
  await page.locator('#action-menu').press('ArrowDown');
  await rememberUI(page);
  const reads=v.imageReads;
  await v.refresh(data => {data.changes[0].difference=ready(25);data.failures.scanning=true;});
  await assertUI(page);
  assert.equal(await page.locator('.file .difference-value').first().textContent(),'25.00%');
  assert.equal(await page.locator('.file input').first().isChecked(),true);
  await v.refresh(data => {data.changes[1].difference=ready(0);data.changes[2].difference=ready(0);data.failures.scanning=false;});
  await assertUI(page);
  assert.equal(await page.locator('summary[title="screens/alpha"] .difference-value').textContent(),'12.50%');
  assert.equal(v.imageReads,reads);
  await page.evaluate(() => {window.metricChanges=[];new MutationObserver(r=>metricChanges.push(...r)).observe(document.querySelector('.difference-value'),{subtree:true,childList:true,attributes:true});});
  await v.refresh();
  assert.equal(await page.evaluate(()=>metricChanges.length),0);
});

test('folder menu and collapsed state survive unrelated file insertion', async t => {
  const {page,refresh,actions}=await viewer(t);
  await page.locator('summary[title="screens/beta"]').click();
  await page.locator('summary[title="screens/alpha"]').click({button:'right'});
  await rememberUI(page);
  await refresh(data => {data.changes.forEach(c=>c.difference=ready(20));data.changes.push(item('d','screens/alpha'));});
  await assertUI(page,false);
  assert.equal(await page.locator('details[data-folder-key="unstaged:screens/beta"]').getAttribute('open'),null);
  await Promise.all([page.waitForResponse(r=>new URL(r.url()).pathname==='/api/stage'),page.getByRole('menuitem',{name:'Stage (2)',exact:true}).click()]);
  assert.deepEqual(actions[0].revisions,{a:'a-v1',b:'b-v1'});
});

test('view options remain open across actual timer polls and hidden failure changes', async t => {
  const {page,data}=await viewer(t);
  await page.getByRole('button',{name:'File view options',exact:true}).click();
  await page.locator('#action-menu').press('ArrowDown');
  await rememberUI(page);
  data.failures.items=[{...item('failure'),failure:true,artifactCount:2}];data.failures.fileCount=2;data.failures.scanning=true;
  await page.waitForResponse(r=>new URL(r.url()).pathname==='/api/changes');
  await page.evaluate(() => new Promise(requestAnimationFrame));
  await assertUI(page);
  assert.equal(await page.locator('#failure-count').textContent(),'1');
});

test('scrolled list and open file menu preserve captured revision guards', async t => {
  const {page,refresh,actions}=await viewer(t,Array.from({length:80},(_,i)=>item(`image-${String(i).padStart(3,'0')}`)));
  await page.getByRole('button',{name:'List',exact:true}).click();
  const target=page.locator('.file button').nth(40);
  await target.scrollIntoViewIfNeeded();
  await target.click({button:'right'});
  await rememberUI(page);
  await refresh(data => {data.changes[40].revision='new-revision';data.changes[40].difference=ready(50);});
  await assertUI(page);
  await Promise.all([page.waitForResponse(r=>new URL(r.url()).pathname==='/api/stage'),page.getByRole('menuitem',{name:'Stage (1)',exact:true}).click()]);
  assert.equal(actions[0].revisions['image-040'],'image-040-v1');
});

test('failure percentages update in place and aggregate unequal image sizes', async t => {
  const {page,refresh}=await viewer(t);
  await refresh(data => {data.failures.items=[{...item('f1'),failure:true,artifactCount:2},{...item('f2'),failure:true,artifactCount:2}];data.failures.fileCount=4;});
  await page.locator('#file-scope').selectOption('failures');
  await page.getByRole('button',{name:'File view options',exact:true}).click();
  await rememberUI(page);
  await refresh(data => {data.failures.items[0].difference=ready(10,20);data.failures.items[1].difference=ready(0,80);});
  await assertUI(page);
  assert.equal(await page.locator('summary .difference-value').textContent(),'10.00%');
  await refresh(data => {data.failures.items[0].difference={status:'unavailable',error:'bad image'};});
  assert.equal(await page.locator('summary .difference-value').textContent(),'—');
  await refresh(data => {data.failures.items[0].difference=ready(20,20);});
  assert.equal(await page.locator('summary .difference-value').textContent(),'20.00%');
});

test('one changed metric in a large tree touches only its file and ancestors', async t => {
  const changes=Array.from({length:1000},(_,i)=>({...item(`image-${i}`,`screens/group-${Math.floor(i/100)}`),difference:ready(0)}));
  const {page,refresh}=await viewer(t,changes);
  await page.evaluate(() => {
    window.changedMetrics=new Set();
    new MutationObserver(records=>{
      for(const record of records) {
        const value=record.target.closest?.('.difference-value');
        if(value) changedMetrics.add(value);
      }
    }).observe(document.getElementById('files'),{subtree:true,childList:true,attributes:true});
  });
  await refresh(data=>{data.changes[500].difference=ready(25);});
  assert.equal(await page.evaluate(()=>changedMetrics.size),3);
  assert.equal(await page.locator('summary[title="screens/group-5"] .difference-value').textContent(),'0.25%');
});

test('new images use the full pane with a new badge before and after staging', async t => {
  const added={...item('new'),status:'?',hasBefore:false};
  const v=await viewer(t,[added]), {page}=v;
  async function assertNew() {
    assert.equal(await page.locator('#before-pane').isVisible(),false);
    assert.equal(await page.locator('#new-image-badge').innerText(),'new');
    assert.equal(await page.locator('#after-pane').isVisible(),true);
    assert.equal(await page.locator('#combined').isVisible(),false);
    assert.equal(await page.locator('#comparison-toolbar').isVisible(),false);
    assert.equal(await page.locator('#metrics').innerText(),'1 × 1');
    const size=await page.evaluate(()=>({pane:document.getElementById('after-pane').clientWidth,viewer:document.getElementById('side').clientWidth,zoom:Number(document.getElementById('zoom-percent').value)}));
    assert.equal(size.pane,size.viewer);
    assert.equal(size.zoom,100);
  }
  await assertNew();
  assert.equal(v.imageReads,1);
  await page.getByRole('button',{name:'Zoom in',exact:true}).click();
  assert.ok(await page.locator('#zoom-percent').inputValue()>100);
  await page.getByRole('button',{name:'Fit',exact:true}).click();
  await v.refresh(data=>{data.changes[0].difference=ready(1,1);});
  await assertNew();
  assert.equal(v.imageReads,1);
  await v.refresh(data=>{data.changes[0]={...added,id:'staged-new',revision:'staged-revision',staged:true,status:'A'};});
  await page.waitForFunction(()=>!document.getElementById('zoom-in').disabled && document.getElementById('after-label').textContent==='Index');
  await assertNew();
  assert.equal(v.imageReads,2);
});

test('returning from a new image restores comparison mode and highlight settings', async t => {
  const v=await viewer(t,[item('modified'),{...item('new'),status:'A',hasBefore:false}]), {page}=v;
  await page.getByLabel('Highlight changes',{exact:true}).check();
  await page.locator('#mode').selectOption('overlay');
  await page.locator('.file button[title="screens/alpha/new.png"]').click();
  await page.waitForFunction(()=>!document.getElementById('zoom-in').disabled);
  assert.equal(await page.locator('#new-image-badge').isVisible(),true);
  assert.equal(await page.locator('#before-pane').isVisible(),false);
  // It is the actual image at full opacity, even with saved comparison settings.
  assert.deepEqual(await page.evaluate(()=>Array.from(document.getElementById('after-canvas').getContext('2d').getImageData(0,0,1,1).data)),[255,0,0,255]);
  await page.locator('.file button[title="screens/alpha/modified.png"]').click();
  await page.waitForFunction(()=>!document.getElementById('zoom-in').disabled);
  assert.equal(await page.locator('#new-image-badge').isVisible(),false);
  assert.equal(await page.locator('#comparison-toolbar').isVisible(),true);
  assert.equal(await page.locator('#mode').inputValue(),'overlay');
  assert.equal(await page.locator('#combined').isVisible(),true);
  await page.locator('#mode').selectOption('side');
  assert.equal(await page.locator('#before-pane').isVisible(),true);
  assert.equal(await page.getByLabel('Highlight changes',{exact:true}).isChecked(),true);
  const widths=await page.evaluate(()=>[document.getElementById('before-pane').clientWidth,document.getElementById('after-pane').clientWidth,document.getElementById('side').clientWidth]);
  assert.ok(Math.abs(widths[0]-widths[1])<=1 && widths[0]<widths[2]*.6);
});

test('deleted images and failure artifacts without an expected image are not new', async t => {
  const {page,refresh}=await viewer(t,[{...item('deleted'),status:'D',hasAfter:false}]);
  assert.equal(await page.locator('#new-image-badge').isVisible(),false);
  assert.equal(await page.locator('#before-pane').isVisible(),true);
  await refresh(data=>{data.failures.items=[{...item('failure'),failure:true,hasBefore:false,artifactCount:1}];data.failures.fileCount=1;});
  await page.locator('#file-scope').selectOption('failures');
  await page.waitForFunction(()=>!document.getElementById('zoom-in').disabled && document.getElementById('after-label').textContent==='Actual');
  assert.equal(await page.locator('#new-image-badge').isVisible(),false);
  assert.equal(await page.locator('#before-pane').isVisible(),true);
});
