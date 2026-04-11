import AVFoundation

enum PlynAudioInputFormat {
  static func isValidRecordingFormat(sampleRate: Double, channelCount: AVAudioChannelCount) -> Bool {
    sampleRate > 0 && channelCount > 0
  }
}
