'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { validateDiagnose, ValidationError } = require('../src/validate');

/** Start a server on an ephemeral port with a fake upstream fetch. */
async function start(opts = {}) {
  const calls = [];
  const fakeFetch = opts.fetchImpl || (async (url, init) => {
    calls.push({ url, init, body: JSON.parse(init.body) });
    return {
      ok: true,
      status: 200,
      json: async () => ({ content: [{ type: 'text', text: 'Likely overwatering. Let it dry out.' }] }),
    };
  });
  const server = createServer({ apiKey: 'test-key', fetchImpl: fakeFetch, ...opts });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { server, base, calls, close: () => new Promise((r) => server.close(r)) };
}

const post = (base, path, body, headers = {}) =>
  fetch(base + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });

const good = { plantName: 'Pothos', sunHrs: 4, symptoms: ['Yellow leaves (lower/older)'], notes: 'water every day' };

test('GET /health, /api/plants, /api/symptoms', async () => {
  const s = await start();
  try {
    assert.deepEqual(await (await fetch(s.base + '/health')).json(), { ok: true });
    const plants = await (await fetch(s.base + '/api/plants')).json();
    assert.ok(plants.length >= 30);
    const sy = await (await fetch(s.base + '/api/symptoms')).json();
    assert.ok(sy.symptoms.length > 5 && sy.causes.overwater);
    assert.equal((await fetch(s.base + '/nope')).status, 404);
  } finally {
    await s.close();
  }
});

test('CORS preflight and headers', async () => {
  const s = await start({ allowedOrigin: 'https://example.test' });
  try {
    const r = await fetch(s.base + '/api/diagnose', { method: 'OPTIONS' });
    assert.equal(r.status, 204);
    assert.equal(r.headers.get('access-control-allow-origin'), 'https://example.test');
    assert.match(r.headers.get('access-control-allow-headers'), /content-type/);
  } finally {
    await s.close();
  }
});

test('diagnose: happy path forwards correct request and returns text', async () => {
  const s = await start({ model: 'test-model' });
  try {
    const r = await post(s.base, '/api/diagnose', good);
    assert.equal(r.status, 200);
    assert.deepEqual(await r.json(), { diagnosis: 'Likely overwatering. Let it dry out.' });
    assert.equal(s.calls.length, 1);
    const c = s.calls[0];
    assert.equal(c.url, 'https://api.anthropic.com/v1/messages');
    assert.equal(c.init.headers['x-api-key'], 'test-key');
    assert.equal(c.init.headers['anthropic-version'], '2023-06-01');
    assert.equal(c.body.model, 'test-model');
    assert.equal(c.body.max_tokens, 1024);
    assert.match(c.body.system, /beginner grower/);
    const content = c.body.messages[0].content;
    assert.equal(content.length, 1);
    assert.match(content[0].text, /Plant: Pothos/);
    assert.match(content[0].text, /4\.0 hrs\/day/);
    assert.match(content[0].text, /Yellow leaves/);
    assert.match(content[0].text, /Notes: water every day/);
  } finally {
    await s.close();
  }
});

test('diagnose: photo becomes an image block before the text', async () => {
  const s = await start();
  try {
    const photoBase64 = Buffer.from('fake image bytes').toString('base64');
    const r = await post(s.base, '/api/diagnose', { ...good, photoBase64, photoMime: 'image/png' });
    assert.equal(r.status, 200);
    const content = s.calls[0].body.messages[0].content;
    assert.equal(content.length, 2);
    assert.deepEqual(content[0], { type: 'image', source: { type: 'base64', media_type: 'image/png', data: photoBase64 } });
    assert.equal(content[1].type, 'text');
  } finally {
    await s.close();
  }
});

test('diagnose: data-URL prefix on photo is stripped', async () => {
  const s = await start();
  try {
    const b64 = Buffer.from('abc').toString('base64');
    const r = await post(s.base, '/api/diagnose', { ...good, photoBase64: `data:image/jpeg;base64,${b64}` });
    assert.equal(r.status, 200);
    assert.equal(s.calls[0].body.messages[0].content[0].source.data, b64);
  } finally {
    await s.close();
  }
});

