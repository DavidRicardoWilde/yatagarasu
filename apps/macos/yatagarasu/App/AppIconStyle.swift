//
//  AppIconStyle.swift
//  yatagarasu
//
//  The app icons people can choose between in Settings › General.
//

import AppKit

/// macOS has no alternate-icon API like iOS, so the choice swaps the Dock icon while
/// Yatagarasu runs. Finder keeps showing the primary icon from the app bundle.
///
/// Both icons are Icon Composer packages in `Resources/` (drawn by
/// `design/app-icon/tools/build.py`); `PixelAppIcon` is compiled into the asset catalog
/// through the target's `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` build setting.
enum AppIconStyle: String, CaseIterable, Identifiable {
    static let storageKey = "settings.appIcon"

    case classic
    case pixel

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .classic: "settings.app_icon.option.classic"
        case .pixel: "settings.app_icon.option.pixel"
        }
    }

    private var assetName: String {
        switch self {
        case .classic: "AppIcon"
        case .pixel: "PixelAppIcon"
        }
    }

    /// The icon as the Dock draws it, including the standard macOS icon margins.
    var image: NSImage? {
        NSImage(named: assetName)
    }

    /// The style saved in Settings; the classic icon until someone picks another.
    static var saved: AppIconStyle {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppIconStyle.init(rawValue:)) ?? .classic
    }

    /// Shows this icon in the Dock. The classic icon resets to the bundle's own icon,
    /// so the Dock keeps drawing its light, dark and tinted appearances.
    func apply() {
        NSApp.applicationIconImage = self == .classic ? nil : image
    }
}
