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
  getDebugSnapshot: jest.fn().mockResolvedValue({
    usesAppGroupDefaults: true,
    appGroupIdentifier: 'group.com.holas.plynkeyboard',
    hasApiKey: true,
    keyboardVisible: true,
    keyboardStatus: 'inactive',
    keyboardCommand: 'none',
    keyboardStatusUpdatedAt: 1_775_927_200,
    keyboardCommandUpdatedAt: 1_775_927_200,
    keyboardLaunchDebug: '[2026-04-11T17:00:00Z] reloadState status=inactive',
    keyboardDebugLog:
      '[2026-04-11T17:00:00Z] reloadState status=inactive\n[2026-04-11T17:00:01Z] openCompanionApp',
    sessionActive: false,
    sessionHeartbeatUpdatedAt: null,
    sessionRecoveryAttemptUpdatedAt: 1_775_927_201,
    companionDebugLog:
      '[2026-04-11T17:00:02Z] applicationDidBecomeActive\n[2026-04-11T17:00:03Z] startCompanionSessionIfNeeded begin',
  }),
  clearDebugSnapshot: jest.fn().mockResolvedValue(undefined),
};
const sessionModule = {
  getStatus: jest.fn().mockResolvedValue({ isActive: false }),
  startSession: jest.fn().mockResolvedValue({ isActive: true }),
  stopSession: jest.fn().mockResolvedValue({ isActive: false }),
};

let urlHandler: ((event: { url: string }) => void) | null = null;
let checkPermissionSpy: jest.SpyInstance;
let requestPermissionSpy: jest.SpyInstance;

beforeEach(() => {
  NativeModules.PlyńConfig = configModule;
  delete NativeModules.PlyńAppConfig;
  delete NativeModules.GemboardConfig;
  NativeModules.PlyńSession = sessionModule;
  NativeModules.PlynSession = sessionModule;
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
  configModule.getDebugSnapshot.mockResolvedValue({
    usesAppGroupDefaults: true,
    appGroupIdentifier: 'group.com.holas.plynkeyboard',
    hasApiKey: true,
    keyboardVisible: true,
    keyboardStatus: 'inactive',
    keyboardCommand: 'none',
    keyboardStatusUpdatedAt: 1_775_927_200,
    keyboardCommandUpdatedAt: 1_775_927_200,
    keyboardLaunchDebug: '[2026-04-11T17:00:00Z] reloadState status=inactive',
    keyboardDebugLog:
      '[2026-04-11T17:00:00Z] reloadState status=inactive\n[2026-04-11T17:00:01Z] openCompanionApp',
    sessionActive: false,
    sessionHeartbeatUpdatedAt: null,
    sessionRecoveryAttemptUpdatedAt: 1_775_927_201,
    companionDebugLog:
      '[2026-04-11T17:00:02Z] applicationDidBecomeActive\n[2026-04-11T17:00:03Z] startCompanionSessionIfNeeded begin',
  });
  configModule.clearDebugSnapshot.mockResolvedValue(undefined);
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
  jest.spyOn(Linking, 'getInitialURL').mockResolvedValue(null);
  jest
    .spyOn(Linking, 'addEventListener')
    .mockImplementation((_type, listener) => {
      urlHandler = listener as (event: { url: string }) => void;
      return {
        remove: jest.fn(),
      };
    });
  checkPermissionSpy = jest
    .spyOn(PermissionsAndroid, 'check')
    .mockResolvedValue(true);
  requestPermissionSpy = jest
    .spyOn(PermissionsAndroid, 'request')
    .mockResolvedValue(PermissionsAndroid.RESULTS.GRANTED);
});

