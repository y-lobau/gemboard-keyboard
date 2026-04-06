package com.holas.plynkeyboard

import android.content.Context
import com.google.android.gms.tasks.Tasks
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings

object FirebaseRemoteRuntimeConfig {
  private const val MODEL_KEY = "gemini_model"
  private const val SYSTEM_PROMPT_KEY = "gemini_system_prompt"
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

      val model = remoteConfig.getString(MODEL_KEY).trim()
      val systemPrompt = remoteConfig.getString(SYSTEM_PROMPT_KEY).trim()

      if (model.isEmpty() || systemPrompt.isEmpty()) {
        return@runCatching
      }

      PlynPreferences.getSharedPreferences(context)
        .edit()
        .putString(PlynPreferences.RUNTIME_MODEL, model)
        .putString(PlynPreferences.RUNTIME_SYSTEM_PROMPT, systemPrompt)
        .apply()
    }
  }
}
