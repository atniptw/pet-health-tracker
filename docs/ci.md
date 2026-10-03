# CI / release pipeline

`.github/workflows/release.yml` runs on every push to `main`:

```
test (ubuntu) ──┬──> deploy-android (ubuntu)  → Play internal testing track
                └──> deploy-ios     (macos)   → build check only, no upload yet
```

- **test**: `flutter analyze` and `flutter test`. Both deploy jobs wait for it.
- **deploy-android**: builds a signed AAB and uploads it with fastlane (`android/fastlane/Fastfile`, lane `internal`).
- **deploy-ios**: builds without code signing to confirm iOS still compiles. Signing and the TestFlight upload are not written yet; they need the Apple Developer account.

Both deploy jobs are off until a repository variable switches them on (Settings → Secrets and variables → Actions → Variables). While off, they show as skipped, not failed.

Build numbers come from `github.run_number`, so every build uploaded to a store has a higher build number than the one before. The version name still comes from `pubspec.yaml`.

## Turning on Android deploys

1. **Play Console**: finish identity verification, create the app (package `com.pootzandboogie.pet_health_tracker`), and set up the internal testing track with your tester list.
2. **First upload by hand.** The Play API can't upload to an app that has never had a build. Build locally with `flutter build appbundle --release` and upload `build/app/outputs/bundle/release/app-release.aab` to the internal track in the Console. CI build numbers start at the workflow's run number. If you ever upload a build by hand with a higher number, CI uploads will be rejected until the run number passes it.
3. **Service account**:
   - In Google Cloud (the Firebase project `pet-health-tracker-2eed5` works), enable the **Google Play Android Developer API**.
   - Create a service account and download a JSON key for it.
   - In Play Console → Users and permissions, invite the service account's email. Give it access to this app with the **Release to testing tracks** permission.
4. **Secrets** (Settings → Secrets and variables → Actions → Secrets), or use `gh secret set` from the repo root:
   ```
   base64 -i ~/upload-keystore-pet-health-tracker.jks | gh secret set ANDROID_KEYSTORE_BASE64
   gh secret set ANDROID_KEYSTORE_PASSWORD   # storePassword from android/key.properties
   gh secret set ANDROID_KEY_PASSWORD        # keyPassword from android/key.properties
   gh secret set ANDROID_KEY_ALIAS           # "upload"
   gh secret set PLAY_SERVICE_ACCOUNT_JSON < path/to/service-account.json
   ```
5. **Variables**:
   ```
   gh variable set ANDROID_DEPLOY_ENABLED --body true
   ```
   While the app is still a draft in Play Console (not all app content declarations done), the API only accepts draft releases. If the upload fails with "Only releases with status draft may be created on draft app", run `gh variable set PLAY_RELEASE_STATUS --body draft`. Draft releases have to be rolled out to testers by hand in the Console. Delete the variable once the app is out of draft, and uploads will go straight to testers (`completed`).

## Turning on iOS deploys

Needs a paid Apple Developer account first. Then:

1. Register the App ID `com.pootzandboogie.petHealthTracker` and create the app record in App Store Connect.
2. Create an App Store Connect API key (Users and Access → Integrations) for uploads.
3. Choose how CI signs builds (fastlane `match` or a certificate and profile stored as secrets). Then add the signing and TestFlight upload steps to `deploy-ios` and an `ios/fastlane/Fastfile`.
4. `gh variable set IOS_DEPLOY_ENABLED --body true`

Until step 3 is done, turning on the variable only runs the unsigned build check.

## Running the Android lane locally

fastlane is pinned in the root `Gemfile` / `Gemfile.lock`.

```
bundle install
flutter build appbundle --release
cd android && PLAY_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)" bundle exec fastlane internal
```
