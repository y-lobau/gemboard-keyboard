import Foundation

public actor PlynMacDictationController {
  private let audioRecorder: PlynMacAudioRecording
  private let transcriber: PlynMacTranscribing
  private let textInserter: PlynMacTextInserting
  private let configuration: PlynMacConfigurationProviding
  private let permissionChecker: PlynMacPermissionChecking

  public private(set) var state: PlynMacDictationState = .idle
  public private(set) var latestTranscript = ""

  public init(
    audioRecorder: PlynMacAudioRecording,
    transcriber: PlynMacTranscribing,
    textInserter: PlynMacTextInserting,
    configuration: PlynMacConfigurationProviding,
    permissionChecker: PlynMacPermissionChecking
  ) {
    self.audioRecorder = audioRecorder
    self.transcriber = transcriber
    self.textInserter = textInserter
    self.configuration = configuration
    self.permissionChecker = permissionChecker
  }

  public func handleHoldStarted() async {
    PlynMacLogger.log("hold started state=\(state)")

    guard case .idle = state else {
      PlynMacLogger.log("hold start ignored state=\(state)")
      return
    }

    guard configuration.isReady else {
      PlynMacLogger.log("hold start blocked reason=missingConfiguration")
      state = .failed(PlynMacError.missingConfiguration.localizedDescription)
      return
    }

    let permissions = permissionChecker.currentSnapshot()
    guard permissions.isReady else {
      PlynMacLogger.log("hold start blocked reason=missingPermissions message=\(permissions.firstMissingMessage ?? "unknown")")
      state = .failed(permissions.firstMissingMessage ?? "Required permissions are missing.")
      return
    }

    do {
      PlynMacLogger.log("recording start requested")
      try await audioRecorder.startRecording()
      PlynMacLogger.log("recording started")
      state = .recording
    } catch {
      PlynMacLogger.log("recording start failed error=\(error.localizedDescription)")
      state = .failed(error.localizedDescription)
    }
  }

  public func handleHoldEnded() async {
    PlynMacLogger.log("hold ended state=\(state)")

    guard case .recording = state else {
      PlynMacLogger.log("hold end ignored state=\(state)")
      return
    }

    do {
      PlynMacLogger.log("recording stop requested")
      let audioURL = try await audioRecorder.stopRecording()
      PlynMacLogger.log("recording stopped audioURL=\(audioURL.path)")
      state = .transcribing
      let transcript = try await transcriber.transcribe(audioURL: audioURL)
      let trimmedTranscript = Self.sanitizedTranscript(transcript)
      guard !trimmedTranscript.isEmpty else {
        throw PlynMacError.emptyTranscript
      }

      latestTranscript = trimmedTranscript
      PlynMacLogger.log("transcription succeeded chars=\(trimmedTranscript.count)")
      state = .inserting
      try await textInserter.insert(trimmedTranscript)
      PlynMacLogger.log("text insertion requested chars=\(trimmedTranscript.count)")
      state = .idle
    } catch {
      PlynMacLogger.log("dictation failed error=\(error.localizedDescription)")
      state = .failed(error.localizedDescription)
    }
  }

  public func resetFailure() {
    if case .failed = state {
      state = .idle
    }
  }

  public func currentState() -> PlynMacDictationState {
    state
  }

  public func currentTranscript() -> String {
    latestTranscript
  }

  private static func sanitizedTranscript(_ transcript: String) -> String {
    transcript.unicodeScalars
      .filter { scalar in
        scalar == "\n" || scalar == "\r" || scalar == "\t" || !CharacterSet.controlCharacters.contains(scalar)
      }
      .filter { $0.properties.generalCategory != .format }
      .map(String.init)
      .joined()
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
