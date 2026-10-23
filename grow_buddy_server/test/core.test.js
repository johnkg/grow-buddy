'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const plants = require('../data/plants.json');
const symptoms = require('../data/symptoms.json');
const { checkFit, rankCauses, salesSummary, margin } = require('../src/core');

const byId = (id) => plants.find((p) => p.id === id);

test('plants data: schema and unique ids', () => {
  const ids = new Set();
  const cats = new Set(['ornamental', 'succulent', 'herb', 'vegetable', 'fruit', 'flowering']);
  const diffs = new Set(['Easy', 'Medium', 'Hard']);
  for (const p of plants) {
    assert.ok(!ids.has(p.id), `duplicate id ${p.id}`);
    ids.add(p.id);
    assert.match(p.id, /^[a-z0-9]+$/, `bad id ${p.id}`);
    for (const k of ['name', 'emoji', 'water', 'soil', 'timeToSell', 'sellNote']) {
      assert.equal(typeof p[k], 'string', `${p.id}.${k}`);
      assert.ok(p[k].length > 0, `${p.id}.${k} empty`);
    }
    assert.ok(cats.has(p.category), `${p.id} category ${p.category}`);
    assert.ok(diffs.has(p.difficulty), `${p.id} difficulty`);
    assert.ok(Number.isInteger(p.minAfternoonHrs) && Number.isInteger(p.maxAfternoonHrs), `${p.id} hrs`);
    assert.ok(p.minAfternoonHrs >= 0 && p.maxAfternoonHrs <= 9, `${p.id} hrs range`);
    assert.ok(p.minAfternoonHrs <= p.maxAfternoonHrs, `${p.id} min<=max`);
    assert.equal(typeof p.heatSensitive, 'boolean', `${p.id}.heatSensitive`);
    assert.ok(Array.isArray(p.steps) && p.steps.length >= 3, `${p.id} steps`);
    assert.ok(Array.isArray(p.afternoonTips) && p.afternoonTips.length >= 1, `${p.id} tips`);
  }
  assert.ok(plants.length >= 30);
});

test('symptoms data: every cause reference exists', () => {
  const sids = new Set();
  for (const s of symptoms.symptoms) {
    assert.ok(!sids.has(s.id), `duplicate symptom ${s.id}`);
    sids.add(s.id);
    assert.ok(s.causes.length >= 1);
    for (const c of s.causes) assert.ok(symptoms.causes[c], `${s.id} -> missing cause ${c}`);
  }
  for (const [id, c] of Object.entries(symptoms.causes)) {
    for (const k of ['title', 'why', 'fix']) assert.ok(c[k] && c[k].length > 0, `${id}.${k}`);
  }
});

test('checkFit: in range, not heat sensitive -> good', () => {
  assert.equal(checkFit(byId('sansevieria'), 4).verdict, 'good');
  assert.equal(checkFit(byId('lemongrass'), 6).verdict, 'good');
});

test('checkFit: boundaries are inclusive', () => {
  const p = byId('basil'); // 4-7
  assert.equal(checkFit(p, 4).verdict, 'good');
  assert.equal(checkFit(p, 7).verdict, 'good');
});

test('checkFit: too little sun, gap <=1 maybe, gap >1 poor', () => {
  const p = byId('basil'); // min 4
  const near = checkFit(p, 3);
  assert.equal(near.verdict, 'maybe');
  assert.equal(near.headline, 'Not enough sun');
  assert.equal(checkFit(p, 2.5).verdict, 'poor');
});

test('checkFit: too much sun', () => {
  const p = byId('pothos'); // max 2
  const r = checkFit(p, 4);
  assert.equal(r.verdict, 'poor');
  assert.equal(r.headline, 'Too much afternoon sun');
  assert.equal(checkFit(p, 3).verdict, 'maybe');
});

test('checkFit: heat sensitive in range at >=4 hrs -> maybe with protection', () => {
  const p = byId('pechay'); // 3-5, heat sensitive
  assert.equal(checkFit(p, 3).verdict, 'good');
  const r = checkFit(p, 4);
  assert.equal(r.verdict, 'maybe');
  assert.equal(r.headline, 'Works with some protection');
});

test('checkFit: every plant returns a verdict across 0-8 hrs', () => {
  for (const p of plants) {
    for (let h = 0; h <= 8; h += 0.5) {
      const r = checkFit(p, h);
      assert.ok(['good', 'maybe', 'poor'].includes(r.verdict));
      assert.ok(r.tips.length >= 2);
    }
  }
});

test('checkFit: afternoon-only 4 hrs gives sensible answers for common plants', () => {
  assert.equal(checkFit(byId('aloe'), 4).verdict, 'good');
  assert.notEqual(checkFit(byId('peacelily'), 4).verdict, 'good');
  assert.notEqual(checkFit(byId('monstera'), 4).verdict, 'good');
  assert.equal(checkFit(byId('calamansi'), 4).verdict, 'poor');
});

test('rankCauses: no symptoms -> empty', () => {
  assert.deepEqual(rankCauses([], symptoms), []);
});

test('rankCauses: bleached alone points at sunburn', () => {
  const r = rankCauses(['bleached'], symptoms);
  assert.equal(r.length, 1);
  assert.equal(r[0].id, 'sunburn');
});

test('rankCauses: wilting + wet + mushy base ranks rot/overwater on top', () => {
  const r = rankCauses(['wilt_wet', 'mushy_base'], symptoms);
  assert.deepEqual(r.slice(0, 2).map((x) => x.id).sort(), ['overwater', 'rootrot']);
});

test('rankCauses: combining symptoms boosts shared causes', () => {
  const single = rankCauses(['brown_tips'], symptoms);
  assert.equal(single[0].id, 'underwater');
  const combo = rankCauses(['brown_tips', 'bleached', 'wilt_afternoon'], symptoms);
  assert.equal(combo[0].id, 'sunburn');
});

test('rankCauses: ignores unknown symptom ids and is deterministic', () => {
  const a = rankCauses(['nope', 'yellow_lower'], symptoms);
  const b = rankCauses(['yellow_lower'], symptoms);
  assert.deepEqual(a, b);
  assert.equal(a[0].id, 'overwater');
});

test('salesSummary and margin', () => {
  const s = salesSummary([
    { qty: 3, unitPrice: 150, cost: 120 },
    { qty: 2, unitPrice: 80, cost: 50 },
  ]);
  assert.deepEqual(s, { revenue: 610, cost: 170, profit: 440 });
  assert.ok(Math.abs(margin(s) - 440 / 610) < 1e-12);
  assert.deepEqual(salesSummary([]), { revenue: 0, cost: 0, profit: 0 });
  assert.equal(margin(salesSummary([])), null);
});

test('salesSummary: loss is negative profit', () => {
  const s = salesSummary([{ qty: 1, unitPrice: 50, cost: 200 }]);
  assert.equal(s.profit, -150);
});
