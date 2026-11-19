# Grow Buddy server

Zero-dependency Node (20+) backend and shared logic for Grow Buddy.

```bash
export ANTHROPIC_API_KEY=sk-ant-...        # required for /api/diagnose
export APP_TOKEN=some-long-random-string   # optional shared secret (x-app-token header)
export ALLOWED_ORIGIN=https://your.site    # CORS origin, default * (set it in production)
export TRUST_PROXY=1                       # only behind Render/Fly/Cloudflare: use x-forwarded-for for the client IP
export DAILY_LIMIT=500                     # all clients combined, per 24h (default 500)
export GLOBAL_LIMIT_PER_MIN=60             # all clients combined (default 60)
export NODE_ENV=production                 # refuses to start without APP_TOKEN
npm start                                  # listens on :8787 (PORT to change)
npm test                                   # 38 tests, no network needed
npm run gen                                # regenerate ../grow_buddy_client/lib/data/*.dart from data/*.json
node scripts/build_web.js                  # rebuild web/dist/grow-buddy.html
```

Endpoints: `GET /health`, `GET /api/plants`, `GET /api/symptoms`, `POST /api/diagnose`
(`{plantName, sunHrs, symptoms[], notes, photoBase64?, photoMime?}` -> `{diagnosis}`).

Limits: 10 requests/min per IP, 60/min and 500/day across all clients, 8 MB body, 5 MB photo. Counters are
in memory and reset on restart. Do not set `TRUST_PROXY=1` unless a proxy you control is in front, because
clients could then spoof their IP. Also set a hard monthly spend limit on the Anthropic API key in the
Anthropic Console, and put a Cloudflare rate-limiting rule in front of `/api/diagnose`.

`test/web.smoke.js` drives the built page in jsdom (`npm i jsdom` somewhere, then set NODE_PATH).
Not exercised: calls to the real Claude API (this sandbox cannot reach it), so the first live
`/api/diagnose` call is your integration test.
