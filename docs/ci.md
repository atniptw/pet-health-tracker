# CI / release pipeline

`.github/workflows/release.yml` runs on every push to `main`:

```
test ──────────┐
               ├──> deploy-firestore-rules → production Firestore rules
smoke-android ─┼──> deploy-android         → Play internal testing track
               └──> deploy-ios (macos)     → TestFlight
```

- **test**: `scripts/check.sh` — formatting (`dart format`, 100 columns), `flutter analyze --fatal-infos` with strict casts, inference and raw types, `flutter test`, the size limits for `lib/` (`tool/size_check.dart`: 300 lines a file, 40 a function, with existing offenders in `tool/size_baseline.txt`), a check for comments with wording like "for now" or "v2" (`scripts/comment-check.sh`, tested by `scripts/test-comment-check.sh`, allowed uses in `scripts/comment-allowlist.txt`), a check that every commit not yet on `origin/main` that changes `lib/` (other than the generated `lib/firebase_options.dart`) also changes `test/` or `integration_test/`, unless it is a `refactor:` (`scripts/tests-changed.sh`, tested by `scripts/test-tests-changed.sh`), a line-coverage minimum that also fails when coverage is more than 0.2% above it (`scripts/coverage.sh`, tested by `scripts/test-coverage.sh`), the Claude Code hook tests (`scripts/test-hooks.sh`), the reviewer-mapping tests (`scripts/test-required-reviewers.sh`), and the security rules tests in `firestore-tests/` on the Firestore emulator. Dependencies install from the committed lockfiles (`flutter pub get --enforce-lockfile`, `npm ci`). In CI `origin/main` is the push itself, so a step after `check.sh` runs `scripts/tests-changed.sh` on the pushed commits (`github.event.before` to `github.sha`). After a force-push the old tip isn't in the clone, so the step fetches it by id, and fails rather than skip commits if it can't. The checkout fetches full history for it.
- **smoke-android**: boots the debug app on an Android emulator against the Firebase emulators and runs `integration_test/`: it checks the app reaches the sign-in screen, which catches startup crashes the widget tests can't see, and runs the repositories against the real rules (`firestore_rules_test.dart`), which the fake Firestore in the widget and unit tests doesn't have. Debug builds may send cleartext to `10.0.2.2` and `localhost` (`android/app/src/debug/res/xml/network_security_config.xml`) so they can reach the auth emulator. `scripts/smoke-android.sh` caps each attempt at 7 minutes and retries once only when an attempt times out, since `flutter test` has hung in CI after the app launched; a failing test is not retried. On failure it prints the verbose `flutter test` log and the device log. The emulator's system image and a booted snapshot are cached (`actions/cache`), so runs don't download the image.
- **deploy-firestore-rules**: publishes `firestore.rules` through the Firebase Rules API (`scripts/deploy-firestore-rules.sh`), as the `firestore-rules-deploy` service account (Firebase Rules Admin; key in the `FIREBASE_RULES_SERVICE_ACCOUNT_JSON` secret).
- **deploy-android**: builds a signed AAB and uploads it with fastlane (`android/fastlane/Fastfile`, lane `internal`).
- **deploy-ios**: builds the release app, signs it with the stored distribution certificate and profile, and uploads it to TestFlight with fastlane (`ios/fastlane/Fastfile`, lane `testflight`).

Every deploy job waits for both **test** and **smoke-android**. The `.githooks/pre-push` hook runs `scripts/check.sh` before every push (enable it once per clone with `git config core.hooksPath .githooks`), so a broken commit normally never reaches CI.

Each deploy job runs only when a repository variable switches it on (Settings → Secrets and variables → Actions → Variables). While off, it shows as skipped, not failed. Firestore rules (`FIRESTORE_RULES_DEPLOY_ENABLED=true`), Android (`ANDROID_DEPLOY_ENABLED=true`) and iOS (`IOS_DEPLOY_ENABLED=true`) are on.

Build numbers come from `github.run_number`, so every build uploaded to a store has a higher build number than the one before. The version name still comes from `pubspec.yaml`. Don't re-run an old workflow run to deploy: a re-run keeps its run number, so Play and App Store Connect reject the build number as already used. Push a new commit instead.

## Android deploys

