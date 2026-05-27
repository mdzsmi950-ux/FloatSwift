import SwiftUI

struct AccountPalette: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let backgrounds: [String]
    let markers: [String]
    let usesOmbreBackground: Bool

    func background(for index: Int) -> String {
        backgrounds[index % backgrounds.count]
    }

    func marker(for index: Int) -> String {
        markers[index % markers.count]
    }

    static let all: [AccountPalette] = [
        AccountPalette(
            id: "original",
            name: "Original",
            description: "Soft and quiet",
            backgrounds: ["EEE9E7", "E9ECEF", "EEE8EB", "EEECE5", "E8EBE7", "EAE8ED"],
            markers: ["D8B8AA", "AFC4D8", "D8AFC1", "D8CBA9", "B8C9B4", "C2B8D3"],
            usesOmbreBackground: false
        ),
        AccountPalette(
            id: "bright",
            name: "Bright",
            description: "Clearer visual separation",
            backgrounds: ["FFF8DD", "EEF9FF", "FFF1F6", "F1FBEF", "F5F0FF", "FFF3E8"],
            markers: ["F2C94C", "56CCF2", "EB5757", "6FCF97", "9B51E0", "F2994A"],
            usesOmbreBackground: true
        ),
        AccountPalette(
            id: "fall-winter",
            name: "Fall/Winter",
            description: "Warm and muted",
            backgrounds: ["F0E5DC", "E6E0D4", "E3E8E2", "E1E6EA", "EBE3EA", "EFE7D6"],
            markers: ["B97956", "8A7962", "6F8A70", "6E8798", "92708D", "B89A5F"],
            usesOmbreBackground: false
        ),
        AccountPalette(
            id: "white",
            name: "White",
            description: "Minimal, no color wash",
            backgrounds: ["FFFFFF", "FFFFFF", "FFFFFF", "FFFFFF", "FFFFFF", "FFFFFF"],
            markers: ["D6D6D6", "C8C8C8", "BABABA", "ACACAC", "9E9E9E", "909090"],
            usesOmbreBackground: false
        ),
        AccountPalette(
            id: "colorblind",
            name: "Color Safe",
            description: "Color-blind friendly",
            backgrounds: ["F0F7FF", "FFF7E4", "F0FAF4", "F8F1FF", "FFF0EB", "EFFAF8"],
            markers: ["0072B2", "E69F00", "009E73", "CC79A7", "D55E00", "56B4E9"],
            usesOmbreBackground: true
        )
    ]

    static let fallback = all[0]

    static func find(_ id: String) -> AccountPalette {
        all.first { $0.id == id } ?? fallback
    }
}
