'use strict';
// Writes expected results from the tested JS logic, so the Dart port can be checked against them
// with `flutter test` (grow_buddy/test/parity_test.dart).
const fs = require('node:fs');
const path = require('node:path');
const plants = require('../data/plants.json');
const data = require('../data/symptoms.json');
const { checkFit, rankCauses } = require('../src/core');

const app = path.resolve(process.argv[2] || path.join(__dirname, '..', '..', 'grow_buddy'));

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

const out = path.join(app, 'test', 'fixtures', 'parity.json');
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, JSON.stringify({ plantCount: plants.length, fits, ranks }));
console.log(`wrote ${fits.length} fit cases and ${ranks.length} rank cases to ${out}`);
