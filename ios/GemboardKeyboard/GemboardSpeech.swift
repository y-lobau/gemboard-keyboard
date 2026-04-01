import AVFoundation
import Foundation
import React

@objc(GemboardSpeech)
final class GemboardSpeech: NSObject {
  private let apiKeyKey = "gemini_api_key"
  private var recorder: AVAudioRecorder?
  private var outputURL: URL?

  @objc
  func startRecording(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
      try session.setActive(true)

      let url = FileManager.default.temporaryDirectory.appendingPathComponent("gemboard-ios.wav")
      outputURL = url

      let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
      ]

      let recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder.prepareToRecord()

      guard recorder.record() else {
        throw NSError(domain: "GemboardSpeech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording could not start."])
      }

      self.recorder = recorder
      resolve(nil)
    } catch {
      reject("recording_error", error.localizedDescription, error)
    }
  }

  @objc
  func stopRecording(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    recorder?.stop()
    recorder = nil

    guard let outputURL else {
      reject("missing_audio", "No captured audio was available.", nil)
      return
    }

    guard let apiKey = UserDefaults.standard.string(forKey: apiKeyKey), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      reject("missing_key", "Save your Gemini API key before recording.", nil)
      return
    }

    do {
      let audioData = try Data(contentsOf: outputURL)
      transcribe(audioData: audioData, apiKey: apiKey, resolve: resolve, reject: reject)
    } catch {
      reject("audio_read_error", error.localizedDescription, error)
    }
  }

  private func transcribe(
    audioData: Data,
    apiKey: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)") else {
      reject("bad_url", "Gemini endpoint could not be created.", nil)
      return
    }

    let body: [String: Any] = [
      "contents": [[
        "parts": [
          ["text": "Transcribe this speech into plain text only. Return only the transcript."],
          [
            "inlineData": [
              "mimeType": "audio/wav",
              "data": audioData.base64EncodedString(),
            ],
          ],
        ],
      ]],
    ]

    do {
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: body)

      URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
          reject("network_error", error.localizedDescription, error)
          return
        }

        guard let httpResponse = response as? HTTPURLResponse, let data else {
          reject("response_error", "Gemini did not return a valid response.", nil)
          return
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
          let message = String(data: data, encoding: .utf8) ?? "Gemini request failed."
          reject("gemini_error", message, nil)
          return
        }

        do {
          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
          let transcript = GemboardSpeech.extractTranscript(from: json)
          resolve(transcript)
        } catch {
          reject("parse_error", error.localizedDescription, error)
        }
      }.resume()
    } catch {
      reject("request_error", error.localizedDescription, error)
    }
  }

  private static func extractTranscript(from json: [String: Any]?) -> String {
    guard
      let json,
      let candidates = json["candidates"] as? [[String: Any]],
      let content = candidates.first?["content"] as? [String: Any],
      let parts = content["parts"] as? [[String: Any]]
    else {
      return ""
    }

    return parts.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
