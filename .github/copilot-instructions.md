# Copilot Instructions for Yatagarasu

## Build, test, and lint commands

This repository currently has one macOS app target (`yatagarasu`) in `yatagarasu/yatagarasu.xcodeproj`.

```bash
# From repository root
cd yatagarasu

# Inspect available schemes/targets/configurations
xcodebuild -list -project yatagarasu.xcodeproj

# Build (Debug, macOS destination)
xcodebuild -project yatagarasu.xcodeproj -scheme yatagarasu -configuration Debug -destination 'platform=macOS' build
```

Testing status:

```bash
# Current behavior: fails because the scheme has no test action configured yet
xcodebuild test -project yatagarasu.xcodeproj -scheme yatagarasu -destination 'platform=macOS'
```

- There is currently no test target in the project, so there is no runnable "single test" command yet.
- When a test bundle is added, run a single test with:

```bash
xcodebuild test -project yatagarasu.xcodeproj -scheme yatagarasu -destination 'platform=macOS' -only-testing:<TestTarget>/<TestCase>/<testMethod>
```

Linting status:
- No dedicated linter configuration is present in the repo (no SwiftLint config/scripts yet).
- Use the build command above as the current compiler/static-check baseline.

## High-level architecture

The repository currently has two layers of truth:

1. **Implemented scaffold (in code)**  
   - `yatagarasu/yatagarasu/yatagarasu/yatagarasuApp.swift`: app entry point; creates and injects a SwiftData `ModelContainer`.
   - `yatagarasu/yatagarasu/yatagarasu/ContentView.swift`: default `NavigationSplitView` + `@Query` list UI.
   - `yatagarasu/yatagarasu/yatagarasu/Item.swift`: minimal SwiftData `@Model` used by the scaffold.

2. **Target architecture (in docs)**  
   - `docs/ARCHITECTURE.md`, `docs/PRD.md`, `docs/UI_PROTOTYPE.md`, `docs/PROJECT_PLAN.md` define the intended MVP:
     - **UI layer**: SwiftUI (`NavigationSplitView`, App Store-like layout, material-heavy styling).
     - **Service layer**: async shell execution via a dedicated actor (`ShellExecutor`/`ShellService`) and package-source abstractions (`PackageManager`, `BrewManager`, `GitHubManager`).
     - **Data layer**: GitHub REST + download flow via `URLSession`, persistence via SwiftData (`InstalledApp`, `PackageCache`).

When making changes, treat docs as the product/architecture contract and current Swift files as early scaffolding.

## Key conventions specific to this repo

- Keep development aligned with the phased plan in `docs/PROJECT_PLAN.md` (foundation -> shell engine -> UI -> package workflows -> GitHub/SwiftData).
- Preserve native macOS UI direction from docs: `NavigationSplitView`, SF Symbols, and `ultraThinMaterial`-based glass styling.
- Concurrency direction is explicit in docs: shell and long-running operations should be actor-backed and async (`async/await`, streamed output), not blocking UI work on the main actor.
- Data-model split is intentional: Codable models for external package metadata (e.g., Brew JSON) should stay separate from SwiftData persistence entities.
- Sandbox and privilege-sensitive operations are part of core design; use `osascript`/helper-based escalation patterns described in docs rather than hardcoded `sudo` command strings in UI-facing flows.
- Repo layout is intentionally nested: app code and Xcode project are under `yatagarasu/`, while architecture and product guidance live under top-level `docs/`.

### UI architecture and state management patterns

- Keep the app shell centered on `NavigationSplitView`; planned sidebar taxonomy is Discover / Categories / Updates / Dev-Space (see `docs/PRD.md` and `docs/PROJECT_PLAN.md`).
- Keep search in the window toolbar/navigation bar, not as a separate panel (`docs/UI_PROTOTYPE.md`).
- For visual components, continue the glassmorphism direction: material-backed containers/cards (`ultraThinMaterial`), SF Symbols, and native macOS typography.
- State-management direction in project docs is Observation-first (`@Observable` stores for feature/view-model state), while SwiftData powers persisted entities.
- Current scaffold uses `@Environment(\.modelContext)` + `@Query`; expand this pattern carefully as real domain models replace the template `Item` model.
- UI decomposition should favor reusable components/modifiers (`AppCard`, view modifiers) as called out in `docs/PROJECT_PLAN.md`.
