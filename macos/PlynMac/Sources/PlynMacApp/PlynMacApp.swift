import AppKit
import Combine
import PlynMacCore
import SwiftUI

@main
struct PlynMacApp: App {
  @NSApplicationDelegateAdaptor(PlynMacAppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

@MainActor
final class PlynMacAppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var popover: NSPopover?
  private var coordinator: PlynMacCoordinator?
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    let coordinator = PlynMacCoordinator()
    self.coordinator = coordinator
    PlynMacRemoteRuntimeConfig.refresh(preferences: coordinator.preferences)

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    applyMenuBarState(coordinator.menuBarState, to: statusItem.button)
    statusItem.button?.target = self
    statusItem.button?.action = #selector(togglePopover)
    self.statusItem = statusItem

    coordinator.$menuBarState
      .receive(on: RunLoop.main)
      .sink { [weak self] state in
        self?.applyMenuBarState(state, to: self?.statusItem?.button)
      }
      .store(in: &cancellables)

    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentSize = NSSize(width: 420, height: 640)
    popover.contentViewController = NSHostingController(rootView: PlynMacStatusView(coordinator: coordinator))
    self.popover = popover

    coordinator.startHotKeyMonitor()
    coordinator.requestMissingPermissionsOnLaunch()
  }

  @objc private func togglePopover() {
    guard let button = statusItem?.button, let popover else {
      return
    }

    if popover.isShown {
      popover.performClose(nil)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      coordinator?.refreshPermissions()
    }
  }

  private func applyMenuBarState(_ state: PlynMacMenuBarState, to button: NSStatusBarButton?) {
    guard let button else {
      return
    }

    let title = NSMutableAttributedString(
      string: "● ",
      attributes: [
        .foregroundColor: state.color,
        .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
      ]
    )
    title.append(NSAttributedString(
      string: "Plyń",
      attributes: [
        .foregroundColor: NSColor.labelColor,
        .font: NSFont.menuBarFont(ofSize: 0)
      ]
    ))
    button.attributedTitle = title
    button.toolTip = state.tooltip
  }
}

enum PlynMacMenuBarState: Equatable {
  case setupNeeded
  case ready
  case listening
  case processing
  case error

  var color: NSColor {
    switch self {
    case .setupNeeded:
      return .systemOrange
    case .ready:
      return .systemGreen
    case .listening:
      return .systemRed
    case .processing:
      return .systemBlue
    case .error:
      return .systemRed
    }
  }

  var tooltip: String {
    switch self {
    case .setupNeeded:
      return "Plyń: setup required"
    case .ready:
      return "Plyń: ready"
    case .listening:
      return "Plyń: listening"
    case .processing:
      return "Plyń: processing"
    case .error:
      return "Plyń: error"
    }
  }
}

@MainActor
final class PlynMacCoordinator: ObservableObject {
  @Published var statusMessage = "Гатова да дыктоўкі"
  @Published var apiKeyDraft = ""
  @Published var lastSavedKeyAt: Date?
  @Published var hotKeyStatus = "Клавіша чакае дазволу"
  @Published var latestTranscript = ""
  @Published var menuBarState: PlynMacMenuBarState = .setupNeeded

  let preferences = PlynMacPreferences()
  let permissions = PlynMacPermissionService()
  let tokenUsageStore = PlynMacTokenUsageStore()
  private let controller: PlynMacDictationController
  private var monitor: PlynMacHotKeyMonitor?
  private var statePollTask: Task<Void, Never>?
  private var permissionPollTask: Task<Void, Never>?
  private var showErrorUntil: Date?

