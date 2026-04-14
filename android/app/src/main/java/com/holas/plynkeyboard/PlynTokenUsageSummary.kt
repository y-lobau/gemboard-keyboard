package com.holas.plynkeyboard

import android.content.Context
import com.facebook.react.bridge.WritableNativeMap
import org.json.JSONArray
import org.json.JSONObject

data class PlynTokenUsageSummary(
  val inputTokens: Int,
  val cachedInputTokens: Int,
  val outputTokens: Int,
  val totalTokens: Int,
  val requestCount: Int,
  val lastRequest: RequestSummary,
  val inputByModality: ModalitySummary,
  val cachedInputByModality: ModalitySummary,
  val outputByModality: ModalitySummary,
) {
  data class ModalitySummary(
    val text: Int,
    val audio: Int,
    val image: Int,
    val video: Int,
    val document: Int,
  ) {
    operator fun plus(other: ModalitySummary) = ModalitySummary(
      text = text + other.text,
      audio = audio + other.audio,
      image = image + other.image,
      video = video + other.video,
      document = document + other.document,
    )

    fun toJsonObject() = JSONObject()
      .put("text", text)
      .put("audio", audio)
      .put("image", image)
      .put("video", video)
      .put("document", document)

    fun toReactMap() = WritableNativeMap().apply {
      putInt("text", text)
      putInt("audio", audio)
      putInt("image", image)
      putInt("video", video)
      putInt("document", document)
    }

    companion object {
      val zero = ModalitySummary(text = 0, audio = 0, image = 0, video = 0, document = 0)

      fun fromTokenDetails(tokenDetails: JSONArray?): ModalitySummary {
        if (tokenDetails == null) {
          return zero
        }

        var summary = zero

        for (index in 0 until tokenDetails.length()) {
          val tokenDetail = tokenDetails.optJSONObject(index) ?: continue
          val tokenCount = tokenDetail.optInt("tokenCount", 0)

          summary = when (tokenDetail.optString("modality", "").uppercase()) {
            "TEXT" -> summary.copy(text = summary.text + tokenCount)
            "AUDIO" -> summary.copy(audio = summary.audio + tokenCount)
            "IMAGE" -> summary.copy(image = summary.image + tokenCount)
            "VIDEO" -> summary.copy(video = summary.video + tokenCount)
            "DOCUMENT" -> summary.copy(document = summary.document + tokenCount)
            else -> summary
          }
        }

        return summary
      }

      fun fromJsonObject(json: JSONObject?) = ModalitySummary(
        text = json?.optInt("text", 0) ?: 0,
        audio = json?.optInt("audio", 0) ?: 0,
        image = json?.optInt("image", 0) ?: 0,
        video = json?.optInt("video", 0) ?: 0,
        document = json?.optInt("document", 0) ?: 0,
      )
    }
  }

  data class RequestSummary(
    val inputTokens: Int,
    val cachedInputTokens: Int,
    val outputTokens: Int,
    val totalTokens: Int,
    val inputByModality: ModalitySummary,
    val cachedInputByModality: ModalitySummary,
    val outputByModality: ModalitySummary,
  ) {
    fun toJsonObject() = JSONObject()
      .put("inputTokens", inputTokens)
      .put("cachedInputTokens", cachedInputTokens)
      .put("outputTokens", outputTokens)
      .put("totalTokens", totalTokens)
      .put("inputByModality", inputByModality.toJsonObject())
      .put("cachedInputByModality", cachedInputByModality.toJsonObject())
      .put("outputByModality", outputByModality.toJsonObject())

    fun toReactMap() = WritableNativeMap().apply {
      putInt("inputTokens", inputTokens)
      putInt("cachedInputTokens", cachedInputTokens)
      putInt("outputTokens", outputTokens)
      putInt("totalTokens", totalTokens)
      putMap("inputByModality", inputByModality.toReactMap())
      putMap("cachedInputByModality", cachedInputByModality.toReactMap())
      putMap("outputByModality", outputByModality.toReactMap())
    }

    companion object {
      val zero = RequestSummary(
        inputTokens = 0,
        cachedInputTokens = 0,
        outputTokens = 0,
        totalTokens = 0,
        inputByModality = ModalitySummary.zero,
        cachedInputByModality = ModalitySummary.zero,
        outputByModality = ModalitySummary.zero,
      )

      fun fromUsageMetadata(usageMetadata: JSONObject?): RequestSummary? {
        if (usageMetadata == null || !usageMetadata.has("totalTokenCount")) {
          return null
        }

        return RequestSummary(
          inputTokens = usageMetadata.optInt("promptTokenCount", 0),
          cachedInputTokens = usageMetadata.optInt("cachedContentTokenCount", 0),
          outputTokens = usageMetadata.optInt("candidatesTokenCount", 0),
          totalTokens = usageMetadata.optInt("totalTokenCount", 0),
          inputByModality = ModalitySummary.fromTokenDetails(usageMetadata.optJSONArray("promptTokensDetails")),
          cachedInputByModality = ModalitySummary.fromTokenDetails(usageMetadata.optJSONArray("cacheTokensDetails")),
          outputByModality = ModalitySummary.fromTokenDetails(usageMetadata.optJSONArray("candidatesTokensDetails")),
        )
      }

      fun fromJsonObject(json: JSONObject?) = RequestSummary(
        inputTokens = json?.optInt("inputTokens", 0) ?: 0,
        cachedInputTokens = json?.optInt("cachedInputTokens", 0) ?: 0,
        outputTokens = json?.optInt("outputTokens", 0) ?: 0,
        totalTokens = json?.optInt("totalTokens", 0) ?: 0,
        inputByModality = ModalitySummary.fromJsonObject(json?.optJSONObject("inputByModality")),
        cachedInputByModality = ModalitySummary.fromJsonObject(json?.optJSONObject("cachedInputByModality")),
        outputByModality = ModalitySummary.fromJsonObject(json?.optJSONObject("outputByModality")),
      )
    }
  }

  operator fun plus(other: PlynTokenUsageSummary) = PlynTokenUsageSummary(
    inputTokens = inputTokens + other.inputTokens,
    cachedInputTokens = cachedInputTokens + other.cachedInputTokens,
    outputTokens = outputTokens + other.outputTokens,
    totalTokens = totalTokens + other.totalTokens,
    requestCount = requestCount + other.requestCount,
    lastRequest = other.lastRequest,
    inputByModality = inputByModality + other.inputByModality,
    cachedInputByModality = cachedInputByModality + other.cachedInputByModality,
    outputByModality = outputByModality + other.outputByModality,
  )

  fun toJsonObject() = JSONObject()
    .put("inputTokens", inputTokens)
    .put("cachedInputTokens", cachedInputTokens)
    .put("outputTokens", outputTokens)
    .put("totalTokens", totalTokens)
    .put("requestCount", requestCount)
    .put("lastRequest", lastRequest.toJsonObject())
    .put("inputByModality", inputByModality.toJsonObject())
    .put("cachedInputByModality", cachedInputByModality.toJsonObject())
    .put("outputByModality", outputByModality.toJsonObject())

  fun toReactMap() = WritableNativeMap().apply {
    putInt("inputTokens", inputTokens)
    putInt("cachedInputTokens", cachedInputTokens)
    putInt("outputTokens", outputTokens)
    putInt("totalTokens", totalTokens)
    putInt("requestCount", requestCount)
    putMap("lastRequest", lastRequest.toReactMap())
    putMap("inputByModality", inputByModality.toReactMap())
    putMap("cachedInputByModality", cachedInputByModality.toReactMap())
    putMap("outputByModality", outputByModality.toReactMap())
  }

  companion object {
    val zero = PlynTokenUsageSummary(
      inputTokens = 0,
      cachedInputTokens = 0,
      outputTokens = 0,
      totalTokens = 0,
      requestCount = 0,
      lastRequest = RequestSummary.zero,
      inputByModality = ModalitySummary.zero,
      cachedInputByModality = ModalitySummary.zero,
      outputByModality = ModalitySummary.zero,
    )

    fun fromUsageMetadata(usageMetadata: JSONObject?): PlynTokenUsageSummary? {
      val requestSummary = RequestSummary.fromUsageMetadata(usageMetadata) ?: return null

      return PlynTokenUsageSummary(
        inputTokens = requestSummary.inputTokens,
        cachedInputTokens = requestSummary.cachedInputTokens,
        outputTokens = requestSummary.outputTokens,
        totalTokens = requestSummary.totalTokens,
        requestCount = 1,
        lastRequest = requestSummary,
        inputByModality = requestSummary.inputByModality,
        cachedInputByModality = requestSummary.cachedInputByModality,
        outputByModality = requestSummary.outputByModality,
      )
    }

    fun fromStreamPayload(payload: String): PlynTokenUsageSummary? {
      val normalizedPayload = payload.trim()
      if (normalizedPayload.isEmpty() || normalizedPayload == "[DONE]") {
        return null
      }

      return try {
        if (normalizedPayload.startsWith("[")) {
          val chunks = JSONArray(normalizedPayload)
          var summary: PlynTokenUsageSummary? = null

          for (index in 0 until chunks.length()) {
            summary = fromUsageMetadata(chunks.optJSONObject(index)?.optJSONObject("usageMetadata")) ?: summary
          }

          summary
        } else {
          fromUsageMetadata(JSONObject(normalizedPayload).optJSONObject("usageMetadata"))
        }
      } catch (_: Exception) {
        null
      }
    }

    fun fromJsonObject(json: JSONObject?) = if (json == null) {
      zero
    } else {
      PlynTokenUsageSummary(
        inputTokens = json.optInt("inputTokens", 0),
        cachedInputTokens = json.optInt("cachedInputTokens", 0),
        outputTokens = json.optInt("outputTokens", 0),
        totalTokens = json.optInt("totalTokens", 0),
        requestCount = json.optInt("requestCount", 0),
        lastRequest = RequestSummary.fromJsonObject(json.optJSONObject("lastRequest")),
        inputByModality = ModalitySummary.fromJsonObject(json.optJSONObject("inputByModality")),
        cachedInputByModality = ModalitySummary.fromJsonObject(json.optJSONObject("cachedInputByModality")),
        outputByModality = ModalitySummary.fromJsonObject(json.optJSONObject("outputByModality")),
      )
    }
  }
}

object PlynTokenUsageStore {
  private const val TOKEN_USAGE_SUMMARY = "token_usage_summary"

  fun get(context: Context): PlynTokenUsageSummary {
    val json = PlynPreferences.getSharedPreferences(context).getString(TOKEN_USAGE_SUMMARY, null)
      ?: return PlynTokenUsageSummary.zero

    return try {
      PlynTokenUsageSummary.fromJsonObject(JSONObject(json))
    } catch (_: Exception) {
      PlynTokenUsageSummary.zero
    }
  }

  fun add(context: Context, summary: PlynTokenUsageSummary?) {
    if (summary == null) {
      return
    }

    val updatedSummary = get(context) + summary
    PlynPreferences.getSharedPreferences(context)
      .edit()
      .putString(TOKEN_USAGE_SUMMARY, updatedSummary.toJsonObject().toString())
      .apply()
  }

  fun reset(context: Context) {
    PlynPreferences.getSharedPreferences(context)
      .edit()
      .remove(TOKEN_USAGE_SUMMARY)
      .apply()
  }
}
