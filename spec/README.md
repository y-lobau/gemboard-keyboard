# Plyń Specification

## Overview

Plyń is a React Native application with native keyboard integrations for speech-to-text.

## Transcription language

- Plyń accepts speech input only for Belarusian dictation.
- Gemini transcription requests must return transcript text only in Belarusian.
- The transcription flow must not answer requests, translate into other languages, or emit non-Belarusian output.

## Platform behavior

- Android provides a system keyboard implemented as an `InputMethodService`.
- The Android keyboard exposes a press-and-hold microphone control, records audio while held, and only starts Gemini transcription after the user releases the microphone.
- After the user releases the Android keyboard microphone, Gemini transcript text must appear progressively in the active input as streamed transcript snapshots arrive, without duplicating already inserted text or collapsing required spaces between words.
- Android progressive dictation must use IME-safe provisional insertion while Gemini is still streaming and settle the latest transcript snapshot once the streamed response finishes.
- iOS provides a system keyboard extension that can be enabled from iPhone keyboard settings.
- The iOS keyboard extension shows only a compact erase control, a microphone control, and a live speech-wave indicator in its main layout.
- The iOS keyboard extension microphone records only while the user keeps the button pressed and stops when the press ends.
- The iOS keyboard extension erase control removes the previous word during normal ready-state editing, but if the cursor is on an empty line immediately after a newline, it removes only that newline boundary.
- While the iOS keyboard is recording or waiting for the companion session to accept or finish a transcription request, the erase, space, enter, and microphone controls must be visibly inactive.
- The iOS companion app automatically starts a background recording session when a saved Gemini API key is available and microphone access is granted.
- While that iOS companion session is active, the keyboard extension can trigger speech capture, receive the Gemini transcript through shared app-group storage, and insert it into the active text input without a manual round trip through the app for each utterance.
- When the iOS keyboard extension leaves the screen while the companion app remains backgrounded, the companion session must stop and release its audio session so other audio playback outside the keyboard is not blocked.
- When the user returns to the iOS keyboard extension, the companion app must automatically try to restore the companion session again so dictation becomes available without requiring a separate manual stop-start step.
- After the user releases the iOS keyboard microphone, the companion session must publish streamed Gemini transcript snapshots into shared app-group storage so the keyboard extension can update the active text input progressively.
- The iOS keyboard extension must treat each shared transcript update as the latest full snapshot for the active utterance, replace only its own provisional insertion, and avoid duplicating text or collapsing required spaces if newer snapshots arrive.
- Streamed transcript assembly must preserve chunk-boundary whitespace emitted by Gemini so words do not merge when a required separator arrives at the end of one chunk or as its own chunk.
- If the iOS keyboard microphone is pressed while the companion session is inactive, the keyboard must open the companion app so it can restore the session.
- The host app main tab starts with Gemini API-key setup, then shows a compact onboarding summary with expandable details, followed by a text draft area.
- Once the Gemini API key is already saved, the first setup section collapses into a single tappable `Set up` header and expands the full setup controls only when the user opens it.
- The expandable onboarding details explain what an active companion session means and include platform help buttons for keyboard enablement plus the manual companion-session controls on iOS.
- The host app must persist the expanded or collapsed state of its collapsible sections so the same section state returns after the app restarts.
- When the app or keyboard appends a new dictated utterance into existing text, it must insert separator whitespace when needed so consecutive sentences do not run together.
- The host app must show whether the companion session is currently active and refresh that state while the app is open.

## Configuration

