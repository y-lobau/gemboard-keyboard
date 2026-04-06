import React from 'react';
import {
  Linking,
  NativeModules,
  PermissionsAndroid,
  Platform,
  StyleSheet,
} from 'react-native';
import ReactTestRenderer from 'react-test-renderer';
import App from '../App';

function flushAsyncWork() {
  return new Promise(resolve => setImmediate(resolve));
}

function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function findByTestID(
  tree: ReactTestRenderer.ReactTestRenderer,
  testID: string,
) {
  return tree.root.findByProps({testID});
}

function queryByTestID(
  tree: ReactTestRenderer.ReactTestRenderer,
  testID: string,
) {
  return tree.root.findAllByProps({testID});
}

function findTextInputByTestID(
  tree: ReactTestRenderer.ReactTestRenderer,
  testID: string,
) {
  return tree.root.findByProps({testID}) as ReactTestRenderer.ReactTestInstance;
}

function releaseHold(
  instance: ReactTestRenderer.ReactTestInstance,
) {
  instance.props.onTouchEnd?.({});
}

const mockSyncRemoteRuntimeConfig = jest.fn(async () => ({
  inputText: 1,
  inputAudio: 2,
  inputCacheText: 0.5,
  inputCacheAudio: 0.25,
  outputText: 3,
}));
const mockTrackScreenView = jest.fn(async () => undefined);
const mockTrackEvent = jest.fn(async () => undefined);
const mockInitializeAnalytics = jest.fn(async () => undefined);
const mockInitializeCrashlytics = jest.fn(async () => undefined);
const mockTriggerTestCrash = jest.fn();

jest.mock('../config/remoteConfigService', () => ({
  syncRemoteRuntimeConfig: (...args: unknown[]) =>
    mockSyncRemoteRuntimeConfig(...args),
}));

jest.mock('../services/analyticsService', () => ({
  initializeAnalytics: (...args: unknown[]) => mockInitializeAnalytics(...args),
  getLatencyBucket: (latencyMs: number) => {
    if (latencyMs < 1000) {
      return 'lt_1000';
    }

    if (latencyMs < 2000) {
      return '1000_1999';
    }

    if (latencyMs < 4000) {
      return '2000_3999';
    }

    if (latencyMs < 8000) {
      return '4000_7999';
    }

    return '8000_plus';
  },
  getOutputSizeBucket: (outputChars: number) => {
    if (outputChars <= 0) {
      return '0';
    }

    if (outputChars <= 20) {
      return '1_20';
    }

    if (outputChars <= 60) {
      return '21_60';
    }

    if (outputChars <= 120) {
      return '61_120';
    }

    return '121_plus';
  },
  trackScreenView: (...args: unknown[]) => mockTrackScreenView(...args),
  trackEvent: (...args: unknown[]) => mockTrackEvent(...args),
  toAnalyticsBool: (value: boolean) => (value ? 'true' : 'false'),
}));

jest.mock('../services/crashlyticsService', () => ({
  initializeCrashlytics: (...args: unknown[]) =>
    mockInitializeCrashlytics(...args),
  triggerTestCrash: (...args: unknown[]) => mockTriggerTestCrash(...args),
}));

const originalPlatform = Platform.OS;
let currentTokenUsageSummary = {
  inputTokens: 0,
  cachedInputTokens: 0,
  outputTokens: 0,
  totalTokens: 0,
  requestCount: 0,
  lastRequest: {
    inputTokens: 0,
    cachedInputTokens: 0,
    outputTokens: 0,
    totalTokens: 0,
    inputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    cachedInputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    outputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
  },
  inputByModality: {
    text: 0,
    audio: 0,
    image: 0,
    video: 0,
    document: 0,
  },
  cachedInputByModality: {
    text: 0,
    audio: 0,
    image: 0,
    video: 0,
    document: 0,
  },
  outputByModality: {
    text: 0,
    audio: 0,
    image: 0,
    video: 0,
    document: 0,
  },
};
const configModule = {
  getStatus: jest.fn().mockResolvedValue({
    hasApiKey: false,
    platformMode: 'android-ime',
  }),
  getSectionExpansionState: jest.fn().mockResolvedValue({}),
  saveSectionExpansionState: jest.fn().mockResolvedValue(undefined),
  saveApiKey: jest.fn().mockResolvedValue(undefined),
  saveRuntimeConfig: jest.fn().mockResolvedValue(undefined),
  getLatestTranscriptSnapshot: jest.fn().mockResolvedValue(null),
  clearLatestTranscript: jest.fn().mockResolvedValue(undefined),
  resetTokenUsageSummary: jest.fn().mockResolvedValue(undefined),
  getTokenUsageSummary: jest.fn(async () => currentTokenUsageSummary),
};
const speechModule = {
  requestMicrophonePermission: jest.fn().mockResolvedValue(true),
  startRecording: jest.fn().mockResolvedValue(undefined),
  stopRecording: jest.fn().mockResolvedValue('transcribed message'),
  getAudioLevel: jest.fn().mockResolvedValue(0.42),
};
const sessionModule = {
  getStatus: jest.fn().mockResolvedValue({ isActive: false }),
  startSession: jest.fn().mockResolvedValue({ isActive: true }),
  stopSession: jest.fn().mockResolvedValue({ isActive: false }),
};

