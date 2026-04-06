package com.holas.plynkeyboard

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class TranscriptTextFormatterTest {
  @Test
  fun joinPartsPreservesLeadingWhitespaceFromAChunk() {
    val parts = JSONArray().put(JSONObject().put("text", " world"))

    assertEquals(" world", TranscriptTextFormatter.joinParts(parts))
  }

  @Test
  fun mergeStreamTranscriptPreservesBoundaryWhitespaceForDeltaChunks() {
    val firstChunk = TranscriptTextFormatter.joinParts(
      JSONArray().put(JSONObject().put("text", "hello")),
    )
    val secondChunk = TranscriptTextFormatter.joinParts(
      JSONArray().put(JSONObject().put("text", " world")),
    )

    val merged = TranscriptTextFormatter.mergeStreamTranscript(firstChunk, secondChunk)

    assertEquals("hello world", merged)
  }

  @Test
  fun mergeStreamTranscriptIgnoresWhitespaceOnlyChunks() {
    val merged = TranscriptTextFormatter.mergeStreamTranscript("hello", "   \n")

    assertEquals("hello", merged)
  }
}