Live since 2026-10-03. Every push to `main` uploads to the internal testing track and rolls out to testers straight away (release status `completed`).

What's set up:

- **Play Console app**: package `com.pootzandboogie.pet_health_tracker`, internal testing track with a tester email list. The first build (0.0.1, build number 2) was uploaded by hand, because the Play API can't upload to an app that has never had a build. Build number 1 was used up by an earlier upload, and CI run #2 used up build number 2 while deploys were off, so CI deploys started at run #4.
- **Play App Signing**: Google re-signs builds with its own key, so installed apps carry Google's certificate, not the upload key's. Play Console → Test and release → App integrity → App signing has a download of the certificates. The SHA-1s of all three certificates in it are registered for Google Sign-In (see `docs/architecture.md`).
- **Service account**: `play-deploy@pet-health-tracker-2eed5.iam.gserviceaccount.com` in the Firebase project's Google Cloud project, with the **Google Play Android Developer API** enabled. In Play Console → Users and permissions (account level, not inside the app) it has **Release to testing tracks** on this app.
- **Secrets** (Settings → Secrets and variables → Actions → Secrets):
  | Secret | Value |
  |---|---|
  | `ANDROID_KEYSTORE_BASE64` | `~/upload-keystore-pet-health-tracker.jks`, base64 |
  | `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `android/key.properties` |
  | `ANDROID_KEY_PASSWORD` | `keyPassword` from `android/key.properties` |
  | `ANDROID_KEY_ALIAS` | `upload` |
  | `PLAY_SERVICE_ACCOUNT_JSON` | JSON key for the service account |
- **Ruby**: `setup-ruby` reads the version from `.ruby-version` (4.0.7). fastlane is pinned in the root `Gemfile` / `Gemfile.lock`.

To set the secrets again, for example after rotating the service account key, run from the repo root:

```
gcloud iam service-accounts keys create /tmp/play-deploy.json --iam-account play-deploy@pet-health-tracker-2eed5.iam.gserviceaccount.com
gh secret set PLAY_SERVICE_ACCOUNT_JSON < /tmp/play-deploy.json && rm -P /tmp/play-deploy.json
base64 -i ~/upload-keystore-pet-health-tracker.jks | gh secret set ANDROID_KEYSTORE_BASE64
grep '^storePassword=' android/key.properties | cut -d= -f2- | tr -d '\n' | gh secret set ANDROID_KEYSTORE_PASSWORD
grep '^keyPassword=' android/key.properties | cut -d= -f2- | tr -d '\n' | gh secret set ANDROID_KEY_PASSWORD
gh secret set ANDROID_KEY_ALIAS --body upload
```

**Draft releases.** While an app is still a draft in Play Console (App content declarations not finished), the API only accepts draft releases, and uploads fail with "Only releases with status draft may be created on draft app". `gh variable set PLAY_RELEASE_STATUS --body draft` makes CI upload drafts, which then have to be rolled out to testers by hand in the Console. The variable is not set now.

## iOS deploys

On since 2026-10-11. Every push to `main` uploads a build to TestFlight.

The lane imports the certificate into a temporary keychain (`setup_ci`), together with Apple's WWDR G3 intermediate certificate, which issued it. Without the intermediate the signing identity isn't valid. It switches the Runner target's Release configuration to manual signing on the CI checkout only, so local builds keep automatic signing. Then it builds an App Store IPA with `build_app` and uploads it with `upload_to_testflight`, without waiting for Apple to finish processing it. `ITSAppUsesNonExemptEncryption` is `false` in `Info.plist` (the app only uses HTTPS), so builds don't stop at the export compliance question.

What's set up:

- **Team**: `PVKDTU84Z8` (`DEVELOPMENT_TEAM` in the Runner target, `ios/fastlane/Appfile`).
- **App ID**: `com.pootzandboogie.petHealthTracker`, with the Sign In with Apple capability. Adding a capability invalidates the profile, so edit the profile, save it, and set `IOS_PROVISIONING_PROFILE_BASE64` again with the new download.
- **Distribution certificate**: Apple Distribution, expires 2027-10-11. Its private key is `~/ios-distribution-pet-health-tracker.key`, and `~/ios-distribution-pet-health-tracker.p12` (password in `~/ios-distribution-pet-health-tracker.p12-password`) bundles the key with the certificate.
- **App Store Connect app**: "Pet Symptom Tracker" (Apple ID `6821711148`, SKU `pet-health-tracker`). The name under the icon on the home screen is still "Pet Health Tracker" (`CFBundleDisplayName`).
- **API key**: Team key `74RJJ9N8UC`, App Manager access, file at `~/AuthKey_74RJJ9N8UC.p8`.
- **Provisioning profile**: App Store Connect profile `Pet Health Tracker App Store` (the Fastfile refers to it by this name), expires 2027-10-11. A copy is at `~/ios-pet-health-tracker-app-store.mobileprovision`.
- **Secrets**:
  | Secret | Value |
  |---|---|
  | `IOS_DIST_P12_BASE64` | the `.p12`, base64 |
  | `IOS_DIST_P12_PASSWORD` | its password |
  | `IOS_PROVISIONING_PROFILE_BASE64` | the `.mobileprovision`, base64 |
  | `APP_STORE_CONNECT_API_KEY_ID` | API key ID |
  | `APP_STORE_CONNECT_ISSUER_ID` | issuer ID (Users and Access → Integrations) |
  | `APP_STORE_CONNECT_API_KEY` | contents of the `.p8` |

  The workflow passes the three API key secrets to fastlane as `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_CONTENT`. fastlane's actions read variables named `APP_STORE_CONNECT_API_KEY*` on their own, and the first upload failed when the key text arrived under one of those names.

Builds go to TestFlight without waiting for Apple's processing, so testers get them through an internal testing group with automatic distribution turned on (App Store Connect → TestFlight → Internal Testing).

To set the API key secrets again, for example with a new key:

```
gh secret set APP_STORE_CONNECT_API_KEY_ID --body <key id>
gh secret set APP_STORE_CONNECT_ISSUER_ID --body dd4492b3-a800-4d16-93bd-f76ca82b8920
gh secret set APP_STORE_CONNECT_API_KEY < ~/AuthKey_<key id>.p8
```

**Renewing before 2027-10-11.** Make a new certificate from a new CSR (`openssl req -new -newkey rsa:2048 -nodes -keyout <key> -out <csr> -subj "/CN=Pet Health Tracker CI/C=US"`), edit the profile to use it and download it again, then rebuild the `.p12` and reset the secrets:

```
openssl x509 -inform DER -in distribution.cer -out /tmp/dist.pem
openssl pkcs12 -export -legacy -inkey <key> -in /tmp/dist.pem -out <p12> -passout file:<password file>
base64 -i <p12> | gh secret set IOS_DIST_P12_BASE64
gh secret set IOS_DIST_P12_PASSWORD < <password file>
base64 -i <profile> | gh secret set IOS_PROVISIONING_PROFILE_BASE64
```

`-legacy` keeps the `.p12` in a format macOS's `security import` reads.

## Running the iOS lane locally

`setup_ci` does nothing when `MATCH_KEYCHAIN_NAME` is already set. So for a local run, create a throwaway keychain with an empty password, add it to the search list (`security list-keychains -d user -s <keychain> <existing ones>`), and point `MATCH_KEYCHAIN_NAME` at it. Without the API key variables, the lane stops after writing the signed IPA to `build/ios/fastlane/`. The lane switches the project to manual signing, so discard that change in `ios/Runner.xcodeproj/project.pbxproj` afterwards, and put the old keychain search list back.

```
bundle install
flutter build ios --release --no-codesign --build-number=<n>
cd ios && MATCH_KEYCHAIN_NAME=<keychain> IOS_DIST_P12_PATH=~/ios-distribution-pet-health-tracker.p12 \
  IOS_DIST_P12_PASSWORD="$(cat ~/ios-distribution-pet-health-tracker.p12-password)" \
  IOS_PROVISIONING_PROFILE_PATH=~/ios-pet-health-tracker-app-store.mobileprovision bundle exec fastlane testflight
```

## Running the Android lane locally

Needs a JSON key for the service account (`gcloud iam service-accounts keys create`, as above). Use a build number higher than any already in Play.

```
bundle install
flutter build appbundle --release --build-number=<n>
cd android && PLAY_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)" bundle exec fastlane internal
```
