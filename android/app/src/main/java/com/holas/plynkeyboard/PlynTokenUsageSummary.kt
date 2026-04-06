package com.holas.plynkeyboard

import android.content.Context
import com.facebook.react.bridge.WritableNativeMap
import org.json.JSONArray
import org.json.JSONObject

data class PlyńTokenModalitySummary(
  val text: Int,
  val audio: Int,
  val image: Int,
  val video: Int,
  val document: Int,
) {
  fun toWritableMap() = WritableNativeMap().apply {
    putInt("text", text)
    putInt("audio", audio)
    putInt("image", image)
    putInt("video", video)
    putInt("document", document)
  }

  operator fun plus(other: PlyńTokenModalitySummary) = PlyńTokenModalitySummary(
    text = text + other.text,
    audio = audio + other.audio,
    image = image + other.image,
    video = video + other.video,
    document = document + other.document,
  )

  companion object {
    val ZERO = PlyńTokenModalitySummary(
      text = 0,
      audio = 0,
      image = 0,
      video = 0,
      document = 0,
    )

    fun fromTokenDetails(details: JSONArray?): PlyńTokenModalitySummary {
      if (details == null) {
        return ZERO
      }

      var summary = ZERO
      for (index in 0 until details.length()) {
        val item = details.optJSONObject(index) ?: continue
        val tokenCount = item.optInt("tokenCount", 0)
        summary = when (item.optString("modality", "").uppercase()) {
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
  }
}

data class PlyńTokenUsageSummary(
  val inputTokens: Int,
  val cachedInputTokens: Int,
  val outputTokens: Int,
  val totalTokens: Int,
  val requestCount: Int,
  val lastRequest: PlyńTokenRequestSummary,
  val inputByModality: PlyńTokenModalitySummary,
  val cachedInputByModality: PlyńTokenModalitySummary,
  val outputByModality: PlyńTokenModalitySummary,
) {
  fun toWritableMap() = WritableNativeMap().apply {
    putInt("inputTokens", inputTokens)
    putInt("cachedInputTokens", cachedInputTokens)
    putInt("outputTokens", outputTokens)
    putInt("totalTokens", totalTokens)
    putInt("requestCount", requestCount)
    putMap("lastRequest", lastRequest.toWritableMap())
    putMap("inputByModality", inputByModality.toWritableMap())
    putMap("cachedInputByModality", cachedInputByModality.toWritableMap())
    putMap("outputByModality", outputByModality.toWritableMap())
  }

  companion object {
    val ZERO = PlyńTokenUsageSummary(
      inputTokens = 0,
      cachedInputTokens = 0,
      outputTokens = 0,
      totalTokens = 0,
      requestCount = 0,
      lastRequest = PlyńTokenRequestSummary.ZERO,
      inputByModality = PlyńTokenModalitySummary.ZERO,
      cachedInputByModality = PlyńTokenModalitySummary.ZERO,
      outputByModality = PlyńTokenModalitySummary.ZERO,
    )

    fun fromUsageMetadata(usageMetadata: JSONObject?): PlyńTokenUsageSummary? {
      if (usageMetadata == null) {
        return null
      }

      val totalTokens = usageMetadata.optInt("totalTokenCount", -1)
      if (totalTokens < 0) {
        return null
      }

      return PlyńTokenUsageSummary(
        inputTokens = usageMetadata.optInt("promptTokenCount", 0),
        cachedInputTokens = usageMetadata.optInt("cachedContentTokenCount", 0),
        outputTokens = usageMetadata.optInt("candidatesTokenCount", 0),
        totalTokens = totalTokens,
        requestCount = 1,
        lastRequest = PlyńTokenRequestSummary.fromUsageMetadata(usageMetadata),
        inputByModality = PlyńTokenModalitySummary.fromTokenDetails(
          usageMetadata.optJSONArray("promptTokensDetails"),
        ),
        cachedInputByModality = PlyńTokenModalitySummary.fromTokenDetails(
          usageMetadata.optJSONArray("cacheTokensDetails"),
        ),
        outputByModality = PlyńTokenModalitySummary.fromTokenDetails(
          usageMetadata.optJSONArray("candidatesTokensDetails"),
        ),
      )
    }
  }
}

data class PlyńTokenRequestSummary(
  val inputTokens: Int,
  val cachedInputTokens: Int,
  val outputTokens: Int,
  val totalTokens: Int,
  val inputByModality: PlyńTokenModalitySummary,
  val cachedInputByModality: PlyńTokenModalitySummary,
  val outputByModality: PlyńTokenModalitySummary,
) {
  fun toWritableMap() = WritableNativeMap().apply {
    putInt("inputTokens", inputTokens)
    putInt("cachedInputTokens", cachedInputTokens)
    putInt("outputTokens", outputTokens)
    putInt("totalTokens", totalTokens)
    putMap("inputByModality", inputByModality.toWritableMap())
    putMap("cachedInputByModality", cachedInputByModality.toWritableMap())
    putMap("outputByModality", outputByModality.toWritableMap())
  }

  companion object {
    val ZERO = PlyńTokenRequestSummary(
      inputTokens = 0,
      cachedInputTokens = 0,
      outputTokens = 0,
      totalTokens = 0,
      inputByModality = PlyńTokenModalitySummary.ZERO,
      cachedInputByModality = PlyńTokenModalitySummary.ZERO,
      outputByModality = PlyńTokenModalitySummary.ZERO,
    )

    fun fromUsageMetadata(usageMetadata: JSONObject?): PlyńTokenRequestSummary {
      if (usageMetadata == null) {
        return ZERO
      }

      val totalTokens = usageMetadata.optInt("totalTokenCount", -1)
      if (totalTokens < 0) {
        return ZERO
      }

      return PlyńTokenRequestSummary(
        inputTokens = usageMetadata.optInt("promptTokenCount", 0),
        cachedInputTokens = usageMetadata.optInt("cachedContentTokenCount", 0),
        outputTokens = usageMetadata.optInt("candidatesTokenCount", 0),
        totalTokens = totalTokens,
        inputByModality = PlyńTokenModalitySummary.fromTokenDetails(
          usageMetadata.optJSONArray("promptTokensDetails"),
        ),
        cachedInputByModality = PlyńTokenModalitySummary.fromTokenDetails(
          usageMetadata.optJSONArray("cacheTokensDetails"),
        ),
        outputByModality = PlyńTokenModalitySummary.fromTokenDetails(
          usageMetadata.optJSONArray("candidatesTokensDetails"),
        ),
      )
    }
  }
}

object PlyńTokenUsageStore {
  private const val INPUT_TOKENS = "gemini_total_input_tokens"
  private const val CACHED_INPUT_TOKENS = "gemini_total_cached_input_tokens"
  private const val OUTPUT_TOKENS = "gemini_total_output_tokens"
  private const val TOTAL_TOKENS = "gemini_total_tokens"
  private const val REQUEST_COUNT = "gemini_total_request_count"
  private const val INPUT_TEXT_TOKENS = "gemini_total_input_text_tokens"
  private const val INPUT_AUDIO_TOKENS = "gemini_total_input_audio_tokens"
  private const val INPUT_IMAGE_TOKENS = "gemini_total_input_image_tokens"
  private const val INPUT_VIDEO_TOKENS = "gemini_total_input_video_tokens"
  private const val INPUT_DOCUMENT_TOKENS = "gemini_total_input_document_tokens"
  private const val CACHED_INPUT_TEXT_TOKENS = "gemini_total_cached_input_text_tokens"
  private const val CACHED_INPUT_AUDIO_TOKENS = "gemini_total_cached_input_audio_tokens"
  private const val CACHED_INPUT_IMAGE_TOKENS = "gemini_total_cached_input_image_tokens"
  private const val CACHED_INPUT_VIDEO_TOKENS = "gemini_total_cached_input_video_tokens"
  private const val CACHED_INPUT_DOCUMENT_TOKENS = "gemini_total_cached_input_document_tokens"
  private const val OUTPUT_TEXT_TOKENS = "gemini_total_output_text_tokens"
  private const val OUTPUT_AUDIO_TOKENS = "gemini_total_output_audio_tokens"
  private const val OUTPUT_IMAGE_TOKENS = "gemini_total_output_image_tokens"
  private const val OUTPUT_VIDEO_TOKENS = "gemini_total_output_video_tokens"
  private const val OUTPUT_DOCUMENT_TOKENS = "gemini_total_output_document_tokens"
  private const val LAST_REQUEST_INPUT_TOKENS = "gemini_last_request_input_tokens"
  private const val LAST_REQUEST_CACHED_INPUT_TOKENS = "gemini_last_request_cached_input_tokens"
  private const val LAST_REQUEST_OUTPUT_TOKENS = "gemini_last_request_output_tokens"
  private const val LAST_REQUEST_TOTAL_TOKENS = "gemini_last_request_total_tokens"
  private const val LAST_REQUEST_INPUT_TEXT_TOKENS = "gemini_last_request_input_text_tokens"
  private const val LAST_REQUEST_INPUT_AUDIO_TOKENS = "gemini_last_request_input_audio_tokens"
  private const val LAST_REQUEST_INPUT_IMAGE_TOKENS = "gemini_last_request_input_image_tokens"
  private const val LAST_REQUEST_INPUT_VIDEO_TOKENS = "gemini_last_request_input_video_tokens"
  private const val LAST_REQUEST_INPUT_DOCUMENT_TOKENS = "gemini_last_request_input_document_tokens"
  private const val LAST_REQUEST_CACHED_INPUT_TEXT_TOKENS = "gemini_last_request_cached_input_text_tokens"
  private const val LAST_REQUEST_CACHED_INPUT_AUDIO_TOKENS = "gemini_last_request_cached_input_audio_tokens"
  private const val LAST_REQUEST_CACHED_INPUT_IMAGE_TOKENS = "gemini_last_request_cached_input_image_tokens"
  private const val LAST_REQUEST_CACHED_INPUT_VIDEO_TOKENS = "gemini_last_request_cached_input_video_tokens"
  private const val LAST_REQUEST_CACHED_INPUT_DOCUMENT_TOKENS = "gemini_last_request_cached_input_document_tokens"
  private const val LAST_REQUEST_OUTPUT_TEXT_TOKENS = "gemini_last_request_output_text_tokens"
  private const val LAST_REQUEST_OUTPUT_AUDIO_TOKENS = "gemini_last_request_output_audio_tokens"
  private const val LAST_REQUEST_OUTPUT_IMAGE_TOKENS = "gemini_last_request_output_image_tokens"
  private const val LAST_REQUEST_OUTPUT_VIDEO_TOKENS = "gemini_last_request_output_video_tokens"
  private const val LAST_REQUEST_OUTPUT_DOCUMENT_TOKENS = "gemini_last_request_output_document_tokens"

  fun getSummary(context: Context): PlyńTokenUsageSummary {
    val prefs = PlyńPreferences.getSharedPreferences(context)
    return PlyńTokenUsageSummary(
      inputTokens = prefs.getInt(INPUT_TOKENS, 0),
      cachedInputTokens = prefs.getInt(CACHED_INPUT_TOKENS, 0),
      outputTokens = prefs.getInt(OUTPUT_TOKENS, 0),
      totalTokens = prefs.getInt(TOTAL_TOKENS, 0),
      requestCount = prefs.getInt(REQUEST_COUNT, 0),
      lastRequest = PlyńTokenRequestSummary(
        inputTokens = prefs.getInt(LAST_REQUEST_INPUT_TOKENS, 0),
        cachedInputTokens = prefs.getInt(LAST_REQUEST_CACHED_INPUT_TOKENS, 0),
        outputTokens = prefs.getInt(LAST_REQUEST_OUTPUT_TOKENS, 0),
        totalTokens = prefs.getInt(LAST_REQUEST_TOTAL_TOKENS, 0),
        inputByModality = PlyńTokenModalitySummary(
          text = prefs.getInt(LAST_REQUEST_INPUT_TEXT_TOKENS, 0),
          audio = prefs.getInt(LAST_REQUEST_INPUT_AUDIO_TOKENS, 0),
          image = prefs.getInt(LAST_REQUEST_INPUT_IMAGE_TOKENS, 0),
          video = prefs.getInt(LAST_REQUEST_INPUT_VIDEO_TOKENS, 0),
          document = prefs.getInt(LAST_REQUEST_INPUT_DOCUMENT_TOKENS, 0),
        ),
        cachedInputByModality = PlyńTokenModalitySummary(
          text = prefs.getInt(LAST_REQUEST_CACHED_INPUT_TEXT_TOKENS, 0),
          audio = prefs.getInt(LAST_REQUEST_CACHED_INPUT_AUDIO_TOKENS, 0),
          image = prefs.getInt(LAST_REQUEST_CACHED_INPUT_IMAGE_TOKENS, 0),
          video = prefs.getInt(LAST_REQUEST_CACHED_INPUT_VIDEO_TOKENS, 0),
          document = prefs.getInt(LAST_REQUEST_CACHED_INPUT_DOCUMENT_TOKENS, 0),
        ),
        outputByModality = PlyńTokenModalitySummary(
          text = prefs.getInt(LAST_REQUEST_OUTPUT_TEXT_TOKENS, 0),
          audio = prefs.getInt(LAST_REQUEST_OUTPUT_AUDIO_TOKENS, 0),
          image = prefs.getInt(LAST_REQUEST_OUTPUT_IMAGE_TOKENS, 0),
          video = prefs.getInt(LAST_REQUEST_OUTPUT_VIDEO_TOKENS, 0),
          document = prefs.getInt(LAST_REQUEST_OUTPUT_DOCUMENT_TOKENS, 0),
        ),
      ),
      inputByModality = PlyńTokenModalitySummary(
        text = prefs.getInt(INPUT_TEXT_TOKENS, 0),
        audio = prefs.getInt(INPUT_AUDIO_TOKENS, 0),
        image = prefs.getInt(INPUT_IMAGE_TOKENS, 0),
        video = prefs.getInt(INPUT_VIDEO_TOKENS, 0),
        document = prefs.getInt(INPUT_DOCUMENT_TOKENS, 0),
      ),
      cachedInputByModality = PlyńTokenModalitySummary(
        text = prefs.getInt(CACHED_INPUT_TEXT_TOKENS, 0),
        audio = prefs.getInt(CACHED_INPUT_AUDIO_TOKENS, 0),
        image = prefs.getInt(CACHED_INPUT_IMAGE_TOKENS, 0),
        video = prefs.getInt(CACHED_INPUT_VIDEO_TOKENS, 0),
        document = prefs.getInt(CACHED_INPUT_DOCUMENT_TOKENS, 0),
      ),
      outputByModality = PlyńTokenModalitySummary(
        text = prefs.getInt(OUTPUT_TEXT_TOKENS, 0),
        audio = prefs.getInt(OUTPUT_AUDIO_TOKENS, 0),
        image = prefs.getInt(OUTPUT_IMAGE_TOKENS, 0),
        video = prefs.getInt(OUTPUT_VIDEO_TOKENS, 0),
        document = prefs.getInt(OUTPUT_DOCUMENT_TOKENS, 0),
      ),
    )
  }

  fun addSummary(context: Context, summary: PlyńTokenUsageSummary?) {
    if (summary == null) {
      return
    }

    val current = getSummary(context)
    PlyńPreferences.getSharedPreferences(context)
      .edit()
      .putInt(INPUT_TOKENS, current.inputTokens + summary.inputTokens)
      .putInt(CACHED_INPUT_TOKENS, current.cachedInputTokens + summary.cachedInputTokens)
      .putInt(OUTPUT_TOKENS, current.outputTokens + summary.outputTokens)
      .putInt(TOTAL_TOKENS, current.totalTokens + summary.totalTokens)
      .putInt(REQUEST_COUNT, current.requestCount + summary.requestCount)
      .putInt(INPUT_TEXT_TOKENS, current.inputByModality.text + summary.inputByModality.text)
      .putInt(INPUT_AUDIO_TOKENS, current.inputByModality.audio + summary.inputByModality.audio)
      .putInt(INPUT_IMAGE_TOKENS, current.inputByModality.image + summary.inputByModality.image)
      .putInt(INPUT_VIDEO_TOKENS, current.inputByModality.video + summary.inputByModality.video)
      .putInt(INPUT_DOCUMENT_TOKENS, current.inputByModality.document + summary.inputByModality.document)
      .putInt(CACHED_INPUT_TEXT_TOKENS, current.cachedInputByModality.text + summary.cachedInputByModality.text)
      .putInt(CACHED_INPUT_AUDIO_TOKENS, current.cachedInputByModality.audio + summary.cachedInputByModality.audio)
      .putInt(CACHED_INPUT_IMAGE_TOKENS, current.cachedInputByModality.image + summary.cachedInputByModality.image)
      .putInt(CACHED_INPUT_VIDEO_TOKENS, current.cachedInputByModality.video + summary.cachedInputByModality.video)
      .putInt(CACHED_INPUT_DOCUMENT_TOKENS, current.cachedInputByModality.document + summary.cachedInputByModality.document)
      .putInt(OUTPUT_TEXT_TOKENS, current.outputByModality.text + summary.outputByModality.text)
      .putInt(OUTPUT_AUDIO_TOKENS, current.outputByModality.audio + summary.outputByModality.audio)
      .putInt(OUTPUT_IMAGE_TOKENS, current.outputByModality.image + summary.outputByModality.image)
      .putInt(OUTPUT_VIDEO_TOKENS, current.outputByModality.video + summary.outputByModality.video)
      .putInt(OUTPUT_DOCUMENT_TOKENS, current.outputByModality.document + summary.outputByModality.document)
      .putInt(LAST_REQUEST_INPUT_TOKENS, summary.lastRequest.inputTokens)
      .putInt(LAST_REQUEST_CACHED_INPUT_TOKENS, summary.lastRequest.cachedInputTokens)
      .putInt(LAST_REQUEST_OUTPUT_TOKENS, summary.lastRequest.outputTokens)
      .putInt(LAST_REQUEST_TOTAL_TOKENS, summary.lastRequest.totalTokens)
      .putInt(LAST_REQUEST_INPUT_TEXT_TOKENS, summary.lastRequest.inputByModality.text)
      .putInt(LAST_REQUEST_INPUT_AUDIO_TOKENS, summary.lastRequest.inputByModality.audio)
      .putInt(LAST_REQUEST_INPUT_IMAGE_TOKENS, summary.lastRequest.inputByModality.image)
      .putInt(LAST_REQUEST_INPUT_VIDEO_TOKENS, summary.lastRequest.inputByModality.video)
      .putInt(LAST_REQUEST_INPUT_DOCUMENT_TOKENS, summary.lastRequest.inputByModality.document)
      .putInt(LAST_REQUEST_CACHED_INPUT_TEXT_TOKENS, summary.lastRequest.cachedInputByModality.text)
      .putInt(LAST_REQUEST_CACHED_INPUT_AUDIO_TOKENS, summary.lastRequest.cachedInputByModality.audio)
      .putInt(LAST_REQUEST_CACHED_INPUT_IMAGE_TOKENS, summary.lastRequest.cachedInputByModality.image)
      .putInt(LAST_REQUEST_CACHED_INPUT_VIDEO_TOKENS, summary.lastRequest.cachedInputByModality.video)
      .putInt(LAST_REQUEST_CACHED_INPUT_DOCUMENT_TOKENS, summary.lastRequest.cachedInputByModality.document)
      .putInt(LAST_REQUEST_OUTPUT_TEXT_TOKENS, summary.lastRequest.outputByModality.text)
      .putInt(LAST_REQUEST_OUTPUT_AUDIO_TOKENS, summary.lastRequest.outputByModality.audio)
      .putInt(LAST_REQUEST_OUTPUT_IMAGE_TOKENS, summary.lastRequest.outputByModality.image)
      .putInt(LAST_REQUEST_OUTPUT_VIDEO_TOKENS, summary.lastRequest.outputByModality.video)
      .putInt(LAST_REQUEST_OUTPUT_DOCUMENT_TOKENS, summary.lastRequest.outputByModality.document)
      .apply()
  }

  fun resetSummary(context: Context) {
    PlyńPreferences.getSharedPreferences(context)
      .edit()
      .remove(INPUT_TOKENS)
      .remove(CACHED_INPUT_TOKENS)
      .remove(OUTPUT_TOKENS)
      .remove(TOTAL_TOKENS)
      .remove(REQUEST_COUNT)
      .remove(INPUT_TEXT_TOKENS)
      .remove(INPUT_AUDIO_TOKENS)
      .remove(INPUT_IMAGE_TOKENS)
      .remove(INPUT_VIDEO_TOKENS)
      .remove(INPUT_DOCUMENT_TOKENS)
      .remove(CACHED_INPUT_TEXT_TOKENS)
      .remove(CACHED_INPUT_AUDIO_TOKENS)
      .remove(CACHED_INPUT_IMAGE_TOKENS)
      .remove(CACHED_INPUT_VIDEO_TOKENS)
      .remove(CACHED_INPUT_DOCUMENT_TOKENS)
      .remove(OUTPUT_TEXT_TOKENS)
      .remove(OUTPUT_AUDIO_TOKENS)
      .remove(OUTPUT_IMAGE_TOKENS)
      .remove(OUTPUT_VIDEO_TOKENS)
      .remove(OUTPUT_DOCUMENT_TOKENS)
      .remove(LAST_REQUEST_INPUT_TOKENS)
      .remove(LAST_REQUEST_CACHED_INPUT_TOKENS)
      .remove(LAST_REQUEST_OUTPUT_TOKENS)
      .remove(LAST_REQUEST_TOTAL_TOKENS)
      .remove(LAST_REQUEST_INPUT_TEXT_TOKENS)
      .remove(LAST_REQUEST_INPUT_AUDIO_TOKENS)
      .remove(LAST_REQUEST_INPUT_IMAGE_TOKENS)
      .remove(LAST_REQUEST_INPUT_VIDEO_TOKENS)
      .remove(LAST_REQUEST_INPUT_DOCUMENT_TOKENS)
      .remove(LAST_REQUEST_CACHED_INPUT_TEXT_TOKENS)
      .remove(LAST_REQUEST_CACHED_INPUT_AUDIO_TOKENS)
      .remove(LAST_REQUEST_CACHED_INPUT_IMAGE_TOKENS)
      .remove(LAST_REQUEST_CACHED_INPUT_VIDEO_TOKENS)
      .remove(LAST_REQUEST_CACHED_INPUT_DOCUMENT_TOKENS)
      .remove(LAST_REQUEST_OUTPUT_TEXT_TOKENS)
      .remove(LAST_REQUEST_OUTPUT_AUDIO_TOKENS)
      .remove(LAST_REQUEST_OUTPUT_IMAGE_TOKENS)
      .remove(LAST_REQUEST_OUTPUT_VIDEO_TOKENS)
      .remove(LAST_REQUEST_OUTPUT_DOCUMENT_TOKENS)
      .apply()
  }
}
