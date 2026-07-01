import Foundation
import AVFoundation

final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private var sampleRate: Double = 0

    func startRecording(device: AudioDevice? = nil) throws {
        samples.removeAll()

        if let device {
            AudioDeviceManager.setInputDevice(device, on: engine)
        }

        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        sampleRate = fmt.sampleRate
        let channels = Int(fmt.channelCount)

        input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { [weak self] buffer, _ in
            guard let self, let data = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            if channels == 1 {
                self.samples.append(contentsOf: UnsafeBufferPointer(start: data[0], count: frames))
            } else {
                var mono = [Float](repeating: 0, count: frames)
                for c in 0..<channels {
                    let ptr = UnsafeBufferPointer(start: data[c], count: frames)
                    for f in 0..<frames { mono[f] += ptr[f] }
                }
                for f in 0..<frames { mono[f] /= Float(channels) }
                self.samples.append(contentsOf: mono)
            }
        }

        engine.prepare()
        try engine.start()
    }

    func stopRecording() -> (samples: [Float], sampleRate: Double) {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        return (samples, sampleRate)
    }

    static func writeWAV(to path: String, samples: [Float], sampleRate: Double, targetRate: Double = 16000) {
        let resampled = resample(samples, from: sampleRate, to: targetRate)
        let intSamples = resampled.map { Int16(clamping: Int($0 * Float(Int16.max))) }
        let data = intSamples.withUnsafeBytes { Data($0) }

        var wav = Data()
        let byteRate = Int32(targetRate) * 2
        let dataSize = Int32(data.count)
        let fileSize = dataSize + 36

        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        wav.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
        wav.append(withUnsafeBytes(of: Int32(16).littleEndian) { Data($0) }) // chunk size
        wav.append(withUnsafeBytes(of: Int16(1).littleEndian) { Data($0) })  // PCM
        wav.append(withUnsafeBytes(of: Int16(1).littleEndian) { Data($0) })  // mono
        wav.append(withUnsafeBytes(of: Int32(targetRate).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: Int16(2).littleEndian) { Data($0) })  // block align
        wav.append(withUnsafeBytes(of: Int16(16).littleEndian) { Data($0) }) // bits per sample
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        wav.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wav.append(data)

        try? wav.write(to: URL(fileURLWithPath: path))
    }

    static func resample(_ samples: [Float], from: Double, to: Double) -> [Float] {
        guard from != to else { return samples }
        let ratio = from / to
        let count = Int(Double(samples.count) / ratio)
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let pos = Double(i) * ratio
            let idx = Int(pos)
            let frac = pos - Double(idx)
            if idx + 1 < samples.count {
                out[i] = Float((1 - frac) * Double(samples[idx]) + frac * Double(samples[idx + 1]))
            } else if idx < samples.count {
                out[i] = samples[idx]
            }
        }
        return out
    }

    static func loadWavSamples(_ path: String) -> [Float]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        let headerSize = 44
        guard data.count > headerSize else { return nil }
        let sampleData = data[headerSize...]
        let count = sampleData.count / 2
        var samples = [Float](repeating: 0, count: count)
        sampleData.withUnsafeBytes { ptr in
            guard let raw = ptr.baseAddress else { return }
            let int16 = raw.bindMemory(to: Int16.self, capacity: count)
            for i in 0..<count {
                samples[i] = Float(int16[i]) / Float(Int16.max)
            }
        }
        return samples
    }
}
