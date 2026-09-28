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

async function viewer(t, changes=[item('a'),item('b'),item('c','screens/beta')], run={id:null,active:false,cursor:0}) {
  const context = await browser.newContext({viewport:{width:1280,height:800}});
  t.after(() => context.close());
  const page = await context.newPage(), errors=[], actions=[];
  page.on('pageerror', error => errors.push(error.message));
  t.after(() => assert.deepEqual(errors, []));
  const data={repository:'/fixture',input:'.',warnings:[],changes,failures:{items:[],caseCount:0,fileCount:0,totalBytes:0,scanning:false,warnings:[]}};
  let imageReads=0;
  const imageRequests=[],deletions=[],preparations=[],plans=new Map(),hooks={},invalidImages=new Set();
  await page.route('http://review.test/**', async route => {
    const url=new URL(route.request().url());
    if(url.pathname==='/') return route.fulfill({contentType:'text/html',body:html});
    if(url.pathname==='/api/changes') return route.fulfill({json:data});
    if(url.pathname==='/api/image') {imageReads++;imageRequests.push(Object.fromEntries(url.searchParams));return route.fulfill({contentType:'image/png',body:invalidImages.has(url.searchParams.get('side')) ? Buffer.from('invalid PNG') : pixel});}
    if(url.pathname==='/api/test-run') return route.fulfill({json:run});
    if(url.pathname==='/api/failures/prepare-delete') {
      const body=route.request().postDataJSON();preparations.push(body);
      const items=body.all ? data.failures.items : data.failures.items.filter(c=>Object.hasOwn(body.revisions,c.id));
      const count=body.all ? data.failures.fileCount : items.reduce((sum,c)=>sum+c.artifactCount,0);
      const plan={planId:'plan-'+preparations.length,fileCount:count,totalBytes:data.failures.totalBytes,
        paths:Array.from({length:count},(_,i)=>'screens/failures/artifact'+i+'.png'),ids:items.map(c=>c.id)};
      plans.set(plan.planId,plan);return route.fulfill({json:plan});
    }
    if(url.pathname==='/api/failures/delete') {
      const body=route.request().postDataJSON();deletions.push(body);
      const plan=plans.get(body.planId);assert.ok(plan);
      data.failures.items=data.failures.items.filter(c=>!plan.ids.includes(c.id));
      data.failures.caseCount=data.failures.items.length;data.failures.fileCount-=plan.fileCount;
      return route.fulfill({json:{...data,deletedFailureFiles:plan.fileCount}});
    }
    if(['/api/failures/ignore','/api/failures/unignore'].includes(url.pathname)) {
      const body=route.request().postDataJSON();actions.push({path:url.pathname,...body});
      for(const c of data.failures.items) if(Object.hasOwn(body.revisions,c.id)) c.ignored=url.pathname.endsWith('/ignore');
      return route.fulfill({json:data});
    }
    if(url.pathname==='/api/stage') {
      const body=route.request().postDataJSON();actions.push(body);
      const error=await hooks.action?.(body);
      return route.fulfill(error ? {status:409,json:{error}} : {json:data});
    }
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
  return {page,refresh,actions,data,run,imageRequests,deletions,preparations,hooks,invalidImages,get imageReads(){return imageReads;}};
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
  const target=page.locator('.file > button').nth(40);
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

const failure = (id, extra={}) => ({...item(id,'screens/failures'),failure:true,artifactCount:4,hasIsolatedDiff:true,hasMaskedDiff:true,difference:ready(20),...extra});
function setFailures(data, items) {
  data.failures={items,caseCount:items.length,fileCount:items.reduce((sum,item)=>sum+item.artifactCount,0),totalBytes:4096,scanning:false,warnings:[]};
}

test('Git file colors and type filters distinguish added, untracked and deleted files in both groups', async t => {
  const {page,refresh}=await viewer(t,[
    {...item('untracked'),status:'?',hasBefore:false},item('modified'),
    {...item('deleted'),status:'D',hasAfter:false},
    {...item('added'),status:'A',staged:true,hasBefore:false},
  ]);
  const states=await page.locator('.file').evaluateAll(rows=>rows.map(row=>({
    kind:row.dataset.change,badge:row.querySelector('.badge').textContent,
    label:row.querySelector('.badge').getAttribute('aria-label'),
    color:getComputedStyle(row.querySelector('.file-name')).color,
    decoration:getComputedStyle(row.querySelector('.file-name')).textDecorationLine,
  })));
  const untracked=states.find(s=>s.badge==='U'),deleted=states.find(s=>s.badge==='D');
  assert.equal(untracked.label,'Untracked new file');
  assert.equal(untracked.color,states.find(s=>s.badge==='A').color);
  assert.notEqual(untracked.color,deleted.color);
  assert.notEqual(untracked.color,states.find(s=>s.badge==='M').color);
  assert.equal(deleted.decoration,'line-through');
  await page.locator('#change-filter').selectOption('added');
  assert.equal(await page.locator('.file').count(),2);
  await page.locator('#file-scope').selectOption('staged');
  assert.deepEqual(await page.locator('.file .badge').allTextContents(),['A']);
  await refresh(data=>{data.changes[3].difference=ready(100);});
  assert.equal(await page.locator('#change-filter').inputValue(),'added');
  await page.locator('#file-scope').selectOption('all');
  await page.locator('#change-filter').selectOption('deleted');
  assert.deepEqual(await page.locator('.file .badge').allTextContents(),['D']);
});

test('failure filters compose with search and update membership when metrics complete', async t => {
  const {page,refresh}=await viewer(t);
  await refresh(data=>setFailures(data,[
    failure('changed'),failure('same',{difference:ready(0)}),
    failure('missing',{hasBefore:false,artifactCount:3}),
    failure('unreadable',{difference:{status:'unavailable',error:'Cannot decode'}}),
    failure('pending',{difference:{status:'pending'}}),
    failure('mask-only',{hasBefore:false,hasAfter:false,artifactCount:1}),
  ]));
  await page.locator('#show-failures').click();
  assert.equal(await page.locator('#file-scope').inputValue(),'failures');
  assert.equal(await page.locator('#change-filter').isVisible(),false);
  assert.match(await page.locator('#failure-summary').textContent(),/6 comparisons · 20 images · 4.00 KiB/);
  for (const [filter,names] of [
    ['changed',['changed.png']],['unchanged',['same.png']],
    ['incomplete',['mask-only.png','missing.png']],['unavailable',['unreadable.png']],['pending',['pending.png']],
  ]) {
    await page.locator('#failure-filter').selectOption(filter);
    assert.deepEqual((await page.locator('.file-name').allTextContents()).sort(),names);
  }
  await page.locator('#failure-filter').selectOption('unchanged');
  await page.locator('#file-view-options').click();
  await page.locator('#action-menu').press('ArrowDown');
  await rememberUI(page);
  await refresh(data=>{data.failures.items.find(c=>c.id==='pending').difference=ready(0);});
  await assertUI(page,false);
  assert.equal(await page.locator('#failure-filter').inputValue(),'unchanged');
  assert.equal(await page.locator('.file').count(),2);
  await page.locator('#action-menu').press('Escape');
  await page.locator('#search').fill('pending');
  assert.deepEqual(await page.locator('.file-name').allTextContents(),['pending.png']);
  await page.locator('#search').fill('');
  await page.locator('#failure-filter').selectOption('incomplete');
  assert.match((await page.locator('.failure-detail').allTextContents()).join(' '),/Missing expected and actual/);
  assert.equal(await page.locator('.badge.deleted').count(),0);
});

test('failure artifact previews use their guarded endpoints and survive polls', async t => {
  const v=await viewer(t),{page,refresh,imageRequests}=v;
  await refresh(data=>setFailures(data,[failure('all'),failure('only-mask',{hasBefore:false,hasAfter:false,hasIsolatedDiff:false,artifactCount:1})]));
  await page.locator('#show-failures').click();
  await page.waitForFunction(()=>!document.getElementById('failure-view').disabled);
  await page.locator('#mode').selectOption('overlay');
  for (const [side,label] of [['before','Expected'],['after','Actual'],['isolatedDiff','Isolated diff'],['maskedDiff','Masked diff']]) {
    await page.locator('#failure-view').selectOption(side);
    await page.waitForFunction(()=>!document.getElementById('failure-view').disabled);
    assert.deepEqual(imageRequests.at(-1),{id:'all',revision:'all-v1',side,failure:'true'});
    assert.equal(await page.locator('#before-pane').isVisible(),false);
    assert.equal(await page.locator('#after-label').textContent(),label);
    assert.equal(await page.locator('#new-image-badge').isVisible(),false);
    assert.equal(await page.locator('#mode-control').isVisible(),false);
  }
  const reads=v.imageReads;
  await refresh(data=>{data.failures.items[0].difference=ready(40);});
  assert.equal(await page.locator('#failure-view').inputValue(),'maskedDiff');
  assert.equal(v.imageReads,reads);
  await page.locator('#failure-view').selectOption('compare');
  await page.waitForFunction(()=>!document.getElementById('failure-view').disabled);
  assert.equal(await page.locator('#mode').inputValue(),'overlay');
  assert.equal(await page.locator('#combined').isVisible(),true);
  await page.locator('.file button[title="screens/failures/only-mask.png"]').click();
  await page.waitForFunction(()=>!document.getElementById('failure-view').disabled);
  assert.equal(await page.locator('#failure-view').inputValue(),'maskedDiff');
  assert.equal(await page.locator('#after-label').textContent(),'Masked diff');
  assert.equal(await page.locator('#failure-view option[value="compare"]').evaluate(option=>option.disabled),true);
  assert.equal(await page.locator('#metrics').textContent(),'1 × 1');
});

test('Delete all explicitly includes filtered and ungrouped failure images and keeps its dialog during scans', async t => {
  const {page,refresh,deletions,actions}=await viewer(t);
  await refresh(data=>{setFailures(data,[failure('one'),failure('two')]);data.failures.fileCount=9;});
  await page.locator('#show-failures').click();
  await page.locator('#search').fill('one');
  assert.equal(await page.locator('.file').count(),1);
  await page.locator('#delete-failures').click();
  await page.locator('#delete-failures-dialog').waitFor({state:'visible'});
  assert.match(await page.locator('#delete-failures-summary').textContent(),/Delete 9 generated image files/);
  assert.match(await page.locator('#delete-failures-dialog').textContent(),/includes files hidden by search or filters/);
  await page.locator('#cancel-delete-failures').click();
  await page.locator('#action-progress').waitFor({state:'hidden'});
  assert.deepEqual(deletions,[]);
  await page.locator('#delete-failures').click();
  await page.locator('#delete-failures-dialog').waitFor({state:'visible'});
  await refresh(data=>{data.failures.scanning=true;});
  assert.equal(await page.locator('#delete-failures-dialog').isVisible(),true);
  assert.equal(await page.locator('#confirm-delete-failures').isDisabled(),false);
  await refresh(data=>{data.failures.scanning=false;data.failures.fileCount=10;});
  assert.match(await page.locator('#delete-failures-summary').textContent(),/Delete 9 generated image files/);
  await page.locator('#confirm-delete-failures').click();
  await page.waitForFunction(()=>document.getElementById('failure-count').textContent==='0');
  assert.deepEqual(deletions,[{planId:'plan-2'}]);
  assert.deepEqual(actions,[]);
  assert.equal(await page.locator('#delete-failures').isDisabled(),false);
  await page.locator('#search').fill('');
  await page.locator('#show-failures').click();
  assert.equal(await page.locator('.file').count(),3);
});

test('failure cleanup responds immediately to running test status', async t => {
  const run={id:'run-1',active:true,status:'running',cursor:0,logs:[],results:[],started:new Date().toISOString(),finished:null,exitCode:null,completed:0,total:1,currentIndex:-1,plan:{commands:[],discovery:false}};
  const {page,refresh,deletions}=await viewer(t,undefined,run);
  await refresh(data=>setFailures(data,[failure('one')]));
  await page.locator('#show-failures').click();
  assert.equal(await page.locator('#delete-failures').isDisabled(),true);
  assert.match(await page.locator('#delete-failures').getAttribute('title'),/Stop the running golden tests/);
  run.active=false;run.status='passed';run.finished=new Date().toISOString();
  await page.waitForFunction(()=>!document.getElementById('delete-failures').disabled);
  assert.deepEqual(deletions,[]);
});

test('a corrupt expected image does not block viewing other failure artifacts', async t => {
  const {page,refresh,invalidImages}=await viewer(t,[{...item('new'),status:'?',hasBefore:false}]);
  assert.equal(await page.locator('#comparison-toolbar').isVisible(),false);
  invalidImages.add('before');
  await refresh(data=>setFailures(data,[failure('corrupt')]));
  await page.locator('#show-failures').click();
  await page.waitForFunction(()=>document.querySelector('#empty strong').textContent==='Preview unavailable');
  assert.equal(await page.locator('#failure-view-control').isVisible(),true);
  assert.equal(await page.locator('#failure-view').isEnabled(),true);
  await page.locator('#failure-view').selectOption('maskedDiff');
  await page.waitForFunction(()=>!document.getElementById('zoom-in').disabled);
  assert.equal(await page.locator('#after-label').textContent(),'Masked diff');
  assert.equal(await page.locator('#empty').isVisible(),false);
});

test('ungrouped failure images remain discoverable and eligible for cleanup', async t => {
  const {page,refresh}=await viewer(t);
  await Promise.all([page.waitForResponse(r=>new URL(r.url()).pathname==='/api/changes'),page.locator('#show-failures').click()]);
  await page.evaluate(()=>new Promise(requestAnimationFrame));
  await refresh(data=>{data.failures.fileCount=3;data.failures.totalBytes=1024;});
  assert.match(await page.locator('#files').textContent(),/Only ungrouped failure images/);
  assert.match(await page.locator('#failure-summary').textContent(),/0 comparisons · 3 images/);
  assert.equal(await page.locator('#delete-failures').isEnabled(),true);
});

test('failure file, folder and group actions keep the captured scope and support ignore', async t => {
  const {page,refresh,actions,preparations,deletions}=await viewer(t);
  await refresh(data=>setFailures(data,[failure('one'),failure('two'),failure('outside',{path:'other/failures/outside.png'})]));
  await page.locator('#show-failures').click();
  const row=page.locator('.file').filter({has:page.locator('button[title="screens/failures/one.png"]')});
  await row.hover();
  await row.getByRole('button',{name:'Ignore failures',exact:true}).click();
  await page.waitForFunction(()=>!document.querySelector('.file > button[title="screens/failures/one.png"]'));
  assert.deepEqual(actions[0],{path:'/api/failures/ignore',revisions:{one:'one-v1'}});
  await page.locator('#file-view-options').click();
  await page.locator('#show-ignored').click();
  await row.hover();
  await row.getByRole('button',{name:'Stop ignoring failures',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('.file > button[title="screens/failures/one.png"]').closest('.file').querySelector('.row-actions button:last-child').title==='Ignore failures');
  assert.deepEqual(actions[1],{path:'/api/failures/unignore',revisions:{one:'one-v1'}});

  await page.locator('summary[title="screens/failures"]').click({button:'right'});
  await rememberUI(page);
  await refresh(data=>{data.failures.items.push(failure('late'));data.failures.fileCount+=4;data.failures.caseCount++;});
  await assertUI(page,false);
  await page.getByRole('menuitem',{name:'Delete failure images (8)',exact:true}).click();
  await page.locator('#delete-failures-dialog').waitFor({state:'visible'});
  assert.deepEqual(preparations[0],{revisions:{one:'one-v1',two:'two-v1'}});
  await page.locator('#delete-failures-dialog').press('Escape');
  await page.locator('#action-progress').waitFor({state:'hidden'});
  assert.deepEqual(deletions,[]);

  await page.locator('#search').fill('screens/');
  const group=page.locator('.group-title');
  await group.hover();
  await group.getByRole('button',{name:'Delete selected failure images',exact:true}).click();
  await page.locator('#delete-failures-dialog').waitFor({state:'visible'});
  assert.deepEqual(preparations[1],{revisions:{late:'late-v1',one:'one-v1',two:'two-v1'}});
  await page.locator('#confirm-delete-failures').click();
  await page.locator('#action-progress').waitFor({state:'hidden'});
  assert.deepEqual(deletions,[{planId:'plan-2'}]);
  await page.locator('#search').fill('');
  assert.deepEqual(await page.locator('.file-name').allTextContents(),['outside.png']);
});

test('large cleanup lists scroll without moving confirmation buttons out of a short window', async t => {
  const {page,refresh,deletions}=await viewer(t);
  await refresh(data=>{setFailures(data,[failure('one')]);data.failures.fileCount=5000;});
  await page.setViewportSize({width:1000,height:480});
  await page.locator('#show-failures').click();
  await page.locator('#delete-failures').click();
  await page.locator('#delete-failures-dialog').waitFor({state:'visible'});
  await page.locator('#delete-failures-dialog summary').click();
  const dimensions=await page.evaluate(()=>{
    const confirm=document.getElementById('confirm-delete-failures').getBoundingClientRect();
    const cancel=document.getElementById('cancel-delete-failures').getBoundingClientRect();
    const list=document.getElementById('delete-failures-paths');
    return {visible:confirm.top>=0 && confirm.bottom<=innerHeight && cancel.bottom<=innerHeight,scrolls:list.scrollHeight>list.clientHeight,lines:list.textContent.split('\n').length};
  });
  assert.deepEqual(dimensions,{visible:true,scrolls:true,lines:5000});
  await page.locator('#cancel-delete-failures').click();
  await page.locator('#action-progress').waitFor({state:'hidden'});
  assert.deepEqual(deletions,[]);
});

test('commands run in FIFO order, deduplicate outstanding work and retain queued revisions after errors', async t => {
  const {page,refresh,actions,hooks}=await viewer(t);
  let releaseFirst;
  const first=new Promise(resolve=>releaseFirst=resolve);
  t.after(()=>releaseFirst());
  hooks.action=async()=>{if(actions.length===1) {await first;return 'Image changed; review again.';}};
  const stage=async id=>{
    const row=page.locator('.file').filter({has:page.locator(`button[title="screens/alpha/${id}.png"]`)});
    await row.hover();await row.getByRole('button',{name:'Stage images',exact:true}).click();
  };
  await Promise.all([page.waitForRequest(r=>new URL(r.url()).pathname==='/api/stage'),stage('a')]);
  await stage('b');
  await stage('b');
  assert.equal(actions.length,1);
  assert.match(await page.locator('#action-progress').textContent(),/1 queued/);
  await page.locator('.file > button[title="screens/beta/c.png"]').click();
  await page.waitForFunction(()=>document.getElementById('filename').textContent.includes('c.png'));
  await page.locator('summary[title="screens/alpha"]').click({button:'right'});
  await rememberUI(page);
  await refresh(data=>{data.changes[1].revision='b-v2';data.changes[1].difference=ready(15);});
  await assertUI(page);
  releaseFirst();
  await page.locator('#action-progress').waitFor({state:'hidden'});
  assert.deepEqual(actions.map(action=>action.revisions),[{a:'a-v1'},{b:'b-v1'}]);
  assert.match(await page.locator('#message').textContent(),/Image changed; review again/);
  assert.equal(await page.locator('#action-menu').isVisible(),true);
});
