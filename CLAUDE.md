# Grow Buddy

Owner: Joseph. Experienced .NET dev, beginner plant grower. Spot gets afternoon sun only. Wants an app to
(1) teach how to grow a plant variety and say if it fits afternoon-only sun, (2) "debug" sick plants,
(3) track his plants, (4) track sales. Flutter, must also run as web for testing. Based in the Philippines (₱).

## Layout
- `grow_buddy_client/`: Flutter app (package `grow_buddy`). Platforms scaffolded: web, android, ios.
- `grow_buddy_server/`: zero-dep Node 20+ backend and source of truth for data.
  - `data/plants.json` (30 plants), `data/symptoms.json`: edit these, then `npm run gen`.
  - `src/core.js`: fit check, cause ranking, sales math (tested). `src/server.js`: /api/diagnose proxy to Claude.
  - `web/dist/grow-buddy.html`: single-file web prototype (built by `scripts/build_web.js`).
- `lib/data/*.dart` and `test/fixtures/parity.json` are GENERATED. Never hand-edit; run `npm run gen` in the server folder.

## State
- `npm test` in grow_buddy_server: 31 pass. `node test/web.smoke.js` needs jsdom (NODE_PATH).
- Flutter 3.47.4 at ~/flutter. Cloud sessions install it via `.claude/hooks/session-start.sh` (keep version in sync with CI). `flutter analyze` clean; `flutter test` 7 pass (parity + app_flow widget tests).
  `flutter build web` works; app loads and renders in a browser.
- Dialogs with text fields must own their controllers (StatefulWidget, e.g. `showTextPrompt`); disposing
  right after `showDialog` returns crashes during the exit animation.
- Real Claude API call never exercised. Run server with `ANTHROPIC_API_KEY` set, test one /api/diagnose.
- Android/iOS need image_picker permissions (manifest / Info.plist).

## Rules
- Keep Dart logic identical to src/core.js; the parity test enforces it.
- Plant sun ranges are general knowledge, not verified. Say so; let Joseph edit the JSON.
- Prefer terse replies (Joseph likes caveman style).

## Next ideas
Watering reminders, per-plant photo history, price suggestions, listing export for selling, real hosting + accounts.
