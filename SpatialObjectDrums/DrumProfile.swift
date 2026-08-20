import Foundation

enum DrumShape: String, Sendable {
    case box, cylinder, irregular
}

struct DrumProfile: Sendable {
    let displayName: String
    let shape: DrumShape
    let audioResource: String

    static func forReferenceObject(named name: String) -> DrumProfile {
        let normalizedName = name
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        if normalizedName.contains("iphone17") {
            return .init(
                displayName: "iPhone 17 Black",
                shape: .box,
                audioResource: "percussion-fx.wav"
            )
        }

        if normalizedName.contains("magickeyboard") {
            return .init(
                displayName: "Apple Magic Keyboard",
                shape: .box,
                audioResource: "wood-block.wav"
            )
        }

        switch name {
        case "SmallBox":
            return .init(displayName: "Wood Block", shape: .box, audioResource: "wood-block.wav")
        case "LabeledCan":
            return .init(displayName: "Tom", shape: .cylinder, audioResource: "tom.wav")
        default:
            return .init(displayName: "Percussion FX", shape: .irregular, audioResource: "percussion-fx.wav")
        }
    }
}
