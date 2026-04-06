package com.holas.plynkeyboard

import android.content.Context
import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics

object PlyńAnalytics {
  fun trackEvent(context: Context, name: String, params: Map<String, Any>) {
    try {
      val bundle = Bundle()
      params.forEach { (key, value) ->
        when (value) {
          is Int -> bundle.putInt(key, value)
          is Long -> bundle.putLong(key, value)
          is Double -> bundle.putDouble(key, value)
          is Float -> bundle.putDouble(key, value.toDouble())
          else -> bundle.putString(key, value.toString())
        }
      }
      FirebaseAnalytics.getInstance(context).logEvent(name, bundle)
    } catch (_: Exception) {
      return
    }
  }

  fun latencyBucket(latencyMs: Long): String {
    return when {
      latencyMs < 1_000 -> "lt_1000"
      latencyMs < 2_000 -> "1000_1999"
      latencyMs < 4_000 -> "2000_3999"
      latencyMs < 8_000 -> "4000_7999"
      else -> "8000_plus"
    }
  }

  fun outputSizeBucket(outputChars: Int): String {
    return when {
      outputChars <= 0 -> "0"
      outputChars <= 20 -> "1_20"
      outputChars <= 60 -> "21_60"
      outputChars <= 120 -> "61_120"
      else -> "121_plus"
    }
  }
}
