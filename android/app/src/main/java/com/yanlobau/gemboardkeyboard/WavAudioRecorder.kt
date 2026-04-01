package com.yanlobau.gemboardkeyboard

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

class WavAudioRecorder(private val outputFile: File) {
  private val sampleRate = 16_000
  private val channelConfig = AudioFormat.CHANNEL_IN_MONO
  private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
  private val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 2
  private val isRecording = AtomicBoolean(false)
  private var audioRecord: AudioRecord? = null
  private var writerThread: Thread? = null

  fun start() {
    if (isRecording.get()) {
      return
    }

    val recorder = AudioRecord(
      MediaRecorder.AudioSource.MIC,
      sampleRate,
      channelConfig,
      audioFormat,
      bufferSize,
    )

    if (recorder.state != AudioRecord.STATE_INITIALIZED) {
      recorder.release()
      throw IllegalStateException("Microphone could not be initialized.")
    }

    audioRecord = recorder
    isRecording.set(true)
    writerThread = Thread { writeWav(recorder) }.also { it.start() }
    recorder.startRecording()
  }

  fun stop(): File {
    if (!isRecording.get()) {
      return outputFile
    }

    isRecording.set(false)
    audioRecord?.stop()
    writerThread?.join()
    audioRecord?.release()
    audioRecord = null
    writerThread = null
    return outputFile
  }

  @Throws(IOException::class)
  private fun writeWav(recorder: AudioRecord) {
    FileOutputStream(outputFile).use { output ->
      output.write(ByteArray(44))
      val data = ByteArray(bufferSize)
      var totalBytes = 0

      while (isRecording.get()) {
        val read = recorder.read(data, 0, data.size)
        if (read > 0) {
          output.write(data, 0, read)
          totalBytes += read
        }
      }

      output.channel.position(0)
      output.write(createHeader(totalBytes))
    }
  }

  private fun createHeader(totalAudioLength: Int): ByteArray {
    val totalDataLength = totalAudioLength + 36
    val byteRate = sampleRate * 2
    val header = ByteArray(44)

    header[0] = 'R'.code.toByte()
    header[1] = 'I'.code.toByte()
    header[2] = 'F'.code.toByte()
    header[3] = 'F'.code.toByte()
    writeInt(header, 4, totalDataLength)
    header[8] = 'W'.code.toByte()
    header[9] = 'A'.code.toByte()
    header[10] = 'V'.code.toByte()
    header[11] = 'E'.code.toByte()
    header[12] = 'f'.code.toByte()
    header[13] = 'm'.code.toByte()
    header[14] = 't'.code.toByte()
    header[15] = ' '.code.toByte()
    writeInt(header, 16, 16)
    writeShort(header, 20, 1)
    writeShort(header, 22, 1)
    writeInt(header, 24, sampleRate)
    writeInt(header, 28, byteRate)
    writeShort(header, 32, 2)
    writeShort(header, 34, 16)
    header[36] = 'd'.code.toByte()
    header[37] = 'a'.code.toByte()
    header[38] = 't'.code.toByte()
    header[39] = 'a'.code.toByte()
    writeInt(header, 40, totalAudioLength)
    return header
  }

  private fun writeInt(header: ByteArray, offset: Int, value: Int) {
    header[offset] = (value and 0xff).toByte()
    header[offset + 1] = (value shr 8 and 0xff).toByte()
    header[offset + 2] = (value shr 16 and 0xff).toByte()
    header[offset + 3] = (value shr 24 and 0xff).toByte()
  }

  private fun writeShort(header: ByteArray, offset: Int, value: Int) {
    header[offset] = (value and 0xff).toByte()
    header[offset + 1] = (value shr 8 and 0xff).toByte()
  }
}
