import UIKit

final class KeyboardViewController: UIInputViewController {
  private static let companionAppURL = URL(string: "plyn://")
  private static let sessionRecoveryURL = URL(string: "plyn://session")
  private static let widgetSurfaceColor = UIColor(
    red: 74.0 / 255.0,
    green: 89.0 / 255.0,
    blue: 66.0 / 255.0,
    alpha: 1
  )
  private static let supportingTextColor = UIColor(
    red: 60.0 / 255.0,
    green: 72.0 / 255.0,
    blue: 54.0 / 255.0,
    alpha: 1
  )
  private static let accentColor = UIColor(
    red: 226.0 / 255.0,
    green: 217.0 / 255.0,
    blue: 210.0 / 255.0,
    alpha: 1
  )
  private static let buttonTrayColor = UIColor(
    red: 104.0 / 255.0,
    green: 121.0 / 255.0,
    blue: 92.0 / 255.0,
    alpha: 1
  )

  private enum KeyboardPresentationState {
    case ready
    case recording
    case processing
    case setupRequired
    case sessionRequired
    case companionTimeout
    case failed
  }

  private enum WaveAnimationMode {
    case idle
    case recording
    case processing
  }

  private var commandTimeout: TimeInterval {
    PlynSharedStore.keyboardCommandTimeout()
  }

  private var transcriptionTimeout: TimeInterval {
    PlynSharedStore.keyboardTranscriptionTimeout()
  }

  private var supportingInfoColor: UIColor {
    traitCollection.userInterfaceStyle == .dark
      ? Self.accentColor
      : Self.supportingTextColor
  }

  private let stateNotificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
    guard let observer else {
      return
    }

