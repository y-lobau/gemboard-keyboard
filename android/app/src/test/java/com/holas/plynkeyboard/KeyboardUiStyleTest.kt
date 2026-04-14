package com.holas.plynkeyboard

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class KeyboardUiStyleTest {
  @Test
  fun processingPresentationMatchesIosIconAndPalette() {
    val presentation = KeyboardUiPresentation.forState(KeyboardUiState.PROCESSING)

    assertEquals(KeyboardMicIcon.HOURGLASS, presentation.micIcon)
    assertEquals("#47484F", presentation.micBackgroundColor)
    assertEquals("#D1D1D1", presentation.micTintColor)
    assertEquals("#F2DBBD7A", presentation.waveColor)
    assertEquals("#3C4836", presentation.statusColor)
    assertTrue(!presentation.controlsEnabled)
  }

  @Test
  fun keyboardLayoutMatchesIosBannerMetrics() {
    val layout = readResource("src/main/res/layout/keyboard_view.xml")

    assertTrue(layout.contains("android:paddingStart=\"14dp\""))
    assertTrue(layout.contains("android:paddingTop=\"10dp\""))
    assertTrue(layout.contains("android:paddingEnd=\"14dp\""))
    assertTrue(layout.contains("android:paddingBottom=\"8dp\""))
    assertTrue(layout.contains("android:layout_height=\"80dp\""))
    assertTrue(layout.contains("android:paddingStart=\"16dp\""))
    assertTrue(layout.contains("android:paddingEnd=\"16dp\""))
    assertTrue(layout.contains("android:layout_height=\"56dp\""))
    assertTrue(layout.contains("android:layout_width=\"132dp\""))
    assertTrue(layout.contains("android:layout_height=\"40dp\""))
    assertTrue(layout.contains("android:layout_width=\"56dp\""))
    assertTrue(layout.contains("android:layout_height=\"56dp\""))
  }

  @Test
  fun drawablePaletteMatchesIosColors() {
    assertTrue(readResource("src/main/res/drawable/keyboard_surface_background.xml").contains("#4A5942"))
    assertTrue(readResource("src/main/res/drawable/keyboard_utility_tray_background.xml").contains("#68795C"))
    assertTrue(readResource("src/main/res/drawable/keyboard_key_background.xml").contains("#E2D9D2"))
    assertTrue(readResource("src/main/res/drawable/keyboard_wave_bar_background.xml").contains("#E6ADB3C2"))
    assertTrue(readResource("src/main/res/drawable/keyboard_mic_button_background.xml").contains("#E2D9D2"))
    assertTrue(readResource("src/main/res/drawable/keyboard_mic_button_recording_background.xml").contains("#CE510B"))
    assertTrue(readResource("src/main/res/drawable/keyboard_mic_button_processing_background.xml").contains("#47484F"))
  }

  private fun readResource(path: String): String =
    when {
      File(path).isFile -> File(path).readText()
      File("app/$path").isFile -> File("app/$path").readText()
      else -> error("Missing resource file: $path")
    }
}
