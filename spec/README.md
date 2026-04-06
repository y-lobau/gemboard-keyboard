# Gemboard Specification

## Overview
Gemboard is a React Native application with native keyboard integrations for speech-to-text.

## Platform behavior
- Android provides a system keyboard implemented as an `InputMethodService`.
- The Android keyboard exposes a press-and-hold microphone control, records audio while held, sends the captured speech to Gemini, and commits the returned transcript into the active text input.
- iOS provides an in-app composer experience instead of a system keyboard extension for speech capture. The composer shows the standard iOS keyboard and an accessory bar above it with a press-and-hold microphone control.
- The iOS accessory bar records audio while held, sends the captured speech to Gemini, and inserts the returned transcript into the current text field.

## Configuration
- The host app stores the Gemini API key locally on-device.
- The host app shows whether a key has been saved.
- Android keyboard code reads the stored API key from shared app storage.

## Failure handling
- If no API key is available, speech capture must not attempt transcription and the user must see a clear setup error.
- If transcription fails, the existing text stays unchanged and the user sees an error or retry-ready status.

