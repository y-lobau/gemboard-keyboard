import {
  __resetRemoteConfigSyncForTests,
  bundledRuntimeConfig,
  emptyTranscriptionCostRates,
  syncRemoteRuntimeConfig,
} from './remoteConfigService';

const mockSetConfigSettings = jest.fn();
const mockFetchAndActivate = jest.fn();
const mockGetString = jest.fn();
const mockTrackEvent = jest.fn(async () => undefined);
const mockRecordNonFatalCrash = jest.fn(async () => undefined);

jest.mock('@react-native-firebase/remote-config', () => {
  return () => ({
    setConfigSettings: mockSetConfigSettings,
    fetchAndActivate: mockFetchAndActivate,
    getString: mockGetString,
  });
});

jest.mock('../services/analyticsService', () => ({
  toAnalyticsBool: (value: boolean) => (value ? 'true' : 'false'),
  trackEvent: (...args: unknown[]) => mockTrackEvent(...args),
}));

jest.mock('../services/crashlyticsService', () => ({
  recordNonFatalCrash: (...args: unknown[]) => mockRecordNonFatalCrash(...args),
}));

const configModule = {
  saveRuntimeConfig: jest.fn(async () => undefined),
};

beforeEach(() => {
  jest.clearAllMocks();
  __resetRemoteConfigSyncForTests();
  mockSetConfigSettings.mockResolvedValue(undefined);
  mockFetchAndActivate.mockResolvedValue(true);
  mockGetString.mockImplementation((key: string) => {
    switch (key) {
      case 'gemini_model':
        return 'remote-config-model';
      case 'gemini_system_prompt':
        return 'Return only Belarusian transcript text.';
      case 'keyboard_command_timeout_seconds':
        return '3.5';
      case 'keyboard_transcription_timeout_seconds':
        return '24';
      case 'gemini_cost_input_text':
        return '1';
      case 'gemini_cost_input_audio':
        return '2';
      case 'gemini_cost_input_cache_text':
        return '3';
      case 'gemini_cost_input_cache_audio':
        return '4';
      case 'gemini_cost_output_text':
        return '5';
      default:
        return '';
    }
  });
});

test('bundled runtime config keeps only prompt and timeout fallbacks', () => {
  expect(bundledRuntimeConfig).toEqual({
    systemPrompt:
      'Transcribe supplied audio into Belarusian dictation text only. Return only the final Belarusian transcript.',
    keyboardCommandTimeout: 2,
    keyboardTranscriptionTimeout: 12,
  });
});

test('persists Firebase-provided runtime config when model is present', async () => {
  await syncRemoteRuntimeConfig(configModule);

  expect(configModule.saveRuntimeConfig).toHaveBeenCalledWith({
    model: 'remote-config-model',
    systemPrompt: 'Return only Belarusian transcript text.',
    keyboardCommandTimeout: 3.5,
    keyboardTranscriptionTimeout: 24,
  });
});

test('does not save runtime config when Firebase omits the model', async () => {
  mockGetString.mockImplementation((key: string) => {
    switch (key) {
      case 'gemini_system_prompt':
        return 'Return only Belarusian transcript text.';
      case 'keyboard_command_timeout_seconds':
        return '3.5';
      case 'keyboard_transcription_timeout_seconds':
        return '24';
      case 'gemini_cost_input_text':
        return '1';
      case 'gemini_cost_input_audio':
        return '2';
      case 'gemini_cost_input_cache_text':
        return '3';
      case 'gemini_cost_input_cache_audio':
        return '4';
      case 'gemini_cost_output_text':
        return '5';
      default:
        return '';
    }
  });

  const result = await syncRemoteRuntimeConfig(configModule);

  expect(configModule.saveRuntimeConfig).not.toHaveBeenCalled();
  expect(result).toEqual({
    inputText: 1,
    inputAudio: 2,
    inputCacheText: 3,
    inputCacheAudio: 4,
    outputText: 5,
  });
  expect(mockTrackEvent).toHaveBeenCalledWith('remote_config_sync_result', {
    result: 'missing_model',
    has_model: 'false',
    has_system_prompt: 'true',
  });
});

test('does not overwrite runtime config when Firebase fetch fails', async () => {
  mockFetchAndActivate.mockRejectedValueOnce(new Error('offline'));

  const result = await syncRemoteRuntimeConfig(configModule);

  expect(configModule.saveRuntimeConfig).not.toHaveBeenCalled();
  expect(result).toEqual(emptyTranscriptionCostRates);
  expect(mockRecordNonFatalCrash).toHaveBeenCalledWith(
    expect.any(Error),
    'remote_config_sync_failed',
  );
  expect(mockTrackEvent).toHaveBeenCalledWith('remote_config_sync_result', {
    result: 'fallback',
    has_model: 'false',
    has_system_prompt: 'false',
  });
});

test('fetches transcription cost rates on iOS release builds', async () => {
  const devGlobal = globalThis as typeof globalThis & {__DEV__?: boolean};
  const previousDev = devGlobal.__DEV__;

  try {
    devGlobal.__DEV__ = false;
    jest.resetModules();

    const reactNative = jest.requireActual('react-native');
    reactNative.Platform.OS = 'ios';

    const {syncRemoteRuntimeConfig: syncRemoteRuntimeConfigForIOS} = require('./remoteConfigService');

    const result = await syncRemoteRuntimeConfigForIOS(configModule);

    expect(configModule.saveRuntimeConfig).toHaveBeenCalledWith({
      model: 'remote-config-model',
      systemPrompt: 'Return only Belarusian transcript text.',
      keyboardCommandTimeout: 3.5,
      keyboardTranscriptionTimeout: 24,
    });
    expect(result).toEqual({
      inputText: 1,
      inputAudio: 2,
      inputCacheText: 3,
      inputCacheAudio: 4,
      outputText: 5,
    });
  } finally {
    devGlobal.__DEV__ = previousDev;
    jest.resetModules();
  }
});

test('falls back to bundled keyboard timeout values when Firebase timeout config is invalid', async () => {
  mockGetString.mockImplementation((key: string) => {
    switch (key) {
      case 'gemini_model':
        return 'remote-config-model';
      case 'gemini_system_prompt':
        return 'Return only Belarusian transcript text.';
      case 'keyboard_command_timeout_seconds':
        return '-1';
      case 'keyboard_transcription_timeout_seconds':
        return 'not-a-number';
      case 'gemini_cost_input_text':
        return '1';
      case 'gemini_cost_input_audio':
        return '2';
      case 'gemini_cost_input_cache_text':
        return '3';
      case 'gemini_cost_input_cache_audio':
        return '4';
      case 'gemini_cost_output_text':
        return '5';
      default:
        return '';
    }
  });

  await syncRemoteRuntimeConfig(configModule);

  expect(configModule.saveRuntimeConfig).toHaveBeenCalledWith({
    model: 'remote-config-model',
    systemPrompt: 'Return only Belarusian transcript text.',
    keyboardCommandTimeout: bundledRuntimeConfig.keyboardCommandTimeout,
    keyboardTranscriptionTimeout:
      bundledRuntimeConfig.keyboardTranscriptionTimeout,
  });
});
