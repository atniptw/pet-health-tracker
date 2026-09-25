# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

An app for tracking pet health symptoms (per `README.md`). The repository is currently a bare scaffold: it contains only `README.md`, `LICENSE`, and `.gitignore`. There is no source code, build system, or test suite yet, so there are no build/lint/test commands to document.

## Stack hint

The `.gitignore` is the standard Flutter/Dart template (ignores `.dart_tool/`, `.pub-cache/`, `build/`, `*.lock`, etc.), which suggests the app is intended to be built with Flutter. No `pubspec.yaml` exists yet, so this is unconfirmed. Note that `*.lock` is git-ignored, meaning `pubspec.lock` would not be committed.

Once code is added, update this file with the actual build, lint, and test commands (including how to run a single test) and the high-level architecture.
