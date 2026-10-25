'use strict';
// Writes expected results from the tested JS logic, so the Dart port can be checked against them
// with `flutter test` (grow_buddy_client/test/parity_test.dart).
const fs = require('node:fs');
const path = require('node:path');
const plants = require('../data/plants.json');
const data = require('../data/symptoms.json');
const {
  checkFit, rankCauses, salesSummary, margin,
  dayNumber, addDays, wateringStatus, readyEstimate, salesByMonth, salesByVariety,
} = require('../src/core');

const app = path.resolve(process.argv[2] || path.join(__dirname, '..', '..', 'grow_buddy_client'));

const fits = [];
for (const p of plants) {
  for (let h = 0; h <= 8; h += 0.5) {
    const f = checkFit(p, h);
    fits.push({ id: p.id, hrs: h, verdict: f.verdict, headline: f.headline, tips: f.tips });
  }
}

const ids = data.symptoms.map((s) => s.id);
const combos = ids.map((id) => [id]);
// deterministic pairs and triples
for (let i = 0; i < ids.length; i += 1) combos.push([ids[i], ids[(i * 3 + 1) % ids.length]]);
for (let i = 0; i < ids.length; i += 2) combos.push([ids[i], ids[(i + 5) % ids.length], ids[(i + 9) % ids.length]]);
const ranks = combos
  .filter((c) => new Set(c).size === c.length)
  .map((c) => {
    const r = rankCauses(c, data);
    return { symptoms: c, order: r.map((x) => x.id), scores: r.map((x) => x.score) };
  });

// Date edge cases: month ends, leap day, year change, negative offsets.
const starts = ['2024-02-28', '2025-02-28', '2026-01-31', '2026-10-25', '2026-12-30', '2027-03-01'];
const offsets = [-40, -1, 0, 1, 2, 30, 59, 60, 365];
const dates = [];
for (const d of starts) {
  for (const n of offsets) dates.push({ ymd: d, n, day: dayNumber(d), plus: addDays(d, n) });
}

const today = '2026-10-25';
const water = [];
for (let ago = -2; ago <= 12; ago += 1) {
  for (const every of [1, 2, 3, 7, 14]) {
    const last = addDays(today, -ago);
    water.push({ last, every, today, ...wateringStatus(last, every, today) });
  }
}

const ready = [];
for (let age = 0; age <= 130; age += 5) {
  for (const [lo, hi] of [[21, 35], [60, 120], [180, 365]]) {
    const planted = addDays(today, -age);
    ready.push({ planted, lo, hi, today, ...readyEstimate(planted, lo, hi, today) });
  }
}

const sampleSales = [
  { id: 's1', item: 'Pothos', qty: 3, unitPrice: 120, cost: 90, date: '2026-08-30T09:00:00.000', guideId: 'pothos' },
  { id: 's2', item: 'Snake plant', qty: 2, unitPrice: 250.5, cost: 100, date: '2026-09-02T10:30:00.000', guideId: 'sansevieria' },
  { id: 's3', item: 'Mystery pot', qty: 1, unitPrice: 80, cost: 95, date: '2026-09-15T16:00:00.000' },
  { id: 's4', item: 'Pothos', qty: 5, unitPrice: 110, cost: 150, date: '2026-09-28T08:00:00.000', guideId: 'pothos' },
  { id: 's5', item: 'Basil', qty: 10, unitPrice: 35, cost: 120, date: '2026-10-03T07:45:00.000', guideId: 'basil' },
  { id: 's6', item: 'Snake plant', qty: 1, unitPrice: 300, cost: 100, date: '2026-10-20T12:00:00.000', guideId: 'sansevieria' },
  { id: 's7', item: 'Unlinked herb', qty: 4, unitPrice: 0.1, cost: 0.3, date: '2027-01-01T00:00:00.000', guideId: '' },
];
const salesCases = [[], sampleSales.slice(0, 1), sampleSales].map((list) => {
  const sum = salesSummary(list);
  return {
    sales: list,
    summary: sum,
    margin: margin(sum),
    byMonth: salesByMonth(list),
    byVariety: salesByVariety(list),
  };
});

const out = path.join(app, 'test', 'fixtures', 'parity.json');
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, JSON.stringify({ plantCount: plants.length, fits, ranks, dates, water, ready, salesCases }));
console.log(
  `wrote ${fits.length} fit, ${ranks.length} rank, ${dates.length} date, ${water.length} water, ` +
    `${ready.length} ready and ${salesCases.length} sales cases to ${out}`
);