    let controller = Unmanaged<KeyboardViewController>.fromOpaque(observer).takeUnretainedValue()
    DispatchQueue.main.async {
      controller.reloadState()
    }
  }

  private let rootStack = UIStackView()
  private let surfaceView = UIView()
  private let controlsRow = UIStackView()
  private let utilityTray = UIView()
  private let standardKeysRow = UIStackView()
  private let deleteButton = UIButton(type: .system)
  private let waveContainer = UIView()
  private let waveRow = UIStackView()
  private let micButton = UIButton(type: .system)
  private let spaceButton = UIButton(type: .system)
  private let enterButton = UIButton(type: .system)
  private let statusLabel = UILabel()
  private let nextKeyboardButton = UIButton(type: .system)

  private var waveBars: [UIView] = []
  private var waveBarHeightConstraints: [NSLayoutConstraint] = []
  private var refreshTimer: Timer?
  private var waveAnimationTimer: Timer?
  private var lastAppliedTranscriptSessionID = ""
  private var lastAppliedTranscriptSequence = 0
  private var lastAppliedTranscriptText = ""
  private var provisionalTranscriptText = ""
  private var provisionalTranscriptPrefix = ""
  private var finalizedTranscriptSessionID = ""
  private var blockedTranscriptSessionID = ""
  private var isMicButtonPressed = false
  private var pendingStopAfterRecordingStarts = false
  private var transientErrorMessage: String?
  private var waveAnimationMode: WaveAnimationMode = .idle
  private var waveAnimationStep: Int = 0

  private func logDebug(_ message: String) {
    NSLog("[PlyńKeyboardExtension] \(message)")
    PlynSharedStore.saveKeyboardLaunchDebug(message)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureStateNotifications()
    setupView()
    reloadState()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    startRefreshing()
    reloadState()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    refreshTimer?.invalidate()
    refreshTimer = nil
    stopWaveAnimation()
  }

  deinit {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterRemoveObserver(
      center,
      Unmanaged.passUnretained(self).toOpaque(),
      CFNotificationName(PlynSharedStore.stateNotificationName as CFString),
      nil
    )
  }

  override func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)
    reloadState()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else {
      return
    }

    applyStaticPalette()
    reloadState()
  }

  private func applyStaticPalette() {
    surfaceView.backgroundColor = Self.widgetSurfaceColor
    utilityTray.backgroundColor = Self.buttonTrayColor
    utilityTray.layer.borderColor = Self.accentColor.withAlphaComponent(0.3).cgColor
    nextKeyboardButton.tintColor = supportingInfoColor
  }

  private func setupView() {
    view.backgroundColor = .clear
    view.isOpaque = false
    inputView?.backgroundColor = .clear
    inputView?.isOpaque = false

    rootStack.axis = .vertical
    rootStack.alignment = .fill
    rootStack.spacing = 8
    rootStack.translatesAutoresizingMaskIntoConstraints = false

    surfaceView.translatesAutoresizingMaskIntoConstraints = false
    surfaceView.layer.cornerRadius = 22
    surfaceView.layer.shadowColor = UIColor.black.withAlphaComponent(0.18).cgColor
    surfaceView.layer.shadowOffset = CGSize(width: 0, height: 8)
    surfaceView.layer.shadowOpacity = 1
    surfaceView.layer.shadowRadius = 16

    controlsRow.axis = .horizontal
    controlsRow.alignment = .center
    controlsRow.distribution = .fill
    controlsRow.spacing = 10
    controlsRow.translatesAutoresizingMaskIntoConstraints = false

    standardKeysRow.axis = .horizontal
    standardKeysRow.alignment = .fill
    standardKeysRow.distribution = .fill
    standardKeysRow.spacing = 6
    standardKeysRow.translatesAutoresizingMaskIntoConstraints = false

    utilityTray.translatesAutoresizingMaskIntoConstraints = false
    utilityTray.layer.cornerRadius = 12
    utilityTray.layer.borderWidth = 1
    utilityTray.layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
    utilityTray.layer.shadowOffset = CGSize(width: 0, height: 4)
    utilityTray.layer.shadowOpacity = 1
    utilityTray.layer.shadowRadius = 10

    configureStandardKeyButton(deleteButton, symbol: "delete.left")
    deleteButton.addTarget(self, action: #selector(handleDeleteBackward), for: .touchUpInside)

    waveContainer.translatesAutoresizingMaskIntoConstraints = false
    waveContainer.backgroundColor = UIColor.clear

    waveRow.axis = .horizontal
    waveRow.alignment = .center
    waveRow.distribution = .fillEqually
    waveRow.spacing = 6
    waveRow.translatesAutoresizingMaskIntoConstraints = false

    let barHeights: [CGFloat] = [12, 18, 26, 36, 46, 36, 26, 18, 12]
    waveBars = barHeights.map { height in
      let bar = UIView()
      bar.translatesAutoresizingMaskIntoConstraints = false
      bar.backgroundColor = UIColor(red: 0.68, green: 0.7, blue: 0.76, alpha: 0.9)
      bar.layer.cornerRadius = 3
      let heightConstraint = bar.heightAnchor.constraint(equalToConstant: height)
      waveBarHeightConstraints.append(heightConstraint)
      NSLayoutConstraint.activate([
        bar.widthAnchor.constraint(equalToConstant: 6),
        heightConstraint,
      ])
      waveRow.addArrangedSubview(bar)
      return bar
    }

    waveContainer.addSubview(waveRow)

    configureIconButton(micButton, symbol: "mic.fill")
    micButton.backgroundColor = Self.accentColor
    micButton.tintColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
    micButton.addTarget(self, action: #selector(handleMicPressDown), for: .touchDown)
    micButton.addTarget(self, action: #selector(handleMicPressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

    configureStandardKeyButton(spaceButton, symbol: "space")
    spaceButton.addTarget(self, action: #selector(handleInsertSpace), for: .touchUpInside)

    configureStandardKeyButton(enterButton, symbol: "return.left")
    enterButton.addTarget(self, action: #selector(handleInsertReturn), for: .touchUpInside)

    controlsRow.addArrangedSubview(waveContainer)
    controlsRow.addArrangedSubview(utilityTray)
    controlsRow.addArrangedSubview(micButton)

    standardKeysRow.addArrangedSubview(deleteButton)
    standardKeysRow.addArrangedSubview(spaceButton)
    standardKeysRow.addArrangedSubview(enterButton)

    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 2

    nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
    nextKeyboardButton.setImage(UIImage(systemName: "globe"), for: .normal)
    nextKeyboardButton.alpha = 0.9
    nextKeyboardButton.addTarget(self, action: #selector(handleNextKeyboard), for: .touchUpInside)

    applyStaticPalette()

    surfaceView.addSubview(controlsRow)
    utilityTray.addSubview(standardKeysRow)
    rootStack.addArrangedSubview(surfaceView)
    rootStack.addArrangedSubview(statusLabel)
    rootStack.addArrangedSubview(nextKeyboardButton)
    view.addSubview(rootStack)

    NSLayoutConstraint.activate([
      rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
      rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
      rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
      rootStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
      surfaceView.heightAnchor.constraint(equalToConstant: 80),
      controlsRow.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: 16),
      controlsRow.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -16),
      controlsRow.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: 12),
      controlsRow.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor, constant: -12),
      micButton.widthAnchor.constraint(equalToConstant: 56),
      micButton.heightAnchor.constraint(equalToConstant: 56),
      waveContainer.heightAnchor.constraint(equalToConstant: 56),
      utilityTray.widthAnchor.constraint(equalToConstant: 132),
      utilityTray.heightAnchor.constraint(equalToConstant: 40),
      standardKeysRow.leadingAnchor.constraint(equalTo: utilityTray.leadingAnchor, constant: 6),
      standardKeysRow.trailingAnchor.constraint(equalTo: utilityTray.trailingAnchor, constant: -6),
      standardKeysRow.topAnchor.constraint(equalTo: utilityTray.topAnchor, constant: 6),
      standardKeysRow.bottomAnchor.constraint(equalTo: utilityTray.bottomAnchor, constant: -6),
      deleteButton.widthAnchor.constraint(equalToConstant: 34),
      deleteButton.heightAnchor.constraint(equalToConstant: 28),
      spaceButton.widthAnchor.constraint(equalToConstant: 44),
      spaceButton.heightAnchor.constraint(equalToConstant: 28),
      enterButton.widthAnchor.constraint(equalToConstant: 34),
      enterButton.heightAnchor.constraint(equalToConstant: 28),
      waveRow.centerXAnchor.constraint(equalTo: waveContainer.centerXAnchor),
      waveRow.centerYAnchor.constraint(equalTo: waveContainer.centerYAnchor),
      waveRow.leadingAnchor.constraint(greaterThanOrEqualTo: waveContainer.leadingAnchor),
      waveRow.trailingAnchor.constraint(lessThanOrEqualTo: waveContainer.trailingAnchor),
      nextKeyboardButton.heightAnchor.constraint(equalToConstant: 24),
    ])
  }

  private func configureStateNotifications() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterAddObserver(
      center,
      Unmanaged.passUnretained(self).toOpaque(),
      stateNotificationCallback,
      PlynSharedStore.stateNotificationName as CFString,
      nil,
      .deliverImmediately
    )
  }

  private func configureIconButton(_ button: UIButton, symbol: String) {
    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = UIColor(red: 0.35, green: 0.38, blue: 0.46, alpha: 1)
    button.tintColor = Self.accentColor
    button.layer.cornerRadius = 28
    button.layer.shadowColor = UIColor.black.withAlphaComponent(0.24).cgColor
    button.layer.shadowOffset = CGSize(width: 0, height: 1)
    button.layer.shadowOpacity = 1
    button.layer.shadowRadius = 1.5
    button.setImage(UIImage(systemName: symbol), for: .normal)
    button.imageView?.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
  }

  private func configureStandardKeyButton(_ button: UIButton, title: String) {
    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = Self.accentColor
    button.layer.cornerRadius = 8
    button.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
    button.layer.shadowOffset = CGSize(width: 0, height: 1)
    button.layer.shadowOpacity = 1
    button.layer.shadowRadius = 2
  }

  private func configureStandardKeyButton(_ button: UIButton, symbol: String) {
    configureStandardKeyButton(button, title: "")
    button.tintColor = UIColor(red: 0.1, green: 0.11, blue: 0.14, alpha: 1)
    button.setImage(UIImage(systemName: symbol), for: .normal)
    button.imageView?.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
  }

  private func reloadState() {
    nextKeyboardButton.isHidden = !needsInputModeSwitchKey

    let sessionActive = hasResponsiveCompanionSession()
    let sharedKeyboardStatus = PlynSharedStore.keyboardStatus()
    let transientErrorLogValue = transientErrorMessage ?? "<none>"

    logDebug(
      "reloadState status=\(sharedKeyboardStatus.rawValue) sessionActive=\(sessionActive) apiKey=\(PlynSharedStore.hasApiKey()) transientError=\(transientErrorLogValue)"
    )

    if pendingStopAfterRecordingStarts, sharedKeyboardStatus == .recording {
      pendingStopAfterRecordingStarts = false
      PlynSharedStore.saveKeyboardCommand(.stopCapture)
    }

    applyTranscriptSnapshotIfNeeded(sharedKeyboardStatus: sharedKeyboardStatus)

    let presentationState = makePresentationState(sessionActive: sessionActive, keyboardStatus: sharedKeyboardStatus)
    applyPresentationState(presentationState)
  }

  private func hasResponsiveCompanionSession() -> Bool {
    PlynCompanionSessionLiveness.isResponsive(
      isSessionActive: PlynSharedStore.isSessionActive(),
      heartbeatTimestamp: PlynSharedStore.sessionHeartbeatTimestamp()
    )
  }

  private func makePresentationState(
    sessionActive: Bool,
    keyboardStatus: PlynSharedStore.KeyboardStatus
  ) -> KeyboardPresentationState {
    if let transientErrorMessage, !transientErrorMessage.isEmpty {
      return .companionTimeout
    }

    guard PlynSharedStore.hasApiKey() else {
      return .setupRequired
    }

    guard sessionActive else {
      return .sessionRequired
    }

    if hasCompanionTimedOut(status: keyboardStatus) {
      transientErrorMessage = "Праграма-кампаньён не адказвае"
      return .companionTimeout
    }

    if isMicButtonPressed || keyboardStatus == .recording {
      transientErrorMessage = nil
      return .recording
    }

    switch keyboardStatus {
    case .transcribing:
      transientErrorMessage = nil
      return .processing
    case .failed:
      transientErrorMessage = nil
      return .failed
    case .inactive:
      return .sessionRequired
    case .ready:
      transientErrorMessage = nil
      return .ready
    case .recording:
      transientErrorMessage = nil
      return .recording
    }
  }

  private func hasCompanionTimedOut(status: PlynSharedStore.KeyboardStatus) -> Bool {
    let now = Date().timeIntervalSince1970
    let command = PlynSharedStore.keyboardCommand()
    let commandTimestamp = PlynSharedStore.keyboardCommandTimestamp()?.timeIntervalSince1970 ?? 0
    let statusTimestamp = PlynSharedStore.keyboardStatusTimestamp()?.timeIntervalSince1970 ?? 0
    let transcriptTimestamp = PlynSharedStore.latestTranscriptSnapshot()?.updatedAt.timeIntervalSince1970 ?? 0

    if command != .none, commandTimestamp > statusTimestamp, now - commandTimestamp > commandTimeout {
      return true
    }

    if status == .transcribing {
      let activityTimestamp = max(statusTimestamp, transcriptTimestamp)
      if activityTimestamp > 0, now - activityTimestamp > transcriptionTimeout {
        return true
      }
    }

    if blockedTranscriptSessionID == lastAppliedTranscriptSessionID,
       !blockedTranscriptSessionID.isEmpty,
       status == .transcribing,
       transcriptTimestamp > 0,
       now - transcriptTimestamp > transcriptionTimeout
    {
      return true
    }

    return false
  }

  private func applyPresentationState(_ state: KeyboardPresentationState) {
    var statusText = ""
    var statusColor = supportingInfoColor
    var micSymbol = "mic.fill"
    var micBackground = Self.accentColor
    var micTint = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
    var waveColor = UIColor(red: 0.68, green: 0.7, blue: 0.76, alpha: 0.9)
    var nextWaveAnimationMode: WaveAnimationMode = .idle
    var controlsEnabled = true
    var deleteEnabled = true

    switch state {
    case .ready:
      statusText = "Утрымлівай мікрафон, каб дыктаваць"
    case .recording:
      statusText = "Слухаю... адпусці, каб адправіць"
      statusColor = supportingInfoColor
      micSymbol = "stop.fill"
      micBackground = UIColor(
        red: 206.0 / 255.0,
        green: 81.0 / 255.0,
        blue: 11.0 / 255.0,
        alpha: 1
      )
      micTint = Self.accentColor
      waveColor = Self.accentColor
      nextWaveAnimationMode = .recording
      deleteEnabled = false
    case .processing:
      statusText = "Апрацоўка... чакаю адказу ад праграмы-кампаньёна"
      micSymbol = "hourglass"
      micBackground = UIColor(red: 0.28, green: 0.28, blue: 0.31, alpha: 1)
      micTint = UIColor(white: 0.82, alpha: 1)
      waveColor = UIColor(red: 0.86, green: 0.74, blue: 0.48, alpha: 0.95)
      nextWaveAnimationMode = .processing
      controlsEnabled = false
      deleteEnabled = false
    case .setupRequired:
      statusText = "Дадай API-ключ у праграме-кампаньёне"
      statusColor = supportingInfoColor
      micSymbol = "arrow.up.forward.app"
      micBackground = UIColor(red: 0.96, green: 0.76, blue: 0.48, alpha: 1)
      micTint = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
      waveColor = UIColor(red: 0.96, green: 0.76, blue: 0.48, alpha: 0.9)
      deleteEnabled = true
    case .sessionRequired:
      statusText = "Запусці праграму-кампаньён"
      statusColor = supportingInfoColor
      micSymbol = "bolt.fill"
      micBackground = UIColor(red: 0.96, green: 0.76, blue: 0.48, alpha: 1)
      micTint = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
      waveColor = UIColor(red: 0.96, green: 0.76, blue: 0.48, alpha: 0.9)
    case .companionTimeout:
      statusText = transientErrorMessage ?? "Праграма-кампаньён не адказвае"
      statusColor = supportingInfoColor
      micSymbol = "exclamationmark"
      micBackground = UIColor(red: 0.97, green: 0.52, blue: 0.43, alpha: 1)
      micTint = Self.accentColor
      waveColor = UIColor(red: 0.97, green: 0.52, blue: 0.43, alpha: 0.95)
    case .failed:
      statusText = "Памылка распазнавання. Паспрабуй яшчэ раз"
      statusColor = supportingInfoColor
      micSymbol = "arrow.clockwise"
      micBackground = UIColor(red: 0.97, green: 0.52, blue: 0.43, alpha: 1)
      micTint = Self.accentColor
      waveColor = UIColor(red: 0.97, green: 0.52, blue: 0.43, alpha: 0.95)
    }

    statusLabel.text = statusText
    statusLabel.textColor = statusColor
    micButton.setImage(UIImage(systemName: micSymbol), for: .normal)
    micButton.backgroundColor = micBackground
    micButton.tintColor = micTint

    deleteButton.isEnabled = deleteEnabled
    deleteButton.alpha = deleteEnabled ? 1 : 0.35

    let utilityKeysEnabled = deleteEnabled
    spaceButton.isEnabled = utilityKeysEnabled
    spaceButton.alpha = utilityKeysEnabled ? 1 : 0.35
    enterButton.isEnabled = utilityKeysEnabled
    enterButton.alpha = utilityKeysEnabled ? 1 : 0.35

    micButton.isEnabled = controlsEnabled || isMicButtonPressed
    micButton.alpha = (controlsEnabled || isMicButtonPressed) ? 1 : 0.45

    updateWaveformAppearance(color: waveColor, mode: nextWaveAnimationMode)
  }

  private func updateWaveformAppearance(color: UIColor, mode: WaveAnimationMode) {
    let idleHeights: [CGFloat] = [6, 10, 14, 20, 26, 20, 14, 10, 6]

    for (index, bar) in waveBars.enumerated() {
      bar.backgroundColor = color
      bar.alpha = mode == .idle ? 0.72 : 1
    }

    switch mode {
    case .idle:
      stopWaveAnimation()
      animateWaveHeights(idleHeights)
    case .recording, .processing:
      startWaveAnimation(mode: mode)
      applyAnimatedWaveFrame(mode: mode)
    }
  }

  private func startWaveAnimation(mode: WaveAnimationMode) {
    guard waveAnimationMode != mode || waveAnimationTimer == nil else {
      return
    }

    stopWaveAnimation()
    waveAnimationMode = mode
    waveAnimationStep = 0
    let timer = Timer.scheduledTimer(withTimeInterval: 0.14, repeats: true) { [weak self] _ in
      self?.applyAnimatedWaveFrame(mode: mode)
    }
    RunLoop.main.add(timer, forMode: .common)
    waveAnimationTimer = timer
  }

  private func stopWaveAnimation() {
    waveAnimationTimer?.invalidate()
    waveAnimationTimer = nil
    waveAnimationMode = .idle
    waveAnimationStep = 0
  }

  private func applyAnimatedWaveFrame(mode: WaveAnimationMode) {
    waveAnimationStep += 1

    switch mode {
    case .idle:
      animateWaveHeights([6, 10, 14, 20, 26, 20, 14, 10, 6])
    case .recording:
      let heights = waveBars.indices.map { index -> CGFloat in
        let distanceFromCenter = abs(CGFloat(index) - 4)
        let base = max(12, 42 - distanceFromCenter * 6)
        let oscillation = sin(CGFloat(waveAnimationStep) * 0.9 + CGFloat(index) * 0.8) * 10
        let flutter = cos(CGFloat(waveAnimationStep) * 1.4 + CGFloat(index) * 1.2) * 4
        return max(10, min(48, base + oscillation + flutter))
      }
      animateWaveHeights(heights)
    case .processing:
      let travel = waveAnimationStep % max(1, waveBars.count * 2)
      let heights = waveBars.indices.map { index -> CGFloat in
        let mirroredIndex = travel < waveBars.count ? travel : (waveBars.count * 2 - 1 - travel)
        let distance = abs(index - mirroredIndex)
        switch distance {
        case 0: return 46
        case 1: return 32
        case 2: return 22
        case 3: return 15
        default: return 10
        }
      }
      animateWaveHeights(heights)
    }
  }

  private func animateWaveHeights(_ heights: [CGFloat]) {
    guard heights.count == waveBarHeightConstraints.count else {
      return
    }

    for (constraint, height) in zip(waveBarHeightConstraints, heights) {
      constraint.constant = height
    }

    UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
      self.view.layoutIfNeeded()
    }
  }

  private func startRefreshing() {
    refreshTimer?.invalidate()
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      self?.reloadState()
    }
  }

  private func applyTranscriptSnapshotIfNeeded(sharedKeyboardStatus: PlynSharedStore.KeyboardStatus) {
    guard
      sharedKeyboardStatus == .transcribing || sharedKeyboardStatus == .ready || sharedKeyboardStatus == .failed,
      let snapshot = PlynSharedStore.latestTranscriptSnapshot()
    else {
      return
    }

    if snapshot.sessionID == finalizedTranscriptSessionID,
       snapshot.sequence <= lastAppliedTranscriptSequence
    {
      return
    }

    if snapshot.sessionID != lastAppliedTranscriptSessionID {
      lastAppliedTranscriptSessionID = snapshot.sessionID
      lastAppliedTranscriptSequence = 0
      lastAppliedTranscriptText = ""
      provisionalTranscriptText = ""
      provisionalTranscriptPrefix = ""
      blockedTranscriptSessionID = ""
    }

    guard snapshot.sequence > lastAppliedTranscriptSequence else {
      return
    }

    if blockedTranscriptSessionID == snapshot.sessionID {
      lastAppliedTranscriptSequence = snapshot.sequence
      if snapshot.isFinal, sharedKeyboardStatus == .ready || sharedKeyboardStatus == .failed {
        PlynSharedStore.clearLatestTranscript()
      }
      return
    }

    guard let insertedText = replaceProvisionalTranscript(with: snapshot.text, for: snapshot) else {
      blockedTranscriptSessionID = snapshot.sessionID
      lastAppliedTranscriptSequence = snapshot.sequence
      return
    }

    lastAppliedTranscriptSequence = snapshot.sequence
    lastAppliedTranscriptText = snapshot.text
    transientErrorMessage = nil

    if snapshot.isFinal {
      provisionalTranscriptText = ""
      provisionalTranscriptPrefix = ""
      finalizedTranscriptSessionID = snapshot.sessionID

      if sharedKeyboardStatus == .ready || sharedKeyboardStatus == .failed {
        PlynSharedStore.clearLatestTranscript()
      }
      return
    }

    provisionalTranscriptText = insertedText
  }

  private func replaceProvisionalTranscript(
    with nextText: String,
    for snapshot: PlynSharedStore.TranscriptSnapshot
  ) -> String? {
    if snapshot.state == .empty {
      return provisionalTranscriptText
    }

    let normalizedText = nextText.trimmingCharacters(in: .whitespacesAndNewlines)
    let preparedText: String

    if normalizedText.isEmpty {
      preparedText = ""
    } else if provisionalTranscriptText.isEmpty {
      provisionalTranscriptPrefix = PlynSharedStore.transcriptInsertionPrefix(
        before: textDocumentProxy.documentContextBeforeInput ?? "",
        incoming: normalizedText
      )
      preparedText = provisionalTranscriptPrefix + normalizedText
    } else {
      preparedText = provisionalTranscriptPrefix + normalizedText
    }

    if preparedText == provisionalTranscriptText {
      return preparedText
    }

    if provisionalTranscriptText.isEmpty {
      guard !preparedText.isEmpty else {
        return preparedText
      }

      textDocumentProxy.insertText(preparedText)
      return preparedText
    }

    let context = textDocumentProxy.documentContextBeforeInput ?? ""
    let matchedSuffix = String(provisionalTranscriptText.suffix(context.count))

    guard context.hasSuffix(matchedSuffix) else {
      logDebug(
        "replaceProvisionalTranscript blocked sessionID=\(snapshot.sessionID) sequence=\(snapshot.sequence) contextChars=\(context.count) provisionalChars=\(provisionalTranscriptText.count)"
      )
      return nil
    }

    for _ in 0 ..< provisionalTranscriptText.count {
      textDocumentProxy.deleteBackward()
    }

    if !preparedText.isEmpty {
      textDocumentProxy.insertText(preparedText)
    }

    return preparedText
  }

  @objc
  private func handleNextKeyboard() {
    advanceToNextInputMode()
  }

  @objc
  private func handleMicPressDown() {
    let keyboardStatus = PlynSharedStore.keyboardStatus()
    let timedOut = hasCompanionTimedOut(status: keyboardStatus) || (transientErrorMessage?.isEmpty == false)

    logDebug(
      "handleMicPressDown status=\(keyboardStatus.rawValue) timedOut=\(timedOut) apiKey=\(PlynSharedStore.hasApiKey()) responsiveSession=\(hasResponsiveCompanionSession())"
    )

    if timedOut {
      logDebug("blocked mic press because companion timed out; trying session recovery URL")
      openCompanionApp(
        using: Self.sessionRecoveryURL,
        failureMessage: "Адкрый праграму-кампаньён уручную"
      )
      return
    }

    transientErrorMessage = nil

    guard PlynSharedStore.hasApiKey() else {
      logDebug("blocked mic press because API key is missing; trying companion app root URL")
      openCompanionApp(
        using: Self.companionAppURL,
        failureMessage: "Адкрый праграму-кампаньён уручную і дадай API-ключ"
      )
      return
    }

    guard hasResponsiveCompanionSession() else {
      logDebug("blocked mic press because responsive session is unavailable; trying session recovery URL")
      openCompanionApp(
        using: Self.sessionRecoveryURL,
        failureMessage: "Адкрый праграму-кампаньён уручную і запусці сесію"
      )
      return
    }

    switch keyboardStatus {
    case .recording:
      logDebug("mic press while already recording")
      isMicButtonPressed = true
      pendingStopAfterRecordingStarts = false
    case .transcribing:
      logDebug("mic press ignored while transcribing")
      isMicButtonPressed = false
      pendingStopAfterRecordingStarts = false
    case .inactive, .ready, .failed:
      logDebug("sending startCapture command to companion")
      isMicButtonPressed = true
      pendingStopAfterRecordingStarts = false
      PlynSharedStore.saveKeyboardCommand(.startCapture)
    }

    reloadState()
  }

  @objc
  private func handleMicPressUp() {
    guard PlynSharedStore.hasApiKey(), hasResponsiveCompanionSession() else {
      isMicButtonPressed = false
      pendingStopAfterRecordingStarts = false
      return
    }

    guard isMicButtonPressed else {
      return
    }

    isMicButtonPressed = false

    if PlynSharedStore.keyboardStatus() == .recording {
      pendingStopAfterRecordingStarts = false
      PlynSharedStore.saveKeyboardCommand(.stopCapture)
    } else {
      pendingStopAfterRecordingStarts = true
    }

    reloadState()
  }

  private func openCompanionApp(using url: URL?, failureMessage: String) {
    isMicButtonPressed = false
    pendingStopAfterRecordingStarts = false

    guard let url, let extensionContext else {
      logDebug("openCompanionApp aborted because url/context missing url=\(String(describing: url)) hasContext=\(extensionContext != nil)")
      transientErrorMessage = failureMessage
      reloadState()
      return
    }

    transientErrorMessage = nil
    if openCompanionAppThroughSharedApplication(url) {
      logDebug("sharedApplication launch reported success for url=\(url.absoluteString)")
      return
    }

    if openCompanionAppThroughResponderChain(url) {
      logDebug("primary responder-chain launch reported success for url=\(url.absoluteString)")
      return
    }

    logDebug("trying extensionContext.open for url=\(url.absoluteString)")
    extensionContext.open(url) { [weak self] success in
      guard let self else {
        return
      }

      DispatchQueue.main.async {
        self.logDebug("extensionContext.open completed success=\(success) url=\(url.absoluteString)")

        guard !success else {
          return
        }

        if self.openCompanionAppThroughResponderChain(url) {
          self.logDebug("responder-chain fallback reported success for url=\(url.absoluteString)")
          return
        }

        self.logDebug("all launch paths failed for url=\(url.absoluteString)")
        self.transientErrorMessage = failureMessage
        self.reloadState()
      }
    }
  }

  private func openCompanionAppThroughResponderChain(_ url: URL) -> Bool {
    let selector = sel_registerName("openURL:")
    var responder: UIResponder? = self

    while let currentResponder = responder {
      let responderClassName = NSStringFromClass(type(of: currentResponder))
      logDebug("responder-chain inspecting \(responderClassName)")
      if responderClassName.contains("UIApplication"), currentResponder.responds(to: selector) {
        logDebug("responder-chain invoking openURL: on \(responderClassName) for url=\(url.absoluteString)")
        let success = invokeOpenURL(selector: selector, on: currentResponder, url: url)
        logDebug("responder-chain openURL: returned success=\(success) responder=\(responderClassName)")
        return success
      }

      responder = currentResponder.next
    }

    logDebug("responder-chain did not find UIApplication responder for url=\(url.absoluteString)")
    return false
  }

  private func openCompanionAppThroughSharedApplication(_ url: URL) -> Bool {
    guard let application = sharedApplicationInstance() else {
      logDebug("sharedApplication lookup failed for url=\(url.absoluteString)")
      return false
    }

    if invokeOpenURL(selector: sel_registerName("openURL:"), on: application, url: url) {
      logDebug("sharedApplication openURL: returned success for url=\(url.absoluteString)")
      return true
    }

    let modernSelector = sel_registerName("openURL:options:completionHandler:")
    if application.responds(to: modernSelector) {
      let success = invokeModernOpenURL(selector: modernSelector, on: application, url: url)
      logDebug("sharedApplication openURL:options:completionHandler: returned success=\(success) url=\(url.absoluteString)")
      if success {
        return true
      }
    } else {
      logDebug("sharedApplication missing modern openURL selector for url=\(url.absoluteString)")
    }

    return false
  }

  private func sharedApplicationInstance() -> AnyObject? {
    guard let applicationClass: AnyObject = NSClassFromString("UIApplication") else {
      return nil
    }

    let sharedSelector = sel_registerName("sharedApplication")
    guard applicationClass.responds(to: sharedSelector) else {
      return nil
    }

    return applicationClass.perform(sharedSelector)?.takeUnretainedValue()
  }

  private func invokeOpenURL(selector: Selector, on target: AnyObject, url: URL) -> Bool {
    guard target.responds(to: selector) else {
      return false
    }

    typealias OpenURLFunction = @convention(c) (AnyObject, Selector, URL) -> Bool
    let method = target.method(for: selector)
    let openURL = unsafeBitCast(method, to: OpenURLFunction.self)
    return openURL(target, selector, url)
  }

  private func invokeModernOpenURL(selector: Selector, on target: AnyObject, url: URL) -> Bool {
    typealias CompletionHandler = @convention(block) (Bool) -> Void
    typealias OpenURLFunction = @convention(c) (AnyObject, Selector, URL, NSDictionary, CompletionHandler?) -> Void

    guard target.responds(to: selector) else {
      return false
    }

    var completionResult = false
    let completion: CompletionHandler = { success in
      completionResult = success
    }

    let method = target.method(for: selector)
    let openURL = unsafeBitCast(method, to: OpenURLFunction.self)
    openURL(target, selector, url, [:], completion)
    return completionResult
  }

  @objc
  private func handleDeleteBackward() {
    guard deleteButton.isEnabled else {
      return
    }

    var context = textDocumentProxy.documentContextBeforeInput ?? ""

    guard !context.isEmpty else {
      return
    }

    // At the start of an empty line, collapse only the newline instead of
    // deleting the preceding word as part of the word-erase behavior.
    if context.last?.isNewline == true {
      textDocumentProxy.deleteBackward()
      return
    }

    while let lastCharacter = context.last, lastCharacter.isWhitespace {
      textDocumentProxy.deleteBackward()
      context.removeLast()
    }

    while let lastCharacter = context.last, !lastCharacter.isWhitespace {
      textDocumentProxy.deleteBackward()
      context.removeLast()
    }
  }

  @objc
  private func handleInsertSpace() {
    guard spaceButton.isEnabled else {
      return
    }

    textDocumentProxy.insertText(" ")
  }

  @objc
  private func handleInsertReturn() {
    guard enterButton.isEnabled else {
      return
    }

    textDocumentProxy.insertText("\n")
  }
}
