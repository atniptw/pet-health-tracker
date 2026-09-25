# Architecture

Status: planning. No Firebase project exists yet and none of this is implemented.

## Decisions

| Concern | Choice | Status |
|---|---|---|
| Platforms | iOS + Android (Flutter) | Decided |
| Backend / DB | Firebase Firestore, cloud-backed from day one | Decided |
| Local DB | None. Firestore's built-in offline cache covers logging without signal | Decided |
| Auth | Firebase Auth: Google, Apple, anonymous | Decided |
| State management | Riverpod | Proposed, not yet confirmed |
| Navigation | `go_router` | Proposed |
| Model classes | Hand-written, immutable, `fromFirestore`/`toFirestore` | Decided. Can move to `freezed` later without changing stored data |
| Tests | `fake_cloud_firestore`, `mocktail`, Firestore rules tests on the emulator | Proposed |

## Auth

Order of work: **Google first**, then anonymous, then Apple.

- **Google:** enable the provider in the Firebase console. Android needs the debug SHA-1 registered (release and Play signing SHA-1s later). iOS needs the `REVERSED_CLIENT_ID` URL scheme in `Info.plist`, which `flutterfire configure` provides. Use `firebase_auth` with `google_sign_in`, written against the current API.
- **Anonymous:** lets a user start logging without signing up. Signing in with Google or Apple later *links* the credential to the anonymous account, so the uid and data are kept.
- **Apple:** required on iOS once any other social login is offered, so it must ship before App Store submission. Needs a paid Apple Developer account.
- **Open: `credential-already-in-use`.** If an anonymous user signs in with a Google/Apple account that already exists (e.g. after a reinstall), the anonymous account's pets are orphaned under the old uid. Leading option: add the existing account's uid to `memberIds` on those pets. Alternative: discard them. Decide when building anonymous auth.
- **Account deletion:** Apple requires it in-app. Deleting an account must delete the user's pets and logs.

## Planned code layout

```
lib/
  core/            # theme, router, Firebase init
  data/            # Firestore repositories, model classes
  features/
    pets/          # add/edit/list pets
    symptoms/      # quick-log flow, history list
```

## Order of work

1. Create the Firebase project, run `flutterfire configure`, add `firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_riverpod`. Not started; deliberately deferred.
2. Google sign-in, then models, repositories, and security rules (rules and rules tests first).
3. Pets screens, then the quick-log flow.
4. Anonymous auth, then Apple sign-in.

See [data-model.md](data-model.md) for the Firestore schema.
