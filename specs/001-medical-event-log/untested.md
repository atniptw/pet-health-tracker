# Untested

The spec ids, or the parts of them, no test can check, each with its reason (`scripts/spec-coverage.sh`).

- 001-FR-013: the app holds no feed, social features or diary entries, which a test can't prove absent.
- 001-FR-014: only the first sentence (everything works signed out) is tested. Keeping events when a caregiver signs in can't be checked until signing in exists (spec 002).
- 001-SC-002: whether a first-time user logs without help needs a person to try it; `expectAccessible` on every screen covers what a test can check.
- 001-SC-004: only the phone half is tested (no event lost on the phone, offline included). None lost at sign-in can't be checked until signing in exists (spec 002).
