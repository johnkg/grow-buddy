'use strict';
// Builds web/dist/grow-buddy.html: one self-contained page from the template + data + core logic.
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

const core = read('src/core.js')
  .replace("'use strict';", '')
  .replace(/module\.exports\s*=\s*\{[^}]*\};?/, '');
// "</script" inside JSON would end the inline script early
const json = (v) => JSON.stringify(v).replace(/</g, '\\u003c');

let html = read('web/template.html');
html = html.replace('/*__PLANTS__*/[]', () => json(JSON.parse(read('data/plants.json'))));
html = html.replace('/*__SYMPTOMS__*/{}', () => json(JSON.parse(read('data/symptoms.json'))));
html = html.replace('/*__CORE__*/', () => core);

fs.mkdirSync(path.join(root, 'web', 'dist'), { recursive: true });
const out = path.join(root, 'web', 'dist', 'grow-buddy.html');
fs.writeFileSync(out, html);
console.log(`wrote ${out} (${(html.length / 1024).toFixed(0)} KB)`);
