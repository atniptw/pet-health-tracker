# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Goal

A mobile app (iOS + Android) for pet owners to track their pets' health symptoms. The first priority is **fast symptom logging**: capturing what happened, when, and how severe, with as little friction as possible. Trend views and vet-visit reports are later goals. The audience is pet owners in general, not just a single household, so accounts and onboarding will eventually matter.

## Project state

The repository is currently a bare scaffold: it contains only `README.md`, `LICENSE`, and `.gitignore`. There is no source code, build system, or test suite yet, so there are no build/lint/test commands to document.

## Stack hint

The target is Flutter (mobile). The `.gitignore` is the standard Flutter/Dart template (ignores `.dart_tool/`, `.pub-cache/`, `build/`, `*.lock`, etc.), but no `pubspec.yaml` exists yet. Note that `*.lock` is git-ignored, meaning `pubspec.lock` would not be committed.

Once code is added, update this file with the actual build, lint, and test commands (including how to run a single test) and the high-level architecture.
