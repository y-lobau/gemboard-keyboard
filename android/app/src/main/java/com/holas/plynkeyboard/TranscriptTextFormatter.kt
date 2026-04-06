package com.holas.plynkeyboard

import org.json.JSONArray
import kotlin.math.min

object TranscriptTextFormatter {
  fun mergeStreamTranscript(existing: String, incoming: String): String {
    if (incoming.isEmpty()) {
      return existing
    }

    if (incoming.isBlank()) {
      return existing
    }

    if (existing.isEmpty()) {
      return incoming
    }

    if (incoming.startsWith(existing)) {
      return incoming
    }

    if (existing.startsWith(incoming)) {
      return existing
    }

    val maxOverlap = min(existing.length, incoming.length)
    for (overlap in maxOverlap downTo 1) {
      if (existing.takeLast(overlap) == incoming.take(overlap)) {
        return existing + incoming.drop(overlap)
      }
    }

    return existing + incoming
  }

  fun joinParts(parts: JSONArray): String {
    return buildString {
      for (index in 0 until parts.length()) {
        append(parts.optJSONObject(index)?.optString("text").orEmpty())
      }
    }
  }

  fun insertionPrefix(existingContextBeforeCursor: String?, incoming: String): String {
    val normalizedIncoming = incoming.trim()
    if (normalizedIncoming.isEmpty()) {
      return ""
    }

    return if (shouldInsertSeparator(existingContextBeforeCursor.orEmpty(), normalizedIncoming)) {
      " "
    } else {
      ""
    }
  }

  private fun shouldInsertSeparator(leftText: String, rightText: String): Boolean {
    val leftIndex = leftText.indexOfLast { !it.isWhitespace() }
    val rightIndex = rightText.indexOfFirst { !it.isWhitespace() }
    if (leftIndex < 0 || rightIndex < 0) {
      return false
    }

    val left = leftText[leftIndex]
    val right = rightText[rightIndex]

    if (isClosingPunctuation(right) || isOpeningDelimiter(left)) {
      return false
    }

    if (left == '-' || left == '\'' || left == '’') {
      return false
    }

    if (right == '-' || right == '\'' || right == '’') {
      return false
    }

    if (
      leftIndex > 0 &&
      (left == '.' || left == ',') &&
      leftText[leftIndex - 1].isDigit() &&
      right.isDigit()
    ) {
      return false
    }

    if (left.isLetterOrDigit() && right.isLetterOrDigit()) {
      return true
    }

    if (isSpacingPunctuation(left) && (right.isLetterOrDigit() || isQuoteLike(right))) {
      return true
    }

    return (left == ')' || left == ']' || left == '}' || isQuoteLike(left)) && right.isLetterOrDigit()
  }

  private fun isClosingPunctuation(value: Char): Boolean {
    return value in charArrayOf('.', ',', '!', '?', ';', ':', '%', ')', ']', '}')
  }

  private fun isOpeningDelimiter(value: Char): Boolean {
    return value in charArrayOf('(', '[', '{')
  }

  private fun isSpacingPunctuation(value: Char): Boolean {
    return value in charArrayOf('.', ',', '!', '?', ';', ':')
  }

  private fun isQuoteLike(value: Char): Boolean {
    return value in charArrayOf('"', '\'', '“', '”', '«', '»')
  }
}