let urlHandler: ((event: { url: string }) => void) | null = null;

beforeEach(() => {
  NativeModules.PlyńConfig = configModule;
  NativeModules.PlyńSpeech = speechModule;
  NativeModules.PlyńSession = sessionModule;
  jest.clearAllMocks();
  configModule.getStatus.mockResolvedValue({
    hasApiKey: false,
    platformMode: 'android-ime',
  });
  configModule.getSectionExpansionState.mockResolvedValue({});
  configModule.saveSectionExpansionState.mockResolvedValue(undefined);
  configModule.saveApiKey.mockResolvedValue(undefined);
  configModule.saveRuntimeConfig.mockResolvedValue(undefined);
  configModule.getLatestTranscriptSnapshot.mockResolvedValue(null);
  configModule.clearLatestTranscript.mockResolvedValue(undefined);
  configModule.resetTokenUsageSummary.mockResolvedValue(undefined);
  configModule.getTokenUsageSummary.mockImplementation(
    async () => currentTokenUsageSummary,
  );
  speechModule.requestMicrophonePermission.mockResolvedValue(true);
  speechModule.startRecording.mockResolvedValue(undefined);
  speechModule.stopRecording.mockResolvedValue('transcribed message');
  speechModule.getAudioLevel.mockResolvedValue(0.42);
  sessionModule.getStatus.mockResolvedValue({ isActive: false });
  sessionModule.startSession.mockResolvedValue({ isActive: true });
  sessionModule.stopSession.mockResolvedValue({ isActive: false });
  Platform.OS = originalPlatform;
  urlHandler = null;
  currentTokenUsageSummary = {
    inputTokens: 0,
    cachedInputTokens: 0,
    outputTokens: 0,
    totalTokens: 0,
    requestCount: 0,
    lastRequest: {
      inputTokens: 0,
      cachedInputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      inputByModality: {
        text: 0,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      cachedInputByModality: {
        text: 0,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      outputByModality: {
        text: 0,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
    },
    inputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    cachedInputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    outputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
  };
  jest
    .spyOn(PermissionsAndroid, 'request')
    .mockResolvedValue(PermissionsAndroid.RESULTS.GRANTED);
  jest.spyOn(Linking, 'getInitialURL').mockResolvedValue(null);
  jest
    .spyOn(Linking, 'addEventListener')
    .mockImplementation((_type, listener) => {
      urlHandler = listener as (event: { url: string }) => void;
      return {
        remove: jest.fn(),
      };
    });
});

afterEach(() => {
  jest.restoreAllMocks();
});

afterAll(() => {
  Platform.OS = originalPlatform;
});

test('renders the main tab with how-it-works first and the first two sections expanded', async () => {
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  findByTestID(tree!, 'onboarding-toggle');
  findByTestID(tree!, 'setup-toggle');
  findByTestID(tree!, 'onboarding-content');
  findByTestID(tree!, 'setup-content');
  findByTestID(tree!, 'api-key-input');
  findByTestID(tree!, 'api-key-help-link');
  findByTestID(tree!, 'draft-input');
  findByTestID(tree!, 'token-summary-toggle');
  expect(queryByTestID(tree!, 'token-summary-content')).toHaveLength(0);
  expect(
    StyleSheet.flatten(tree!.root.findByProps({ testID: 'draft-input' }).props.style),
  ).toEqual(
    expect.objectContaining({
      fontSize: 17,
      lineHeight: 24,
    }),
  );
  expect(
    findByTestID(tree!, 'companion-mic-button'),
  ).toBeTruthy();
  expect(findByTestID(tree!, 'companion-delete-button')).toBeTruthy();
});

test('collapses setup and how-it-works sections from their headers', async () => {
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const hideHowItWorksButton = findByTestID(tree!, 'onboarding-toggle');

  await ReactTestRenderer.act(async () => {
    hideHowItWorksButton.props.onPress();
  });

  expect(queryByTestID(tree!, 'onboarding-content')).toHaveLength(0);

  const hideSetupButton = findByTestID(tree!, 'setup-toggle');

  await ReactTestRenderer.act(async () => {
    hideSetupButton.props.onPress();
  });

  expect(queryByTestID(tree!, 'setup-content')).toHaveLength(0);
});

test('renders fetched token totals in the bottom summary', async () => {
  currentTokenUsageSummary = {
    inputTokens: 123,
    cachedInputTokens: 4,
    outputTokens: 56,
    totalTokens: 183,
    requestCount: 2,
    lastRequest: {
      inputTokens: 80,
      cachedInputTokens: 2,
      outputTokens: 21,
      totalTokens: 103,
      inputByModality: {
        text: 18,
        audio: 62,
        image: 0,
        video: 0,
        document: 0,
      },
      cachedInputByModality: {
        text: 2,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      outputByModality: {
        text: 21,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
    },
    inputByModality: {
      text: 23,
      audio: 100,
      image: 0,
      video: 0,
      document: 0,
    },
    cachedInputByModality: {
      text: 4,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    outputByModality: {
      text: 56,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
  };

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  const expandButton = findByTestID(tree!, 'token-summary-toggle');

  await ReactTestRenderer.act(async () => {
    expandButton.props.onPress();
  });

  expect(findByTestID(tree!, 'token-summary-content')).toBeTruthy();
  expect(configModule.getTokenUsageSummary).toHaveBeenCalled();
});

test('renders last request, total, and average cost sections in order and resets the stats', async () => {
  currentTokenUsageSummary = {
    inputTokens: 123,
    cachedInputTokens: 4,
    outputTokens: 56,
    totalTokens: 183,
    requestCount: 2,
    lastRequest: {
      inputTokens: 80,
      cachedInputTokens: 2,
      outputTokens: 21,
      totalTokens: 103,
      inputByModality: {
        text: 18,
        audio: 62,
        image: 0,
        video: 0,
        document: 0,
      },
      cachedInputByModality: {
        text: 2,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      outputByModality: {
        text: 21,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
    },
    inputByModality: {
      text: 23,
      audio: 100,
      image: 0,
      video: 0,
      document: 0,
    },
    cachedInputByModality: {
      text: 4,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    outputByModality: {
      text: 56,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
  };

  configModule.resetTokenUsageSummary.mockImplementation(async () => {
    currentTokenUsageSummary = {
      inputTokens: 0,
      cachedInputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      requestCount: 0,
      lastRequest: {
        inputTokens: 0,
        cachedInputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
        inputByModality: {
          text: 0,
          audio: 0,
          image: 0,
          video: 0,
          document: 0,
        },
        cachedInputByModality: {
          text: 0,
          audio: 0,
          image: 0,
          video: 0,
          document: 0,
        },
        outputByModality: {
          text: 0,
          audio: 0,
          image: 0,
          video: 0,
          document: 0,
        },
      },
      inputByModality: {
        text: 0,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      cachedInputByModality: {
        text: 0,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      outputByModality: {
        text: 0,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
    };
  });

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  await ReactTestRenderer.act(async () => {
    findByTestID(tree!, 'token-summary-toggle').props.onPress();
  });

  const sectionOrder = tree!.root
    .findAll(
      node =>
        node.props.testID === 'token-summary-last-request-section' ||
        node.props.testID === 'token-summary-total-section' ||
        node.props.testID === 'token-summary-average-section',
    )
    .map(node => node.props.testID)
    .filter((testID, index, values) => values.indexOf(testID) === index);

  expect(sectionOrder).toEqual([
    'token-summary-last-request-section',
    'token-summary-total-section',
    'token-summary-average-section',
  ]);

  await ReactTestRenderer.act(async () => {
    await findByTestID(tree!, 'token-summary-reset-button').props.onPress();
    await flushAsyncWork();
  });

  expect(configModule.resetTokenUsageSummary).toHaveBeenCalledTimes(1);
  expect(
    tree!.root.findAllByProps({children: '0 / 0.0000$'}).length,
  ).toBeGreaterThan(0);
});

test('falls back to aggregate prompt token totals when modality details omit audio tokens', async () => {
  currentTokenUsageSummary = {
    inputTokens: 440,
    cachedInputTokens: 0,
    outputTokens: 32,
    totalTokens: 472,
    requestCount: 2,
    lastRequest: {
      inputTokens: 305,
      cachedInputTokens: 0,
      outputTokens: 16,
      totalTokens: 321,
      inputByModality: {
        text: 135,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      cachedInputByModality: {
        text: 0,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      outputByModality: {
        text: 16,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
    },
    inputByModality: {
      text: 270,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    cachedInputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    outputByModality: {
      text: 32,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
  };

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  await ReactTestRenderer.act(async () => {
    findByTestID(tree!, 'token-summary-toggle').props.onPress();
  });

  expect(
    tree!.root.findAllByProps({children: '170 / 0.0003$'}).length,
  ).toBeGreaterThan(0);
  expect(
    tree!.root.findAllByProps({children: '85 / 0.0002$'}).length,
  ).toBeGreaterThan(0);
});

test('syncs Firebase Remote Config on app startup', async () => {
  await ReactTestRenderer.act(async () => {
    ReactTestRenderer.create(<App />);
  });

  expect(mockInitializeAnalytics).toHaveBeenCalledTimes(1);
  expect(mockInitializeCrashlytics).toHaveBeenCalledTimes(1);
  expect(mockSyncRemoteRuntimeConfig).toHaveBeenCalledWith(
    expect.objectContaining({
      getStatus: expect.any(Function),
      saveApiKey: expect.any(Function),
      saveRuntimeConfig: expect.any(Function),
    }),
  );
});

test('tracks the single screen view on app startup', async () => {
  await ReactTestRenderer.act(async () => {
    ReactTestRenderer.create(<App />);
  });

  expect(mockTrackScreenView).toHaveBeenCalledWith('main');
});

test('triggers the Crashlytics test flow from the iOS debug deep link', async () => {
  Platform.OS = 'ios';
  jest
    .spyOn(Linking, 'getInitialURL')
    .mockResolvedValue('plyn://crashlytics-test');

  await ReactTestRenderer.act(async () => {
    ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  expect(mockInitializeCrashlytics).toHaveBeenCalledTimes(1);
  expect(mockTriggerTestCrash).toHaveBeenCalledTimes(1);
});

test('opens the launch preview screen from the debug deep link', async () => {
  Platform.OS = 'ios';
  jest.spyOn(Linking, 'getInitialURL').mockResolvedValue('plyn://debug/launch');

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  expect(findByTestID(tree!, 'launch-debug-screen')).toBeTruthy();
  expect(queryByTestID(tree!, 'setup-toggle')).toHaveLength(0);
});

test('saves the Gemini API key through the native bridge', async () => {
  Platform.OS = 'android';
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const settingsInput = findTextInputByTestID(tree!, 'api-key-input');

  await ReactTestRenderer.act(async () => {
    settingsInput!.props.onChangeText('gemini-token');
  });

  const saveButton = findByTestID(tree!, 'save-api-key-button');

  await ReactTestRenderer.act(async () => {
    await saveButton.props.onPress();
  });

  expect(configModule.saveApiKey).toHaveBeenCalledWith('gemini-token');
  expect(findByTestID(tree!, 'api-key-status-label')).toBeTruthy();
  expect(mockTrackEvent).toHaveBeenCalledWith('api_key_save_attempt', {
    platform: 'android',
    source: 'single_page',
  });
  expect(mockTrackEvent).toHaveBeenCalledWith('api_key_save_result', {
    platform: 'android',
    result: 'success',
  });
});

test('refreshes token totals after a successful host-app dictation', async () => {
  Platform.OS = 'android';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'android-ime',
  });

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  currentTokenUsageSummary = {
    inputTokens: 80,
    cachedInputTokens: 0,
    outputTokens: 20,
    totalTokens: 100,
    requestCount: 1,
    lastRequest: {
      inputTokens: 80,
      cachedInputTokens: 0,
      outputTokens: 20,
      totalTokens: 100,
      inputByModality: {
        text: 10,
        audio: 70,
        image: 0,
        video: 0,
        document: 0,
      },
      cachedInputByModality: {
        text: 0,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      outputByModality: {
        text: 20,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
    },
    inputByModality: {
      text: 10,
      audio: 70,
      image: 0,
      video: 0,
      document: 0,
    },
    cachedInputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    outputByModality: {
      text: 20,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
  };

  const holdButton = findByTestID(tree!, 'companion-mic-button');

  await ReactTestRenderer.act(async () => {
    await holdButton.props.onPressIn();
  });

  await ReactTestRenderer.act(async () => {
    releaseHold(holdButton);
    await flushAsyncWork();
    await sleep(20);
    await flushAsyncWork();
  });

  const expandButton = findByTestID(tree!, 'token-summary-toggle');

  await ReactTestRenderer.act(async () => {
    expandButton.props.onPress();
  });

  expect(findByTestID(tree!, 'token-summary-content')).toBeTruthy();
  expect(configModule.getTokenUsageSummary.mock.calls.length).toBeGreaterThan(1);
});

test('does not refresh token totals after a failed host-app dictation', async () => {
  Platform.OS = 'android';
  speechModule.stopRecording.mockRejectedValueOnce(new Error('boom'));

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  const initialSummaryCalls =
    configModule.getTokenUsageSummary.mock.calls.length;

  const holdButton = findByTestID(tree!, 'companion-mic-button');

  await ReactTestRenderer.act(async () => {
    await holdButton.props.onPressIn();
  });

  await ReactTestRenderer.act(async () => {
    releaseHold(holdButton);
    await flushAsyncWork();
  });

  const expandButton = findByTestID(tree!, 'token-summary-toggle');

  await ReactTestRenderer.act(async () => {
    expandButton.props.onPress();
  });

  expect(configModule.getTokenUsageSummary.mock.calls.length).toBe(
    initialSummaryCalls,
  );
  expect(findByTestID(tree!, 'token-summary-content')).toBeTruthy();
});

test('keeps the Gemini setup card visible when the API key is already saved', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
  });
  sessionModule.getStatus.mockResolvedValueOnce({ isActive: true });

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  expect(findByTestID(tree!, 'setup-toggle')).toBeTruthy();
  expect(findByTestID(tree!, 'api-key-input')).toBeTruthy();
  expect(findByTestID(tree!, 'api-key-help-link')).toBeTruthy();
});

test('keeps the API key saved on iOS even if the companion session restart fails', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: false,
    platformMode: 'ios-keyboard-extension',
  });
  sessionModule.getStatus.mockResolvedValueOnce({ isActive: false });
  sessionModule.startSession.mockRejectedValueOnce(
    new Error('Companion недаступны'),
  );

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const settingsInput = findTextInputByTestID(tree!, 'api-key-input');

  await ReactTestRenderer.act(async () => {
    settingsInput!.props.onChangeText('gemini-token');
  });

  const saveButton = findByTestID(tree!, 'save-api-key-button');

  await ReactTestRenderer.act(async () => {
    await saveButton.props.onPress();
    await flushAsyncWork();
  });

  expect(configModule.saveApiKey).toHaveBeenCalledWith('gemini-token');
  expect(findByTestID(tree!, 'setup-status-message')).toBeTruthy();
  expect(findByTestID(tree!, 'api-key-status-label')).toBeTruthy();
  expect(mockTrackEvent).toHaveBeenCalledWith('api_key_save_result', {
    platform: 'ios',
    result: 'success',
  });
  expect(mockTrackEvent).toHaveBeenCalledWith('companion_session_start', {
    platform: 'ios',
    source: 'settings_save',
    result: 'error',
  });
});

test('renders iPhone keyboard guidance and session state on iOS', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
  });
  sessionModule.getStatus.mockResolvedValueOnce({ isActive: true });

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  expect(findByTestID(tree!, 'session-status-label')).toBeTruthy();
  expect(findByTestID(tree!, 'session-toggle-button')).toBeTruthy();
});

test('allows collapsing and re-expanding onboarding details on iOS', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
  });
  sessionModule.getStatus.mockResolvedValueOnce({ isActive: true });

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  expect(findByTestID(tree!, 'ios-enable-help-button')).toBeTruthy();
  expect(findByTestID(tree!, 'session-toggle-button')).toBeTruthy();

  const collapseButton = findByTestID(tree!, 'onboarding-toggle');

  await ReactTestRenderer.act(async () => {
    collapseButton.props.onPress();
  });

  expect(queryByTestID(tree!, 'onboarding-content')).toHaveLength(0);

  const expandButton = findByTestID(tree!, 'onboarding-toggle');

  await ReactTestRenderer.act(async () => {
    expandButton.props.onPress();
  });

  expect(findByTestID(tree!, 'onboarding-content')).toBeTruthy();
  expect(findByTestID(tree!, 'ios-enable-help-button')).toBeTruthy();
  expect(findByTestID(tree!, 'session-toggle-button')).toBeTruthy();
});

test('restores persisted section expansion state on relaunch', async () => {
  configModule.getSectionExpansionState.mockResolvedValueOnce({
    onboardingExpanded: false,
    setupExpanded: false,
    tokenSummaryExpanded: true,
  });
  currentTokenUsageSummary = {
    inputTokens: 12,
    cachedInputTokens: 3,
    outputTokens: 8,
    totalTokens: 23,
    requestCount: 1,
    lastRequest: {
      inputTokens: 12,
      cachedInputTokens: 3,
      outputTokens: 8,
      totalTokens: 23,
      inputByModality: {
        text: 5,
        audio: 7,
        image: 0,
        video: 0,
        document: 0,
      },
      cachedInputByModality: {
        text: 3,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
      outputByModality: {
        text: 8,
        audio: 0,
        image: 0,
        video: 0,
        document: 0,
      },
    },
    inputByModality: {
      text: 5,
      audio: 7,
      image: 0,
      video: 0,
      document: 0,
    },
    cachedInputByModality: {
      text: 3,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    outputByModality: {
      text: 8,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
  };

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  expect(queryByTestID(tree!, 'onboarding-content')).toHaveLength(0);
  expect(queryByTestID(tree!, 'setup-content')).toHaveLength(0);
  expect(findByTestID(tree!, 'token-summary-content')).toBeTruthy();
});

test('press-and-hold dictation invokes the Android host-app speech bridge', async () => {
  Platform.OS = 'android';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'android-ime',
  });
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const holdButton = findByTestID(tree!, 'companion-mic-button');

  await ReactTestRenderer.act(async () => {
    await holdButton.props.onPressIn();
  });

  await ReactTestRenderer.act(async () => {
    await flushAsyncWork();
  });

  await ReactTestRenderer.act(async () => {
    releaseHold(holdButton);
    await flushAsyncWork();
    await flushAsyncWork();
  });

  expect(speechModule.startRecording).toHaveBeenCalledTimes(1);
  expect(speechModule.stopRecording).toHaveBeenCalledTimes(1);
  expect(mockTrackEvent).toHaveBeenCalledWith(
    'dictation_start',
    expect.objectContaining({
      platform: 'android',
      entry_point: 'host_app',
      session_active: 'false',
    }),
  );
});

test('cancels iOS recording if the user releases while microphone preparation is still pending', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    sessionActive: true,
    platformMode: 'ios-keyboard-extension',
  });

  let resolvePermission: ((granted: boolean) => void) | null = null;
  speechModule.requestMicrophonePermission.mockImplementationOnce(
    () =>
      new Promise<boolean>(resolve => {
        resolvePermission = resolve;
      }),
  );

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  const holdButton = findByTestID(tree!, 'companion-mic-button');

  await ReactTestRenderer.act(async () => {
    holdButton.props.onPressIn();
    await flushAsyncWork();
  });

  await ReactTestRenderer.act(async () => {
    releaseHold(holdButton);
    resolvePermission?.(true);
    await flushAsyncWork();
  });

  expect(speechModule.startRecording).not.toHaveBeenCalled();
  expect(speechModule.stopRecording).not.toHaveBeenCalled();
});

test('tracks blocked dictation attempts when the API key is missing', async () => {
  Platform.OS = 'android';
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const holdButton = findByTestID(tree!, 'companion-mic-button');

  await ReactTestRenderer.act(async () => {
    await holdButton.props.onPressIn();
  });

  expect(mockTrackEvent).toHaveBeenCalledWith('dictation_blocked', {
    platform: 'android',
    entry_point: 'host_app',
    reason: 'missing_api_key',
  });
});

test('keeps the draft unchanged when the transcription service returns no transcript text', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
  });
  sessionModule.getStatus.mockResolvedValueOnce({ isActive: true });
  speechModule.stopRecording.mockResolvedValueOnce('');

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const holdButton = findByTestID(tree!, 'companion-mic-button');
  const composer = findTextInputByTestID(tree!, 'draft-input');

  await ReactTestRenderer.act(async () => {
    await holdButton.props.onPressIn();
  });

  await ReactTestRenderer.act(async () => {
    await flushAsyncWork();
  });

  await ReactTestRenderer.act(async () => {
    releaseHold(holdButton);
  });

  await ReactTestRenderer.act(async () => {
    await flushAsyncWork();
  });

  expect(composer.props.value).toBe('');
});

test('inserts separator whitespace when a second dictation appends to the draft', async () => {
  Platform.OS = 'android';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'android-ime',
  });
  speechModule.stopRecording
    .mockResolvedValueOnce('hello.')
    .mockResolvedValueOnce('how are you?');

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  const holdButton = findByTestID(tree!, 'companion-mic-button');
  const composer = findTextInputByTestID(tree!, 'draft-input');

  await ReactTestRenderer.act(async () => {
    await holdButton.props.onPressIn();
    releaseHold(holdButton);
    await flushAsyncWork();
    await sleep(20);
    await flushAsyncWork();
  });

  await ReactTestRenderer.act(async () => {
    await holdButton.props.onPressIn();
    releaseHold(holdButton);
    await flushAsyncWork();
    await sleep(20);
    await flushAsyncWork();
  });

  expect(composer.props.value).toBe('hello. how are you?');
});

test('updates the iOS host-app draft with progressive transcript snapshots before the final transcript resolves', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
  });
  sessionModule.getStatus.mockResolvedValueOnce({ isActive: true });

  let currentSnapshot: {
    text: string;
    sessionID: string;
    sequence: number;
    isFinal: boolean;
    state: 'streamingPartial';
    errorCode: null;
    updatedAt: number;
  } | null = null;
  let resolveStopRecording: ((transcript: string) => void) | null = null;

  configModule.getLatestTranscriptSnapshot.mockImplementation(
    async () => currentSnapshot,
  );
  speechModule.stopRecording.mockImplementationOnce(
    () =>
      new Promise<string>(resolve => {
        resolveStopRecording = resolve;
      }),
  );

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const holdButton = findByTestID(tree!, 'companion-mic-button');
  const composer = findTextInputByTestID(tree!, 'draft-input');

  await ReactTestRenderer.act(async () => {
    await holdButton.props.onPressIn();
  });

  await ReactTestRenderer.act(async () => {
    await flushAsyncWork();
  });

  await ReactTestRenderer.act(async () => {
    releaseHold(holdButton);
  });

  currentSnapshot = {
    text: 'пры',
    sessionID: 'session-1',
    sequence: 1,
    isFinal: false,
    state: 'streamingPartial',
    errorCode: null,
    updatedAt: Date.now(),
  };

  await ReactTestRenderer.act(async () => {
    await sleep(180);
    await flushAsyncWork();
  });

  expect(composer!.props.value).toBe('пры');

  currentSnapshot = {
    text: 'прывітанне',
    sessionID: 'session-1',
    sequence: 2,
    isFinal: false,
    state: 'streamingPartial',
    errorCode: null,
    updatedAt: Date.now(),
  };

  await ReactTestRenderer.act(async () => {
    await sleep(180);
    await flushAsyncWork();
  });

  expect(composer!.props.value).toBe('прывітанне');

  await ReactTestRenderer.act(async () => {
    resolveStopRecording?.('прывітанне свет');
    await flushAsyncWork();
  });

  expect(composer!.props.value).toBe('прывітанне свет');
});

