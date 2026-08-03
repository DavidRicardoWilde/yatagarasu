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
- Tracks active operations with staged progress and a floating command console
- Filters installed formulae to hide dependency-only installs unless the user explicitly installed them

### Open-source discovery

- Includes a dedicated **Open Source** section for curated GitHub projects
- Fetches repository metadata, README content, and recent releases from the GitHub API
- Renders project READMEs in a native SwiftUI detail experience
- Parses release assets and prefers installable macOS artifacts such as `.dmg`, `.pkg`, and `.zip`
- Falls back to a clear “build from source” path when a repository does not publish a suitable binary release

### Unified installed view

- Shows Homebrew-managed packages and tracked GitHub-origin records in one place
- Preserves installation-source context, including GitHub Release and source-build entry points
- Surfaces outdated packages and supports batch updates for Homebrew-managed items

### macOS-native UX

- `NavigationSplitView` layout with a glassmorphism-inspired interface
- Material-backed cards, native typography, and SF Symbols
- Built-in localization support for English, Simplified Chinese, Traditional Chinese, and Japanese
- Settings for language selection, Homebrew re-check, parser validation, and command console visibility

## Current scope

Implemented areas:

- **Discover**
- **Open Source**
- **Installed**
- **Settings**

Still evolving:

- **Categories** view content
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
  - `ContentView` hosts the main shell and top-level navigation.
  - SwiftUI feature views render discovery, installed packages, open-source details, and settings.

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
│   │       ├── ContentView.swift
│   │       ├── PackageWorkspace.swift
│   │       ├── OpenSourceCatalogWorkspace.swift
│   │       ├── Services/
│   │       └── Models/
│   ├── linux/              # Linux app (placeholder, coming soon)
│   └── windows/            # Windows app (placeholder, coming soon)
├── package.json            # Root workspace config
├── turbo.json              # Turborepo pipeline
└── docs/                   # Architecture & product docs
```

### Monorepo tooling

- **Turborepo** orchestrates builds across apps
- Workspace packages are scoped as `@yatagarasu/<platform>`
- Run `npm run build` from root to build all apps; `npm run build:macos` for just macOS

## Getting started

### Requirements

- A recent version of Xcode with SwiftUI and SwiftData support
- macOS development environment
- Homebrew installed locally if you want to use Homebrew package management features

### Build

From the repository root:

```bash
# Install dependencies (first time only)
npm install

# Build all apps
npm run build

# Build only macOS
npm run build:macos

# Or build directly with xcodebuild
cd apps/macos
xcodebuild -project yatagarasu.xcodeproj -scheme yatagarasu -configuration Debug -destination 'platform=macOS' build
```

You can also open `apps/macos/yatagarasu.xcodeproj` directly in Xcode and run the `yatagarasu` scheme.

### Test status

The repository currently does not expose a fully configured automated test action in the Xcode scheme. At the moment, the build is the primary baseline validation step.

## Limitations and roadmap notes

Yatagarasu already provides a solid core workflow, but it is still early in its lifecycle. A few areas are intentionally in progress:

- Some sidebar destinations are placeholders rather than complete product areas.
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

If you open a pull request, please verify the project still builds with `xcodebuild` or `npm run build` before submitting.

## License

This project is licensed under the [MIT License](./LICENSE).
