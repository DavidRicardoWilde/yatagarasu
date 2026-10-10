# Yatagarasu

[简体中文](./README.zh-CN.md)

Yatagarasu is a native macOS package manager frontend built with SwiftUI. Its goal is to make Homebrew and GitHub-hosted open-source software feel approachable, visual, and cohesive without giving up the power of the underlying tools.

Instead of treating package management as a terminal-only workflow, Yatagarasu presents it as a polished macOS experience: discover software, inspect project context, launch installs and upgrades, and follow command output from a single app.

## Philosophy

Yatagarasu is built around a few simple ideas:

- **Native first.** Use Apple frameworks, platform conventions, and macOS visual language instead of a cross-platform shell wrapped in a window.
- **GUI, not abstraction theater.** The app makes Homebrew and GitHub workflows easier to use, but it does not pretend those systems do not exist.
- **Readable operations.** Package activity, progress, and command output should be visible and understandable.
- **Curated discovery.** Open-source software should be easier to browse than “search GitHub and hope for the best.”
- **Architecture over hacks.** Swift Concurrency, SwiftData, and a service-oriented design keep the project maintainable as it grows.

## What the app does today

Yatagarasu is currently an actively developed MVP with a working core experience.

### Homebrew management

- Detects a local Homebrew installation automatically
- Loads installed formulae and casks through `brew info --json=v2`
- Supports install, upgrade, and uninstall flows from the UI
- Tracks active operations with staged progress; the sidebar Activity card opens live `brew` output
- Filters installed formulae to hide dependency-only installs unless the user explicitly installed them

### Open-source discovery

- Curated GitHub projects open in the shared package detail page
- Fetches repository metadata, README content, and recent releases from the GitHub API
- Renders project READMEs in a native SwiftUI detail experience
- Parses release assets and prefers installable macOS artifacts such as `.dmg`, `.pkg`, and `.zip`
- Falls back to a clear “build from source” path when a repository does not publish a suitable binary release

### One app, many sources

- Each package's detail page lists every place it can come from (Homebrew, official website, GitHub releases, build from source) with a safety check for the selected source
- **Setups** installs whole starter kits in one go; **Specialties** in Settings decide which kits show first

### Installed and Updates

- **Installed** shows Homebrew-managed packages and tracked GitHub-origin records in one expandable table
- **Updates** classifies each update as major, minor, or patch and leaves major updates unchecked by default

### macOS-native UX

- `NavigationSplitView` shell with a calm, light-first design ("Direction A") that adapts to dark mode
- Design tokens and shared components live in `DesignSystem/`
- Built-in localization support for English, Simplified Chinese, Traditional Chinese, and Japanese
- A standard Settings window (⌘,) with General, Specialties, Sources, and Updates tabs

## Current scope

Implemented areas:

- **Installed**
- **Updates**
- **Setups**
- **Package detail**
- **Settings**

Hidden for now:

- **Discover** is built but switched off (`FeatureFlags.showsDiscover`). Its storefront content is hard-coded, so it can't list every version an app offers, link straight to vendor downloads, or show real app icons. It returns once app data comes from a maintained source, such as a backend or a JSON catalog the app refreshes periodically.

Still evolving (shown in the UI as disabled "coming soon" controls; search the code for `pendingFeature()`):

- Brewfile import and export
- Keeping several versions side by side, background update checks, notifications
- GitHub sign-in and searching all of Homebrew
- **Developer / Dev-Space** workflows
- More robust rendering for HTML-heavy READMEs
- Broader automation around GitHub release installation

## Technical overview

Yatagarasu is a native Swift application with a small, focused stack:

- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **State management:** Observation (`@Observable`)
- **Concurrency:** Swift Concurrency (`async/await`, actors, `AsyncThrowingStream`)
- **Networking:** `URLSession`
- **Markdown rendering:** [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)

### Architecture at a glance

- **UI layer**
  - `App/RootView` hosts the `NavigationSplitView` shell; `AppRouter` owns sidebar selection and the push stack.
  - `AppModel` is the composition root and the single entry point views use for install / update / uninstall.
  - `Features/` holds one folder per screen, built from the tokens and components in `DesignSystem/`.

- **Workspace / state layer**
  - `PackageWorkspace` coordinates Homebrew-backed package state.
  - `OpenSourceCatalogWorkspace` coordinates GitHub-backed repository caching and refresh behavior.
  - `InstallationManager` tracks in-flight operations, progress, logs, and console history.

- **Service layer**
  - `ShellExecutor` runs shell commands asynchronously and streams stdout/stderr back into the app.
  - `BrewInfoService` decodes Homebrew JSON output into typed Swift models.
  - `BrewPackageManager` implements install / update / uninstall workflows.
  - `GitHubRepositoryService` fetches repository metadata, README content, and release assets.

- **Persistence layer**
  - SwiftData models cache GitHub repositories, releases, README content, and install-source markers.

## Project structure

Yatagarasu is a **Turborepo monorepo** with platform-specific apps under `apps/`.

