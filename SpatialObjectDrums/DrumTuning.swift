import Foundation

struct DrumTuning: Sendable, Equatable {
    var strikePlaneOffset: Float = 0.012
    var cooldownMilliseconds: Double = 100
    var minimumStrikeSpeed: Float = 0.18
    var maximumStrikeSpeed: Float = 1.4
    var maximumSampleInterval: Float = 0.12
    var maximumSampleDistance: Float = 0.18
    var showsStrikeSurface = true

    var cooldown: Duration {
        .milliseconds(cooldownMilliseconds)
    }
}
