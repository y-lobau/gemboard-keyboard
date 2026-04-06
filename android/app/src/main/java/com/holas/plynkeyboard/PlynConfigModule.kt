package com.holas.plynkeyboard

import android.content.Context
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableNativeMap

class PlynConfigModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "GemboardConfig"

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
}

object PlynPreferences {
  private const val STORE = "Plyn_preferences"
  const val API_KEY = "gemini_api_key"
  const val RUNTIME_MODEL = "gemini_runtime_model"
  const val RUNTIME_SYSTEM_PROMPT = "gemini_runtime_system_prompt"

  fun getSharedPreferences(context: Context) =
    context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
}
