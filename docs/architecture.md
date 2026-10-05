# Architecture

Status: partly implemented. The Firebase project is set up, and Google sign-in, household creation, and adding and editing pets are built. The rest is still a plan.

## Cost

This is a hobby app, so lean toward free tiers. Stay on Firebase's free Spark plan. Cloud Functions needs the paid Blaze plan, so don't design anything that requires it. Unavoidable store costs: Apple's paid developer account (also required for Sign in with Apple) and Google Play's one-time registration fee.

## Decisions

| Concern | Choice | Status |
|---|---|---|
| Platforms | iOS + Android (Flutter) | Decided |
| Backend / DB | Firebase Firestore, cloud-backed from day one | Decided |
| Firestore location | `nam5` (United States multi-region), `(default)` database, Standard edition. Can't be changed | In use |
| Local DB | None. Firestore's built-in offline cache covers logging without signal | Decided |
| Auth | Firebase Auth: Google, Apple | Decided |
| State management | Riverpod | In use |
| Navigation | `go_router` | Proposed |
| Model classes | Hand-written, immutable, `fromFirestore`/`toFirestore` | Decided. Can move to `freezed` later without changing stored data |
| Tests | `fake_cloud_firestore`, `mocktail`, Firestore rules tests on the emulator (`@firebase/rules-unit-testing`), `integration_test` smoke test | In use |
| Crash reporting | Firebase Crashlytics, release builds only | In use |

## Auth

Order of work: **Google first**, then Apple.

- **Google:** enable the provider in the Firebase console. Android SHA-1s are registered for the debug keystore, the upload keystore, and the three Play App Signing certificates. Each is registered twice: on the Firebase Android app (`firebase apps:android:sha:create`, which creates the Android OAuth client) and in the Android API key's allowed apps (`gcloud services api-keys update --allowed-application`, which replaces the whole list, so pass every fingerprint each time). iOS needs the `REVERSED_CLIENT_ID` URL scheme in `Info.plist`, which `flutterfire configure` provides. Use `firebase_auth` with `google_sign_in`, written against the current API.
- **Apple:** required on iOS once any other social login is offered, so it must ship before App Store submission. Needs a paid Apple Developer account.
- **Account deletion:** Apple requires it in-app. Deleting an account must delete the user's data. The user is removed from their households. A household must always keep at least one admin, so how a sole admin leaves or hands over is not decided yet.

## Code layout

```
lib/
  core/            # app shell, Firebase providers
  data/            # Firestore repositories, model classes
  features/
    auth/          # Google sign-in (built)
    household/     # create household, home screen (built)
    settings/      # settings: add and edit pets, sign out (built)
    pets/          # pet form and list (built)
    symptoms/      # quick-log flow, history list (planned)
```

## Order of work

1. Create the Firebase project, run `flutterfire configure`, add `firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_riverpod`. Done.
2. Google sign-in, then models, repositories, and security rules (rules and rules tests first). Google sign-in, the household model and repository, and `firestore.rules` are done; rules tests are not written yet.
3. Pets screens, then the quick-log flow. Adding, listing and editing pets is done; only admins can add or edit.
4. Apple sign-in.

See [data-model.md](data-model.md) for the Firestore schema.
