package com.holas.plynkeyboard

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

object KeyboardWaveAnimator {
  val idleHeights: List<Int> = listOf(6, 10, 14, 20, 26, 20, 14, 10, 6)

  fun recordingHeights(step: Int, level: Float): List<Int> {
    val normalizedLevel = level.coerceIn(0f, 1f)
    val motionStrength = 0.45f + normalizedLevel * 0.95f
    val loudnessBoost = 2f + normalizedLevel * 10f

    return idleHeights.indices.map { index ->
      val distanceFromCenter = abs(index - 4).toFloat()
      val base = max(12f, 42f - distanceFromCenter * 6f + loudnessBoost)
      val oscillation = sin(step * 0.9f + index * 0.8f) * (6f + 8f * motionStrength)
      val flutter = cos(step * 1.4f + index * 1.2f) * (2f + 4f * motionStrength)
      min(48f, max(10f, base + oscillation + flutter)).toInt()
    }
  }

  fun processingHeights(step: Int): List<Int> {
    val travel = step % max(1, idleHeights.size * 2)

    return idleHeights.indices.map { index ->
      val mirroredIndex = if (travel < idleHeights.size) travel else (idleHeights.size * 2 - 1 - travel)
      when (abs(index - mirroredIndex)) {
        0 -> 46
        1 -> 32
        2 -> 22
        3 -> 15
        else -> 10
      }
    }
  }
}
