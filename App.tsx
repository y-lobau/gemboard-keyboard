import React, {useEffect, useMemo, useState} from 'react';
import {
  ActivityIndicator,
  Alert,
  InputAccessoryView,
  NativeModules,
  PermissionsAndroid,
  Platform,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';

type NativeStatus = {
  hasApiKey: boolean;
  platformMode: 'android-ime' | 'ios-accessory' | 'unsupported';
};

type ConfigModule = {
  getStatus: () => Promise<NativeStatus>;
  saveApiKey: (key: string) => Promise<void>;
};

type SpeechModule = {
  startRecording: () => Promise<void>;
  stopRecording: () => Promise<string>;
};

const fallbackConfigModule: ConfigModule = {
  getStatus: async () => ({
    hasApiKey: false,
    platformMode: Platform.OS === 'ios' ? 'ios-accessory' : 'android-ime',
  }),
  saveApiKey: async () => undefined,
};

const fallbackSpeechModule: SpeechModule = {
  startRecording: async () => {
    throw new Error('Speech capture is not available in this build.');
  },
  stopRecording: async () => '',
};

const accessoryId = 'gemboard-accessory';

function App(): React.JSX.Element {
  const configModule = useMemo<ConfigModule>(() => NativeModules.GemboardConfig ?? fallbackConfigModule, []);
  const speechModule = useMemo<SpeechModule>(() => NativeModules.GemboardSpeech ?? fallbackSpeechModule, []);
  const [apiKey, setApiKey] = useState('');
  const [draft, setDraft] = useState('');
  const [statusMessage, setStatusMessage] = useState('Checking device status...');
  const [hasApiKey, setHasApiKey] = useState(false);
  const [platformMode, setPlatformMode] = useState<NativeStatus['platformMode']>('unsupported');
  const [saving, setSaving] = useState(false);
  const [recording, setRecording] = useState(false);
  const [transcribing, setTranscribing] = useState(false);

  useEffect(() => {
    let active = true;

    const loadStatus = async () => {
      try {
        const status = await configModule.getStatus();

        if (!active) {
          return;
        }

        setHasApiKey(status.hasApiKey);
        setPlatformMode(status.platformMode);
        setStatusMessage(
          status.hasApiKey
            ? 'API key saved on this device.'
            : 'Save your Gemini API key to unlock transcription.',
        );
      } catch (error) {
        if (!active) {
          return;
        }

        setStatusMessage(getErrorMessage(error));
      }
    };

    loadStatus();

    return () => {
      active = false;
    };
  }, [configModule]);

  const platformSummary = useMemo(() => {
    if (platformMode === 'ios-accessory') {
      return 'iOS mode: in-app accessory bar above the system keyboard.';
    }

    if (platformMode === 'android-ime') {
      return 'Android mode: save the key here, then enable Gemboard as a system keyboard.';
    }

    return 'This build exposes the host app only.';
  }, [platformMode]);

  const handleSaveKey = async () => {
    if (!apiKey.trim()) {
      setStatusMessage('Paste a Gemini API key before saving.');
      return;
    }

    setSaving(true);

    try {
      await configModule.saveApiKey(apiKey.trim());
      setHasApiKey(true);
      setStatusMessage('API key saved on this device.');
      setApiKey('');
    } catch (error) {
      setStatusMessage(getErrorMessage(error));
    } finally {
      setSaving(false);
    }
  };

  const handlePressIn = async () => {
    if (!hasApiKey) {
      setStatusMessage('Save your Gemini API key before recording.');
      return;
    }

    if (Platform.OS === 'android') {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
        {
          title: 'Microphone access for Gemboard',
          message: 'Gemboard needs microphone access to capture audio for Gemini transcription.',
          buttonPositive: 'Allow',
          buttonNegative: 'Not now',
        },
      );

      if (granted !== PermissionsAndroid.RESULTS.GRANTED) {
        setStatusMessage('Microphone permission is required for speech capture.');
        return;
      }
    }

    try {
      setRecording(true);
      setStatusMessage('Listening... release to transcribe.');
      await speechModule.startRecording();
    } catch (error) {
      setRecording(false);
      setStatusMessage(getErrorMessage(error));
    }
  };

  const handlePressOut = async () => {
    if (!recording) {
      return;
    }

    setRecording(false);
    setTranscribing(true);
    setStatusMessage('Transcribing with Gemini...');

    try {
      const transcript = (await speechModule.stopRecording()).trim();

      if (!transcript) {
        setStatusMessage('No speech was detected. Try again.');
        return;
      }

      setDraft(current => joinTranscript(current, transcript));
      setStatusMessage('Transcript inserted into the composer.');
    } catch (error) {
      setStatusMessage(getErrorMessage(error));
    } finally {
      setTranscribing(false);
    }
  };

  const handleAndroidEnableHint = () => {
    Alert.alert(
      'Enable Gemboard on Android',
      'After saving your API key, open Android Settings > System > Keyboard > On-screen keyboard and enable Gemboard. Then select it from the keyboard switcher.',
    );
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar barStyle="light-content" />
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.eyebrow}>Gemini speech keyboard</Text>
        <Text style={styles.title}>Gemboard</Text>
        <Text style={styles.lead}>
          A keyboard companion that turns press-and-hold speech into text and inserts it into the active composer.
        </Text>

        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Device mode</Text>
          <Text style={styles.body}>{platformSummary}</Text>
          <Text style={styles.status}>{statusMessage}</Text>
        </View>

        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Gemini setup</Text>
          <TextInput
            autoCapitalize="none"
            autoCorrect={false}
            placeholder="Paste Gemini API key"
            placeholderTextColor="#73808f"
            secureTextEntry
            style={styles.input}
            value={apiKey}
            onChangeText={setApiKey}
          />

          <Pressable
            accessibilityLabel="Save API key"
            disabled={saving}
            style={({pressed}) => [styles.primaryButton, pressed && styles.primaryButtonPressed, saving && styles.buttonDisabled]}
            onPress={handleSaveKey}>
            <Text style={styles.primaryButtonLabel}>{saving ? 'Saving...' : 'Save API key'}</Text>
          </Pressable>

          {Platform.OS === 'android' ? (
            <Pressable
              accessibilityLabel="Enable Android keyboard"
              style={({pressed}) => [styles.secondaryButton, pressed && styles.secondaryButtonPressed]}
              onPress={handleAndroidEnableHint}>
              <Text style={styles.secondaryButtonLabel}>How to enable the Android keyboard</Text>
            </Pressable>
          ) : null}
        </View>

        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Demo composer</Text>
          <Text style={styles.body}>
            On iOS the microphone sits in the accessory bar above the system keyboard. On Android this text area mirrors the insertion target used by the keyboard service.
          </Text>
          <TextInput
            multiline
            inputAccessoryViewID={Platform.OS === 'ios' ? accessoryId : undefined}
            placeholder="Type here or use speech"
            placeholderTextColor="#73808f"
            style={styles.composer}
            value={draft}
            onChangeText={setDraft}
          />
        </View>
      </ScrollView>

      {Platform.OS === 'ios' ? (
        <InputAccessoryView nativeID={accessoryId}>
          <View style={styles.accessoryBar}>
            <Pressable
              accessibilityLabel="Hold to speak"
              style={({pressed}) => [styles.holdButton, pressed && styles.holdButtonPressed, (transcribing || !hasApiKey) && styles.buttonDisabled]}
              onPressIn={handlePressIn}
              onPressOut={handlePressOut}>
              <Text style={styles.holdButtonLabel}>{recording ? 'Listening...' : 'Hold to speak'}</Text>
            </Pressable>
            {transcribing ? <ActivityIndicator color="#f8fafc" /> : null}
          </View>
        </InputAccessoryView>
      ) : null}
    </SafeAreaView>
  );
}

