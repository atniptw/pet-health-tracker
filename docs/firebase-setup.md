# Firebase setup

The Firebase project (`pet-health-tracker-2eed5`) and the accounts around it, as they are set up. CI setup and secrets are in `ci.md`.

## Cost

This is a hobby app, so it stays on free tiers. The project is on Firebase's free Spark plan. Cloud Functions needs the paid Blaze plan, so nothing may require it. The unavoidable store costs are Apple's paid developer account (also required for Sign in with Apple) and Google Play's one-time registration fee.

## Firestore

The `(default)` database, Standard edition, in `nam5` (United States multi-region). The location can't be changed.

## Sign-in providers

- **Google:** the provider is on in the Firebase console. Android SHA-1s are registered for the debug keystore, the upload keystore and the three Play App Signing certificates. Each is registered twice: on the Firebase Android app (`firebase apps:android:sha:create`, which creates the Android OAuth client) and in the Android API key's allowed apps (`gcloud services api-keys update --allowed-application`, which replaces the whole list, so pass every fingerprint each time). iOS needs the `REVERSED_CLIENT_ID` URL scheme in `ios/Runner/Info.plist`, which `flutterfire configure` provides.
- **Apple:** the provider is on in the Firebase console, with no Services ID since there is no web or Android flow. The App ID has the Sign In with Apple capability, and `ios/Runner/Runner.entitlements` declares it. Apple requires it on iOS once any other social sign-in is offered.

## Crash reporting

Firebase Crashlytics reports crashes from release builds only (`lib/main.dart`).
