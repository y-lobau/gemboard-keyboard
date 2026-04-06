package com.holas.plynkeyboard

import android.Manifest
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputConnection
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class PlyńInputMethodService : InputMethodService() {
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
  private var activeTranscriptionSession: ActiveTranscriptionSession? = null

  override fun onCreateInputView(): View {
    val root = layoutInflater.inflate(R.layout.keyboard_view, null)
    statusView = root.findViewById(R.id.statusText)

    val speechButton = root.findViewById<Button>(R.id.speechButton)
    val spaceButton = root.findViewById<Button>(R.id.spaceButton)
    val deleteButton = root.findViewById<Button>(R.id.deleteButton)

    speechButton.setOnTouchListener { _, event ->
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

    spaceButton.setOnClickListener {
      currentInputConnection?.commitText(" ", 1)
    }

    deleteButton.setOnClickListener {
      currentInputConnection?.deleteSurroundingText(1, 0)
    }

    updateStatus(getString(R.string.Plyń_hold_to_talk))
    return root
  }

  override fun onStartInputView(attribute: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
    super.onStartInputView(attribute, restarting)

    executor.execute {
      FirebaseRemoteRuntimeConfig.refresh(this)
    }
  }

  override fun onDestroy() {
    recorder?.stop()
    executor.shutdownNow()
    super.onDestroy()
  }

  override fun onFinishInput() {
    activeTranscriptionSession = null
    super.onFinishInput()
  }

  private fun startRecording() {
    if (recorder != null || activeTranscriptionSession != null) {
      updateStatus(getString(R.string.Plyń_transcribing))
      return
    }

    val apiKey = PlyńPreferences.getSharedPreferences(this).getString(PlyńPreferences.API_KEY, null)

    if (apiKey.isNullOrBlank()) {
      updateStatus(getString(R.string.Plyń_missing_key))
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
        val apiKey = PlyńPreferences.getSharedPreferences(this).getString(PlyńPreferences.API_KEY, null)
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

  private fun updateStatus(message: String) {
    statusView?.text = message
  }
}