function joinTranscript(current: string, transcript: string) {
  if (!current.trim()) {
    return transcript;
  }

  return `${current.trimEnd()} ${transcript}`;
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return 'Something went wrong while talking to Gemini.';
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#102033',
  },
  content: {
    padding: 20,
    paddingBottom: 36,
    gap: 16,
    backgroundColor: '#102033',
  },
  eyebrow: {
    color: '#91f2c2',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 1.4,
    textTransform: 'uppercase',
  },
  title: {
    color: '#f8fafc',
    fontSize: 40,
    fontWeight: '800',
  },
  lead: {
    color: '#d9e5f1',
    fontSize: 17,
    lineHeight: 25,
  },
  card: {
    backgroundColor: '#16314d',
    borderColor: '#2b4968',
    borderRadius: 24,
    borderWidth: 1,
    gap: 14,
    padding: 18,
  },
  sectionTitle: {
    color: '#f8fafc',
    fontSize: 20,
    fontWeight: '700',
  },
  body: {
    color: '#d9e5f1',
    fontSize: 15,
    lineHeight: 22,
  },
  status: {
    color: '#91f2c2',
    fontSize: 14,
    fontWeight: '600',
  },
  input: {
    backgroundColor: '#f8fafc',
    borderRadius: 16,
    color: '#102033',
    fontSize: 16,
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  composer: {
    minHeight: 180,
    backgroundColor: '#f8fafc',
    borderRadius: 20,
    color: '#102033',
    fontSize: 16,
    padding: 16,
    textAlignVertical: 'top',
  },
  primaryButton: {
    backgroundColor: '#91f2c2',
    borderRadius: 999,
    paddingHorizontal: 18,
    paddingVertical: 14,
  },
  primaryButtonPressed: {
    opacity: 0.9,
    transform: [{scale: 0.98}],
  },
  primaryButtonLabel: {
    color: '#102033',
    fontSize: 16,
    fontWeight: '800',
    textAlign: 'center',
  },
  secondaryButton: {
    borderColor: '#4b6885',
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 18,
    paddingVertical: 14,
  },
  secondaryButtonPressed: {
    opacity: 0.9,
  },
  secondaryButtonLabel: {
    color: '#f8fafc',
    fontSize: 15,
    fontWeight: '600',
    textAlign: 'center',
  },
  accessoryBar: {
    alignItems: 'center',
    backgroundColor: '#16314d',
    borderTopColor: '#2b4968',
    borderTopWidth: 1,
    flexDirection: 'row',
    gap: 14,
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  holdButton: {
    backgroundColor: '#f97316',
    borderRadius: 999,
    flex: 1,
    paddingHorizontal: 18,
    paddingVertical: 14,
  },
  holdButtonPressed: {
    backgroundColor: '#ea580c',
  },
  holdButtonLabel: {
    color: '#fff7ed',
    fontSize: 16,
    fontWeight: '800',
    textAlign: 'center',
  },
  buttonDisabled: {
    opacity: 0.6,
  },
});

export default App;
