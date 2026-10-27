# Grow Buddy

Beginner plant-growing helper. Flutter (mobile + web).

- **Guide**: starter plants, set your afternoon-sun hours, get Good / Maybe / Poor fit and tips.
- **My plants**: track what you grow, status (growing / ready / sold), log entries.
- **Diagnose**: pick symptoms for a quick rule-based check, or add a photo and ask Claude. Shows likely causes and what to do about each.
- **Sales**: record sales and costs, see revenue / cost / profit.

## Run it

This folder holds only `lib/`, `pubspec.yaml` and this file (written without a Flutter SDK, so never compiled yet).

```bash
flutter create grow_buddy_tmp --platforms=web,android,ios
cp -r grow_buddy_tmp/{android,ios,web,.metadata,analysis_options.yaml} .   # keep platform folders
rm -rf grow_buddy_tmp
flutter pub get
flutter analyze
flutter run -d chrome
```

Or: run `flutter create .` inside this folder, then restore `lib/` and `pubspec.yaml` if it overwrote them.

Requires a recent Flutter (3.27+ for `withValues`; 3.33+ for `DropdownButtonFormField.initialValue`).
If your Flutter is older, use `value:` in `diagnose_screen.dart` and `withOpacity` in `guide_screen.dart`.

## AI diagnosis

Photo diagnosis goes through `grow_buddy_server` (a small Node backend that holds the Claude API key).
Start it, then in the app tap the gear icon and set the Server URL (default `http://localhost:8787`).
Phone testing needs the server reachable from the phone (same Wi-Fi: use your computer's LAN IP, not localhost).
Mobile photo access needs permission entries (Android manifest, iOS Info.plist) per the `image_picker` docs.

## Data

`lib/data/*.dart` and `test/fixtures/parity.json` are generated from
`grow_buddy_server/data/*.json`. Edit the JSON, then run `npm run gen` in the server folder.

## Next ideas

- Real backend + accounts if you want to share it
- Reminders for watering
- Photo history per plant, price suggestions, listing export for selling

## Check the Dart port

`flutter test` runs `test/parity_test.dart`, which compares the Dart fit check and cause ranking with the
tested JS logic across every plant, every sun hour, and 40 symptom combinations.
