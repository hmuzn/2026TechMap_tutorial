import AVFoundation
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

for (name, frequency) in [("wood-block.wav", 520.0), ("tom.wav", 180.0), ("percussion-fx.wav", 310.0)] {
    let frames = AVAudioFrameCount(0.22 * format.sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    let samples = buffer.floatChannelData![0]
    for i in 0..<Int(frames) {
        let t = Double(i) / format.sampleRate
        let envelope = exp(-22 * t)
        samples[i] = Float(sin(2 * .pi * frequency * t) * envelope * 0.7)
    }
    let file = try AVAudioFile(forWriting: output.appendingPathComponent(name), settings: format.settings)
    try file.write(from: buffer)
}

