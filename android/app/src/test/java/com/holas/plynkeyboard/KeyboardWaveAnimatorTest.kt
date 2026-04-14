package com.holas.plynkeyboard

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class KeyboardWaveAnimatorTest {
  @Test
  fun idleHeightsMatchIosWaveShape() {
    assertEquals(listOf(6, 10, 14, 20, 26, 20, 14, 10, 6), KeyboardWaveAnimator.idleHeights)
  }

  @Test
  fun recordingHeightsGrowWithLiveAudioLevel() {
    val quiet = KeyboardWaveAnimator.recordingHeights(step = 3, level = 0.05f)
    val loud = KeyboardWaveAnimator.recordingHeights(step = 3, level = 0.95f)

    assertEquals(9, quiet.size)
    assertEquals(9, loud.size)
    assertTrue(loud.sum() > quiet.sum())
    assertTrue(loud[4] > quiet[4])
  }

  @Test
  fun processingHeightsMovePeakAcrossWaveLikeIos() {
    val start = KeyboardWaveAnimator.processingHeights(step = 0)
    val center = KeyboardWaveAnimator.processingHeights(step = 4)
    val returnPass = KeyboardWaveAnimator.processingHeights(step = 10)

    assertEquals(46, start.max())
    assertEquals(0, start.indexOfFirst { it == 46 })
    assertEquals(4, center.indexOfFirst { it == 46 })
    assertEquals(7, returnPass.indexOfFirst { it == 46 })
  }
}
