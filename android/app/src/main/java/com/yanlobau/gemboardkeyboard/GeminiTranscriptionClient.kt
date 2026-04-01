package com.yanlobau.gemboardkeyboard

import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class GeminiTranscriptionClient {
  fun transcribe(apiKey: String, audioFile: File): String {
    val endpoint = URL(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey",
    )
    val connection = (endpoint.openConnection() as HttpURLConnection).apply {
      requestMethod = "POST"
      doOutput = true
      setRequestProperty("Content-Type", "application/json")
      connectTimeout = 30_000
      readTimeout = 60_000
    }

    val parts = JSONArray()
      .put(JSONObject().put("text", "Transcribe this speech into plain text only. Return only the transcript."))
      .put(
        JSONObject().put(
          "inlineData",
          JSONObject()
            .put("mimeType", "audio/wav")
            .put("data", Base64.encodeToString(audioFile.readBytes(), Base64.NO_WRAP)),
        ),
      )

    val body = JSONObject().put("contents", JSONArray().put(JSONObject().put("parts", parts)))

    connection.outputStream.use { output ->
      output.write(body.toString().toByteArray(Charsets.UTF_8))
    }

    val stream = if (connection.responseCode in 200..299) connection.inputStream else connection.errorStream
    val response = stream.use { input ->
      BufferedReader(InputStreamReader(input)).readText()
    }

    if (connection.responseCode !in 200..299) {
      throw IllegalStateException("Gemini request failed: ${connection.responseCode} $response")
    }

    return parseTranscript(response)
  }

  private fun parseTranscript(response: String): String {
    val root = JSONObject(response)
    val candidates = root.optJSONArray("candidates") ?: return ""
    if (candidates.length() == 0) {
      return ""
    }

    val parts = candidates.getJSONObject(0)
      .optJSONObject("content")
      ?.optJSONArray("parts") ?: return ""

    val transcript = buildString {
      for (index in 0 until parts.length()) {
        append(parts.getJSONObject(index).optString("text"))
      }
    }

    return transcript.trim()
  }
}
