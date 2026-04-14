package com.holas.plynkeyboard

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class PlynTokenUsageSummaryTest {
  @Test
  fun fromUsageMetadataBuildsLatestRequestAndTotals() {
    val summary = PlynTokenUsageSummary.fromUsageMetadata(
      JSONObject()
        .put("promptTokenCount", 120)
        .put("cachedContentTokenCount", 15)
        .put("candidatesTokenCount", 18)
        .put("totalTokenCount", 153)
        .put(
          "promptTokensDetails",
          JSONArray()
            .put(JSONObject().put("modality", "TEXT").put("tokenCount", 80))
            .put(JSONObject().put("modality", "AUDIO").put("tokenCount", 40)),
        )
        .put(
          "cacheTokensDetails",
          JSONArray().put(JSONObject().put("modality", "TEXT").put("tokenCount", 15)),
        )
        .put(
          "candidatesTokensDetails",
          JSONArray().put(JSONObject().put("modality", "TEXT").put("tokenCount", 18)),
        ),
    )

    requireNotNull(summary)
    assertEquals(120, summary.inputTokens)
    assertEquals(15, summary.cachedInputTokens)
    assertEquals(18, summary.outputTokens)
    assertEquals(153, summary.totalTokens)
    assertEquals(1, summary.requestCount)
    assertEquals(80, summary.inputByModality.text)
    assertEquals(40, summary.inputByModality.audio)
    assertEquals(15, summary.cachedInputByModality.text)
    assertEquals(18, summary.outputByModality.text)
    assertEquals(153, summary.lastRequest.totalTokens)
    assertEquals(40, summary.lastRequest.inputByModality.audio)
  }

  @Test
  fun fromStreamPayloadUsesLatestChunkWithUsageMetadata() {
    val summary = PlynTokenUsageSummary.fromStreamPayload(
      JSONArray()
        .put(
          JSONObject().put(
            "usageMetadata",
            JSONObject()
              .put("promptTokenCount", 10)
              .put("cachedContentTokenCount", 0)
              .put("candidatesTokenCount", 2)
              .put("totalTokenCount", 12),
          ),
        )
        .put(
          JSONObject().put(
            "usageMetadata",
            JSONObject()
              .put("promptTokenCount", 30)
              .put("cachedContentTokenCount", 5)
              .put("candidatesTokenCount", 7)
              .put("totalTokenCount", 42),
          ),
        )
        .toString(),
    )

    requireNotNull(summary)
    assertEquals(30, summary.inputTokens)
    assertEquals(5, summary.cachedInputTokens)
    assertEquals(7, summary.outputTokens)
    assertEquals(42, summary.totalTokens)
  }

  @Test
  fun plusAccumulatesTotalsWhileReplacingLatestRequest() {
    val first = PlynTokenUsageSummary.fromUsageMetadata(
      JSONObject()
        .put("promptTokenCount", 100)
        .put("cachedContentTokenCount", 0)
        .put("candidatesTokenCount", 10)
        .put("totalTokenCount", 110),
    )
    val second = PlynTokenUsageSummary.fromUsageMetadata(
      JSONObject()
        .put("promptTokenCount", 60)
        .put("cachedContentTokenCount", 12)
        .put("candidatesTokenCount", 8)
        .put("totalTokenCount", 80),
    )

    requireNotNull(first)
    requireNotNull(second)

    val accumulated = first + second

    assertEquals(160, accumulated.inputTokens)
    assertEquals(12, accumulated.cachedInputTokens)
    assertEquals(18, accumulated.outputTokens)
    assertEquals(190, accumulated.totalTokens)
    assertEquals(2, accumulated.requestCount)
    assertEquals(80, accumulated.lastRequest.totalTokens)
    assertEquals(60, accumulated.lastRequest.inputTokens)
  }
}
