package com.holas.plynkeyboard

import androidx.annotation.DrawableRes

enum class KeyboardUiState {
  READY,
  RECORDING,
  PROCESSING,
}

enum class KeyboardMicIcon(@DrawableRes val drawableRes: Int) {
  MICROPHONE(android.R.drawable.ic_btn_speak_now),
  STOP(android.R.drawable.ic_media_pause),
  HOURGLASS(android.R.drawable.ic_popup_sync),
}

data class KeyboardUiPresentation(
  val micIcon: KeyboardMicIcon,
  val micBackgroundColor: String,
  val micTintColor: String,
  val waveColor: String,
  val statusColor: String,
  val controlsEnabled: Boolean,
  val deleteEnabled: Boolean,
) {
  companion object {
    fun forState(state: KeyboardUiState): KeyboardUiPresentation = when (state) {
      KeyboardUiState.READY -> KeyboardUiPresentation(
        micIcon = KeyboardMicIcon.MICROPHONE,
        micBackgroundColor = "#E2D9D2",
        micTintColor = "#141519",
        waveColor = "#E6ADB3C2",
        statusColor = "#3C4836",
        controlsEnabled = true,
        deleteEnabled = true,
      )
      KeyboardUiState.RECORDING -> KeyboardUiPresentation(
        micIcon = KeyboardMicIcon.STOP,
        micBackgroundColor = "#CE510B",
        micTintColor = "#E2D9D2",
        waveColor = "#E2D9D2",
        statusColor = "#3C4836",
        controlsEnabled = true,
        deleteEnabled = false,
      )
      KeyboardUiState.PROCESSING -> KeyboardUiPresentation(
        micIcon = KeyboardMicIcon.HOURGLASS,
        micBackgroundColor = "#47484F",
        micTintColor = "#D1D1D1",
        waveColor = "#F2DBBD7A",
        statusColor = "#3C4836",
        controlsEnabled = false,
        deleteEnabled = false,
      )
    }
  }
}
