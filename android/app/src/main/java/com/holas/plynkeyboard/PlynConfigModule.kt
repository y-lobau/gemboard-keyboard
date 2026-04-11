package com.holas.plynkeyboard

import android.content.Context
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableNativeMap

class PlynConfigModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "PlyńConfig"

  @ReactMethod
  fun getStatus(promise: Promise) {
    val prefs = PlynPreferences.getSharedPreferences(reactContext)
    val map = WritableNativeMap()
    map.putBoolean("hasApiKey", !prefs.getString(PlynPreferences.API_KEY, null).isNullOrBlank())
    map.putString("platformMode", "android-ime")
    promise.resolve(map)
  }

  @ReactMethod
  fun saveApiKey(apiKey: String, promise: Promise) {
    PlynPreferences.getSharedPreferences(reactContext)
      .edit()
      .putString(PlynPreferences.API_KEY, apiKey.trim())
      .apply()
    promise.resolve(null)
  }

  @ReactMethod
  fun saveRuntimeConfig(config: ReadableMap, promise: Promise) {
    val model = config.getString("model")?.trim().orEmpty()
    val systemPrompt = config.getString("systemPrompt")?.trim().orEmpty()
    val keyboardCommandTimeout =
      if (config.hasKey("keyboardCommandTimeout") && !config.isNull("keyboardCommandTimeout")) {
        config.getDouble("keyboardCommandTimeout")
      } else {
        null
      }
    val keyboardTranscriptionTimeout =
      if (
        config.hasKey("keyboardTranscriptionTimeout") &&
        !config.isNull("keyboardTranscriptionTimeout")
      ) {
        config.getDouble("keyboardTranscriptionTimeout")
      } else {
        null
      }

    val editor = PlynPreferences.getSharedPreferences(reactContext).edit()
      .putString(PlynPreferences.RUNTIME_MODEL, model)
      .putString(PlynPreferences.RUNTIME_SYSTEM_PROMPT, systemPrompt)

    if (keyboardCommandTimeout != null) {
      editor.putLong(PlynPreferences.KEYBOARD_COMMAND_TIMEOUT_MS, (keyboardCommandTimeout * 1000).toLong())
    }

    if (keyboardTranscriptionTimeout != null) {
      editor.putLong(
        PlynPreferences.KEYBOARD_TRANSCRIPTION_TIMEOUT_MS,
        (keyboardTranscriptionTimeout * 1000).toLong(),
      )
    }

    editor.apply()
    promise.resolve(null)
  }
}

object PlynPreferences {
  private const val STORE = "Plyn_preferences"
  const val API_KEY = "gemini_api_key"
  const val RUNTIME_MODEL = "gemini_runtime_model"
  const val RUNTIME_SYSTEM_PROMPT = "gemini_runtime_system_prompt"
  const val KEYBOARD_COMMAND_TIMEOUT_MS = "keyboard_command_timeout_ms"
  const val KEYBOARD_TRANSCRIPTION_TIMEOUT_MS = "keyboard_transcription_timeout_ms"

  fun getSharedPreferences(context: Context) =
    context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
}
