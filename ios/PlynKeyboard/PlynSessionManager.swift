import AVFoundation
import FirebaseAnalytics
import Foundation
import UIKit

final class PlyńSessionManager {
  static let shared = PlyńSessionManager()
  private let userInstruction = "Transcribe this audio as Belarusian dictation. Return only Belarusian transcript text."

  private let notificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
    guard let observer else {
      return
    }

    let manager = Unmanaged<PlyńSessionManager>.fromOpaque(observer).takeUnretainedValue()
    manager.handleSharedCommandNotification()
  }

  private let session = AVAudioSession.sharedInstance()
  private let engine = AVAudioEngine()
  private let workQueue = DispatchQueue(label: "com.holas.Plyńkeyboard.session")
  private let workQueueKey = DispatchSpecificKey<Void>()

  private var notificationObservers: [NSObjectProtocol] = []
  private var configured = false
  private var tapInstalled = false
  private var isCapturing = false
  private var isRecoveringSession = false
  private var latestHandledCommandTimestamp: TimeInterval = 0
  private var sampleRate: Double = 16_000
  private var audioChunks: [Data] = []
  private var recoveryState = PlynSessionRecoveryState()
  private var sessionSuspendedForAppRecording = false
  private var commandPollTimer: DispatchSourceTimer?
  private var transcriptionTask: Task<Void, Never>?
  private var activeTranscriptSessionID: String?
  private var transcriptSnapshotSequence = 0

  private func log(_ message: String) {
    NSLog("[PlyńSession] \(message)")
  }

  private init() {
    workQueue.setSpecific(key: workQueueKey, value: ())
  }

  func configure() {
    guard !configured else {
      return
    }

    configured = true
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterAddObserver(
      center,
      Unmanaged.passUnretained(self).toOpaque(),
      notificationCallback,
      PlynSharedStore.commandNotificationName as CFString,
      nil,
      .deliverImmediately
    )

    configureLifecycleObservers()
    startCommandPolling()
    log("configure engineRunning=\(engine.isRunning) suspended=\(sessionSuspendedForAppRecording)")
    synchronizeSharedSessionState()
  }

  func getStatus() -> [String: Any] {
    let isActive = onWorkQueueSync {
      recoverSessionIfNeeded(reason: "status_check")
    }
    log("getStatus isActive=\(isActive) engineRunning=\(engine.isRunning) suspended=\(sessionSuspendedForAppRecording)")
    return ["isActive": isActive]
  }

  func startSession() throws -> [String: Any] {
    configure()
    recoveryState.markSessionRequestedActive()
    _ = synchronizeSharedSessionState()

    try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
    try session.setActive(true)

    let inputFormat = engine.inputNode.inputFormat(forBus: 0)
    guard PlynAudioInputFormat.isValidRecordingFormat(
      sampleRate: inputFormat.sampleRate,
      channelCount: inputFormat.channelCount
    ) else {
      PlynSharedStore.saveKeyboardCommand(.none)
      log("startSession deferred invalidInput sampleRate=\(inputFormat.sampleRate) channelCount=\(inputFormat.channelCount)")
      return getStatus()
    }

    sampleRate = inputFormat.sampleRate

    if !tapInstalled {
      engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
        self?.appendAudioBuffer(buffer)
      }

      tapInstalled = true
    }

    if !engine.isRunning {
      engine.prepare()
      try engine.start()
    }

    PlynSharedStore.saveSessionActive(true)
    PlynSharedStore.saveSessionRequestedActive(true)
    PlynSharedStore.clearSessionRecoveryAttemptTimestamp()
    PlynSharedStore.saveKeyboardCommand(.none)
    log("startSession engineRunning=\(engine.isRunning) sampleRate=\(sampleRate)")
    return getStatus()
  }

  func stopSession() {
    cancelTranscriptionTask()
    isCapturing = false
    recoveryState.markSessionStopped()
    audioChunks.removeAll()
    sessionSuspendedForAppRecording = false
    activeTranscriptSessionID = nil
    transcriptSnapshotSequence = 0

    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }

    engine.stop()
    try? session.setActive(false, options: .notifyOthersOnDeactivation)

    PlynSharedStore.saveSessionActive(false)
    PlynSharedStore.saveSessionRequestedActive(false)
    PlynSharedStore.clearSessionRecoveryAttemptTimestamp()
    PlynSharedStore.saveKeyboardCommand(.none)
    PlynSharedStore.clearLatestTranscript()
    log("stopSession engineRunning=\(engine.isRunning)")
  }

  private func configureLifecycleObservers() {
    guard notificationObservers.isEmpty else {
      return
    }

    let center = NotificationCenter.default
    notificationObservers = [
      center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: session,
        queue: nil
      ) { [weak self] notification in
        self?.handleAudioSessionInterruption(notification)
      },
      center.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        self?.recoverSessionIfNeededAsync(reason: "app_did_become_active")
      },
    ]
  }

  @discardableResult
  private func synchronizeSharedSessionState() -> Bool {
    let isActive = PlynCompanionSessionAvailability.isSharedSessionActive(
      engineRunning: engine.isRunning,
      suspendedForAppRecording: sessionSuspendedForAppRecording
    )
    let isRequestedActive = PlynCompanionSessionAvailability.isSharedSessionRequestedActive(
      shouldKeepSessionActive: recoveryState.shouldKeepSessionActive,
      engineRunning: engine.isRunning,
      suspendedForAppRecording: sessionSuspendedForAppRecording
    )

    if PlynSharedStore.isSessionRequestedActive() != isRequestedActive {
      PlynSharedStore.saveSessionRequestedActive(isRequestedActive)
    }

    if PlynSharedStore.isSessionActive() != isActive {
      PlynSharedStore.saveSessionActive(isActive)

      if !isActive {
        PlynSharedStore.saveKeyboardCommand(.none)
        PlynSharedStore.clearLatestTranscript()
      }
    }

    log("synchronize isActive=\(isActive) requested=\(isRequestedActive) engineRunning=\(engine.isRunning) suspended=\(sessionSuspendedForAppRecording) command=\(PlynSharedStore.keyboardCommand().rawValue) status=\(PlynSharedStore.keyboardStatus().rawValue)")

    return isActive
  }

  private func handleAudioSessionInterruption(_ notification: Notification) {
    workQueue.async {
      guard
        let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        let interruptionType = AVAudioSession.InterruptionType(rawValue: rawType)
      else {
        return
      }

      switch interruptionType {
      case .began:
        let wasSuspended = (notification.userInfo?[AVAudioSessionInterruptionWasSuspendedKey] as? NSNumber)?.boolValue ?? false
        self.log("audioInterruption began wasSuspended=\(wasSuspended)")
        self.recoveryState.markAudioSessionInterrupted()
        self.cancelTranscriptionTask()
        self.isCapturing = false
        self.audioChunks.removeAll()
        self.activeTranscriptSessionID = nil
        self.transcriptSnapshotSequence = 0
        if self.engine.isRunning {
          self.engine.stop()
        }
        self.synchronizeSharedSessionState()
      case .ended:
        let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
        self.log("audioInterruption ended shouldResume=\(shouldResume)")
        _ = self.recoverSessionIfNeeded(reason: "audio_interruption_ended")
      @unknown default:
        self.synchronizeSharedSessionState()
      }
    }
  }

  private func recoverSessionIfNeededAsync(reason: String) {
    workQueue.async {
      _ = self.recoverSessionIfNeeded(reason: reason)
    }
  }

  @discardableResult
  private func recoverSessionIfNeeded(reason: String) -> Bool {
    guard recoveryState.shouldAttemptRecovery(engineRunning: engine.isRunning) else {
      return synchronizeSharedSessionState()
    }

    guard !isRecoveringSession else {
      return synchronizeSharedSessionState()
    }

    isRecoveringSession = true
    defer {
      isRecoveringSession = false
    }

    do {
      PlynSharedStore.saveSessionRecoveryAttemptTimestamp()
      log("recoverSessionIfNeeded attempting reason=\(reason)")
      _ = try startSession()
      return synchronizeSharedSessionState()
    } catch {
      log("recoverSessionIfNeeded failed reason=\(reason) error=\(error.localizedDescription)")
      return synchronizeSharedSessionState()
    }
  }

  func suspendForAppRecording() {
    workQueue.sync {
      self.cancelTranscriptionTask()
      guard !sessionSuspendedForAppRecording else {
        return
      }

      recoveryState.markSuspendedForAppRecording()
      sessionSuspendedForAppRecording = true
      isCapturing = false
      audioChunks.removeAll()
      activeTranscriptSessionID = nil
      transcriptSnapshotSequence = 0

      if tapInstalled {
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
      }

      if engine.isRunning {
        engine.stop()
      }

      PlynSharedStore.saveKeyboardCommand(.none)
      PlynSharedStore.saveKeyboardStatus(.ready)
      self.log("suspendForAppRecording engineRunning=\(self.engine.isRunning)")
    }
  }

  func resumeAfterAppRecording() throws {
    let shouldRestoreSession = workQueue.sync { () -> Bool in
      recoveryState.markResumedAfterAppRecording()
      sessionSuspendedForAppRecording = false
      return recoveryState.shouldKeepSessionActive
    }

    guard shouldRestoreSession else {
      return
    }

    _ = try startSession()
    log("resumeAfterAppRecording engineRunning=\(engine.isRunning)")
  }

  private func handleSharedCommandNotification() {
    workQueue.async {
      self.processPendingKeyboardCommand()
    }
  }

  private func startCommandPolling() {
    guard commandPollTimer == nil else {
      return
    }

    let timer = DispatchSource.makeTimerSource(queue: workQueue)
    timer.schedule(deadline: .now(), repeating: .milliseconds(250))
    timer.setEventHandler { [weak self] in
      self?.refreshSharedSessionRequestedHeartbeatIfNeeded()
      self?.refreshSharedSessionHeartbeatIfNeeded()
      self?.processPendingKeyboardCommand()
    }
    timer.resume()
    commandPollTimer = timer
  }

  private func refreshSharedSessionHeartbeatIfNeeded() {
    guard PlynCompanionSessionAvailability.isSharedSessionActive(
      engineRunning: engine.isRunning,
      suspendedForAppRecording: sessionSuspendedForAppRecording
    ) else {
      return
    }

    PlynSharedStore.refreshSessionHeartbeat()
  }

  private func refreshSharedSessionRequestedHeartbeatIfNeeded() {
    guard PlynCompanionSessionAvailability.isSharedSessionRequestedActive(
      shouldKeepSessionActive: recoveryState.shouldKeepSessionActive,
      engineRunning: engine.isRunning,
      suspendedForAppRecording: sessionSuspendedForAppRecording
    ) else {
      return
    }

    PlynSharedStore.refreshSessionRequestedHeartbeat()
  }

  private func processPendingKeyboardCommand() {
    guard PlynSharedStore.isSessionActive(), let timestamp = PlynSharedStore.keyboardCommandTimestamp() else {
      return
    }

    let timestampValue = timestamp.timeIntervalSince1970
    guard timestampValue > latestHandledCommandTimestamp else {
      return
    }

    latestHandledCommandTimestamp = timestampValue
    log("processPendingKeyboardCommand command=\(PlynSharedStore.keyboardCommand().rawValue) timestamp=\(timestampValue)")

    switch PlynSharedStore.keyboardCommand() {
    case .none:
      break
    case .startCapture:
      startKeyboardCapture()
    case .stopCapture:
      finishKeyboardCapture()
    }
  }

  private func startKeyboardCapture() {
    guard PlynSharedStore.isSessionActive() else {
      PlynSharedStore.saveKeyboardStatus(.inactive)
      return
    }

    guard recoverSessionIfNeeded(reason: "keyboard_start_capture") else {
      PlynSharedStore.saveKeyboardStatus(.failed)
      log("startKeyboardCapture failed to recover session")
      return
    }

    guard engine.isRunning else {
      PlynSharedStore.saveKeyboardStatus(.failed)
      log("startKeyboardCapture blocked because engine is not running")
      return
    }

    PlyńRemoteRuntimeConfig.refreshForDictationSession()

    workQueue.async {
      self.audioChunks.removeAll()
      self.isCapturing = true
      self.cancelTranscriptionTask()
      self.activeTranscriptSessionID = UUID().uuidString
      self.transcriptSnapshotSequence = 0
      PlynSharedStore.clearLatestTranscript()
      PlynSharedStore.saveKeyboardStatus(.recording)
      Analytics.logEvent("dictation_start", parameters: [
        "platform": "ios",
        "entry_point": "ios_keyboard",
        "session_active": "true",
      ])
      self.log("startKeyboardCapture engineRunning=\(self.engine.isRunning)")
    }
  }

  private func finishKeyboardCapture() {
    workQueue.async {
      guard self.isCapturing else {
        return
      }

      self.isCapturing = false
      let audioData = self.buildWavData(from: self.audioChunks, sampleRate: self.sampleRate)
      self.audioChunks.removeAll()

      guard !audioData.isEmpty else {
        let transcriptSessionID = self.activeTranscriptSessionID ?? UUID().uuidString
        self.activeTranscriptSessionID = transcriptSessionID
        self.transcriptSnapshotSequence = 0
        self.publishTranscriptSnapshot(
          "",
          transcriptSessionID: transcriptSessionID,
          isFinal: true,
          state: .empty,
          errorCode: nil
        )
        PlynSharedStore.saveKeyboardStatus(.ready)
        self.log("finishKeyboardCapture emptyAudio -> ready")
        return
      }

      PlynSharedStore.saveKeyboardStatus(.transcribing)
      self.log("finishKeyboardCapture transcribing bytes=\(audioData.count)")
      let transcriptSessionID = self.activeTranscriptSessionID ?? UUID().uuidString
      self.activeTranscriptSessionID = transcriptSessionID
      self.transcriptSnapshotSequence = 0
      self.transcribe(audioData: audioData, transcriptSessionID: transcriptSessionID)
    }
  }

  private func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    workQueue.async {
      guard self.isCapturing else {
        return
      }

      self.sampleRate = buffer.format.sampleRate
      self.audioChunks.append(self.pcm16Data(from: buffer))
    }
  }

  private func transcribe(audioData: Data, transcriptSessionID: String) {
    let startedAt = Date()

    guard let apiKey = PlynSharedStore.apiKey() else {
      publishTranscriptSnapshot("", transcriptSessionID: transcriptSessionID, isFinal: true, state: .failed, errorCode: "missing_api_key")
      PlynSharedStore.saveKeyboardStatus(.failed)
      trackKeyboardTranscriptionMetrics(result: "error", transcript: "", startedAt: startedAt)
      return
    }

    guard let systemInstruction = PlynSharedStore.geminiSystemPrompt() else {
      publishTranscriptSnapshot("", transcriptSessionID: transcriptSessionID, isFinal: true, state: .failed, errorCode: "missing_runtime_config")
      PlynSharedStore.saveKeyboardStatus(.failed)
      trackKeyboardTranscriptionMetrics(result: "error", transcript: "", startedAt: startedAt)
      return
    }

    guard let url = PlynSharedStore.geminiStreamEndpointURL(apiKey: apiKey) else {
      publishTranscriptSnapshot("", transcriptSessionID: transcriptSessionID, isFinal: true, state: .failed, errorCode: "missing_runtime_config")
      PlynSharedStore.saveKeyboardStatus(.failed)
      trackKeyboardTranscriptionMetrics(result: "error", transcript: "", startedAt: startedAt)
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

      cancelTranscriptionTask()
      transcriptionTask = Task { [weak self] in
        guard let self else {
          return
        }

        do {
          let result: PlyńSpeech.TranscriptionResult

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

          guard self.isTranscriptSessionActive(transcriptSessionID) else {
            return
          }

          PlynSharedStore.addTokenUsageSummary(result.usageSummary)

          if result.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.publishTranscriptSnapshot(
              "",
              transcriptSessionID: transcriptSessionID,
              isFinal: true,
              state: .empty,
              errorCode: nil
            )
            PlynSharedStore.saveKeyboardStatus(.ready)
            self.trackKeyboardTranscriptionMetrics(result: "empty", transcript: result.transcript, startedAt: startedAt)
            self.log("transcribe emptyTranscript -> ready")
            return
          }

          self.publishTranscriptSnapshot(
            result.transcript,
            transcriptSessionID: transcriptSessionID,
            isFinal: true,
            state: .completed,
            errorCode: nil
          )
          PlynSharedStore.saveKeyboardStatus(.ready)
          self.trackKeyboardTranscriptionMetrics(result: "success", transcript: result.transcript, startedAt: startedAt)
        } catch is CancellationError {
          self.log("transcribe cancelled sessionID=\(transcriptSessionID)")
        } catch {
          guard self.isTranscriptSessionActive(transcriptSessionID) else {
            return
          }

          let latestTranscript = self.latestTranscriptText(for: transcriptSessionID)
          self.publishTranscriptSnapshot(
            latestTranscript,
            transcriptSessionID: transcriptSessionID,
            isFinal: true,
            state: .failed,
            errorCode: "stream_error"
          )
          PlynSharedStore.saveKeyboardStatus(.failed)
          self.trackKeyboardTranscriptionMetrics(result: "error", transcript: "", startedAt: startedAt)
          self.log("transcribe failed sessionID=\(transcriptSessionID) error=\(error.localizedDescription)")
        }
      }
    } catch {
      PlynSharedStore.saveKeyboardStatus(.failed)
      trackKeyboardTranscriptionMetrics(result: "error", transcript: "", startedAt: startedAt)
    }
  }

  private func cancelTranscriptionTask() {
    transcriptionTask?.cancel()
    transcriptionTask = nil
  }

  private func isTranscriptSessionActive(_ transcriptSessionID: String) -> Bool {
    onWorkQueueSync {
      activeTranscriptSessionID == transcriptSessionID
    }
  }

  private func publishTranscriptSnapshot(
    _ transcript: String,
    transcriptSessionID: String,
    isFinal: Bool,
    state: PlynSharedStore.TranscriptState,
    errorCode: String?
  ) {
    onWorkQueueSync {
      guard activeTranscriptSessionID == transcriptSessionID else {
        return
      }

      transcriptSnapshotSequence += 1
      PlynSharedStore.saveTranscriptSnapshot(
        transcript,
        sessionID: transcriptSessionID,
        sequence: transcriptSnapshotSequence,
        isFinal: isFinal,
        state: state,
        errorCode: errorCode
      )
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

  private func onWorkQueueSync<T>(_ work: () -> T) -> T {
    if DispatchQueue.getSpecific(key: workQueueKey) != nil {
      return work()
    }

    return workQueue.sync(execute: work)
  }

  private func fetchTranscriptFallback(request: URLRequest) async throws -> PlyńSpeech.TranscriptionResult {
    try await withCheckedThrowingContinuation { continuation in
      URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        guard
          let httpResponse = response as? HTTPURLResponse,
          (200 ... 299).contains(httpResponse.statusCode),
          let data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
          continuation.resume(throwing: NSError(domain: "PlyńSession", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini response"]))
          return
        }

        continuation.resume(
          returning: PlyńSpeech.TranscriptionResult(
            transcript: PlyńSpeech.extractTranscript(from: json),
            usageSummary: PlyńSpeech.extractUsageSummary(from: json)
          )
        )
      }.resume()
    }
  }

  @available(iOS 15.0, *)
  private func streamTranscript(request: URLRequest, transcriptSessionID: String) async throws -> PlyńSpeech.TranscriptionResult {
    let (bytes, response) = try await URLSession.shared.bytes(for: request)

    guard
      let httpResponse = response as? HTTPURLResponse,
      (200 ... 299).contains(httpResponse.statusCode)
    else {
      throw NSError(domain: "PlyńSession", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini stream response"])
    }

    var mergedTranscript = ""
    var latestUsageSummary: PlynSharedStore.TokenUsageSummary?

    for try await rawLine in bytes.lines {
      if Task.isCancelled {
        throw CancellationError()
      }

      guard let payload = streamPayload(from: rawLine) else {
        continue
      }

      if payload == "[DONE]" {
        break
      }

      if let usageSummary = extractUsageSummaryFromStreamPayload(payload) {
        latestUsageSummary = usageSummary
      }

      let incomingTranscript = extractTranscriptFromStreamPayload(payload)
      guard !incomingTranscript.isEmpty else {
        continue
      }

      let nextTranscript = mergeStreamTranscript(existing: mergedTranscript, incoming: incomingTranscript)
      guard nextTranscript != mergedTranscript else {
        continue
      }

      mergedTranscript = nextTranscript
      publishTranscriptSnapshot(
        mergedTranscript,
        transcriptSessionID: transcriptSessionID,
        isFinal: false,
        state: .streamingPartial,
        errorCode: nil
      )
    }

    return PlyńSpeech.TranscriptionResult(
      transcript: mergedTranscript,
      usageSummary: latestUsageSummary
    )
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
        .first(where: { !$0.isEmpty }) ?? ""
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
      return PlyńSpeech.extractUsageSummary(from: json)
    }

    if let chunks = object as? [[String: Any]] {
      return chunks.compactMap { PlyńSpeech.extractUsageSummary(from: $0) }.last
    }

    return nil
  }

  private func mergeStreamTranscript(existing: String, incoming: String) -> String {
    PlynSharedStore.mergeStreamTranscript(existing: existing, incoming: incoming)
  }

  private func trackKeyboardTranscriptionMetrics(result: String, transcript: String, startedAt: Date) {
    let latencyMs = max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
    let outputChars = transcript.count
    let outputSizeBucket = outputSizeBucket(outputChars)
    let latencyBucket = latencyBucket(latencyMs)

    Analytics.logEvent("dictation_complete", parameters: [
      "platform": "ios",
      "entry_point": "ios_keyboard",
      "result": result,
      "output_size_bucket": outputSizeBucket,
    ])
    Analytics.logEvent("gemini_transcription_latency", parameters: [
      "platform": "ios",
      "entry_point": "ios_keyboard",
      "latency_ms": latencyMs,
      "latency_bucket": latencyBucket,
      "result": result,
      "output_chars": outputChars,
      "output_size_bucket": outputSizeBucket,
    ])
    Analytics.logEvent("gemini_transcription_size_latency", parameters: [
      "platform": "ios",
      "entry_point": "ios_keyboard",
      "latency_bucket": latencyBucket,
      "output_size_bucket": outputSizeBucket,
      "result": result,
    ])
  }

  private func latencyBucket(_ latencyMs: Int) -> String {
    switch latencyMs {
    case ..<1_000:
      return "lt_1000"
    case ..<2_000:
      return "1000_1999"
    case ..<4_000:
      return "2000_3999"
    case ..<8_000:
      return "4000_7999"
    default:
      return "8000_plus"
    }
  }

  private func outputSizeBucket(_ outputChars: Int) -> String {
    switch outputChars {
    case ...0:
      return "0"
    case ...20:
      return "1_20"
    case ...60:
      return "21_60"
    case ...120:
      return "61_120"
    default:
      return "121_plus"
    }
  }

  private func pcm16Data(from buffer: AVAudioPCMBuffer) -> Data {
    let frameLength = Int(buffer.frameLength)

    if let channelData = buffer.int16ChannelData?[0] {
      return Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
    }

    guard let channelData = buffer.floatChannelData?[0] else {
      return Data()
    }

    var pcm = Data(capacity: frameLength * MemoryLayout<Int16>.size)

    for index in 0 ..< frameLength {
      let clamped = max(-1.0, min(1.0, channelData[index]))
      var sample = Int16(clamped * Float(Int16.max))
      withUnsafeBytes(of: &sample) { bytes in
        pcm.append(contentsOf: bytes)
      }
    }

    return pcm
  }

  private func buildWavData(from chunks: [Data], sampleRate: Double) -> Data {
    let pcmData = chunks.reduce(into: Data()) { result, chunk in
      result.append(chunk)
    }

    guard !pcmData.isEmpty else {
      return Data()
    }

    let channelCount: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let sampleRateValue = UInt32(sampleRate.rounded())
    let byteRate = sampleRateValue * UInt32(channelCount) * UInt32(bitsPerSample / 8)
    let blockAlign = channelCount * bitsPerSample / 8
    let dataSize = UInt32(pcmData.count)
    let chunkSize = 36 + dataSize

    var data = Data()
    data.append("RIFF".data(using: .ascii)!)
    data.append(littleEndian(chunkSize))
    data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!)
    data.append(littleEndian(UInt32(16)))
    data.append(littleEndian(UInt16(1)))
    data.append(littleEndian(channelCount))
    data.append(littleEndian(sampleRateValue))
    data.append(littleEndian(byteRate))
    data.append(littleEndian(blockAlign))
    data.append(littleEndian(bitsPerSample))
    data.append("data".data(using: .ascii)!)
    data.append(littleEndian(dataSize))
    data.append(pcmData)
    return data
  }

  private func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
    var value = value.littleEndian
    return withUnsafeBytes(of: &value) { bytes in
      Data(bytes: bytes.baseAddress!, count: bytes.count)
    }
  }
}