```text
.
├── apps/
│   ├── macos/              # Native macOS app (SwiftUI)
│   │   ├── package.json
│   │   ├── yatagarasu.xcodeproj
│   │   └── yatagarasu/
│   │       ├── App/            # Entry point, AppModel, commands, root window
│   │       ├── Navigation/     # Sidebar destinations and router
│   │       ├── DesignSystem/   # Tokens (color, type, spacing) and shared components
│   │       ├── Catalog/        # Curated items, starter kits, specialties
│   │       ├── Features/       # Discover, Installed, Updates, Setups, PackageDetail, Settings, Sidebar
│   │       ├── Core/           # Models, services, workspaces, Homebrew detection, localization
│   │       └── Resources/      # Assets and Localizable.strings (en, ja, zh-Hans, zh-Hant)
│   ├── linux/              # Linux app (placeholder, coming soon)
│   └── windows/            # Windows app (placeholder, coming soon)
├── package.json            # Root workspace config
├── turbo.json              # Turborepo pipeline
└── docs/                   # Architecture & product docs
```

### Monorepo tooling

- **Turborepo** orchestrates builds across apps
- Workspace packages are scoped as `@yatagarasu/<platform>`
- **pnpm** workspaces (`pnpm-workspace.yaml`); the pnpm version is pinned in `package.json`
- Run `pnpm build` from root to build all apps; `pnpm build:macos` for just macOS

## Getting started

### Requirements

- macOS 26.2 or later and Xcode 26.2 or later
- Node.js and [pnpm](https://pnpm.io) (`corepack enable` picks up the pinned version)
- Homebrew installed locally if you want to use Homebrew package management features

### Build

From the repository root:

```bash
# Install dependencies (first time only)
pnpm install

# Build all apps
pnpm build

# Build only macOS
pnpm build:macos

# Or build directly with xcodebuild
cd apps/macos
xcodebuild -project yatagarasu.xcodeproj -scheme yatagarasu -configuration Debug -destination 'platform=macOS' build
```

You can also open `apps/macos/yatagarasu.xcodeproj` directly in Xcode and run the `yatagarasu` scheme.

### Build a standalone app

To get a `Yatagarasu.app` you can launch from the Applications folder like any other app:

```bash
# Build a Release, universal app and copy it into /Applications
pnpm install:macos

# Or only build it, plus a .zip and a drag-to-install .dmg, into apps/macos/dist/
pnpm package:macos
```

Both run `apps/macos/scripts/package-app.sh`; see `--help` for options such as `--install-dir ~/Applications`, `--version`, and `--sign` for a Developer ID identity. By default the app is ad-hoc signed, which needs no Apple Developer account.

## Download

Every push to `master` builds the app with GitHub Actions (`.github/workflows/macos-app.yml`) and publishes it to this repository's **Packages** section as `ghcr.io/davidricardowilde/yatagarasu-macos`:

- `edge`: the latest `master` build
- `X.Y.Z` and `latest`: builds from version tags (`vX.Y.Z`), which are also attached to a GitHub Release for one-click downloads

To download from Packages, use [ORAS](https://oras.land) (`brew install oras`):

```bash
oras pull ghcr.io/davidricardowilde/yatagarasu-macos:latest
```

This gives you `Yatagarasu-<version>-macOS.dmg`, the same app as a `.zip`, and `SHA256SUMS.txt`. Open the .dmg and drag Yatagarasu into Applications.

The builds are not notarized by Apple yet. If macOS says the app can't be opened after a browser download, Control-click it in Applications and choose **Open**, or allow it under **System Settings › Privacy & Security**.

### Test status

The repository currently does not expose a fully configured automated test action in the Xcode scheme. At the moment, the build is the primary baseline validation step.

## Limitations and roadmap notes

Yatagarasu already provides a solid core workflow, but it is still early in its lifecycle. A few areas are intentionally in progress:

- Some controls from the design are placeholders until their backends exist (see `pendingFeature()`).
- HTML-heavy GitHub READMEs are not yet rendered with a dedicated fallback path.
- GitHub integration currently focuses on discovery, release inspection, and install-source tracking rather than end-to-end managed installation for every repository.
- Homebrew-backed workflows naturally depend on a valid local Homebrew installation.

## Why this project exists

Package managers are powerful, but the surrounding experience is often fragmented:

- Homebrew is efficient, but terminal-centric
- GitHub Releases are flexible, but inconsistent across projects
- Great open-source software is easy to miss if discovery starts and ends with a package name

Yatagarasu exists to bring those worlds together in a native desktop interface that feels intentional, clear, and pleasant to use.

## Contributing

Contributions are welcome, especially around:

- SwiftUI UX polish
- Homebrew and GitHub integration edge cases
- package metadata modeling and caching
- localization
- test coverage and developer tooling

If you open a pull request, please verify the project still builds with `xcodebuild` or `pnpm build` before submitting.

## License

This project is licensed under the [MIT License](./LICENSE).
