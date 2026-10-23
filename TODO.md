# TODO

- [ ] **Host the Node server** so Ask AI works on the live site.
  Sign up on Render, Fly.io or Railway and add `ANTHROPIC_API_KEY` and `APP_TOKEN` there as secrets (Joseph does this).
  Claude writes the host config, CORS for `johnkg.github.io` and the deploy steps, then points the app's server URL at it.
- [ ] **Update GitHub Actions to Node 24 versions** (`actions/checkout`, `setup-node`, `upload-pages-artifact`, `deploy-pages`)
  to clear the Node 20 deprecation warnings in `.github/workflows/deploy-web.yml`. Small job.
- [ ] **Photo permissions for Android/iOS.** `image_picker` needs camera and photo-library permission entries in
  `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.
- [ ] **Feature ideas** (from `CLAUDE.md`): watering reminders, per-plant photo history, price suggestions,
  listing export for selling, real hosting + accounts.
