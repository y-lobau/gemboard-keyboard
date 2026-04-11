package com.holas.plynkeyboard

import android.content.Context

object GeminiRuntimeConfig {
  private const val DEFAULT_SYSTEM_PROMPT =
    "Transcribe supplied audio into Belarusian dictation text only. Return only the final Belarusian transcript."

  fun model(context: Context): String? =
    normalizeModel(
      PlynPreferences.getSharedPreferences(context)
        .getString(PlynPreferences.RUNTIME_MODEL, null)
    )

  fun normalizeModel(rawModel: String?): String? = rawModel?.trim()?.takeIf { it.isNotEmpty() }

  fun systemPrompt(context: Context): String {
    val storedPrompt =
      PlynPreferences.getSharedPreferences(context)
        .getString(PlynPreferences.RUNTIME_SYSTEM_PROMPT, null)
        ?.trim()
        .orEmpty()

    if (storedPrompt.isNotEmpty()) {
      return storedPrompt
    }

    return DEFAULT_SYSTEM_PROMPT
  }
}
