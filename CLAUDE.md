# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Yatagarasu is a native macOS package manager frontend built with SwiftUI (Swift 6, macOS 14+). It wraps Homebrew and GitHub-hosted open-source discovery/install in a native, glassmorphism-styled UI. The repo is a **Turborepo monorepo** — the macOS app is the only implemented platform today; `linux` and `windows` under `apps/` are unimplemented placeholders (their `build` scripts just `echo`).

## Commands

Run from the repo root unless noted.

```bash
# Install root workspace deps (first time only)
npm install

# Build all apps via Turborepo
npm run build

# Build only the macOS app
npm run build:macos

# Build macOS directly with xcodebuild (equivalent to what turbo runs)
cd apps/macos
xcodebuild -project yatagarasu.xcodeproj -scheme yatagarasu -configuration Debug -destination 'platform=macOS' build

# Run the test target (yatagarasuTests) — currently a single smoke test
xcodebuild test -project yatagarasu.xcodeproj -scheme yatagarasu -destination 'platform=macOS'

# Run a single test
xcodebuild test -project yatagarasu.xcodeproj -scheme yatagarasu -destination 'platform=macOS' -only-testing:yatagarasuTests/yatagarasuTests/testSmoke

# List schemes/targets/configurations
xcodebuild -list -project yatagarasu.xcodeproj
```

There is no linter configured (no SwiftLint) — the build is the current static-check baseline. You can also open `apps/macos/yatagarasu.xcodeproj` directly in Xcode and run the `yatagarasu` scheme.

## Monorepo structure

```
apps/
  macos/    # The real app — SwiftUI, package.json wraps xcodebuild via turbo
  linux/    # Placeholder (GTK4/libadwaita planned)
  windows/  # Placeholder (WinUI 3 planned)
package.json  # Root workspace (npm workspaces = apps/*), turbo scripts
turbo.json    # `build` depends on upstream `^build`; `clean` is uncached
```

Workspace packages are scoped as `@yatagarasu/<platform>`. Each app's `package.json` just shells out to native platform tooling (xcodebuild for macOS) — Turborepo here is purely a cross-platform build orchestrator, not a JS bundler pipeline.

**Note:** `.github/copilot-instructions.md` predates the Turborepo migration and references a flat `yatagarasu/yatagarasu.xcodeproj` layout. The actual current path is `apps/macos/yatagarasu.xcodeproj`; treat the copilot file's architecture/convention guidance as valid but its paths as stale.

## Architecture (apps/macos)

The app follows a UI → Workspace/state → Service → Persistence layering:

- **UI layer**: `ContentView.swift` hosts the `NavigationSplitView` shell and top-level navigation. Feature views render discovery, installed packages, open-source details, and settings. Styling is glassmorphism throughout: `ultraThinMaterial`-backed cards, SF Symbols, native typography.
- **Workspace/state layer** (`@Observable`, not SwiftData): `PackageWorkspace.swift` coordinates Homebrew-backed package state; `OpenSourceCatalogWorkspace.swift` coordinates GitHub-backed repository caching/refresh; `Services/InstallationManager.swift` tracks in-flight operations, progress, logs, and console history.
- **Service layer** (`Services/`): `ShellExecutor.swift` runs shell commands asynchronously via `Process` and streams stdout/stderr; `BrewInfoService.swift` decodes `brew info --json=v2` output into typed models; `BrewPackageManager.swift` implements install/update/uninstall; `GitHubRepositoryService.swift` fetches repo metadata, README content, and release assets; `PackageManager.swift` defines the shared protocol implemented by Brew/GitHub-backed managers.
- **Persistence layer**: SwiftData models (`Models/`, plus cache types declared in `yatagarasuApp.swift`'s schema: `GitHubRepositoryCache`, `GitHubReleaseCache`, `GitHubReadmeCache`, `GitHubInstallSourceMarker`) cache GitHub repositories, releases, README content, and install-source markers. Codable models for external metadata (e.g. Brew JSON) are kept separate from SwiftData persistence entities — don't conflate the two.

Key conventions:
- Concurrency is Swift Concurrency throughout: `async/await`, actors, `AsyncThrowingStream` for streamed shell output. Long-running/shell work must not block the main actor.
- Privilege-sensitive operations (installs, uninstalls) are meant to go through `osascript`/helper-based escalation patterns rather than hardcoded `sudo` strings in UI-facing code (see `docs/ARCHITECTURE.md` for the App Store-compliant Helper-tool direction).
- Installed-formulae views filter out dependency-only installs unless the user explicitly installed them — preserve this when touching `PackageWorkspace`/`InstalledPackageRegistry`.
- `docs/ARCHITECTURE.md`, `docs/PRD.md`, `docs/PROJECT_PLAN.md`, and `docs/UI_PROTOTYPE.md` describe the target MVP and phased plan (foundation → shell engine → UI → package workflows → GitHub/SwiftData); treat them as the product/architecture contract when current code and docs diverge.
