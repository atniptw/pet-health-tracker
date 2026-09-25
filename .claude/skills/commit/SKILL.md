---
name: commit
description: Create a git commit with a short Conventional Commits 1.0.0 message. Use when the user asks to commit changes or says "/commit".
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
---

# Commit

Commit the current changes using [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/), kept short.

## Steps

1. Run `git status` and `git diff HEAD` (plus `git log -5 --oneline` for style) to see what changed.
2. If changes are unrelated, split them into separate commits, staging files by name. Never `git add -A`, and never stage secrets or `.env` files.
3. Write the message per the format below and commit. Do not push.
4. If a pre-commit hook fails, fix the issue and make a new commit. Don't use `--no-verify` or `--amend` unless asked.

## Format

```
<type>(<optional scope>): <description>

<optional body>

<optional footers>
```

**Types:** `feat` (new feature), `fix` (bug fix), `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

**Subject line**
- Imperative mood, lowercase, no trailing period: `fix(symptoms): handle empty date range`
- 50 characters or fewer where possible, 72 max.
- Scope is optional; use it only when it adds clarity (a feature area such as `symptoms`, `pets`, `reminders`).

**Body: usually omit it**
- Skip the body when the subject says it all, which is most of the time.
- Add one only to explain *why* something non-obvious was done. Max 1-3 short lines, wrapped at 72 columns.
- Never restate the diff, list changed files, or describe *what* the code does.

**Breaking changes**
- Add `!` after the type/scope (`feat(api)!: drop v1 endpoints`) and/or a `BREAKING CHANGE: <what breaks>` footer.

**Footers**
- Only when needed, e.g. `Refs: #12` or `Closes: #12`.
- Append any attribution trailer (e.g. `Co-Authored-By`) that the environment instructs you to add.

## Examples

Good:
```
feat(symptoms): add severity rating to symptom log
fix: prevent duplicate pet profiles on double tap
docs: add setup steps to README
refactor(reminders): extract schedule parsing
chore: ignore .dart_tool
```

With a body (only because the reason isn't obvious):
```
fix(sync): retry failed uploads once

Vet clinic wifi drops often; a single retry avoids losing entries.
```

Too long (don't do this):
```
feat: add a new feature that allows users to log symptoms for their pets, including severity, date, notes, and photos, and update the database schema and UI components accordingly
```