  init() {
    controller = PlynMacDictationController(
      audioRecorder: PlynMacAudioRecorder(),
      transcriber: PlynMacGeminiTranscriber(
        configurationProvider: preferences,
        tokenUsageRecorder: tokenUsageStore
      ),
      textInserter: PlynMacPasteboardTextInserter(),
      configuration: preferences,
      permissionChecker: permissions
    )
    statePollTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.syncStateMessage()
        try? await Task.sleep(nanoseconds: 200_000_000)
      }
    }

    permissionPollTask = Task { [weak self] in
      while !Task.isCancelled {
        await MainActor.run {
          self?.permissions.refresh()
          self?.ensureHotKeyMonitorRunning()
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
      }
    }
  }

  deinit {
    statePollTask?.cancel()
    permissionPollTask?.cancel()
  }

  func startHotKeyMonitor() {
    guard monitor == nil else {
      return
    }

    monitor = PlynMacHotKeyMonitor(
      triggerProvider: { [weak preferences] in preferences?.holdTrigger ?? .functionGlobe },
      handler: { [weak self] transition in
        Task { @MainActor in
          switch transition {
          case .started:
            self?.hotKeyStatus = "\(self?.preferences.holdTrigger.title ?? "Клавіша") націснута"
            await self?.controller.handleHoldStarted()
          case .stopped:
            self?.hotKeyStatus = "\(self?.preferences.holdTrigger.title ?? "Клавіша") адпушчана"
            await self?.controller.handleHoldEnded()
          case .unchanged:
            break
          }
        }
      }
    )

    do {
      try monitor?.start()
      hotKeyStatus = "Клавіша гатовая: \(preferences.holdTrigger.title)"
    } catch {
      monitor = nil
      hotKeyStatus = "Клавіша не падключана"
      statusMessage = error.localizedDescription
    }
  }

  func ensureHotKeyMonitorRunning() {
    guard monitor == nil, permissions.snapshot.inputMonitoringGranted else {
      return
    }
    startHotKeyMonitor()
  }

  func saveAPIKey() {
    do {
      try preferences.saveAPIKey(apiKeyDraft)
      apiKeyDraft = ""
      lastSavedKeyAt = Date()
      statusMessage = "Ключ Gemini захаваны"
    } catch {
      statusMessage = error.localizedDescription
    }
  }

  func refreshPermissions() {
    permissions.refresh()
    preferences.refreshSavedKeyState()
  }

  func requestMicrophone() {
    Task {
      await permissions.requestMicrophone()
      if !permissions.snapshot.microphoneGranted {
        permissions.openMicrophoneSettings()
      }
    }
  }

  func requestInputMonitoring() {
    permissions.requestInputMonitoring()
    if !permissions.snapshot.inputMonitoringGranted {
      permissions.openInputMonitoringSettings()
    }
  }

  func requestAccessibility() {
    permissions.requestAccessibility()
    permissions.openAccessibilitySettings()
  }

  func requestMissingPermissionsOnLaunch() {
    Task { @MainActor in
      PlynMacRemoteRuntimeConfig.refresh(preferences: preferences)
      try? await Task.sleep(nanoseconds: 700_000_000)
      permissions.refresh()

      if !permissions.snapshot.microphoneGranted {
        await permissions.requestMicrophone()
      }

      if !permissions.snapshot.inputMonitoringGranted {
        permissions.requestInputMonitoring()
      }

      if !permissions.snapshot.accessibilityGranted {
        permissions.requestAccessibility()
      }

      permissions.refresh()
      ensureHotKeyMonitorRunning()
    }
  }

  private func syncStateMessage() async {
    let state = await controller.state
    switch state {
    case .idle:
      let ready = preferences.isReady && permissions.currentSnapshot().isReady
      statusMessage = ready ? "Гатова да дыктоўкі" : "Завяршыце налады і дазволы"
      if let showErrorUntil, Date() < showErrorUntil {
        menuBarState = .error
      } else {
        showErrorUntil = nil
        menuBarState = ready ? .ready : .setupNeeded
      }
      latestTranscript = await controller.currentTranscript()
    case .recording:
      statusMessage = "Запіс ідзе..."
      showErrorUntil = nil
      menuBarState = .listening
    case .transcribing:
      statusMessage = "Gemini апрацоўвае запіс..."
      showErrorUntil = nil
      menuBarState = .processing
    case .inserting:
      statusMessage = "Устаўляем тэкст..."
      showErrorUntil = nil
      menuBarState = .processing
    case let .failed(message):
      statusMessage = message
      showErrorUntil = Date().addingTimeInterval(3)
      menuBarState = .error
      latestTranscript = await controller.currentTranscript()
      await controller.resetFailure()
    }
  }
}

struct PlynMacStatusView: View {
  @ObservedObject var coordinator: PlynMacCoordinator
  @ObservedObject private var preferences: PlynMacPreferences
  @ObservedObject private var permissions: PlynMacPermissionService
  @ObservedObject private var tokenUsageStore: PlynMacTokenUsageStore
  @State private var costSummaryExpanded = false

