package com.holas.plynkeyboard

import android.content.Context
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class GeminiTranscriptionClient {
  data class TranscriptSnapshot(
    val revision: Int,
    val text: String,
    val isFinal: Boolean,
  )

  data class TranscriptionResult(
    val transcript: String,
    val usageSummary: PlynTokenUsageSummary?,
  )

  private val userInstruction =
    "Transcribe this audio as Belarusian dictation. Return only Belarusian transcript text."

  fun transcribeStream(
    context: Context,
    apiKey: String,
    audioFile: File,
    onSnapshot: (TranscriptSnapshot) -> Unit,
  ): TranscriptionResult {
    val model = GeminiRuntimeConfig.model(context)
      ?: throw IllegalStateException("Адкрыйце Plyń, каб атрымаць канфігурацыю дыктоўкі з Firebase.")
    val systemInstruction = GeminiRuntimeConfig.systemPrompt(context)
    val endpoint = URL(
      "https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse&key=$apiKey",
    )
    val connection = (endpoint.openConnection() as HttpURLConnection).apply {
      requestMethod = "POST"
      doOutput = true
      setRequestProperty("Content-Type", "application/json")
      setRequestProperty("Accept", "text/event-stream")
      connectTimeout = 30_000
      readTimeout = 60_000
    }

    val parts = JSONArray()
      .put(JSONObject().put("text", userInstruction))
      .put(
        JSONObject().put(
          "inlineData",
          JSONObject()
            .put("mimeType", "audio/wav")
            .put("data", Base64.encodeToString(audioFile.readBytes(), Base64.NO_WRAP)),
        ),
      )

    val body = JSONObject()
      .put(
        "system_instruction",
        JSONObject().put("parts", JSONArray().put(JSONObject().put("text", systemInstruction))),
      )
      .put("contents", JSONArray().put(JSONObject().put("parts", parts)))

    connection.outputStream.use { output ->
      output.write(body.toString().toByteArray(Charsets.UTF_8))
    }

    val stream = if (connection.responseCode in 200..299) connection.inputStream else connection.errorStream

    if (connection.responseCode !in 200..299) {
      val response = stream.use { input ->
        BufferedReader(InputStreamReader(input)).readText()
      }
      throw IllegalStateException("Gemini request failed: ${connection.responseCode} $response")
    }

    var transcript = ""
    var revision = 0
    var latestUsageSummary: PlynTokenUsageSummary? = null

    stream.use { input ->
      BufferedReader(InputStreamReader(input)).use { reader ->
        val eventLines = mutableListOf<String>()

        while (true) {
          val line = reader.readLine() ?: break

          if (line.isBlank()) {
            val eventPayload = parseEventPayload(eventLines)
            eventLines.clear()

            if (eventPayload.isNullOrEmpty()) {
              continue
            }

            latestUsageSummary = PlynTokenUsageSummary.fromStreamPayload(eventPayload) ?: latestUsageSummary
            val chunkText = extractTranscriptFromStreamPayload(eventPayload)

            if (chunkText.isEmpty()) {
              continue
            }

            transcript = TranscriptTextFormatter.mergeStreamTranscript(transcript, chunkText)
            revision += 1
            onSnapshot(TranscriptSnapshot(revision = revision, text = transcript.trim(), isFinal = false))
            continue
          }

          if (line.startsWith("data:")) {
            eventLines.add(line.removePrefix("data:").trimStart())
          }
        }

        val trailingPayload = parseEventPayload(eventLines)
        if (!trailingPayload.isNullOrEmpty()) {
          latestUsageSummary = PlynTokenUsageSummary.fromStreamPayload(trailingPayload) ?: latestUsageSummary
          val trailingChunk = extractTranscriptFromStreamPayload(trailingPayload)

          if (!trailingChunk.isNullOrEmpty()) {
            transcript = TranscriptTextFormatter.mergeStreamTranscript(transcript, trailingChunk)
            revision += 1
            onSnapshot(TranscriptSnapshot(revision = revision, text = transcript.trim(), isFinal = false))
          }
        }
      }
    }

    val finalTranscript = transcript.trim()
    onSnapshot(
      TranscriptSnapshot(
        revision = revision + 1,
        text = finalTranscript,
        isFinal = true,
      ),
    )

    return TranscriptionResult(transcript = finalTranscript, usageSummary = latestUsageSummary)
  }

  private fun parseEventPayload(eventLines: List<String>): String? {
    if (eventLines.isEmpty()) {
      return null
    }

    val eventPayload = eventLines.joinToString(separator = "\n").trim()
    if (eventPayload.isEmpty() || eventPayload == "[DONE]") {
      return null
    }

    return eventPayload
  }

  private fun extractTranscriptFromStreamPayload(payload: String): String {
    val normalizedPayload = payload.trim()
    if (normalizedPayload.isEmpty() || normalizedPayload == "[DONE]") {
      return ""
    }

    return try {
      if (normalizedPayload.startsWith("[")) {
        val chunks = JSONArray(normalizedPayload)

        for (index in 0 until chunks.length()) {
          val transcript = extractTranscriptFromJson(chunks.optJSONObject(index))
          if (transcript.isNotEmpty()) {
            return transcript
          }
        }

        ""
      } else {
        extractTranscriptFromJson(JSONObject(normalizedPayload))
      }
    } catch (_: Exception) {
      ""
    }
  }

  private fun extractTranscriptFromJson(response: JSONObject?): String {
    val candidates = response?.optJSONArray("candidates") ?: return ""
    if (candidates.length() == 0) {
      return ""
    }

    val parts = candidates.optJSONObject(0)
      ?.optJSONObject("content")
      ?.optJSONArray("parts") ?: return ""

    return TranscriptTextFormatter.joinParts(parts)
  }
}
