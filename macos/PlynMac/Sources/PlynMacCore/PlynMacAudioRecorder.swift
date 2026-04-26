import AVFoundation
import Foundation

public final class PlynMacAudioRecorder: NSObject, PlynMacAudioRecording, @unchecked Sendable {
  private var recorder: AVAudioRecorder?
  private var outputURL: URL?

  public override init() {
    super.init()
  }

  public func startRecording() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlynMac-\(UUID().uuidString).wav")
    outputURL = url

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 16_000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
    ]

    let recorder = try AVAudioRecorder(url: url, settings: settings)
    recorder.prepareToRecord()
    guard recorder.record() else {
      throw PlynMacError.serviceError("Recording could not start.")
    }
    self.recorder = recorder
    PlynMacLogger.log("audio recorder started file=\(url.path)")
  }

  public func stopRecording() async throws -> URL {
    recorder?.stop()
    recorder = nil

    guard let outputURL else {
      throw PlynMacError.missingAudio
    }
    let bytes = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.intValue ?? -1
    PlynMacLogger.log("audio recorder stopped file=\(outputURL.path) bytes=\(bytes)")
    return outputURL
  }
}
