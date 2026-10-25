# TODO

- [ ] **Host the Node server** so Ask AI works on the live site.
  Sign up on Render, Fly.io or Railway and add `ANTHROPIC_API_KEY` and `APP_TOKEN` there as secrets (Joseph does this).
  Claude writes the host config, CORS for `johnkg.github.io` and the deploy steps, then points the app's server URL at it.
- [x] **Update GitHub Actions to Node 24 versions** (`actions/checkout`, `setup-node`, `upload-pages-artifact`, `deploy-pages`)
  to clear the Node 20 deprecation warnings in `.github/workflows/deploy-web.yml`. Small job.
- [ ] **Photo permissions for Android/iOS.** `image_picker` needs camera and photo-library permission entries in
  `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.
- [x] Backup / restore (Settings), watering badges with a per-plant interval, sales linked to plants,
  sales insights (by month, by plant), ready-to-sell estimate.
- [ ] **Feature ideas**: phone notifications for watering (needs `flutter_local_notifications`),
  per-plant photo history (photos are too big for localStorage on web), price suggestions from past sales,
  listing export for selling, plant finder sorted by sun fit, real hosting + accounts.
