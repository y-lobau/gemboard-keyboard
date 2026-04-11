package com.holas.plynkeyboard

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputConnection
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView
import androidx.annotation.DrawableRes
import androidx.core.content.ContextCompat
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class PlyńInputMethodService : InputMethodService() {
  private enum class KeyboardUiState {
    READY,
    RECORDING,
    PROCESSING,
  }

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
  private var deleteButton: Button? = null
  private var spaceButton: Button? = null
  private var enterButton: Button? = null
  private var deleteRepeatController: HoldRepeatController? = null
  private var activeTranscriptionSession: ActiveTranscriptionSession? = null

  override fun onCreateInputView(): View {
    val root = layoutInflater.inflate(R.layout.keyboard_view, null)
    statusView = root.findViewById(R.id.statusText)

    speechButton = root.findViewById(R.id.speechButton)
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

    updateStatus(getString(R.string.Plyń_hold_to_talk))
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
    recorder?.stop()
    executor.shutdownNow()
    super.onDestroy()
  }

  override fun onFinishInput() {
    deleteRepeatController?.stop()
    activeTranscriptionSession = null
    applyKeyboardUiState(KeyboardUiState.READY)
    super.onFinishInput()
  }

  private fun startRecording() {
    if (recorder != null || activeTranscriptionSession != null) {
      updateStatus(getString(R.string.Plyń_transcribing))
      applyKeyboardUiState(KeyboardUiState.PROCESSING)
      return
    }

    val apiKey = PlynPreferences.getSharedPreferences(this).getString(PlynPreferences.API_KEY, null)

    if (apiKey.isNullOrBlank()) {
      updateStatus(getString(R.string.Plyń_missing_key))
      applyKeyboardUiState(KeyboardUiState.READY)
      openCompanionAppForSetup()
      PlyńAnalytics.trackEvent(
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
      updateStatus(getString(R.string.Plyń_missing_permission))
      applyKeyboardUiState(KeyboardUiState.READY)
      openCompanionAppForSetup()
      PlyńAnalytics.trackEvent(
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

      val outputFile = File(cacheDir, "Plyń-live.wav")
      recorder = WavAudioRecorder(outputFile).also { it.start() }
      updateStatus(getString(R.string.Plyń_listening))
      applyKeyboardUiState(KeyboardUiState.RECORDING)
      PlyńAnalytics.trackEvent(
        this,
        "dictation_start",
        mapOf(
          "platform" to "android",
          "entry_point" to "android_keyboard",
          "session_active" to "true",
        ),
      )
    } catch (error: Exception) {
      updateStatus(error.message ?: getString(R.string.Plyń_generic_error))
      applyKeyboardUiState(KeyboardUiState.READY)
      PlyńAnalytics.trackEvent(
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

    updateStatus(getString(R.string.Plyń_transcribing))
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
          ?: throw IllegalStateException(getString(R.string.Plyń_missing_key))
        val transcript = transcriptionClient.transcribeStream(this, apiKey, audioFile) { snapshot ->
          mainHandler.post {
            applyTranscriptSnapshot(utteranceId, snapshot)
          }
        }
        val latencyMs = (System.currentTimeMillis() - startedAt).coerceAtLeast(0)
        val outputChars = transcript.length
        val outputSizeBucket = PlyńAnalytics.outputSizeBucket(outputChars)
        val latencyBucket = PlyńAnalytics.latencyBucket(latencyMs)

        PlyńAnalytics.trackEvent(
          this,
          "dictation_complete",
          mapOf(
            "platform" to "android",
            "entry_point" to "android_keyboard",
            "result" to if (transcript.isBlank()) "empty" else "success",
            "output_size_bucket" to outputSizeBucket,
          ),
        )
        PlyńAnalytics.trackEvent(
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
        PlyńAnalytics.trackEvent(
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
        val latencyBucket = PlyńAnalytics.latencyBucket(latencyMs)

        PlyńAnalytics.trackEvent(
          this,
          "dictation_complete",
          mapOf(
            "platform" to "android",
            "entry_point" to "android_keyboard",
            "result" to "error",
            "output_size_bucket" to "0",
          ),
        )
        PlyńAnalytics.trackEvent(
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
        PlyńAnalytics.trackEvent(
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
      if (renderedText.isBlank()) getString(R.string.Plyń_transcribing)
      else getString(R.string.Plyń_streaming)
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
      updateStatus(getString(R.string.Plyń_inserted))
    } else if (!session.hasInsertedSnapshot && transcript.isBlank()) {
      updateStatus(getString(R.string.Plyń_no_speech))
    } else if (session.hasInsertedSnapshot) {
      session.inputConnection?.finishComposingText()
      updateStatus(getString(R.string.Plyń_inserted))
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
    updateStatus(error.message ?: getString(R.string.Plyń_generic_error))
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
    val controlsEnabled = state == KeyboardUiState.READY
    if (!controlsEnabled) {
      deleteRepeatController?.stop()
    }

    speechButton?.isEnabled = state != KeyboardUiState.PROCESSING
    deleteButton?.isEnabled = controlsEnabled
    spaceButton?.isEnabled = controlsEnabled
    enterButton?.isEnabled = controlsEnabled

    deleteButton?.alpha = if (controlsEnabled) 1f else 0.55f
    spaceButton?.alpha = if (controlsEnabled) 1f else 0.55f
    enterButton?.alpha = if (controlsEnabled) 1f else 0.55f

    when (state) {
      KeyboardUiState.READY -> configureMicButton(
        backgroundRes = R.drawable.keyboard_mic_button_background,
        tintColor = android.graphics.Color.parseColor("#141519"),
        iconRes = android.R.drawable.ic_btn_speak_now,
      )
      KeyboardUiState.RECORDING -> configureMicButton(
        backgroundRes = R.drawable.keyboard_mic_button_recording_background,
        tintColor = android.graphics.Color.parseColor("#E2D9D2"),
        iconRes = android.R.drawable.ic_media_pause,
      )
      KeyboardUiState.PROCESSING -> configureMicButton(
        backgroundRes = R.drawable.keyboard_mic_button_processing_background,
        tintColor = android.graphics.Color.parseColor("#D1D1D4"),
        iconRes = android.R.drawable.ic_popup_sync,
      )
    }
  }

  private fun configureMicButton(
    @DrawableRes backgroundRes: Int,
    tintColor: Int,
    @DrawableRes iconRes: Int,
  ) {
    speechButton?.setBackgroundResource(backgroundRes)
    speechButton?.setImageResource(iconRes)
    speechButton?.setColorFilter(tintColor)
    speechButton?.alpha = if (speechButton?.isEnabled == true) 1f else 0.7f
  }
}
