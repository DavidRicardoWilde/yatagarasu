//
//  FeatureFlags.swift
//  yatagarasu
//
//  Compile-time switches for screens that are built but not ready to ship.
//

enum FeatureFlags {
    /// Discover is hidden until its catalog comes from a maintained data source
    /// (a backend or a periodically refreshed JSON list) instead of the hard-coded
    /// `CuratedCatalog`: today it can't list every available version, link to
    /// direct downloads, or show real app icons.
    static let showsDiscover = false
}
