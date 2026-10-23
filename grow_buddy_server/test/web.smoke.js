'use strict';
// Smoke test for the built web page using jsdom (installed outside the project).
// Run: NODE_PATH=/path/to/node_modules node test/web.smoke.js
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');

const html = fs.readFileSync(path.join(__dirname, '..', 'web', 'dist', 'grow-buddy.html'), 'utf8');
const errors = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  url: 'https://example.test/',
  pretendToBeVisual: true,
  beforeParse(w) {
    w.addEventListener('error', (e) => errors.push(e.message));
    w.scrollTo = () => {};
  },
});
const { window } = dom;
const { document } = window;
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const click = (el) => el.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
const tab = (k) => click($(`[data-act=tab][data-v=${k}]`));

// Guide
assert.equal($$('#plantlist details.card').length, 30, 'all 30 plants listed');
assert.match($('#sunval').textContent, /4\.0 hrs/);
const firstPill = $('#plantlist .pill').className;
assert.match(firstPill, /good/, 'best fits sorted first');
$('#sun').value = '1';
$('#sun').dispatchEvent(new window.Event('input', { bubbles: true }));
assert.match($('#sunval').textContent, /1\.0 hrs/);
assert.equal($$('#plantlist details.card').length, 30);
click($('[data-act=cat][data-v=herb]'));
assert.ok($$('#plantlist details.card').length >= 3 && $$('#plantlist details.card').length < 30, 'category filter');
click($('[data-act=cat][data-v=all]'));

// Start growing -> My plants
const before = JSON.parse(window.localStorage.getItem('growbuddy.web.v1')).plants.length;
click($('[data-act=start][data-v=basil]'));
assert.equal($('[aria-current=page]').textContent, 'My plants');
assert.equal(JSON.parse(window.localStorage.getItem('growbuddy.web.v1')).plants.length, before + 1);
assert.ok($$('details.card').length === before + 1);

// Add a log
const form = $('form[data-act=log]');
form.querySelector('input[name=t]').value = 'Watered <b>x</b>';
form.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
assert.ok(document.body.innerHTML.includes('Watered &lt;b&gt;x&lt;/b&gt;'), 'log text is escaped');
assert.ok(!$('#view b'), 'no injected <b>');

// Status change
const sel = $('select[data-act=status]');
sel.value = 'ready';
sel.dispatchEvent(new window.Event('change', { bubbles: true }));
assert.ok(JSON.parse(window.localStorage.getItem('growbuddy.web.v1')).plants.some((p) => p.status === 'ready'));

// Debug
tab('debug');
assert.equal($$('[data-act=sym]').length, 16);
assert.equal($('[data-act=check]').disabled, true);
click($('[data-act=sym][data-v=bleached]'));
assert.equal($('[data-act=check]').disabled, false);
click($('[data-act=check]'));
assert.match($('#view').textContent, /Sunburn/);
click($('[data-act=sym][data-v=wilt_wet]'));
click($('[data-act=check]'));
assert.match($('#view').textContent, /Overwatering/);

// Sales
tab('sales');
const tiles = $('.tiles').textContent;
assert.match(tiles, /₱330\.00/, 'example revenue 3 x 150 = 450 less cost 120 -> profit 330');
const sf = $('form[data-act=sale]');
sf.querySelector('[name=item]').value = 'Pothos';
sf.querySelector('[name=qty]').value = '2';
sf.querySelector('[name=price]').value = '80';
sf.querySelector('[name=cost]').value = '50';
sf.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
assert.match($('.tiles').textContent, /₱610\.00/, 'revenue now 450+160');
assert.match($('.tiles').textContent, /₱440\.00/, 'profit now 330+110');
click($('[data-act=rmsale]'));

// Clear examples
click($('[data-act=clearex]'));
const st = JSON.parse(window.localStorage.getItem('growbuddy.web.v1'));
assert.ok(!st.plants.some((p) => p.example) && !st.sales.some((p) => p.example));

assert.deepEqual(errors, [], 'no page errors');
console.log('web smoke: OK');