test('uses the ascii iOS session bridge when the accented native module is unavailable', async () => {
  Platform.OS = 'ios';
  delete NativeModules.PlyńSession;
  NativeModules.PlynSession = sessionModule;

  let tree: ReactTestRenderer.ReactTestRenderer;

  configModule.getStatus.mockResolvedValue({
    hasApiKey: true,
    sessionActive: false,
    platformMode: 'ios-keyboard-extension',
  });

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const sessionToggleButton = findByTestID(tree!, 'session-toggle-button');

  await ReactTestRenderer.act(async () => {
    sessionToggleButton.props.onPress();
  });

  expect(sessionModule.startSession).toHaveBeenCalledTimes(1);
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
  expect(queryByTestID(tree!, 'companion-mic-button')).toHaveLength(0);
  expect(queryByTestID(tree!, 'companion-delete-button')).toHaveLength(0);
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
    await new Promise(resolve => setTimeout(resolve, 0));
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

test('opens the iOS debug panel from the visible onboarding action and renders shared logs', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValue({
    hasApiKey: true,
    sessionActive: false,
    platformMode: 'ios-keyboard-extension',
  });

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  const openDebugButton = findByTestID(tree!, 'debug-open-button');

  await ReactTestRenderer.act(async () => {
    openDebugButton.props.onPress();
    await flushAsyncWork();
  });

  expect(findByTestID(tree!, 'debug-panel')).toBeTruthy();
  expect(configModule.getDebugSnapshot).toHaveBeenCalled();
  expect(findByTestID(tree!, 'debug-keyboard-latest').props.children).toContain(
    'reloadState status=inactive',
  );
  expect(findByTestID(tree!, 'debug-keyboard-log').props.children).toContain(
    'openCompanionApp',
  );
  expect(findByTestID(tree!, 'debug-companion-log').props.children).toContain(
    'applicationDidBecomeActive',
  );
});

test('saves the Gemini API key through the native bridge', async () => {
  Platform.OS = 'android';
  delete NativeModules.PlyńConfig;
  delete NativeModules.PlyńAppConfig;
  NativeModules.GemboardConfig = configModule;
  checkPermissionSpy.mockResolvedValue(true);
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
  expect(findByTestID(tree!, 'session-status-label').props.children).toBe(
    'Gemini гатовы',
  );
  expect(
    StyleSheet.flatten(findByTestID(tree!, 'session-status-dot').props.style),
  ).toEqual(expect.objectContaining({backgroundColor: '#3f8f59'}));
  expect(mockTrackEvent).toHaveBeenCalledWith('api_key_save_attempt', {
    platform: 'android',
    source: 'single_page',
  });
  expect(mockTrackEvent).toHaveBeenCalledWith('api_key_save_result', {
    platform: 'android',
    result: 'success',
  });
});

test('requests Android microphone permission from onboarding on first open when missing', async () => {
  Platform.OS = 'android';
  checkPermissionSpy.mockResolvedValue(false);
  requestPermissionSpy.mockResolvedValue(PermissionsAndroid.RESULTS.GRANTED);

  await ReactTestRenderer.act(async () => {
    ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  expect(checkPermissionSpy).toHaveBeenCalledWith(
    PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
  );
  expect(requestPermissionSpy).toHaveBeenCalledWith(
    PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
    expect.objectContaining({
      title: expect.any(String),
      message: expect.any(String),
    }),
  );
});

test('shows Android microphone setup state and exposes a permission action in onboarding', async () => {
  Platform.OS = 'android';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'android-ime',
  });
  checkPermissionSpy.mockResolvedValue(false);
  requestPermissionSpy.mockResolvedValue(PermissionsAndroid.RESULTS.DENIED);

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
    await flushAsyncWork();
  });

  expect(findByTestID(tree!, 'android-microphone-help-button')).toBeTruthy();
  expect(findByTestID(tree!, 'session-status-label').props.children).toBe(
    'Патрэбны доступ да мікрафона',
  );

  await ReactTestRenderer.act(async () => {
    await findByTestID(tree!, 'android-microphone-help-button').props.onPress();
  });

  expect(requestPermissionSpy).toHaveBeenCalled();
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
  expect(findByTestID(tree!, 'session-status-label').props.children).toBe(
    'Кампаньён актыўны',
  );
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
    expect(findByTestID(tree!, 'session-status-label').props.children).toBe(
      'Кампаньён неактыўны',
    );

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
    expect(findByTestID(tree!, 'session-status-label').props.children).toBe(
      'Кампаньён актыўны',
    );
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
  sessionModule.startSession.mockResolvedValueOnce({ isActive: true });

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
