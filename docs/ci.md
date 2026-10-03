# CI / release pipeline

`.github/workflows/release.yml` runs on every push to `main`:

```
test (ubuntu) ──┬──> deploy-android (ubuntu)  → Play internal testing track
                └──> deploy-ios     (macos)   → build check only, no upload yet
```

- **test**: `flutter analyze` and `flutter test`. Both deploy jobs wait for it.
- **deploy-android**: builds a signed AAB and uploads it with fastlane (`android/fastlane/Fastfile`, lane `internal`).
- **deploy-ios**: builds without code signing to confirm iOS still compiles. Signing and the TestFlight upload are not written yet; they need the Apple Developer account.

Each deploy job runs only when a repository variable switches it on (Settings → Secrets and variables → Actions → Variables). While off, it shows as skipped, not failed. Android is on (`ANDROID_DEPLOY_ENABLED=true`); iOS is off.

Build numbers come from `github.run_number`, so every build uploaded to a store has a higher build number than the one before. The version name still comes from `pubspec.yaml`. Don't re-run an old workflow run to deploy: a re-run keeps its run number, so Play rejects the build number as already used. Push a new commit instead.

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

## Turning on iOS deploys

Needs a paid Apple Developer account first. Then:

1. Register the App ID `com.pootzandboogie.petHealthTracker` and create the app record in App Store Connect.
2. Create an App Store Connect API key (Users and Access → Integrations) for uploads.
3. Choose how CI signs builds (fastlane `match` or a certificate and profile stored as secrets). Then add the signing and TestFlight upload steps to `deploy-ios` and an `ios/fastlane/Fastfile`.
4. `gh variable set IOS_DEPLOY_ENABLED --body true`

Until step 3 is done, turning on the variable only runs the unsigned build check.

## Running the Android lane locally

Needs a JSON key for the service account (`gcloud iam service-accounts keys create`, as above). Use a build number higher than any already in Play.

```
bundle install
flutter build appbundle --release --build-number=<n>
cd android && PLAY_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)" bundle exec fastlane internal
```
