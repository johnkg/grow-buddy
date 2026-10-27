'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const plants = require('../data/plants.json');
const symptoms = require('../data/symptoms.json');
const {
  checkFit, rankCauses, salesSummary, margin,
  dayNumber, addDays, wateringStatus, readyEstimate, salesByMonth, salesByVariety,
} = require('../src/core');

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
    for (const k of ['waterEveryDays', 'daysToSellMin', 'daysToSellMax']) {
      assert.ok(Number.isInteger(p[k]) && p[k] > 0, `${p.id}.${k}`);
    }
    assert.ok(p.waterEveryDays <= 30, `${p.id} waterEveryDays`);
    assert.ok(p.daysToSellMin <= p.daysToSellMax, `${p.id} daysToSell min<=max`);
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

test('addDays: month ends, leap day, year change, negative', () => {
  assert.equal(addDays('2026-01-31', 1), '2026-02-01');
  assert.equal(addDays('2024-02-28', 1), '2024-02-29');
  assert.equal(addDays('2025-02-28', 1), '2025-03-01');
  assert.equal(addDays('2026-12-30', 3), '2027-01-02');
  assert.equal(addDays('2026-03-01', -1), '2026-02-28');
  assert.equal(addDays('2026-10-25T10:11:12.123456', 0), '2026-10-25'); // ISO timestamps are fine
});

test('dayNumber: whole-day differences', () => {
  assert.equal(dayNumber('1970-01-01'), 0);
  assert.equal(dayNumber('2026-10-26') - dayNumber('2026-10-25'), 1);
  assert.equal(dayNumber('2025-03-01') - dayNumber('2025-02-28'), 1);
});

test('wateringStatus: ok, due today, overdue', () => {
  const today = '2026-10-25';
  assert.deepEqual(wateringStatus('2026-10-25', 3, today), { dueOn: '2026-10-28', daysUntil: 3, state: 'ok' });
  assert.deepEqual(wateringStatus('2026-10-22', 3, today), { dueOn: '2026-10-25', daysUntil: 0, state: 'today' });
  assert.deepEqual(wateringStatus('2026-10-20', 3, today), { dueOn: '2026-10-23', daysUntil: -2, state: 'overdue' });
});

test('readyEstimate: window edges are inclusive', () => {
  const planted = '2026-10-01'; // 30-60 days -> 2026-10-31 .. 2026-11-30
  assert.equal(readyEstimate(planted, 30, 60, '2026-10-30').phase, 'notYet');
  assert.equal(readyEstimate(planted, 30, 60, '2026-10-31').phase, 'window');
  assert.equal(readyEstimate(planted, 30, 60, '2026-11-30').phase, 'window');
  const late = readyEstimate(planted, 30, 60, '2026-12-01');
  assert.equal(late.phase, 'late');
  assert.equal(late.earliest, '2026-10-31');
  assert.equal(late.latest, '2026-11-30');
  assert.equal(readyEstimate(planted, 30, 60, '2026-10-25').daysToEarliest, 6);
});

const sale = (o) => ({ qty: 1, unitPrice: 100, cost: 0, date: '2026-10-01T00:00:00', ...o });

test('salesByMonth: groups by month, oldest first, sums add up', () => {
  const rows = salesByMonth([
    sale({ date: '2026-10-03T08:00:00', qty: 2, unitPrice: 50, cost: 30 }),
    sale({ date: '2026-09-28T08:00:00', unitPrice: 200, cost: 80 }),
    sale({ date: '2026-10-20T08:00:00', unitPrice: 10 }),
  ]);
  assert.deepEqual(rows.map((r) => r.key), ['2026-09', '2026-10']);
  assert.deepEqual(rows[1], { key: '2026-10', qty: 3, revenue: 110, cost: 30, profit: 80 });
  assert.deepEqual(salesByMonth([]), []);
});

test('salesByVariety: groups by guideId, unlinked -> other, most profit first', () => {
  const rows = salesByVariety([
    sale({ guideId: 'pothos', unitPrice: 100, cost: 60 }),
    sale({ guideId: 'basil', unitPrice: 300 }),
    sale({ unitPrice: 20, cost: 50 }),
    sale({ guideId: '', unitPrice: 20 }),
    sale({ guideId: 'pothos', unitPrice: 100, cost: 60 }),
  ]);
  assert.deepEqual(rows.map((r) => r.key), ['basil', 'pothos', 'other']);
  assert.equal(rows[1].qty, 2);
  assert.equal(rows[1].profit, 80);
  assert.equal(rows[2].profit, -10);
});

test('sales rows agree with salesSummary', () => {
  const list = [sale({ unitPrice: 12.5, cost: 3 }), sale({ qty: 4, unitPrice: 7.25, cost: 9, guideId: 'aloe' })];
  const total = salesSummary(list);
  const byMonth = salesByMonth(list);
  assert.equal(byMonth.reduce((a, r) => a + r.profit, 0), total.profit);
  assert.equal(margin(salesSummary([])), null);
});
