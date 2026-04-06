package com.holas.plynkeyboard

import android.content.Context

object GeminiRuntimeConfig {
  private const val DEFAULT_MODEL = "gemini-3.1-flash-preview"
  private const val DEFAULT_SYSTEM_PROMPT =
    "Transcribe supplied audio into Belarusian dictation text only. Return only the final Belarusian transcript."

  fun model(context: Context): String {
    val storedModel =
      PlyńPreferences.getSharedPreferences(context)
        .getString(PlyńPreferences.RUNTIME_MODEL, null)
        ?.trim()
        .orEmpty()

    if (storedModel.isNotEmpty()) {
      return storedModel
    }

    return DEFAULT_MODEL
  }

  fun systemPrompt(context: Context): String {
    val storedPrompt =
      PlyńPreferences.getSharedPreferences(context)
        .getString(PlyńPreferences.RUNTIME_SYSTEM_PROMPT, null)
        ?.trim()
        .orEmpty()

    if (storedPrompt.isNotEmpty()) {
      return storedPrompt
    }

    return DEFAULT_SYSTEM_PROMPT
  }
}