test('deletes only the last dictated word from the live draft', async () => {
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const composer = findTextInputByTestID(tree!, 'draft-input');

  await ReactTestRenderer.act(async () => {
    composer!.props.onChangeText('адзін два тры');
  });

  const deleteButton = findByTestID(tree!, 'companion-delete-button');

  await ReactTestRenderer.act(async () => {
    deleteButton.props.onPress();
  });

  expect(composer!.props.value).toBe('адзін два');
});

test('starts the iPhone companion session automatically when a saved key exists', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
  });
  sessionModule.getStatus.mockResolvedValueOnce({ isActive: false });
  sessionModule.startSession.mockResolvedValueOnce({ isActive: true });

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  expect(sessionModule.startSession).toHaveBeenCalledTimes(1);
  expect(findByTestID(tree!, 'session-status-label')).toBeTruthy();
  expect(mockTrackEvent).toHaveBeenCalledWith('companion_session_start', {
    platform: 'ios',
    source: 'auto_start',
    result: 'success',
  });
});

test('opens the API key help link from the setup card', async () => {
  const openUrlSpy = jest.spyOn(Linking, 'openURL').mockResolvedValueOnce();
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const linkButton = findByTestID(tree!, 'api-key-help-link');

  await ReactTestRenderer.act(async () => {
    linkButton.props.onPress();
  });

  expect(openUrlSpy).toHaveBeenCalledWith(
    'https://aistudio.google.com/api-keys',
  );
});

