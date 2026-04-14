package com.holas.plynkeyboard

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import java.io.File
import java.util.concurrent.Executors

class PlynSpeechModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private val executor = Executors.newSingleThreadExecutor()
  private val transcriptionClient = GeminiTranscriptionClient()
  private var recorder: WavAudioRecorder? = null

  override fun getName(): String = "GemboardSpeech"

  @ReactMethod
  fun startRecording(promise: Promise) {
    try {
      if (recorder != null) {
        promise.resolve(null)
        return
      }

      val outputFile = File(reactContext.cacheDir, "Plyn-app.wav")
      recorder = WavAudioRecorder(outputFile).also { it.start() }
      promise.resolve(null)
    } catch (error: Exception) {
      promise.reject("recording_error", error.message, error)
    }
  }

  @ReactMethod
  fun stopRecording(promise: Promise) {
    val activeRecorder = recorder
    recorder = null

    if (activeRecorder == null) {
      promise.resolve("")
      return
    }

    executor.execute {
      try {
        val outputFile = activeRecorder.stop()
        val apiKey = PlynPreferences.getSharedPreferences(reactContext).getString(PlynPreferences.API_KEY, null)
          ?: throw IllegalStateException("Save your Gemini API key before recording.")
        val result = transcriptionClient.transcribeStream(reactContext, apiKey, outputFile) { _ -> }
        PlynTokenUsageStore.add(reactContext, result.usageSummary)
        promise.resolve(result.transcript)
      } catch (error: Exception) {
        promise.reject("transcription_error", error.message, error)
      }
    }
  }

  @ReactMethod
  fun getAudioLevel(promise: Promise) {
    promise.resolve(recorder?.getLevel()?.toDouble() ?: 0.0)
  }

  override fun invalidate() {
    recorder?.stop()
    recorder = null
    executor.shutdownNow()
    super.invalidate()
  }
}
