import Foundation

struct DrumProfile: Sendable {
    let displayName: String
    let audioResource: String















        let fallbackName = name.isEmpty ? "사용자 Reference Object" : name
        return .init(displayName: fallbackName, audioResource: "percussion-fx.wav")
    }
}