test('diagnose: validation errors give 400 and never call upstream', async () => {
  const s = await start({ rateLimitPerMin: 1000 });
  try {
    const bad = [
      [{ ...good, plantName: '' }, /plantName/],
      [{ ...good, sunHrs: 'lots' }, /sunHrs/],
      [{ ...good, sunHrs: 99 }, /sunHrs/],
      [{ ...good, sunHrs: undefined }, /sunHrs/],
      [{ ...good, symptoms: 'yellow' }, /symptoms must be an array/],
      [{ ...good, symptoms: Array(21).fill('x') }, /too many/],
      [{ ...good, notes: 'x'.repeat(1001) }, /notes is too long/],
      [{ plantName: 'Pothos', sunHrs: 3 }, /at least one/],
      [{ ...good, photoBase64: '!!!not base64!!!' }, /base64/],
      [{ ...good, photoBase64: 'YWJj', photoMime: 'image/bmp' }, /photoMime/],
      [[1, 2], /JSON object/],
    ];
    for (const [body, re] of bad) {
      const r = await post(s.base, '/api/diagnose', body);
      assert.equal(r.status, 400, JSON.stringify(body).slice(0, 80));
      assert.match((await r.json()).error, re);
    }
    const r = await post(s.base, '/api/diagnose', '{not json');
    assert.equal(r.status, 400);
    assert.equal(s.calls.length, 0);
  } finally {
    await s.close();
  }
});

test('diagnose: oversized photo rejected', () => {
  const big = 'A'.repeat(Math.ceil((5 * 1024 * 1024 * 4) / 3) + 8);
  assert.throws(() => validateDiagnose({ plantName: 'x', sunHrs: 1, photoBase64: big }), ValidationError);
});

test('diagnose: body over limit -> 413', async () => {
  const s = await start({ maxBodyBytes: 200 });
  try {
    const r = await post(s.base, '/api/diagnose', { ...good, notes: 'y'.repeat(500) });
    assert.equal(r.status, 413);
    assert.equal(s.calls.length, 0);
  } finally {
    await s.close();
  }
});

test('diagnose: 503 when no API key configured', async () => {
  const s = await start({ apiKey: '' });
  try {
    const r = await post(s.base, '/api/diagnose', good);
    assert.equal(r.status, 503);
    assert.equal(s.calls.length, 0);
  } finally {
    await s.close();
  }
});

test('diagnose: x-app-token enforced when configured', async () => {
  const s = await start({ appToken: 'secret' });
  try {
    assert.equal((await post(s.base, '/api/diagnose', good)).status, 401);
    assert.equal((await post(s.base, '/api/diagnose', good, { 'x-app-token': 'wrong' })).status, 401);
    assert.equal((await post(s.base, '/api/diagnose', good, { 'x-app-token': 'secret' })).status, 200);
  } finally {
    await s.close();
  }
});

test('diagnose: rate limit per minute, resets after window', async () => {
  let t = 1_000_000;
  const s = await start({ rateLimitPerMin: 2, now: () => t });
  try {
    assert.equal((await post(s.base, '/api/diagnose', good)).status, 200);
    assert.equal((await post(s.base, '/api/diagnose', good)).status, 200);
    const limited = await post(s.base, '/api/diagnose', good);
    assert.equal(limited.status, 429);
    assert.equal(limited.headers.get('retry-after'), '60');
    t += 61_000;
    assert.equal((await post(s.base, '/api/diagnose', good)).status, 200);
  } finally {
    await s.close();
  }
});

test('diagnose: upstream error -> 502 without leaking body or key', async () => {
  const s = await start({
    fetchImpl: async () => ({ ok: false, status: 401, json: async () => ({ error: 'invalid x-api-key test-key' }) }),
  });
  const origErr = console.error;
  console.error = () => {};
  try {
    const r = await post(s.base, '/api/diagnose', good);
    assert.equal(r.status, 502);
    const text = await r.text();
    assert.ok(!text.includes('test-key'));
    assert.ok(!text.includes('invalid x-api-key'));
    assert.equal(JSON.parse(text).upstreamStatus, 401);
  } finally {
    console.error = origErr;
    await s.close();
  }
});

test('diagnose: upstream network failure/timeout -> 504', async () => {
  const s = await start({ fetchImpl: async () => { throw new Error('boom'); } });
  try {
    assert.equal((await post(s.base, '/api/diagnose', good)).status, 504);
  } finally {
    await s.close();
  }
});

test('diagnose: upstream with no text or bad JSON -> 502', async () => {
  const s1 = await start({ fetchImpl: async () => ({ ok: true, status: 200, json: async () => ({ content: [] }) }) });
  const s2 = await start({ fetchImpl: async () => ({ ok: true, status: 200, json: async () => { throw new Error('x'); } }) });
  try {
    assert.equal((await post(s1.base, '/api/diagnose', good)).status, 502);
    assert.equal((await post(s2.base, '/api/diagnose', good)).status, 502);
  } finally {
    await s1.close();
    await s2.close();
  }
});

test('diagnose: multiple text parts are joined, non-text parts ignored', async () => {
  const s = await start({
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      json: async () => ({ content: [{ type: 'text', text: 'one' }, { type: 'thinking', text: 'no' }, { type: 'text', text: 'two' }] }),
    }),
  });
  try {
    assert.deepEqual(await (await post(s.base, '/api/diagnose', good)).json(), { diagnosis: 'one\ntwo' });
  } finally {
    await s.close();
  }
});