test('refreshes the saved iOS state when native bridges appear after the first render', async () => {
  jest.useFakeTimers();
  Platform.OS = 'ios';
  (
    globalThis as { __Plyń_ENABLE_BOOTSTRAP_RETRIES__?: boolean }
  ).__Plyń_ENABLE_BOOTSTRAP_RETRIES__ = true;
  delete NativeModules.PlyńConfig;
  delete NativeModules.PlyńAppConfig;
  delete NativeModules.PlyńSession;

  let tree: ReactTestRenderer.ReactTestRenderer;

  try {
    await ReactTestRenderer.act(async () => {
      tree = ReactTestRenderer.create(<App />);
    });

    expect(findByTestID(tree!, 'api-key-status-label')).toBeTruthy();
    expect(findByTestID(tree!, 'session-status-label')).toBeTruthy();

    NativeModules.PlyńConfig = {
      ...configModule,
      getStatus: jest.fn().mockResolvedValue({
        hasApiKey: true,
        sessionActive: true,
        platformMode: 'ios-keyboard-extension',
      }),
    };
    NativeModules.PlyńSession = {
      ...sessionModule,
      getStatus: jest.fn().mockResolvedValue({ isActive: true }),
    };

    await ReactTestRenderer.act(async () => {
      jest.advanceTimersByTime(1000);
      await Promise.resolve();
    });

    expect(findByTestID(tree!, 'api-key-status-label')).toBeTruthy();
    expect(findByTestID(tree!, 'session-status-label')).toBeTruthy();
  } finally {
    if (tree) {
      await ReactTestRenderer.act(async () => {
        tree.unmount();
      });
    }
    delete (globalThis as { __Plyń_ENABLE_BOOTSTRAP_RETRIES__?: boolean })
      .__Plyń_ENABLE_BOOTSTRAP_RETRIES__;
    jest.useRealTimers();
  }
});

test('retries the iPhone companion session when opened from the session deep link', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
  });
  sessionModule.getStatus.mockResolvedValueOnce({ isActive: true });

  await ReactTestRenderer.act(async () => {
    ReactTestRenderer.create(<App />);
  });

  expect(urlHandler).toBeTruthy();

  await ReactTestRenderer.act(async () => {
    urlHandler?.({ url: 'plyn://session' });
  });

  expect(sessionModule.startSession).toHaveBeenCalledTimes(1);
  expect(mockTrackEvent).toHaveBeenCalledWith('session_recovery_link_opened', {
    platform: 'ios',
  });
  expect(mockTrackEvent).toHaveBeenCalledWith('companion_session_start', {
    platform: 'ios',
    source: 'deep_link_retry',
    result: 'success',
  });
});
