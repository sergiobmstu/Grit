# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Grit is a native iOS application built with Swift, SwiftUI, and the Composable Architecture (TCA) framework. It targets iOS 26.2+ and is in its early stages (initial commit with scaffolding).

## Build Commands

```bash
# Build (debug)
xcodebuild -scheme Grit -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build (release)
xcodebuild -scheme Grit -configuration Release build

# Clean build
xcodebuild -scheme Grit clean build
```

There is one target (`Grit`) and one scheme (`Grit`). No test targets exist yet.

## Architecture

- **Framework:** SwiftUI with Composable Architecture (TCA) via SPM (`swift-composable-architecture >= 1.23.1`)
- **Entry point:** `Grit/GritApp.swift` — standard `@main` App struct with a single `WindowGroup`
- **Concurrency:** MainActor isolation by default, Swift Approachable Concurrency enabled
- **State management:** TCA reducers/stores (framework integrated, not yet wired into views)

## Project Structure

```
Grit/                    # App source (Swift files, assets)
Grit.xcodeproj/          # Xcode project config, SPM dependency resolution
```

All Swift source lives under `Grit/`. The project uses Xcode's file-system synchronization (no manual pbxproj group management needed).

## Dependencies

Managed via Swift Package Manager through the Xcode project. Primary dependency:
- **ComposableArchitecture** >= 1.23.1 (brings in swift-dependencies, swift-navigation, swift-case-paths, swift-perception, etc.)

## Conventions

- SwiftUI-first declarative UI
- TCA pattern: features should be built as `Reducer` conformances with `Store`-driven views
- Code signing is automatic (team F82X95T478)
- Bundle ID: `grit.Grit`
