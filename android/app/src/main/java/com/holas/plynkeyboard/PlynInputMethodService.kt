package com.holas.plynkeyboard

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.inputmethodservice.InputMethodService
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputConnection
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class PlynInputMethodService : InputMethodService() {
  private data class ActiveTranscriptionSession(
    val utteranceId: String,
    val inputConnection: InputConnection?,
    var hasInsertedSnapshot: Boolean = false,
    var lastSnapshotText: String = "",
    var insertionPrefix: String = "",
  )

  private val mainHandler = Handler(Looper.getMainLooper())
  private val executor = Executors.newSingleThreadExecutor()
  private val transcriptionClient = GeminiTranscriptionClient()

  private var recorder: WavAudioRecorder? = null
  private var statusView: TextView? = null
  private var speechButton: ImageButton? = null
  private var waveContainer: LinearLayout? = null
  private var waveBars: List<View> = emptyList()
  private var deleteButton: ImageButton? = null
  private var spaceButton: ImageButton? = null
  private var enterButton: ImageButton? = null
  private var deleteRepeatController: HoldRepeatController? = null
  private var activeTranscriptionSession: ActiveTranscriptionSession? = null
  private var animatedWaveState: KeyboardUiState? = null
  private var waveAnimationStep = 0
  private var smoothedRecordingLevel = 0f
  private val waveAnimationRunnable = object : Runnable {
    override fun run() {
      renderWaveFrame()
      mainHandler.postDelayed(this, WAVE_FRAME_DELAY_MS)
    }
  }

  override fun onCreateInputView(): View {
    val root = layoutInflater.inflate(R.layout.keyboard_view, null)
    statusView = root.findViewById(R.id.statusText)

    speechButton = root.findViewById(R.id.speechButton)
    waveContainer = root.findViewById(R.id.waveContainer)
    waveBars = waveContainer?.children().orEmpty()
    spaceButton = root.findViewById(R.id.spaceButton)
    deleteButton = root.findViewById(R.id.deleteButton)
    enterButton = root.findViewById(R.id.enterButton)

    deleteRepeatController = HoldRepeatController(
      postDelayed = { runnable, delayMs -> mainHandler.postDelayed(runnable, delayMs) },
      removeCallbacks = { runnable -> mainHandler.removeCallbacks(runnable) },
      action = { performDeleteBackward() },
    )

    speechButton?.setOnTouchListener { _, event ->
      when (event.action) {
        MotionEvent.ACTION_DOWN -> {
          startRecording()
          true
        }
        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
          stopRecordingAndTranscribe()
          true
        }
        else -> false
      }
    }

    spaceButton?.setOnClickListener {
      currentInputConnection?.commitText(" ", 1)
    }

    deleteButton?.setOnTouchListener { _, event ->
      when (event.actionMasked) {
        MotionEvent.ACTION_DOWN -> {
          deleteRepeatController?.start()
          true
        }
        MotionEvent.ACTION_UP,
        MotionEvent.ACTION_CANCEL,
        MotionEvent.ACTION_OUTSIDE,
        MotionEvent.ACTION_POINTER_UP -> {
          deleteRepeatController?.stop()
          true
        }
        else -> false
      }
    }

    enterButton?.setOnClickListener {
      currentInputConnection?.commitText("\n", 1)
    }

    updateStatus(getString(R.string.plyn_hold_to_talk))
    applyKeyboardUiState(KeyboardUiState.READY)
    return root
  }

  override fun onStartInputView(attribute: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
    super.onStartInputView(attribute, restarting)

    executor.execute {
      FirebaseRemoteRuntimeConfig.refresh(this)
    }
  }

  override fun onDestroy() {
    deleteRepeatController?.stop()
    stopWaveAnimation()
    recorder?.stop()
    executor.shutdownNow()
    super.onDestroy()
  }

  override fun onFinishInput() {
    deleteRepeatController?.stop()
    activeTranscriptionSession = null
    stopWaveAnimation()
    applyKeyboardUiState(KeyboardUiState.READY)
    super.onFinishInput()
  }

  private fun startRecording() {
    if (recorder != null || activeTranscriptionSession != null) {
      updateStatus(getString(R.string.plyn_transcribing))
      applyKeyboardUiState(KeyboardUiState.PROCESSING)
      return
    }

    val apiKey = PlynPreferences.getSharedPreferences(this).getString(PlynPreferences.API_KEY, null)

    if (apiKey.isNullOrBlank()) {
      updateStatus(getString(R.string.plyn_missing_key))
      applyKeyboardUiState(KeyboardUiState.READY)
      openCompanionAppForSetup()
      PlynAnalytics.trackEvent(
        this,
        "dictation_blocked",
        mapOf(
          "platform" to "android",
          "entry_point" to "android_keyboard",
          "reason" to "missing_api_key",
        ),
      )
      return
    }

    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      updateStatus(getString(R.string.plyn_missing_permission))
      applyKeyboardUiState(KeyboardUiState.READY)
      openCompanionAppForSetup()
      PlynAnalytics.trackEvent(
        this,
        "dictation_blocked",
        mapOf(
          "platform" to "android",
          "entry_point" to "android_keyboard",
          "reason" to "missing_microphone_permission",
        ),
      )
      return
    }

    try {
      executor.execute {
        FirebaseRemoteRuntimeConfig.refresh(this)
      }

      val outputFile = File(cacheDir, "Plyn-live.wav")
      recorder = WavAudioRecorder(outputFile).also { it.start() }
      updateStatus(getString(R.string.plyn_listening))
      applyKeyboardUiState(KeyboardUiState.RECORDING)
      PlynAnalytics.trackEvent(
        this,
        "dictation_start",
        mapOf(
          "platform" to "android",
          "entry_point" to "android_keyboard",
          "session_active" to "true",
        ),
      )
    } catch (error: Exception) {
      updateStatus(error.message ?: getString(R.string.plyn_generic_error))
      applyKeyboardUiState(KeyboardUiState.READY)
      PlynAnalytics.trackEvent(
        this,
        "dictation_complete",
        mapOf(
          "platform" to "android",
          "entry_point" to "android_keyboard",
          "result" to "error",
          "output_size_bucket" to "0",
        ),
      )
    }
  }

  private fun stopRecordingAndTranscribe() {
    val activeRecorder = recorder ?: return
    recorder = null

    updateStatus(getString(R.string.plyn_transcribing))
    applyKeyboardUiState(KeyboardUiState.PROCESSING)

    val utteranceId = UUID.randomUUID().toString()
    val inputConnection = currentInputConnection
    activeTranscriptionSession = ActiveTranscriptionSession(
      utteranceId = utteranceId,
      inputConnection = inputConnection,
    )

    executor.execute {
      val startedAt = System.currentTimeMillis()

      try {
        val audioFile = activeRecorder.stop()
        // Refresh runtime config on the transcription worker so this utterance
        // uses the latest activated Firebase model when it is available.
        FirebaseRemoteRuntimeConfig.refresh(this)
        val apiKey = PlynPreferences.getSharedPreferences(this).getString(PlynPreferences.API_KEY, null)
          ?: throw IllegalStateException(getString(R.string.plyn_missing_key))
        val result = transcriptionClient.transcribeStream(this, apiKey, audioFile) { snapshot ->
          mainHandler.post {
            applyTranscriptSnapshot(utteranceId, snapshot)
          }
        }
        PlynTokenUsageStore.add(this, result.usageSummary)
        val transcript = result.transcript
        val latencyMs = (System.currentTimeMillis() - startedAt).coerceAtLeast(0)
        val outputChars = transcript.length
        val outputSizeBucket = PlynAnalytics.outputSizeBucket(outputChars)
        val latencyBucket = PlynAnalytics.latencyBucket(latencyMs)

        PlynAnalytics.trackEvent(
          this,
          "dictation_complete",
          mapOf(
            "platform" to "android",
            "entry_point" to "android_keyboard",
            "result" to if (transcript.isBlank()) "empty" else "success",
            "output_size_bucket" to outputSizeBucket,
          ),
        )
        PlynAnalytics.trackEvent(
          this,
          "gemini_transcription_latency",
          mapOf(
            "platform" to "android",
            "entry_point" to "android_keyboard",
            "latency_ms" to latencyMs,
            "latency_bucket" to latencyBucket,
            "result" to if (transcript.isBlank()) "empty" else "success",
            "output_chars" to outputChars,
            "output_size_bucket" to outputSizeBucket,
          ),
        )
        PlynAnalytics.trackEvent(
          this,
          "gemini_transcription_size_latency",
          mapOf(
            "platform" to "android",
            "entry_point" to "android_keyboard",
            "latency_bucket" to latencyBucket,
            "output_size_bucket" to outputSizeBucket,
            "result" to if (transcript.isBlank()) "empty" else "success",
          ),
        )

        mainHandler.post {
          finalizeCompletedSession(utteranceId, transcript)
        }
      } catch (error: Exception) {
        val latencyMs = (System.currentTimeMillis() - startedAt).coerceAtLeast(0)
        val latencyBucket = PlynAnalytics.latencyBucket(latencyMs)

        PlynAnalytics.trackEvent(
          this,
          "dictation_complete",
          mapOf(
            "platform" to "android",
            "entry_point" to "android_keyboard",
            "result" to "error",
            "output_size_bucket" to "0",
          ),
        )
        PlynAnalytics.trackEvent(
          this,
          "gemini_transcription_latency",
          mapOf(
            "platform" to "android",
            "entry_point" to "android_keyboard",
            "latency_ms" to latencyMs,
            "latency_bucket" to latencyBucket,
            "result" to "error",
            "output_chars" to 0,
            "output_size_bucket" to "0",
          ),
        )
        PlynAnalytics.trackEvent(
          this,
          "gemini_transcription_size_latency",
          mapOf(
            "platform" to "android",
            "entry_point" to "android_keyboard",
            "latency_bucket" to latencyBucket,
            "output_size_bucket" to "0",
            "result" to "error",
          ),
        )

        mainHandler.post {
          handleTranscriptionFailure(utteranceId, error)
        }
      }
    }
  }

  private fun applyTranscriptSnapshot(
    utteranceId: String,
    snapshot: GeminiTranscriptionClient.TranscriptSnapshot,
  ) {
    val session = activeTranscriptionSession ?: return
    if (session.utteranceId != utteranceId) {
      return
    }

    val currentConnection = currentInputConnection
    if (session.inputConnection == null || session.inputConnection !== currentConnection) {
      activeTranscriptionSession = null
      return
    }

    val renderedText = renderedTranscriptText(session, snapshot.text)

    if (renderedText == session.lastSnapshotText) {
      return
    }

    if (snapshot.isFinal) {
      return
    }

    session.inputConnection.setComposingText(renderedText, 1)
    session.hasInsertedSnapshot = renderedText.isNotBlank()
    session.lastSnapshotText = renderedText
    updateStatus(
      if (renderedText.isBlank()) getString(R.string.plyn_transcribing)
      else getString(R.string.plyn_streaming)
    )
    applyKeyboardUiState(KeyboardUiState.PROCESSING)
  }

  private fun finalizeCompletedSession(utteranceId: String, transcript: String) {
    val session = activeTranscriptionSession
    if (session?.utteranceId != utteranceId) {
      return
    }

    val connection = session.inputConnection
    val renderedText = renderedTranscriptText(session, transcript)
    if (connection != null && connection === currentInputConnection && renderedText.isNotBlank()) {
      connection.setComposingText(renderedText, 1)
      connection.finishComposingText()
      session.hasInsertedSnapshot = true
      session.lastSnapshotText = renderedText
      updateStatus(getString(R.string.plyn_inserted))
    } else if (!session.hasInsertedSnapshot && transcript.isBlank()) {
      updateStatus(getString(R.string.plyn_no_speech))
    } else if (session.hasInsertedSnapshot) {
      session.inputConnection?.finishComposingText()
      updateStatus(getString(R.string.plyn_inserted))
    }

    activeTranscriptionSession = null
    applyKeyboardUiState(KeyboardUiState.READY)
  }

  private fun handleTranscriptionFailure(utteranceId: String, error: Exception) {
    val session = activeTranscriptionSession
    if (session?.utteranceId != utteranceId) {
      return
    }

    if (session.hasInsertedSnapshot && session.inputConnection === currentInputConnection) {
      session.inputConnection?.finishComposingText()
    }

    activeTranscriptionSession = null
    updateStatus(error.message ?: getString(R.string.plyn_generic_error))
    applyKeyboardUiState(KeyboardUiState.READY)
  }

  private fun renderedTranscriptText(
    session: ActiveTranscriptionSession,
    transcript: String,
  ): String {
    val normalizedTranscript = transcript.trim()
    if (normalizedTranscript.isEmpty()) {
      return ""
    }

    if (session.insertionPrefix.isEmpty()) {
      val contextBeforeCursor = session.inputConnection
        ?.getTextBeforeCursor(256, 0)
        ?.toString()
      session.insertionPrefix = TranscriptTextFormatter.insertionPrefix(
        contextBeforeCursor,
        normalizedTranscript,
      )
    }

    return session.insertionPrefix + normalizedTranscript
  }

  private fun openCompanionAppForSetup() {
    val setupIntent =
      Intent(Intent.ACTION_VIEW, Uri.parse("plyn://session"))
        .setPackage(packageName)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)

    val launchIntent =
      packageManager.getLaunchIntentForPackage(packageName)
        ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)

    try {
      startActivity(setupIntent)
    } catch (_: Exception) {
      launchIntent?.let { startActivity(it) }
    }
  }

  private fun updateStatus(message: String) {
    statusView?.text = message
  }

  private fun performDeleteBackward() {
    if (deleteButton?.isEnabled != true) {
      return
    }

    currentInputConnection?.deleteSurroundingText(1, 0)
  }

  private fun applyKeyboardUiState(state: KeyboardUiState) {
    val presentation = KeyboardUiPresentation.forState(state)
    if (!presentation.deleteEnabled) {
      deleteRepeatController?.stop()
    }

    speechButton?.isEnabled = state != KeyboardUiState.PROCESSING
    deleteButton?.isEnabled = presentation.deleteEnabled
    spaceButton?.isEnabled = presentation.deleteEnabled
    enterButton?.isEnabled = presentation.deleteEnabled

    deleteButton?.alpha = if (presentation.deleteEnabled) 1f else 0.35f
    spaceButton?.alpha = if (presentation.deleteEnabled) 1f else 0.35f
    enterButton?.alpha = if (presentation.deleteEnabled) 1f else 0.35f
    statusView?.setTextColor(Color.parseColor(presentation.statusColor))

    configureMicButton(presentation)
    updateWaveAppearance(presentation.waveColor)

    when (state) {
      KeyboardUiState.READY -> stopWaveAnimation()
      KeyboardUiState.RECORDING, KeyboardUiState.PROCESSING -> startWaveAnimation(state)
    }
  }

  private fun configureMicButton(presentation: KeyboardUiPresentation) {
    speechButton?.setBackgroundResource(
      when (presentation.micIcon) {
        KeyboardMicIcon.MICROPHONE -> R.drawable.keyboard_mic_button_background
        KeyboardMicIcon.STOP -> R.drawable.keyboard_mic_button_recording_background
        KeyboardMicIcon.HOURGLASS -> R.drawable.keyboard_mic_button_processing_background
      },
    )
    speechButton?.setImageResource(presentation.micIcon.drawableRes)
    speechButton?.setColorFilter(Color.parseColor(presentation.micTintColor))
    speechButton?.alpha = if (speechButton?.isEnabled == true) 1f else 0.45f
  }

  private fun updateWaveAppearance(colorHex: String) {
    val color = Color.parseColor(colorHex)
    waveBars.forEach { bar ->
      bar.background?.mutate()?.setTint(color)
      bar.alpha = if (colorHex == "#E6ADB3C2") 0.72f else 1f
    }
  }

  private fun startWaveAnimation(state: KeyboardUiState) {
    if (animatedWaveState == state) {
      return
    }

    animatedWaveState = state
    mainHandler.removeCallbacks(waveAnimationRunnable)
    waveAnimationStep = 0
    renderWaveFrame()
    mainHandler.postDelayed(waveAnimationRunnable, WAVE_FRAME_DELAY_MS)
  }

  private fun stopWaveAnimation() {
    mainHandler.removeCallbacks(waveAnimationRunnable)
    animatedWaveState = null
    smoothedRecordingLevel = 0f
    waveAnimationStep = 0
    applyWaveHeights(KeyboardWaveAnimator.idleHeights)
  }

  private fun renderWaveFrame() {
    waveAnimationStep += 1
    val heights = when {
      recorder != null -> {
        val liveLevel = recorder?.getLevel() ?: 0f
        smoothedRecordingLevel = if (smoothedRecordingLevel == 0f) liveLevel else (smoothedRecordingLevel * 0.65f + liveLevel * 0.35f)
        KeyboardWaveAnimator.recordingHeights(waveAnimationStep, smoothedRecordingLevel)
      }
      activeTranscriptionSession != null -> KeyboardWaveAnimator.processingHeights(waveAnimationStep)
      else -> KeyboardWaveAnimator.idleHeights
    }

    applyWaveHeights(heights)
  }

  private fun applyWaveHeights(heights: List<Int>) {
    if (heights.size != waveBars.size) {
      return
    }

    heights.zip(waveBars).forEach { (heightDp, bar) ->
      val layoutParams = bar.layoutParams
      layoutParams.height = dpToPx(heightDp)
      bar.layoutParams = layoutParams
    }
  }

  private fun LinearLayout.children(): List<View> =
    (0 until childCount).map { getChildAt(it) }

  private fun dpToPx(valueDp: Int): Int =
    (valueDp * resources.displayMetrics.density + 0.5f).toInt()

  companion object {
    private const val WAVE_FRAME_DELAY_MS = 140L
  }
}
