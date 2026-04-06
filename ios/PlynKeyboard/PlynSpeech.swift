import AVFoundation
import Foundation
import React

@objc(PlyńSpeech)
final class PlyńSpeech: RCTEventEmitter {
  private static let transcriptSnapshotEventName = "PlyńSpeechTranscriptSnapshot"

  struct TranscriptionResult {
    let transcript: String
    let usageSummary: PlynSharedStore.TokenUsageSummary?
  }

  private let userInstruction = "Transcribe this audio as Belarusian dictation. Return only Belarusian transcript text."
  private var recorder: AVAudioRecorder?
  private var outputURL: URL?
  private var activeTranscriptSessionID: String?
  private var transcriptSnapshotSequence = 0

  override static func requiresMainQueueSetup() -> Bool {
    false
  }

  override func supportedEvents() -> [String]! {
    [Self.transcriptSnapshotEventName]
  }

  private func log(_ message: String) {
    NSLog("[PlyńSpeech] \(message)")
  }

  @objc
  func requestMicrophonePermission(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    let session = AVAudioSession.sharedInstance()

    switch session.recordPermission {
    case .granted:
      do {
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
      } catch {
        log("requestMicrophonePermission warmupFailed error=\(error.localizedDescription)")
      }
      resolve(true)
    case .denied:
      resolve(false)
    case .undetermined:
      session.requestRecordPermission { granted in
        if granted {
          do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
          } catch {
            self.log("requestMicrophonePermission warmupFailed error=\(error.localizedDescription)")
          }
        }

        resolve(granted)
      }
    @unknown default:
      resolve(false)
    }
  }

  @objc
  func startRecording(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    if PlyńE2EOverrides.isEnabled {
      log("startRecording usingE2EOverride")
      resolve(nil)
      return
    }

    do {
      log("startRecording requested")
      PlyńSessionManager.shared.suspendForAppRecording()
      activeTranscriptSessionID = nil
      transcriptSnapshotSequence = 0
      PlynSharedStore.clearLatestTranscript()

      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
      try session.setActive(true)

      let url = FileManager.default.temporaryDirectory.appendingPathComponent("Plyń-ios.wav")
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
      recorder.isMeteringEnabled = true
      recorder.prepareToRecord()

      guard recorder.record() else {
        throw NSError(domain: "PlyńSpeech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording could not start."])
      }

      self.recorder = recorder
      log("startRecording started file=\(url.lastPathComponent) sampleRate=16000")
      resolve(nil)
    } catch {
      log("startRecording failed error=\(error.localizedDescription)")
      try? PlyńSessionManager.shared.resumeAfterAppRecording()
      reject("recording_error", error.localizedDescription, error)
    }
  }

  @objc
  func stopRecording(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if PlyńE2EOverrides.isEnabled {
      if let transcriptError = PlyńE2EOverrides.transcriptError {
        log("stopRecording e2eError=\(transcriptError)")
        reject("e2e_transcription_error", transcriptError, nil)
        return
      }

      let transcript = PlyńE2EOverrides.transcript ?? ""
      log("stopRecording usingE2EOverride transcriptChars=\(transcript.count)")
      resolve(transcript)
      return
    }

    recorder?.stop()
    recorder = nil
    log("stopRecording requested")

    guard let outputURL else {
      try? PlyńSessionManager.shared.resumeAfterAppRecording()
      log("stopRecording missingAudioFile")
      reject("missing_audio", "No captured audio was available.", nil)
      return
    }

    guard let apiKey = PlynSharedStore.apiKey() else {
      try? PlyńSessionManager.shared.resumeAfterAppRecording()
      log("stopRecording missingApiKey")
      reject("missing_key", "Save your Gemini API key before recording.", nil)
      return
    }

    do {
      let audioData = try Data(contentsOf: outputURL)
      log("stopRecording audioBytes=\(audioData.count)")
      let transcriptSessionID = UUID().uuidString
      activeTranscriptSessionID = transcriptSessionID
      transcriptSnapshotSequence = 0
      transcribe(audioData: audioData, apiKey: apiKey, transcriptSessionID: transcriptSessionID, resolve: resolve, reject: reject)
    } catch {
      try? PlyńSessionManager.shared.resumeAfterAppRecording()
      log("stopRecording audioReadFailed error=\(error.localizedDescription)")
      reject("audio_read_error", error.localizedDescription, error)
    }
  }

  @objc
  func getAudioLevel(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    guard let recorder else {
      resolve(0)
      return
    }

    recorder.updateMeters()
    let averagePower = recorder.averagePower(forChannel: 0)
    let normalized = max(0, min(1, pow(10, averagePower / 20)))
    resolve(normalized)
  }

  private func transcribe(
    audioData: Data,
    apiKey: String,
    transcriptSessionID: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let systemInstruction = PlynSharedStore.geminiSystemPrompt() else {
      log("transcribe missingRuntimeConfig systemPrompt")
      try? PlyńSessionManager.shared.resumeAfterAppRecording()
      reject("missing_runtime_config", PlynSharedStore.missingRuntimeConfigError().localizedDescription, nil)
      return
    }

    guard let url = PlynSharedStore.geminiStreamEndpointURL(apiKey: apiKey) else {
      log("transcribe missingRuntimeConfig endpoint")
      try? PlyńSessionManager.shared.resumeAfterAppRecording()
      reject("missing_runtime_config", PlynSharedStore.missingRuntimeConfigError().localizedDescription, nil)
      return
    }

    let body: [String: Any] = [
      "system_instruction": [
        "parts": [
          ["text": systemInstruction],
        ],
      ],
      "contents": [[
        "parts": [
          ["text": userInstruction],
          [
            "inlineData": [
              "mimeType": "audio/wav",
              "data": audioData.base64EncodedString(),
            ],
          ],
        ],
      ]],
    ]

    do {
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      log("transcribe requestPrepared bytes=\(audioData.count) sessionID=\(transcriptSessionID)")

      Task {
        defer {
          try? PlyńSessionManager.shared.resumeAfterAppRecording()
        }

        do {
          let result: TranscriptionResult

          if #available(iOS 15.0, *) {
            result = try await self.streamTranscript(request: request, transcriptSessionID: transcriptSessionID)
          } else {
            result = try await self.fetchTranscriptFallback(request: request)
            self.publishTranscriptSnapshot(
              result.transcript,
              transcriptSessionID: transcriptSessionID,
              isFinal: false,
              state: .streamingPartial,
              errorCode: nil
            )
          }

          PlynSharedStore.addTokenUsageSummary(result.usageSummary)
          self.log("transcribe completed sessionID=\(transcriptSessionID) transcriptChars=\(result.transcript.count)")
          self.publishTranscriptSnapshot(
            result.transcript,
            transcriptSessionID: transcriptSessionID,
            isFinal: true,
            state: result.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .completed,
            errorCode: nil
          )
          resolve(result.transcript)
        } catch {
          let latestTranscript = self.latestTranscriptText(for: transcriptSessionID)
          self.log("transcribe failed sessionID=\(transcriptSessionID) error=\(error.localizedDescription)")
          if !latestTranscript.isEmpty {
            self.publishTranscriptSnapshot(
              latestTranscript,
              transcriptSessionID: transcriptSessionID,
              isFinal: true,
              state: .failed,
              errorCode: "stream_error"
            )
          }
          reject("gemini_error", error.localizedDescription, error)
        }
      }
    } catch {
      log("transcribe requestEncodingFailed error=\(error.localizedDescription)")
      try? PlyńSessionManager.shared.resumeAfterAppRecording()
      reject("request_error", error.localizedDescription, error)
    }
  }

  private func publishTranscriptSnapshot(
    _ transcript: String,
    transcriptSessionID: String,
    isFinal: Bool,
    state: PlynSharedStore.TranscriptState,
    errorCode: String?
  ) {
    guard activeTranscriptSessionID == transcriptSessionID else {
      log("publishTranscriptSnapshot ignoredInactiveSession sessionID=\(transcriptSessionID)")
      return
    }

    transcriptSnapshotSequence += 1
    let updatedAt = Date().timeIntervalSince1970
    log(
      "publishTranscriptSnapshot sessionID=\(transcriptSessionID) sequence=\(transcriptSnapshotSequence) state=\(state.rawValue) chars=\(transcript.count) final=\(isFinal)"
    )
    PlynSharedStore.saveTranscriptSnapshot(
      transcript,
      sessionID: transcriptSessionID,
      sequence: transcriptSnapshotSequence,
      isFinal: isFinal,
      state: state,
      errorCode: errorCode
    )

    let eventPayload: [String: Any] = [
      "text": transcript,
      "sessionID": transcriptSessionID,
      "sequence": transcriptSnapshotSequence,
      "isFinal": isFinal,
      "state": state.rawValue,
      "errorCode": errorCode as Any,
      "updatedAt": updatedAt,
    ]

    DispatchQueue.main.async {
      self.log(
        "emitTranscriptSnapshotEvent sessionID=\(transcriptSessionID) sequence=\(self.transcriptSnapshotSequence) state=\(state.rawValue) chars=\(transcript.count)"
      )
      self.sendEvent(withName: Self.transcriptSnapshotEventName, body: eventPayload)
    }
  }

  private func latestTranscriptText(for transcriptSessionID: String) -> String {
    guard
      let snapshot = PlynSharedStore.latestTranscriptSnapshot(),
      snapshot.sessionID == transcriptSessionID
    else {
      return ""
    }

    return snapshot.text
  }

  private func fetchTranscriptFallback(request: URLRequest) async throws -> TranscriptionResult {
    try await withCheckedThrowingContinuation { continuation in
      URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        guard
          let httpResponse = response as? HTTPURLResponse,
          let data
        else {
          continuation.resume(throwing: NSError(domain: "PlyńSpeech", code: 500, userInfo: [NSLocalizedDescriptionKey: "Сэрвіс апрацоўкі вярнуў некарэктны адказ."]))
          return
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
          continuation.resume(throwing: NSError(domain: "PlyńSpeech", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: PlyńSpeech.extractServiceErrorMessage(from: data, statusCode: httpResponse.statusCode)]))
          return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          continuation.resume(throwing: NSError(domain: "PlyńSpeech", code: 500, userInfo: [NSLocalizedDescriptionKey: "Сэрвіс апрацоўкі вярнуў некарэктны адказ."]))
          return
        }

        continuation.resume(
          returning: TranscriptionResult(
            transcript: PlyńSpeech.extractTranscript(from: json),
            usageSummary: PlyńSpeech.extractUsageSummary(from: json)
          )
        )
      }.resume()
    }
  }

  @available(iOS 15.0, *)
  private func streamTranscript(request: URLRequest, transcriptSessionID: String) async throws -> TranscriptionResult {
    let (bytes, response) = try await URLSession.shared.bytes(for: request)

    guard
      let httpResponse = response as? HTTPURLResponse
    else {
      throw NSError(domain: "PlyńSpeech", code: 500, userInfo: [NSLocalizedDescriptionKey: "Сэрвіс апрацоўкі вярнуў некарэктны адказ."])
    }

    guard (200 ... 299).contains(httpResponse.statusCode) else {
      var responseBody = Data()
      for try await rawLine in bytes.lines {
        guard let data = rawLine.data(using: .utf8) else {
          continue
        }
        responseBody.append(data)
        responseBody.append(0x0A)
      }

      throw NSError(domain: "PlyńSpeech", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: PlyńSpeech.extractServiceErrorMessage(from: responseBody, statusCode: httpResponse.statusCode)])
    }

    var mergedTranscript = ""
    var latestUsageSummary: PlynSharedStore.TokenUsageSummary?

    for try await rawLine in bytes.lines {
      log("streamTranscript rawLineChars=\(rawLine.count)")
      guard let payload = streamPayload(from: rawLine) else {
        continue
      }

      if payload == "[DONE]" {
        log("streamTranscript doneMarker sessionID=\(transcriptSessionID)")
        break
      }

      if let usageSummary = extractUsageSummaryFromStreamPayload(payload) {
        latestUsageSummary = usageSummary
      }

      let incomingTranscript = extractTranscriptFromStreamPayload(payload)
      guard !incomingTranscript.isEmpty else {
        log("streamTranscript emptyIncoming sessionID=\(transcriptSessionID)")
        continue
      }

      log(
        "streamTranscript incoming sessionID=\(transcriptSessionID) chars=\(incomingTranscript.count) preview=\(incomingTranscript.prefix(80))"
      )

      let nextTranscript = mergeStreamTranscript(existing: mergedTranscript, incoming: incomingTranscript)
      guard nextTranscript != mergedTranscript else {
        log("streamTranscript unchangedMerge sessionID=\(transcriptSessionID) chars=\(mergedTranscript.count)")
        continue
      }

      mergedTranscript = nextTranscript
      log(
        "streamTranscript merged sessionID=\(transcriptSessionID) chars=\(mergedTranscript.count)"
      )
      publishTranscriptSnapshot(
        mergedTranscript,
        transcriptSessionID: transcriptSessionID,
        isFinal: false,
        state: .streamingPartial,
        errorCode: nil
      )
    }

    return TranscriptionResult(transcript: mergedTranscript, usageSummary: latestUsageSummary)
  }

  private func streamPayload(from rawLine: String) -> String? {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !line.isEmpty else {
      return nil
    }

    if line.hasPrefix("data:") {
      return String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if line.first == "{" || line.first == "[" {
      return line
    }

    return nil
  }

  private func extractTranscriptFromStreamPayload(_ payload: String) -> String {
    guard let data = payload.data(using: .utf8) else {
      return ""
    }

    guard let object = try? JSONSerialization.jsonObject(with: data) else {
      return ""
    }

    if let json = object as? [String: Any] {
      return PlyńSpeech.extractTranscript(from: json)
    }

    if let chunks = object as? [[String: Any]] {
      return chunks
        .map { PlyńSpeech.extractTranscript(from: $0) }
        .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
    }

    return ""
  }

  private func extractUsageSummaryFromStreamPayload(_ payload: String) -> PlynSharedStore.TokenUsageSummary? {
    guard let data = payload.data(using: .utf8) else {
      return nil
    }

    guard let object = try? JSONSerialization.jsonObject(with: data) else {
      return nil
    }

    if let json = object as? [String: Any] {
      return Self.extractUsageSummary(from: json)
    }

    if let chunks = object as? [[String: Any]] {
      return chunks.compactMap { Self.extractUsageSummary(from: $0) }.last
    }

    return nil
  }

  private func mergeStreamTranscript(existing: String, incoming: String) -> String {
    PlynSharedStore.mergeStreamTranscript(existing: existing, incoming: incoming)
  }

  static func extractTranscript(from json: [String: Any]?) -> String {
    guard
      let json,
      let candidates = json["candidates"] as? [[String: Any]],
      let content = candidates.first?["content"] as? [String: Any],
      let parts = content["parts"] as? [[String: Any]]
    else {
      return ""
    }

    return PlynSharedStore.transcriptText(from: parts)
  }

  static func extractUsageSummary(from json: [String: Any]?) -> PlynSharedStore.TokenUsageSummary? {
    PlynSharedStore.TokenUsageSummary(usageMetadata: json?["usageMetadata"] as? [String: Any])
  }

  static func extractServiceErrorMessage(from data: Data, statusCode: Int) -> String {
    if
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let error = json["error"] as? [String: Any],
      let message = error["message"] as? String,
      !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return message
    }

    switch statusCode {
    case 400 ... 499:
      return "Не ўдалося апрацаваць запіс. Праверце налады і паспрабуйце яшчэ раз."
    case 500 ... 599:
      return "Сэрвіс апрацоўкі часова недаступны. Паспрабуйце крыху пазней."
    default:
      return "Падчас апрацоўкі маўлення нешта пайшло не так. Паспрабуйце яшчэ раз."
    }
  }
}
