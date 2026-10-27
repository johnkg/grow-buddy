# Grow Buddy server

Zero-dependency Node (20+) backend and shared logic for Grow Buddy.

```bash
export ANTHROPIC_API_KEY=sk-ant-...        # required for /api/diagnose
export APP_TOKEN=some-long-random-string   # optional shared secret (x-app-token header)
export ALLOWED_ORIGIN=https://your.site    # optional CORS origin, default *
npm start                                  # listens on :8787 (PORT to change)
npm test                                   # 38 tests, no network needed
npm run gen                                # regenerate ../grow_buddy_client/lib/data/*.dart from data/*.json
node scripts/build_web.js                  # rebuild web/dist/grow-buddy.html
```

Endpoints: `GET /health`, `GET /api/plants`, `GET /api/symptoms`, `POST /api/diagnose`
(`{plantName, sunHrs, symptoms[], notes, photoBase64?, photoMime?}` -> `{diagnosis}`).

Limits: 10 requests/min per IP (in memory), 8 MB body, 5 MB photo. The rate limit and token are basic
protection. Put it behind HTTPS and a real gateway before sharing it widely.

`test/web.smoke.js` drives the built page in jsdom (`npm i jsdom` somewhere, then set NODE_PATH).
Not exercised: calls to the real Claude API (this sandbox cannot reach it), so the first live
`/api/diagnose` call is your integration test.
