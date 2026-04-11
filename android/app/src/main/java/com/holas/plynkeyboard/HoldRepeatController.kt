package com.holas.plynkeyboard

class HoldRepeatController(
  private val initialDelayMs: Long = 350,
  private val repeatIntervalMs: Long = 70,
  private val postDelayed: (Runnable, Long) -> Unit,
  private val removeCallbacks: (Runnable) -> Unit,
  private val action: () -> Unit,
) {
  private var isPressed = false

  private val repeatRunnable = object : Runnable {
    override fun run() {
      if (!isPressed) {
        return
      }

      action()
      postDelayed(this, repeatIntervalMs)
    }
  }

  fun start() {
    if (isPressed) {
      return
    }

    isPressed = true
    action()
    postDelayed(repeatRunnable, initialDelayMs)
  }

  fun stop() {
    if (!isPressed) {
      return
    }

    isPressed = false
    removeCallbacks(repeatRunnable)
  }
}
