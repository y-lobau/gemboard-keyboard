package com.yanlobau.gemboardkeyboard

import android.content.Context
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableNativeMap

class GemboardConfigModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "GemboardConfig"

  @ReactMethod
  fun getStatus(promise: Promise) {
    val prefs = GemboardPreferences.getSharedPreferences(reactContext)
    val map = WritableNativeMap()
    map.putBoolean("hasApiKey", !prefs.getString(GemboardPreferences.API_KEY, null).isNullOrBlank())
    map.putString("platformMode", "android-ime")
    promise.resolve(map)
  }

  @ReactMethod
  fun saveApiKey(apiKey: String, promise: Promise) {
    GemboardPreferences.getSharedPreferences(reactContext)
      .edit()
      .putString(GemboardPreferences.API_KEY, apiKey.trim())
      .apply()
    promise.resolve(null)
  }
}

object GemboardPreferences {
  const val STORE = "gemboard_preferences"
  const val API_KEY = "gemini_api_key"

  fun getSharedPreferences(context: Context) =
    context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
}
