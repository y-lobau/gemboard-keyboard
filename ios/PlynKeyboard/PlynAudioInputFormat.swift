import AVFoundation

enum PlynAudioInputFormat {
  enum SessionStartMode {
    case recording
    case validationOnly
    case unavailable
  }

  static func isValidRecordingFormat(sampleRate: Double, channelCount: AVAudioChannelCount) -> Bool {
    sampleRate > 0 && channelCount > 0
  }

  static func sessionStartMode(sampleRate: Double, channelCount: AVAudioChannelCount) -> SessionStartMode {
    if supportsLiveDictationCapture(sampleRate: sampleRate, channelCount: channelCount) {
      return .recording
    }

#if targetEnvironment(simulator)
    return .validationOnly
#else
    return .unavailable
#endif
  }

  static func supportsLiveDictationCapture(sampleRate: Double, channelCount: AVAudioChannelCount) -> Bool {
    isValidRecordingFormat(sampleRate: sampleRate, channelCount: channelCount)
  }
}