- The host app stores the Gemini API key locally on-device.
- The host app shows whether a key has been saved.
- The host app connects to Firebase Remote Config for runtime Gemini settings.
- The host app connects to Firebase Analytics for product telemetry.
- The host app connects to Firebase Crashlytics for crash reporting on iOS and Android.
- Firebase Remote Config defines nine runtime Gemini values for this app: the LLM model name, the system prompt, two keyboard timeout values named `keyboard_command_timeout_seconds` and `keyboard_transcription_timeout_seconds`, and five transcription cost rates named `gemini_cost_input_text`, `gemini_cost_input_audio`, `gemini_cost_input_cache_text`, `gemini_cost_input_cache_audio`, and `gemini_cost_output_text`.
- On app startup, the host app fetches those Firebase Remote Config values on both iOS and Android, persists the model, system prompt, and keyboard timeout values into native shared storage for the current platform, and uses the cost rates to render dollar totals in the host-app transcription-cost summary.
- On app startup, the host app records analytics events for screen views, Remote Config sync outcomes, key setup or session actions that happen in the companion UI, and initializes Crashlytics collection for the current platform.
- If Firebase Remote Config cannot be accessed, the host app must send a non-fatal Crashlytics error with context about the failed sync while continuing to use the existing fallback runtime behavior.
- When a new keyboard dictation session starts, the platform-native dictation flow refreshes Firebase Remote Config before the transcription request is built so the current transcription can use the latest Gemini model and system prompt without requiring a full app relaunch.
- When a dictation request reaches Gemini, the app records analytics for the dictation outcome, Gemini latency, and output-size bucket without storing transcript text.
- The host app stores cumulative Gemini token usage totals for successful requests only, also keeps the token stats for the latest successful Gemini request on that device, and exposes both in a collapsed-by-default summary card titled `Кошт транскрыпцыі`.
- When expanded, that summary card shows three groups in this order: `Апошні запыт`, `Усяго`, and `Сярэдняе на запыт`.
- The `avg per request` group derives its values from the cumulative token totals divided by the count of successful Gemini requests on that device.
- Each row in that summary shows the token total and the computed dollar cost in the format `tokens / dollars`, and the value column is labeled `токены/$`.
- The transcription cost rates from Firebase Remote Config are interpreted as dollar prices per 1,000,000 tokens, so the UI computes each row cost as `(tokens / 1_000_000) * rate`.
- The expanded transcription-cost summary includes a compact reset action that clears both the latest-request token stats and the cumulative token totals on the current device.
- In development builds, the host app exposes a manual Crashlytics test action so a debug build can send a real crash report during verification.
- Android keyboard code reads the stored API key from shared app storage.
- Android keyboard code reads the persisted Gemini model and system prompt from shared app storage.
- Android keyboard code records analytics for dictation attempts, blocked states, outcomes, and Gemini latency buckets.
- iOS host app and keyboard extension share configuration and transcript handoff state through a shared app-group container.
- The iOS host app persists the fetched Gemini model and system prompt into the shared app-group container so the keyboard extension uses the same runtime configuration.
- The host app persists the `Як гэта працуе`, `Наладзьце Plyń`, and `Кошт транскрыпцыі` expand/collapse preferences in native local storage.
- The token-usage summary keeps separate cumulative buckets for input, cached-input, and output token counts by Gemini modality such as text and audio when those modality details are present in the response.
- When Gemini omits output modality details but still returns aggregate output tokens, the host app treats the displayed `OUT > text` value as that aggregate output total.
- The iOS host app explains how to enable the Plyń keyboard and when full access is required.
- The iOS host app shows whether the companion background session is active and can retry activation if it stops.
- If the iOS host app saves a Gemini API key successfully but cannot restart the companion session immediately afterward, it must still confirm that the key was saved and separately report that the companion session is inactive.
- The iOS host app accepts a `plyn://session` deep link that brings the app into the foreground and immediately tries to restore the companion session.
- If the iOS companion session is interrupted or suspended by another app's audio session, returning to the companion app must retry that background session automatically so the keyboard can recover without requiring a full app relaunch.
- After the user reopens the iOS companion app to restore that session, the keyboard must keep treating the companion as available for a short handoff window so an immediate return to the keyboard does not fall back into the same `open companion app` loop.
- The host app accepts a `plyn://debug/launch` deep link that opens an in-app full-screen preview of the iOS loading view using the same launch logo artwork and background color for visual verification.

## Failure handling

- If no API key is available, speech capture must not attempt transcription and the user must see a clear setup error.
- If Firebase Remote Config fetch fails, the app and keyboard must keep using the last persisted Gemini runtime configuration and otherwise fall back to the bundled default Gemini model `gemini-3.1-flash-preview`, the bundled default system prompt, and the bundled default keyboard timeout values.
- If Firebase Remote Config returns empty runtime transcription values and no persisted Gemini runtime configuration is available yet, the app must seed native storage with the bundled default Gemini model `gemini-3.1-flash-preview`, the bundled default system prompt, and the bundled default keyboard timeout values so speech capture can still proceed.
- If transcription fails, the existing text stays unchanged and the user sees an error or retry-ready status.
- If Gemini fails before any streamed transcript snapshot is inserted, the existing text stays unchanged and the user sees an error or retry-ready status.
- If Gemini fails after one or more streamed transcript snapshots were already inserted, the latest inserted snapshot remains in place, no duplicate text is inserted, and the keyboard shows an error or retry-ready status.
- If the iOS keyboard does not have a fresh shared transcript, inserting from the extension must leave the current text unchanged and show a ready-to-record hint instead.
- If the iOS keyboard tries to capture speech without an active companion session, it must instruct the user to reopen Plyń so the session can be re-established.
- If the iOS keyboard does not receive a timely response from the companion session after a capture command or while waiting for transcription to finish, it must show a clear companion-not-responding error.
- In that companion-not-responding state, pressing the keyboard microphone must reopen the Companion app through the session recovery deep link so the app can immediately try to restart the session.
- If automatic return to the keyboard is not available after reopening the iOS companion app, the app must still make the restored session state obvious so the user knows the keyboard can be used again.
- Streamed dictation updates on both platforms must be session-bound so stale updates from an older utterance or a cancelled capture do not insert text into a newer editing context.
