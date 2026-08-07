import Foundation

enum DrumShape: String, Sendable {
    case box, cylinder, irregular
}

struct DrumProfile: Sendable {
    let displayName: String
    let shape: DrumShape
    let audioResource: String

    static func forReferenceObject(named name: String) -> DrumProfile {
        switch name {
        case "SmallBox":
            .init(displayName: "Wood Block", shape: .box, audioResource: "wood-block.wav")
        case "LabeledCan":
            .init(displayName: "Tom", shape: .cylinder, audioResource: "tom.wav")
        default:
            .init(displayName: "Percussion FX", shape: .irregular, audioResource: "percussion-fx.wav")
        }
    }
}

