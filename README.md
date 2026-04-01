# Gemboard

Gemboard is a React Native speech-to-text keyboard prototype backed by Gemini.

## What ships today
- Android includes a native `InputMethodService` keyboard with a hold-to-talk microphone button, space, and delete.
- iOS includes an in-app composer that uses the system keyboard plus an accessory bar with a hold-to-talk microphone button.
- The host app stores the Gemini API key locally on-device so the native layers can read it.

## Important platform note
- Android can behave like a real system keyboard.
- iOS custom keyboard extensions do not get a practical microphone path for this feature, so the current iOS implementation is intentionally in-app rather than system-wide.

## Running locally

### Metro
```sh
npm start
```

### iOS
```sh
cd ios
bundle install
bundle exec pod install
cd ..
npm run ios
```

### Android
```sh
npm run android
```

## Using the app
1. Launch the app.
2. Paste a Gemini API key and save it.
3. On Android, enable Gemboard in system keyboard settings and switch to it.
4. Hold the microphone button, speak, and release to send audio to Gemini.

## Test suite
```sh
make test
```

## Security note
This prototype stores the Gemini API key on-device for local development convenience. A production version should proxy Gemini requests through your own backend instead of shipping the API key in the client.
