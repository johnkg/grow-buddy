'use strict';
const http = require('node:http');
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
    upstreamTimeoutMs = 30000,
    now = () => Date.now(),
  } = opts;

  const hits = new Map(); // ip -> timestamps (ms)

  function limited(ip) {
    const t = now();
    const recent = (hits.get(ip) || []).filter((x) => t - x < 60000);
    if (recent.length >= rateLimitPerMin) {
      hits.set(ip, recent);
      return true;
    }
    recent.push(t);
    hits.set(ip, recent);
    return false;
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
    if (appToken && req.headers['x-app-token'] !== appToken) {
      return send(res, 401, { error: 'bad or missing x-app-token' });
    }
    const ip = req.socket.remoteAddress || 'unknown';
    if (limited(ip)) return send(res, 429, { error: 'too many requests, try again in a minute' }, { 'retry-after': '60' });

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

  return http.createServer(async (req, res) => {
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
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 8787;
  createServer().listen(port, () => console.log(`grow-buddy server on :${port}`));
}

module.exports = { createServer };
