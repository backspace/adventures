# Building poles_app

Three flavors, set via `--dart-define`:

| Flavor | Default API | Env switcher visible | Audience |
|---|---|---|---|
| `dev` | localhost | yes | local dev (Xcode/Android Studio Run) |
| `alpha` | staging | yes | TestFlight Internal + Play Internal Testing |
| `production` | prod | no | TestFlight External / App Store / Play Open Testing |

`F.appFlavor` is set from the `FLAVOR_NAME` build define. `app.dart` resolves the API root in priority order:

1. User-saved override (`UserService.getApiRootOverride()`)
2. `--dart-define=API_ROOT=...` (compile-time)
3. `.env.local` then `.env`
4. `http://localhost:4000`

## Local dev

```bash
flutter run -d <device>
# uses dev flavor by default, reads .env.local or .env for API_ROOT
```

## Versioning

`pubspec.yaml` carries the marketing version (e.g. `version: 1.0.0+1`). Bump the left side (`1.0.0` → `1.1.0`) by hand when you want a new public version; the right side is overridden at build time so its value doesn't matter.

The build number is derived from git commit count, which is always monotonic and reproducible:

```bash
--build-number=$(git rev-list --count HEAD)
```

That number maps back to a git revision if you ever need to investigate a crash. Apple wants the build number to increase per marketing version; Google wants it to increase across all releases ever. Commit count satisfies both because it only ever goes up.

## Alpha build

For testers who need to switch environments.

### iOS — TestFlight Internal

```bash
flutter build ipa \
  --build-number=$(git rev-list --count HEAD) \
  --dart-define=FLAVOR_NAME=alpha \
  --dart-define=API_ROOT=https://poles-staging.chromatin.ca \
  --dart-define=SENTRY_DSN=$SENTRY_DSN
```

Upload the resulting `build/ios/ipa/poles.ipa` via Xcode → Window → Organizer, or `xcrun altool --upload-app`. Add to TestFlight Internal group.

### Android — Play Internal Testing

```bash
flutter build appbundle \
  --build-number=$(git rev-list --count HEAD) \
  --dart-define=FLAVOR_NAME=alpha \
  --dart-define=API_ROOT=https://poles-staging.chromatin.ca \
  --dart-define=SENTRY_DSN=$SENTRY_DSN
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console → Testing → Internal testing → Create new release.

## Production build

For everyone else. No env switcher in the UI.

### iOS

```bash
flutter build ipa \
  --build-number=$(git rev-list --count HEAD) \
  --dart-define=FLAVOR_NAME=production \
  --dart-define=API_ROOT=https://poles.chromatin.ca \
  --dart-define=SENTRY_DSN=$SENTRY_DSN
```

Upload to TestFlight (external testing review) or App Store.

### Android

```bash
flutter build appbundle \
  --build-number=$(git rev-list --count HEAD) \
  --dart-define=FLAVOR_NAME=production \
  --dart-define=API_ROOT=https://poles.chromatin.ca \
  --dart-define=SENTRY_DSN=$SENTRY_DSN
```

Upload to Play Console → Testing → Closed testing (or Production directly).

## Sentry tagging

Sentry events are tagged with the flavor name via `options.environment` in `main.dart`. In Sentry's UI, filter by `environment:alpha` vs `environment:production` to keep crashes separate. Both flavors can share a single Sentry project — the `environment` tag splits them.

## Code signing notes (one-time setup)

- **iOS**: open `ios/Runner.xcworkspace` in Xcode → select project → Signing & Capabilities → set your Apple Developer team. Automatic signing handles certificates.
- **Android**: generate a keystore once and keep it safe:
  ```bash
  keytool -genkey -v -keystore ~/keystores/poles-upload.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
  Then create `android/key.properties` (gitignored):
  ```properties
  storePassword=...
  keyPassword=...
  keyAlias=upload
  storeFile=/Users/you/keystores/poles-upload.jks
  ```
  And reference it in `android/app/build.gradle.kts` (Flutter wires this up automatically if `key.properties` exists).

Lose the keystore = can never publish app updates under the same Play Console listing. Back it up to your password manager (or 1Password Vault) and to a USB drive.
