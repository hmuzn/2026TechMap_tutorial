import AVFoundation
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("Usage: swift generate_audio.swift <output-directory>\n".utf8)
    )
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

struct NoiseGenerator {
    private var state: UInt64 = 0x5EED_2026

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        let unit = Double((state >> 40) & 0xFF_FFFF) / Double(0xFF_FFFF)
        return unit * 2 - 1
    }
}

enum Voice {
    case woodBlock
    case tom
    case percussionFX
}

let voices: [(name: String, duration: Double, voice: Voice)] = [
    ("wood-block.wav", 0.18, .woodBlock),
    ("tom.wav", 0.34, .tom),
    ("percussion-fx.wav", 0.24, .percussionFX),
]

var noise = NoiseGenerator()

for item in voices {
    let frames = AVAudioFrameCount(item.duration * format.sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    let samples = buffer.floatChannelData![0]

    for i in 0..<Int(frames) {
        let t = Double(i) / format.sampleRate
        let sample: Double

        switch item.voice {
        case .woodBlock:
            let body = sin(2 * .pi * 520 * t) + 0.55 * sin(2 * .pi * 810 * t)
            sample = (body * 0.42 + noise.next() * 0.08) * exp(-25 * t)
        case .tom:
            let pitch = 190 - 55 * (1 - exp(-18 * t))
            let body = sin(2 * .pi * pitch * t) + 0.22 * sin(2 * .pi * pitch * 2 * t)
            sample = body * 0.62 * exp(-11 * t)
        case .percussionFX:
            let metallic = sin(2 * .pi * 310 * t) + 0.45 * sin(2 * .pi * 1_127 * t)
            sample = (metallic * 0.28 + noise.next() * 0.34) * exp(-17 * t)
        }

        samples[i] = Float(min(max(sample, -1), 1))
    }

    let file = try AVAudioFile(
        forWriting: output.appendingPathComponent(item.name),
        settings: format.settings
    )
    try file.write(from: buffer)
}
