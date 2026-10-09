//
//  Specialty.swift
//  yatagarasu
//
//  Specialties (Settings › Specialties) tune what the storefront shows first.
//  Nothing is ever hidden; everything stays reachable through search.
//

import Foundation

enum Specialty: String, CaseIterable, Identifiable, Hashable {
    case development
    case creative
    case data
    case media
    case administration

    var id: String { rawValue }

    var titleKey: String { "specialty.\(rawValue).title" }
    var blurbKey: String { "specialty.\(rawValue).blurb" }

    var symbol: String {
        switch self {
        case .development: "chevron.left.forwardslash.chevron.right"
        case .creative: "paintpalette"
        case .data: "chart.bar.xaxis"
        case .media: "music.note"
        case .administration: "checkmark.shield"
        }
    }

    var tint: BrandTint {
        switch self {
        case .development: .blue
        case .creative: .purple
        case .data: .teal
        case .media: .amber
        case .administration: .green
        }
    }
}

/// The enabled specialties, stored in `@AppStorage` as a comma-separated list.
struct SpecialtySet: RawRepresentable, Equatable {
    static let storageKey = "enabledSpecialties"
    static let defaultValue = SpecialtySet(members: [.development])

    var members: Set<Specialty>

    init(members: Set<Specialty>) {
        self.members = members
    }

    init(rawValue: String) {
        members = Set(rawValue.split(separator: ",").compactMap { Specialty(rawValue: String($0)) })
    }

    var rawValue: String {
        Specialty.allCases.filter(members.contains).map(\.rawValue).joined(separator: ",")
    }

    func contains(_ specialty: Specialty) -> Bool {
        members.contains(specialty)
    }

    mutating func toggle(_ specialty: Specialty) {
        if members.contains(specialty) {
            members.remove(specialty)
        } else {
            members.insert(specialty)
        }
    }
}
