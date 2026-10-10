# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Yatagarasu is a native macOS package manager frontend built with SwiftUI (Swift 6, macOS 14+). It wraps Homebrew and GitHub-hosted open-source discovery/install in a native, calm, light-first UI (the "Direction A" redesign). The repo is a **Turborepo monorepo** — the macOS app is the only implemented platform today; `linux` and `windows` under `apps/` are unimplemented placeholders (their `build` scripts just `echo`).

## Commands

Run from the repo root unless noted.

```bash
# Install root workspace deps (first time only; pnpm version is pinned in package.json)
pnpm install

# Build all apps via Turborepo
pnpm build

# Build only the macOS app
pnpm build:macos

# Build a standalone Release Yatagarasu.app (+ .zip/.dmg) into apps/macos/dist/
pnpm package:macos

# Same, then copy it into /Applications
pnpm install:macos

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
package.json         # Root scripts (turbo) and the pinned pnpm version
pnpm-workspace.yaml  # Workspace packages = apps/*
turbo.json           # `build` depends on upstream `^build`; `package` and `clean` are uncached
.github/workflows/macos-app.yml  # Builds Yatagarasu.app; publishes to GitHub Packages (ghcr.io) and, for v* tags, a Release
```

`apps/macos/scripts/package-app.sh` builds and signs in a temporary folder outside the repo on purpose: folders synced by iCloud Drive (such as `~/Documents`) add Finder metadata that `codesign` rejects. Turbo runs tasks in strict environment mode, so variables a task needs (e.g. `YATAGARASU_*`) must be listed in that task's `passThroughEnv` in `turbo.json`.

Workspace packages are scoped as `@yatagarasu/<platform>`. Each app's `package.json` just shells out to native platform tooling (xcodebuild for macOS) — Turborepo here is purely a cross-platform build orchestrator, not a JS bundler pipeline.

**Note:** `.github/copilot-instructions.md` predates the Turborepo migration and the Direction A redesign. Its paths and its glassmorphism styling guidance are stale; follow this file instead.

## Architecture (apps/macos)

Sources live under `apps/macos/yatagarasu/` (Xcode uses filesystem-synchronized groups, so new files and folders are picked up without editing the `.pbxproj`):

```
App/           YatagarasuApp (scenes), AppModel (composition root), RootView, AppCommands, AppIconStyle, FeatureFlags, Persistence, PreviewSupport
Navigation/    SidebarItem, AppRouter (sidebar selection + push stack, AppRoute)
DesignSystem/  Theme/ (Palette, Typography, Metrics tokens) and Components/ (buttons, chips, cards, banners, …)
Catalog/       CatalogItem, StarterKit, Specialty, CuratedCatalog (shipped storefront content)
Features/      Sidebar/, Discover/, Installed/, Updates/, Setups/, PackageDetail/, Settings/, Shared/
Core/          Models/, Services/, Workspaces/, Homebrew/ (brew detection), Localization/ (L10n, AppLanguage)
Resources/     Assets.xcassets, AppIcon.icon + PixelAppIcon.icon (Icon Composer), <lang>.lproj/Localizable.strings
```

The app icons are generated, not hand-edited: `apps/macos/design/app-icon/tools/build.py` draws the Classic and Pixel crow and writes both `.icon` packages (see that folder's README). `PixelAppIcon` is an alternate icon (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`); macOS has no alternate-icon API, so Settings › General only swaps the Dock icon at runtime via `AppIconStyle`.

The app follows a UI → Workspace/state → Service → Persistence layering:

- **UI layer**: implements the "Direction A" design (calm, light-first, sidebar app; source of truth is the "Yatagarasu Redesign" design canvas). `RootView` hosts the `NavigationSplitView`; one folder per screen under `Features/`. Views call package operations only through `AppModel` (`install`/`update`/`uninstall`/`refreshPackages`), never through workspaces with a brew path. Settings is a separate `Settings` scene (⌘,).
- **Workspace/state layer** (`@Observable`, not SwiftData): `Core/Workspaces/PackageWorkspace.swift` coordinates Homebrew-backed package state; `OpenSourceCatalogWorkspace.swift` coordinates GitHub-backed repository caching/refresh; `Core/Homebrew/HomebrewEnvironment.swift` locates `brew`; `Core/Services/InstallationManager.swift` tracks in-flight operations, progress, logs, and console history.
- **Service layer** (`Core/Services/`): `ShellExecutor.swift` runs shell commands asynchronously via `Process` and streams stdout/stderr; `BrewInfoService.swift` decodes `brew info --json=v2` output into typed models; `BrewPackageManager.swift` implements install/update/uninstall; `GitHubRepositoryService.swift` fetches repo metadata, README content, and release assets; `PackageManager.swift` defines the shared protocol implemented by Brew/GitHub-backed managers.
- **Persistence layer**: SwiftData models (`Core/Models/`, registered in `App/Persistence.swift`'s schema: `GitHubRepositoryCache`, `GitHubReleaseCache`, `GitHubReadmeCache`, `GitHubInstallSourceMarker`) cache GitHub repositories, releases, README content, and install-source markers. Codable models for external metadata (e.g. Brew JSON) are kept separate from SwiftData persistence entities — don't conflate the two.

Key conventions:
- UI styling comes from `DesignSystem/`: colors only via `Palette`/`Tone`/`BrandTint` tokens (each has light and dark values), fonts via `Typography`, spacing/radii via `Spacing`/`Radius`, buttons via `.buttonStyle(.action(...))`, cards via `.cardSurface()`. Don't hard-code hex values or sizes in feature views.
- User-facing strings go through `L10n.t` / `L10n.f` / `L10n.p` (plural: `<key>.one` / `<key>.other`) and must be added to all four `Localizable.strings` (en, ja, zh-Hans, zh-Hant). The app switches language at runtime, independent of the system language.
- Controls the design calls for but whose backend doesn't exist yet use `.pendingFeature()` (disabled + "coming soon" tooltip). Search for it to find unwired UI.
- Whole screens that aren't ready are switched off in `App/FeatureFlags.swift`; `SidebarItem.enabledCases` drives the sidebar and the ⌘1… shortcuts. Discover is off until the storefront catalog comes from a maintained data source (backend or periodically refreshed JSON) rather than the hard-coded `CuratedCatalog`.
- Under the target's default `MainActor` isolation, default-argument expressions are evaluated nonisolated: don't call `@MainActor` initializers in default arguments (use a convenience init instead).
- Concurrency is Swift Concurrency throughout: `async/await`, actors, `AsyncThrowingStream` for streamed shell output. Long-running/shell work must not block the main actor.
- Privilege-sensitive operations (installs, uninstalls) are meant to go through `osascript`/helper-based escalation patterns rather than hardcoded `sudo` strings in UI-facing code (see `docs/ARCHITECTURE.md` for the App Store-compliant Helper-tool direction).
- Installed-formulae views filter out dependency-only installs unless the user explicitly installed them — preserve this when touching `PackageWorkspace`/`InstalledPackageRegistry`.
- `docs/ARCHITECTURE.md`, `docs/PRD.md`, `docs/PROJECT_PLAN.md`, and `docs/UI_PROTOTYPE.md` describe the target MVP and phased plan (foundation → shell engine → UI → package workflows → GitHub/SwiftData); treat them as the product/architecture contract when current code and docs diverge, except for visual design, where Direction A supersedes the glassmorphism styling in `UI_PROTOTYPE.md`.
