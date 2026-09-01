import Foundation

struct DrumProfile: Sendable {
    let displayName: String
    let audioResource: String

    static func forReferenceObject(named name: String) -> DrumProfile {
        let normalizedName = name
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        if normalizedName.contains("magickeyboard") {
            return .init(
                displayName: "Apple Magic Keyboard",
                audioResource: "wood-block.wav"
            )
        }

        let fallbackName = name.isEmpty ? "사용자 Reference Object" : name
        return .init(displayName: fallbackName, audioResource: "percussion-fx.wav")
    }
}