  init(coordinator: PlynMacCoordinator) {
    self.coordinator = coordinator
    preferences = coordinator.preferences
    permissions = coordinator.permissions
    tokenUsageStore = coordinator.tokenUsageStore
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
      Text("Plyń для macOS")
        .font(.title2.bold())

      Text(coordinator.statusMessage)
        .font(.callout)
        .foregroundStyle(.secondary)

      Text(Bundle.main.bundlePath)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      GroupBox("Gemini") {
        VStack(alignment: .leading, spacing: 10) {
          Label(
            preferences.hasSavedAPIKey ? "Ключ Gemini захаваны" : "Ключ Gemini яшчэ не захаваны",
            systemImage: preferences.hasSavedAPIKey ? "checkmark.circle.fill" : "exclamationmark.circle"
          )
          .foregroundStyle(preferences.hasSavedAPIKey ? .green : .orange)

          if let lastSavedKeyAt = coordinator.lastSavedKeyAt {
            Text("Захавана: \(lastSavedKeyAt.formatted(date: .omitted, time: .standard))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          SecureField("Ключ API", text: $coordinator.apiKeyDraft)
            .onSubmit {
              coordinator.saveAPIKey()
            }
          Button("Захаваць ключ") {
            coordinator.saveAPIKey()
          }
          .disabled(coordinator.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          Picker("Мадэль", selection: $preferences.model) {
            ForEach(PlynMacGeminiModel.allCases) { model in
              Text(model.title).tag(model.rawValue)
            }
          }
          .pickerStyle(.menu)
        }
        .padding(.vertical, 4)
      }

      CostSummaryView(
        summary: tokenUsageStore.summary,
        rates: PlynMacGeminiModel(rawValue: preferences.model)?.costRates ?? PlynMacGeminiModel.gemini25Flash.costRates,
        expanded: $costSummaryExpanded,
        reset: { tokenUsageStore.reset() }
      )

      GroupBox("Клавіша запісу") {
        VStack(alignment: .leading, spacing: 8) {
          Picker("Клавіша", selection: $preferences.holdTrigger) {
            ForEach(PlynMacHoldTrigger.allCases) { trigger in
              Text(trigger.title).tag(trigger)
            }
          }
          Text(coordinator.hotKeyStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if !coordinator.latestTranscript.isEmpty {
        GroupBox("Апошні тэкст") {
          Text(coordinator.latestTranscript)
            .font(.callout)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      GroupBox("Дазволы") {
        VStack(alignment: .leading, spacing: 8) {
          permissionRow("Мікрафон", granted: permissions.snapshot.microphoneGranted) {
            coordinator.requestMicrophone()
          }
          permissionRow("Input Monitoring", granted: permissions.snapshot.inputMonitoringGranted) {
            coordinator.requestInputMonitoring()
          }
          permissionRow("Accessibility", granted: permissions.snapshot.accessibilityGranted) {
            coordinator.requestAccessibility()
          }
          Button("Абнавіць") {
            coordinator.refreshPermissions()
          }
        }
      }

      HStack {
        Spacer()
        Button("Выйсці") {
          NSApplication.shared.terminate(nil)
        }
      }
      }
    }
    .padding(18)
  }

  private func permissionRow(_ title: String, granted: Bool, action: @escaping () -> Void) -> some View {
    HStack {
      Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
        .foregroundStyle(granted ? .green : .orange)
      Text(title)
      Spacer()
      Button(granted ? "Гатова" : "Дазволіць", action: action)
        .disabled(granted)
    }
  }
}

private struct CostSummaryView: View {
  let summary: PlynMacTokenUsageSummary
  let rates: PlynMacTranscriptionCostRates
  @Binding var expanded: Bool
  let reset: () -> Void

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 10) {
        Button {
          expanded.toggle()
        } label: {
          HStack {
            Text("Кошт транскрыпцыі")
              .font(.headline)
            Spacer()
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)

        Text("Апошні паспяховы запыт, назапашаныя сумы і сярэдняе для гэтага Mac.")
          .font(.caption)
          .foregroundStyle(.secondary)

        if expanded {
          HStack {
            Button("Скінуць", action: reset)
              .disabled(summary.requestCount == 0)
            Spacer()
            Text("токены/$")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          }

          costSection(title: "Апошні запыт", snapshot: summary.lastRequest)
          costSection(title: "Усяго", snapshot: summary.totalSnapshot)
          costSection(title: "Сярэдняе на запыт", snapshot: summary.average)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func costSection(title: String, snapshot: PlynMacTokenUsageSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text("IN")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      costRow("Text", tokens: snapshot.inputByModality.text, rate: rates.inputText)
      costRow("Audio", tokens: snapshot.inputByModality.audio, rate: rates.inputAudio)
      costRow("Cached text", tokens: snapshot.cachedInputByModality.text, rate: rates.inputCacheText)
      costRow("Cached audio", tokens: snapshot.cachedInputByModality.audio, rate: rates.inputCacheAudio)
      Text("OUT")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      costRow("Text", tokens: snapshot.outputByModality.text, rate: rates.outputText)
    }
    .padding(.top, 4)
  }

  private func costRow(_ label: String, tokens: Int, rate: Double) -> some View {
    HStack {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Text(formatTokenCost(tokens: tokens, rate: rate))
        .font(.caption.monospacedDigit())
    }
  }

  private func formatTokenCost(tokens: Int, rate: Double) -> String {
    let cost = (Double(tokens) / 1_000_000) * rate
    return "\(tokens) / \(String(format: "%.4f", cost))$"
  }
}

private extension PlynMacTokenUsageSummary {
  var totalSnapshot: PlynMacTokenUsageSnapshot {
    PlynMacTokenUsageSnapshot(
      inputTokens: inputTokens,
      cachedInputTokens: cachedInputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      inputByModality: inputByModality,
      cachedInputByModality: cachedInputByModality,
      outputByModality: outputByModality
    )
  }
}
