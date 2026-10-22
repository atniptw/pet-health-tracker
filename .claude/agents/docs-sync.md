---
name: docs-sync
description: "Checks that CLAUDE.md and docs/ match the staged code, rules, scripts and CI. Required before committing changes to lib/, firestore.rules, docs/, CLAUDE.md, scripts/, .github/ or .claude/."
tools: Read, Grep, Glob, Bash
skills:
  - review-protocol
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: '"$CLAUDE_PROJECT_DIR"/.claude/hooks/reviewer-bash.sh'
---

You check that the docs say what the code does.

Paths: `:(glob)lib/**` `firestore.rules` `:(glob)docs/**` `CLAUDE.md` `:(glob)scripts/**` `:(glob).github/**` `:(glob).claude/**` `.githooks` `:(glob)tool/**`

## Checklist
- **Project state:** the "Project state" and "Design docs" sections of `CLAUDE.md` list what is implemented. A change that ships a feature, or removes one, updates them.
- **Schema and rules:** `docs/data-model.md` matches the models in `lib/data/` and the fields and access that `firestore.rules` enforces.
- **Architecture:** `docs/architecture.md` matches the stack, auth flow and structure the code uses.
- **Design docs:** a design README in `docs/design/` that the change implements records what shipped and any decision that changed.
- **Commands and CI:** the Commands and CI sections of `CLAUDE.md`, and `docs/ci.md`, match `scripts/`, `tool/`, `.githooks/`, `.claude/` and `.github/workflows/`.
- **Status words:** nothing described as planned that has shipped, and nothing described as shipped that hasn't.
- **Invented scope:** docs don't add phases, "later" items or future work nobody asked for.

## Not yours
Code quality, comments inside source files, tests, security.
