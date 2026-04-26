package com.holas.plynkeyboard

import android.content.Context
import com.google.android.gms.tasks.Tasks
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings

object FirebaseRemoteRuntimeConfig {
  private const val MODEL_KEY = "gemini_model"
  private const val SYSTEM_PROMPT_KEY = "gemini_system_prompt"
  private const val KEYBOARD_COMMAND_TIMEOUT_KEY = "keyboard_command_timeout_seconds"
  private const val KEYBOARD_TRANSCRIPTION_TIMEOUT_KEY = "keyboard_transcription_timeout_seconds"
  private const val FETCH_TIMEOUT_MILLIS = 10_000L

  fun refresh(context: Context) {
    runCatching<Unit> {
      val remoteConfig = FirebaseRemoteConfig.getInstance()
      val settings =
        FirebaseRemoteConfigSettings.Builder()
          .setFetchTimeoutInSeconds(FETCH_TIMEOUT_MILLIS / 1_000)
          .setMinimumFetchIntervalInSeconds(0)
          .build()

      Tasks.await(remoteConfig.setConfigSettingsAsync(settings))
      Tasks.await(remoteConfig.fetchAndActivate())

      val model = GeminiRuntimeConfig.normalizeModel(remoteConfig.getString(MODEL_KEY))
      val systemPrompt = remoteConfig.getString(SYSTEM_PROMPT_KEY).trim()
      val keyboardCommandTimeoutMillis = positiveTimeoutMillis(
        remoteConfig.getString(KEYBOARD_COMMAND_TIMEOUT_KEY),
      )
      val keyboardTranscriptionTimeoutMillis = positiveTimeoutMillis(
        remoteConfig.getString(KEYBOARD_TRANSCRIPTION_TIMEOUT_KEY),
      )

      if (model.isNullOrEmpty() || systemPrompt.isEmpty()) {
        return@runCatching
      }

      val editor = PlynPreferences.getSharedPreferences(context).edit()
        .putString(PlynPreferences.RUNTIME_MODEL, model)
        .putString(PlynPreferences.RUNTIME_SYSTEM_PROMPT, systemPrompt)
      if (keyboardCommandTimeoutMillis != null) {
        editor.putLong(PlynPreferences.KEYBOARD_COMMAND_TIMEOUT_MS, keyboardCommandTimeoutMillis)
      }
      if (keyboardTranscriptionTimeoutMillis != null) {
        editor.putLong(PlynPreferences.KEYBOARD_TRANSCRIPTION_TIMEOUT_MS, keyboardTranscriptionTimeoutMillis)
      }
      editor.apply()
    }
  }

  fun positiveTimeoutMillis(rawValue: String?): Long? {
    val seconds = rawValue?.trim()?.toDoubleOrNull() ?: return null
    if (!seconds.isFinite() || seconds <= 0) {
      return null
    }
    return (seconds * 1_000).toLong()
  }
}
