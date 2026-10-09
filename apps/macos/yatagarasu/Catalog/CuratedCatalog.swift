//
//  CuratedCatalog.swift
//  yatagarasu
//
//  Hand-picked storefront content: catalog items, starter kits, and the
//  "Popular this week" shelf. Shipped with the app until a remote catalog exists.
//

import Foundation

struct CuratedCatalog {
    let items: [CatalogItem]
    let starterKits: [StarterKit]
    let popularItemIDs: [String]

    private let itemsByID: [String: CatalogItem]

    init(items: [CatalogItem], starterKits: [StarterKit], popularItemIDs: [String]) {
        self.items = items
        self.starterKits = starterKits
        self.popularItemIDs = popularItemIDs
        self.itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    func item(id: String) -> CatalogItem? {
        itemsByID[id]
    }

    func items(in kit: StarterKit) -> [CatalogItem] {
        kit.itemIDs.compactMap(item(id:))
    }

    var popularItems: [CatalogItem] {
        popularItemIDs.compactMap(item(id:))
    }

    /// The curated entry for a Homebrew package, if there is one.
    func item(matching package: PackageReference) -> CatalogItem? {
        let keys = package.normalizedLookupKeys
        return items.first { item in
            guard let homebrew = item.homebrew else { return false }
            return !homebrew.normalizedLookupKeys.isDisjoint(with: keys)
        }
    }

    /// The curated entry for a GitHub repository, if there is one.
    func item(forRepository fullName: String) -> CatalogItem? {
        items.first { $0.repositoryFullName?.caseInsensitiveCompare(fullName) == .orderedSame }
    }

    /// Kits for enabled specialties first, then general kits, then the rest.
    func starterKits(prioritizing specialties: SpecialtySet) -> [StarterKit] {
        func rank(_ kit: StarterKit) -> Int {
            guard let specialty = kit.specialty else { return 1 }
            return specialties.contains(specialty) ? 0 : 2
        }
        return starterKits.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    func search(_ query: String) -> [CatalogItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(needle)
                || item.summary.text.localizedCaseInsensitiveContains(needle)
                || (item.homebrew?.brewName.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }
}

// MARK: - Shipped content

extension CuratedCatalog {
    static let standard = CuratedCatalog(
        items: [
            .curated("ghostty", "Ghostty", tint: .teal, cask: "ghostty", repository: "ghostty-org/ghostty", homepage: "https://ghostty.org"),
            .curated("orbstack", "OrbStack", tint: .blue, cask: "orbstack", homepage: "https://orbstack.dev"),
            .curated("raycast", "Raycast", tint: .vermilion, cask: "raycast", homepage: "https://www.raycast.com"),
            .curated("wezterm", "WezTerm", tint: .purple, cask: "wezterm", repository: "wez/wezterm", homepage: "https://wezfurlong.org/wezterm/"),
            .curated("zed", "Zed", tint: .blue, cask: "zed", homepage: "https://zed.dev"),
            .curated("rectangle", "Rectangle", tint: .green, cask: "rectangle", repository: "rxhanson/Rectangle", homepage: "https://rectangleapp.com"),
            .curated("stats", "Stats", tint: .teal, cask: "stats", homepage: "https://github.com/exelban/stats"),
            .curated("iina", "IINA", tint: .purple, cask: "iina", homepage: "https://iina.io"),
            .curated("git", "Git", tint: .vermilion, formula: "git", homepage: "https://git-scm.com"),
            .curated("node", "Node.js", tint: .green, formula: "node", homepage: "https://nodejs.org"),
            .curated("gh", "GitHub CLI", tint: .blue, formula: "gh", homepage: "https://cli.github.com"),
            .curated("jq", "jq", tint: .purple, formula: "jq", homepage: "https://jqlang.org"),
            .curated("vscode", "Visual Studio Code", tint: .blue, cask: "visual-studio-code", homepage: "https://code.visualstudio.com"),
            .curated("figma", "Figma", tint: .purple, cask: "figma", homepage: "https://www.figma.com/downloads/"),
            .curated("inkscape", "Inkscape", tint: .teal, cask: "inkscape", homepage: "https://inkscape.org"),
            .curated("blender", "Blender", tint: .amber, cask: "blender", homepage: "https://www.blender.org"),
            .curated("imageoptim", "ImageOptim", tint: .green, cask: "imageoptim", homepage: "https://imageoptim.com/mac"),
            .curated("uv", "uv", tint: .purple, formula: "uv", homepage: "https://docs.astral.sh/uv/"),
            .curated("jupyterlab", "JupyterLab", tint: .amber, formula: "jupyterlab", homepage: "https://jupyter.org"),
            .curated("duckdb", "DuckDB", tint: .amber, formula: "duckdb", homepage: "https://duckdb.org"),
            .curated("ffmpeg", "FFmpeg", tint: .green, formula: "ffmpeg", homepage: "https://ffmpeg.org"),
            .curated("audacity", "Audacity", tint: .blue, cask: "audacity", homepage: "https://www.audacityteam.org"),
            .curated("obs", "OBS Studio", tint: .purple, cask: "obs", homepage: "https://obsproject.com"),
            .curated("nmap", "Nmap", tint: .teal, formula: "nmap", homepage: "https://nmap.org"),
            .curated("lulu", "LuLu", tint: .green, cask: "lulu", homepage: "https://objective-see.org/products/lulu.html"),
            .curated("skhd", "skhd", tint: .amber, formula: "koekeishiya/formulae/skhd", repository: "koekeishiya/skhd"),
        ],
        starterKits: [
            StarterKit(
                id: "web-developer", titleKey: "setups.kit.webDeveloper.title", blurbKey: "setups.kit.webDeveloper.blurb",
                symbol: "chevron.left.forwardslash.chevron.right", tint: .blue, specialty: .development, unit: .tools,
                itemIDs: ["git", "node", "gh", "jq", "vscode", "orbstack", "ghostty", "zed"]
            ),
            StarterKit(
                id: "designer", titleKey: "setups.kit.designer.title", blurbKey: "setups.kit.designer.blurb",
                symbol: "paintpalette", tint: .purple, specialty: .creative, unit: .apps,
                itemIDs: ["figma", "inkscape", "blender", "imageoptim"]
            ),
            StarterKit(
                id: "data-and-ai", titleKey: "setups.kit.dataAndAI.title", blurbKey: "setups.kit.dataAndAI.blurb",
                symbol: "chart.bar.xaxis", tint: .teal, specialty: .data, unit: .tools,
                itemIDs: ["uv", "jupyterlab", "duckdb", "git", "vscode"]
            ),
            StarterKit(
                id: "creator", titleKey: "setups.kit.creator.title", blurbKey: "setups.kit.creator.blurb",
                symbol: "music.note", tint: .amber, specialty: .media, unit: .apps,
                itemIDs: ["audacity", "obs", "ffmpeg", "iina"]
            ),
            StarterKit(
                id: "it-admin", titleKey: "setups.kit.itAdmin.title", blurbKey: "setups.kit.itAdmin.blurb",
                symbol: "checkmark.shield", tint: .green, specialty: .administration, unit: .tools,
                itemIDs: ["nmap", "lulu", "stats", "jq"]
            ),
            StarterKit(
                id: "everyday-mac", titleKey: "setups.kit.everydayMac.title", blurbKey: "setups.kit.everydayMac.blurb",
                symbol: "sparkles", tint: .vermilion, specialty: nil, unit: .apps,
                itemIDs: ["raycast", "rectangle", "stats", "iina"]
            ),
        ],
        popularItemIDs: ["ghostty", "raycast", "orbstack", "zed", "rectangle", "stats"]
    )
}

private extension CatalogItem {
    static func curated(
        _ id: String,
        _ name: String,
        tint: BrandTint,
        cask: String? = nil,
        formula: String? = nil,
        repository: String? = nil,
        homepage: String? = nil
    ) -> CatalogItem {
        let homebrew: PackageReference? = if let cask {
            PackageReference(displayName: name, brewName: cask, kind: .cask)
        } else if let formula {
            PackageReference(displayName: name, brewName: formula, kind: .formula)
        } else {
            nil
        }

        return CatalogItem(
            id: id,
            name: name,
            summary: .localized(key: "catalog.item.\(id).summary"),
            tint: tint,
            homebrew: homebrew,
            repositoryFullName: repository,
            homepage: homepage.flatMap(URL.init(string:))
        )
    }
}
