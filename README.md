# Grow Buddy

A plant-growing helper for beginners. It tells you whether a plant suits a spot that only gets afternoon sun, helps diagnose sick plants, and tracks your plants and sales.

**Live web app:** https://johnkg.github.io/grow-buddy/

## Features

- **Guide**: 30 starter plants. Enter your afternoon-sun hours and get a Good / Maybe / Poor fit with growing tips.
- **My plants**: track what you grow, its status (growing / ready / sold), log entries, watering reminders and a ready-to-sell estimate.
- **Diagnose**: pick symptoms for a quick rule-based check, or add a photo and ask Claude. Shows likely causes and how to fix each one.
- **Sales**: record sales and costs linked to plants, and see revenue, cost and profit by month and by plant.
- **Backup**: export and import your data from Settings.

Data stays on the device (SharedPreferences, or browser localStorage on web). The app works in light and dark mode.

## Repository layout

| Folder | What it holds |
| --- | --- |
| `grow_buddy_client/` | Flutter app for web, Android and iOS |
| `grow_buddy_server/` | Zero-dependency Node 20+ server, shared logic and the plant and symptom data |

`grow_buddy_server/data/plants.json` and `symptoms.json` are the source of truth. The Dart files in `grow_buddy_client/lib/data/` and `grow_buddy_client/test/fixtures/parity.json` are generated from them, so do not edit those by hand.

## Getting started

### Server

Requires Node 20 or later.

```bash
cd grow_buddy_server
npm test    # run the tests
npm start   # serve on http://localhost:8787
```

The server exposes `GET /api/plants`, `GET /api/symptoms` and `POST /api/diagnose`. The diagnose route calls the Claude API and reads these environment variables:

| Variable | Purpose |
| --- | --- |
| `ANTHROPIC_API_KEY` | Required for photo diagnosis |
| `APP_TOKEN` | Optional shared secret the app must send |
| `CLAUDE_MODEL` | Model to use (default `claude-sonnet-5-5`) |
| `ALLOWED_ORIGIN` | CORS origin (default `*`) |
| `PORT` | Port to listen on (default `8787`) |

After you edit `data/plants.json` or `data/symptoms.json`, regenerate the app's data files:

```bash
npm run gen
```

### App

Requires Flutter 3.47.4.

```bash
cd grow_buddy_client
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

To use photo diagnosis, set the server URL in the app's Settings.

## Testing

- Server: `npm test` in `grow_buddy_server`.
- App: `flutter test` in `grow_buddy_client`. A parity test checks that the Dart logic matches `grow_buddy_server/src/core.js`.

## Deployment

GitHub Actions (`.github/workflows/deploy-web.yml`) runs the server and app tests on every push and pull request. On pushes to `main` it also builds the web app and deploys it to GitHub Pages.

The Node server is not hosted yet, so Ask AI diagnosis does not work on the live site.

## Notes

- Sun ranges, watering intervals and days-to-sell values are general guidance, not verified data. Edit `plants.json` to suit your conditions.
- Android and iOS still need camera and photo-library permission entries for `image_picker`.

See [TODO.md](TODO.md) for planned work.
