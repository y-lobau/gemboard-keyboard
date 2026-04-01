package com.yanlobau.gemboardkeyboard

import android.Manifest
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.Executors

class GemboardInputMethodService : InputMethodService() {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val executor = Executors.newSingleThreadExecutor()
  private val transcriptionClient = GeminiTranscriptionClient()

  private var recorder: WavAudioRecorder? = null
  private var statusView: TextView? = null

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

    updateStatus(getString(R.string.gemboard_hold_to_talk))
    return root
  }

  override fun onDestroy() {
    recorder?.stop()
    executor.shutdownNow()
    super.onDestroy()
  }

  private fun startRecording() {
    val apiKey = GemboardPreferences.getSharedPreferences(this).getString(GemboardPreferences.API_KEY, null)

    if (apiKey.isNullOrBlank()) {
      updateStatus(getString(R.string.gemboard_missing_key))
      return
    }

    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      updateStatus(getString(R.string.gemboard_missing_permission))
      return
    }

    try {
      val outputFile = File(cacheDir, "gemboard-live.wav")
      recorder = WavAudioRecorder(outputFile).also { it.start() }
      updateStatus(getString(R.string.gemboard_listening))
    } catch (error: Exception) {
      updateStatus(error.message ?: getString(R.string.gemboard_generic_error))
    }
  }

  private fun stopRecordingAndTranscribe() {
    val activeRecorder = recorder ?: return
    recorder = null

    updateStatus(getString(R.string.gemboard_transcribing))

    executor.execute {
      try {
        val audioFile = activeRecorder.stop()
        val apiKey = GemboardPreferences.getSharedPreferences(this).getString(GemboardPreferences.API_KEY, null)
          ?: throw IllegalStateException(getString(R.string.gemboard_missing_key))
        val transcript = transcriptionClient.transcribe(apiKey, audioFile)

        mainHandler.post {
          if (transcript.isBlank()) {
            updateStatus(getString(R.string.gemboard_no_speech))
          } else {
            currentInputConnection?.commitText(transcript, 1)
            updateStatus(getString(R.string.gemboard_inserted))
          }
        }
      } catch (error: Exception) {
        mainHandler.post {
          updateStatus(error.message ?: getString(R.string.gemboard_generic_error))
        }
      }
    }
  }

  private fun updateStatus(message: String) {
    statusView?.text = message
  }
}
