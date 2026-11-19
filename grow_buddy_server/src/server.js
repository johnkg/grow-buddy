'use strict';
const http = require('node:http');
const crypto = require('node:crypto');
const plants = require('../data/plants.json');
const symptoms = require('../data/symptoms.json');
const { buildRequest } = require('./prompt');
const { validateDiagnose, ValidationError } = require('./validate');

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';

/**
 * Create the HTTP server. Everything configurable is a parameter so tests can
 * inject a fake fetch and tiny limits.
 */
function createServer(opts = {}) {
  const {
    apiKey = process.env.ANTHROPIC_API_KEY || '',
    appToken = process.env.APP_TOKEN || '', // optional shared secret
    model = process.env.CLAUDE_MODEL || 'claude-sonnet-5-5',
    allowedOrigin = process.env.ALLOWED_ORIGIN || '*',
    fetchImpl = globalThis.fetch,
    maxBodyBytes = 8 * 1024 * 1024,
    rateLimitPerMin = 10,
    // Ceilings across ALL clients, so a pool of IPs cannot run up the Anthropic bill.
    globalLimitPerMin = Number(process.env.GLOBAL_LIMIT_PER_MIN) || 60,
    dailyLimit = Number(process.env.DAILY_LIMIT) || 500,
    // Only trust forwarding headers when a reverse proxy you control sits in front (Render, Fly, Cloudflare).
    trustProxy = process.env.TRUST_PROXY === '1',
    upstreamTimeoutMs = 30000,
    now = () => Date.now(),
  } = opts;

  const MAX_TRACKED_IPS = 5000;
  const hits = new Map(); // ip -> timestamps (ms)
  const globalHits = []; // timestamps (ms) of every accepted diagnose call in the last minute
  let day = { start: now(), count: 0 };

  /** Real client address. Behind a proxy the socket address is the proxy, so every user would share one bucket. */
  function clientIp(req) {
    if (trustProxy) {
      const cf = req.headers['cf-connecting-ip'];
      if (typeof cf === 'string' && cf) return cf.trim();
      const xff = req.headers['x-forwarded-for'];
      if (typeof xff === 'string' && xff) return xff.split(',')[0].trim();
    }
    return req.socket.remoteAddress || 'unknown';
  }

  /** Drop expired entries so the map cannot grow without bound. */
  function sweep(t) {
    for (const [ip, stamps] of hits) {
      if (!stamps.length || t - stamps[stamps.length - 1] >= 60000) hits.delete(ip);
    }
  }

  function limited(ip) {
    const t = now();
    if (hits.size >= MAX_TRACKED_IPS) sweep(t);
    // Still full of live entries: refuse new addresses instead of growing.
    if (hits.size >= MAX_TRACKED_IPS && !hits.has(ip)) return 'busy';

    const recent = (hits.get(ip) || []).filter((x) => t - x < 60000);
    if (recent.length >= rateLimitPerMin) {
      hits.set(ip, recent);
      return 'ip';
    }

    while (globalHits.length && t - globalHits[0] >= 60000) globalHits.shift();
    if (globalHits.length >= globalLimitPerMin) return 'global';
    if (t - day.start >= 86400000) day = { start: t, count: 0 };
    if (day.count >= dailyLimit) return 'daily';

    recent.push(t);
    hits.set(ip, recent);
    globalHits.push(t);
    day.count += 1;
    return false;
  }

  /** Constant-time token comparison. */
  function tokenOk(given) {
    if (typeof given !== 'string') return false;
    const a = crypto.createHash('sha256').update(given).digest();
    const b = crypto.createHash('sha256').update(appToken).digest();
    return crypto.timingSafeEqual(a, b);
  }

  function send(res, status, obj, extra = {}) {
    if (status === 204) {
      res.writeHead(204, {
        'access-control-allow-origin': allowedOrigin,
        'access-control-allow-headers': 'content-type, x-app-token',
        'access-control-allow-methods': 'GET, POST, OPTIONS',
      });
      return res.end();
    }
    const body = JSON.stringify(obj);
    res.writeHead(status, {
      'content-type': 'application/json; charset=utf-8',
      'content-length': Buffer.byteLength(body),
      'access-control-allow-origin': allowedOrigin,
      'access-control-allow-headers': 'content-type, x-app-token',
      'access-control-allow-methods': 'GET, POST, OPTIONS',
      ...extra,
    });
    res.end(body);
  }

  function readBody(req) {
    return new Promise((resolve, reject) => {
      let size = 0;
      let tooBig = false;
      const chunks = [];
      req.on('data', (c) => {
        if (tooBig) return; // drain the rest without storing it, so the 413 can be delivered
        size += c.length;
        if (size > maxBodyBytes) {
          tooBig = true;
          chunks.length = 0;
          reject(Object.assign(new Error('body too large'), { status: 413 }));
          return;
        }
        chunks.push(c);
      });
      req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
      req.on('error', reject);
    });
  }

  async function diagnose(req, res) {
    if (!apiKey) return send(res, 503, { error: 'server has no ANTHROPIC_API_KEY configured' });
    if (appToken && !tokenOk(req.headers['x-app-token'])) {
      return send(res, 401, { error: 'bad or missing x-app-token' });
    }
    const why = limited(clientIp(req));
    if (why === 'daily') return send(res, 429, { error: 'daily limit reached, try again tomorrow' }, { 'retry-after': '3600' });
    if (why) return send(res, 429, { error: 'too many requests, try again in a minute' }, { 'retry-after': '60' });
    // Refuse oversized bodies before reading them.
    if (Number(req.headers['content-length']) > maxBodyBytes) {
      return send(res, 413, { error: 'request body too large' });
    }

    let raw;
    try {
      raw = await readBody(req);
    } catch (e) {
      return send(res, e.status || 400, { error: e.status === 413 ? 'request body too large' : 'could not read body' });
    }
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return send(res, 400, { error: 'body is not valid JSON' });
    }
    let input;
    try {
      input = validateDiagnose(parsed);
    } catch (e) {
      if (e instanceof ValidationError) return send(res, 400, { error: e.message });
      throw e;
    }

    let upstream;
    try {
      upstream = await fetchImpl(ANTHROPIC_URL, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify(buildRequest(input, model)),
        signal: AbortSignal.timeout(upstreamTimeoutMs),
      });
    } catch {
      return send(res, 504, { error: 'AI service did not respond in time' });
    }
    if (!upstream.ok) {
      // Log status only. Never forward the upstream body or headers (may echo request details).
      console.error(`upstream error ${upstream.status}`);
      return send(res, 502, { error: 'AI service error', upstreamStatus: upstream.status });
    }
    let data;
    try {
      data = await upstream.json();
    } catch {
      return send(res, 502, { error: 'AI service returned an unreadable response' });
    }
    const text = (Array.isArray(data.content) ? data.content : [])
      .filter((p) => p && p.type === 'text' && typeof p.text === 'string')
      .map((p) => p.text)
      .join('\n')
      .trim();
    if (!text) return send(res, 502, { error: 'AI service returned no text' });
    return send(res, 200, { diagnosis: text });
  }

  const server = http.createServer(async (req, res) => {
    try {
      const path = new URL(req.url, 'http://x').pathname;
      if (req.method === 'OPTIONS') return send(res, 204, {});
      if (req.method === 'GET' && path === '/health') return send(res, 200, { ok: true });
      if (req.method === 'GET' && path === '/api/plants') return send(res, 200, plants);
      if (req.method === 'GET' && path === '/api/symptoms') return send(res, 200, symptoms);
      if (req.method === 'POST' && path === '/api/diagnose') return await diagnose(req, res);
      return send(res, 404, { error: 'not found' });
    } catch (e) {
      console.error('unhandled', e && e.message);
      if (!res.headersSent) send(res, 500, { error: 'internal error' });
    }
  });
  // Cut off slow-loris style connections that trickle bytes to hold sockets open.
  server.headersTimeout = 10000;
  server.requestTimeout = 30000;
  server.keepAliveTimeout = 5000;
  server.maxHeadersCount = 50;
  return server;
}

if (require.main === module) {
  if (process.env.NODE_ENV === 'production') {
    // Fail closed: an open paid endpoint on the internet is how API bills get run up.
    if (!process.env.APP_TOKEN) {
      console.error('Refusing to start: set APP_TOKEN when NODE_ENV=production.');
      process.exit(1);
    }
    if (!process.env.ALLOWED_ORIGIN) console.warn('ALLOWED_ORIGIN is not set; CORS allows any origin.');
  }
  const port = Number(process.env.PORT) || 8787;
  createServer().listen(port, () => console.log(`grow-buddy server on :${port}`));
}

module.exports = { createServer };
