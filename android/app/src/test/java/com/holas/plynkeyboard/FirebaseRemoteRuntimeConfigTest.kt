package com.holas.plynkeyboard

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FirebaseRemoteRuntimeConfigTest {
  @Test
  fun positiveTimeoutMillisParsesSeconds() {
    assertEquals(3500L, FirebaseRemoteRuntimeConfig.positiveTimeoutMillis("3.5"))
    assertEquals(24000L, FirebaseRemoteRuntimeConfig.positiveTimeoutMillis(" 24 "))
  }

  @Test
  fun positiveTimeoutMillisRejectsInvalidValues() {
    assertNull(FirebaseRemoteRuntimeConfig.positiveTimeoutMillis(""))
    assertNull(FirebaseRemoteRuntimeConfig.positiveTimeoutMillis("0"))
    assertNull(FirebaseRemoteRuntimeConfig.positiveTimeoutMillis("-1"))
    assertNull(FirebaseRemoteRuntimeConfig.positiveTimeoutMillis("not-a-number"))
  }
}
