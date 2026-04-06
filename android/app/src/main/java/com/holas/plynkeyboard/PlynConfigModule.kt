package com.holas.plynkeyboard

import android.content.Context
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableNativeMap

class PlyńConfigModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "PlyńConfig"

  @ReactMethod
  fun getStatus(promise: Promise) {
    val prefs = PlyńPreferences.getSharedPreferences(reactContext)
    val map = WritableNativeMap()
    map.putBoolean("hasApiKey", !prefs.getString(PlyńPreferences.API_KEY, null).isNullOrBlank())
    map.putString("platformMode", "android-ime")
    promise.resolve(map)
  }

  @ReactMethod
  fun getSectionExpansionState(promise: Promise) {
    val prefs = PlyńPreferences.getSharedPreferences(reactContext)
    val map = WritableNativeMap()
    if (prefs.contains(PlyńPreferences.ONBOARDING_EXPANDED)) {
      map.putBoolean(
        "onboardingExpanded",
        prefs.getBoolean(PlyńPreferences.ONBOARDING_EXPANDED, true)
      )
    }
    if (prefs.contains(PlyńPreferences.SETUP_EXPANDED)) {
      map.putBoolean(
        "setupExpanded",
        prefs.getBoolean(PlyńPreferences.SETUP_EXPANDED, true)
      )
    }
    if (prefs.contains(PlyńPreferences.TOKEN_SUMMARY_EXPANDED)) {
      map.putBoolean(
        "tokenSummaryExpanded",
        prefs.getBoolean(PlyńPreferences.TOKEN_SUMMARY_EXPANDED, false)
      )
    }
    promise.resolve(map)
  }

  @ReactMethod
  fun saveSectionExpansionState(config: ReadableMap, promise: Promise) {
    val editor = PlyńPreferences.getSharedPreferences(reactContext).edit()
    if (config.hasKey("onboardingExpanded")) {
      editor.putBoolean(
        PlyńPreferences.ONBOARDING_EXPANDED,
        config.getBoolean("onboardingExpanded")
      )
    }
    if (config.hasKey("setupExpanded")) {
      editor.putBoolean(
        PlyńPreferences.SETUP_EXPANDED,
        config.getBoolean("setupExpanded")
      )
    }
    if (config.hasKey("tokenSummaryExpanded")) {
      editor.putBoolean(
        PlyńPreferences.TOKEN_SUMMARY_EXPANDED,
        config.getBoolean("tokenSummaryExpanded")
      )
    }
    editor.apply()
    promise.resolve(null)
  }

  @ReactMethod
  fun saveApiKey(apiKey: String, promise: Promise) {
    PlyńPreferences.getSharedPreferences(reactContext)
      .edit()
      .putString(PlyńPreferences.API_KEY, apiKey.trim())
      .apply()
    promise.resolve(null)
  }

  @ReactMethod
  fun saveRuntimeConfig(config: ReadableMap, promise: Promise) {
    val model = config.getString("model")?.trim().orEmpty()
    val systemPrompt = config.getString("systemPrompt")?.trim().orEmpty()

    PlyńPreferences.getSharedPreferences(reactContext)
      .edit()
      .putString(PlyńPreferences.RUNTIME_MODEL, model)
      .putString(PlyńPreferences.RUNTIME_SYSTEM_PROMPT, systemPrompt)
      .apply()
    promise.resolve(null)
  }

  @ReactMethod
  fun getTokenUsageSummary(promise: Promise) {
    promise.resolve(PlyńTokenUsageStore.getSummary(reactContext).toWritableMap())
  }

  @ReactMethod
  fun resetTokenUsageSummary(promise: Promise) {
    PlyńTokenUsageStore.resetSummary(reactContext)
    promise.resolve(null)
  }
}

object PlyńPreferences {
  const val STORE = "Plyń_preferences"
  const val API_KEY = "gemini_api_key"
  const val RUNTIME_MODEL = "gemini_runtime_model"
  const val RUNTIME_SYSTEM_PROMPT = "gemini_runtime_system_prompt"
  const val ONBOARDING_EXPANDED = "onboarding_expanded"
  const val SETUP_EXPANDED = "setup_expanded"
  const val TOKEN_SUMMARY_EXPANDED = "token_summary_expanded"

  fun getSharedPreferences(context: Context) =
    context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
}
