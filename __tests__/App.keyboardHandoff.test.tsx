import React from 'react';
import {AppState, Linking, NativeModules, Platform} from 'react-native';
import ReactTestRenderer from 'react-test-renderer';
import App from '../App';

jest.setTimeout(20_000);

const mountedTrees: ReactTestRenderer.ReactTestRenderer[] = [];

function renderTrackedApp(props: React.ComponentProps<typeof App> = {}) {
  const tree = ReactTestRenderer.create(<App {...props} />);
  mountedTrees.push(tree);
  return tree;
}

async function flushAsyncWork(iterations: number = 12) {
  for (let index = 0; index < iterations; index += 1) {
    await Promise.resolve();
  }
}

async function renderTrackedAppAndFlush(
  props: React.ComponentProps<typeof App> = {},
) {
  jest.useRealTimers();

  let tree: ReactTestRenderer.ReactTestRenderer;

  ReactTestRenderer.act(() => {
    tree = renderTrackedApp(props);
  });

  await ReactTestRenderer.act(async () => {
    await flushAsyncWork();
  });

  return tree!;
}

async function renderTrackedAppAndFlushLoosely(
  props: React.ComponentProps<typeof App> = {},
) {
  jest.useRealTimers();

  let tree: ReactTestRenderer.ReactTestRenderer;

  ReactTestRenderer.act(() => {
    tree = renderTrackedApp(props);
  });

  await ReactTestRenderer.act(async () => {
    await flushAsyncWork(32);
  });

  return tree!;
}

function queryByTestID(
  tree: ReactTestRenderer.ReactTestRenderer,
  testID: string,
) {
  return tree.root.findAllByProps({testID});
}

function findByTestID(
  tree: ReactTestRenderer.ReactTestRenderer,
  testID: string,
) {
  return tree.root.findByProps({testID});
}

async function waitForKeyboardHandoffPopup(
  tree: ReactTestRenderer.ReactTestRenderer,
  visible: boolean,
  attempts: number = 20,
) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const isVisible = queryByTestID(tree, 'keyboard-handoff-popup').length > 0;

    if (isVisible === visible) {
      return;
    }

    await ReactTestRenderer.act(async () => {
      await flushAsyncWork();
    });
  }

  throw new Error(`Expected keyboard handoff popup visible=${visible}`);
}

const mockTrackEvent = jest.fn(async () => undefined);
const mockTrackScreenView = jest.fn(async () => undefined);
const mockInitializeAnalytics = jest.fn(async () => undefined);
const mockInitializeCrashlytics = jest.fn(async () => undefined);
const mockTriggerTestCrash = jest.fn();
const mockSyncRemoteRuntimeConfig = jest.fn(async () => ({
  inputText: 1,
  inputAudio: 2,
  inputCacheText: 0.5,
  inputCacheAudio: 0.25,
  outputText: 3,
}));

jest.mock('../config/remoteConfigService', () => ({
  syncRemoteRuntimeConfig: (...args: unknown[]) =>
    mockSyncRemoteRuntimeConfig(...args),
}));

jest.mock('../services/analyticsService', () => ({
  initializeAnalytics: (...args: unknown[]) => mockInitializeAnalytics(...args),
  getLatencyBucket: () => 'lt_1000',
  getOutputSizeBucket: () => '1_20',
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
const currentTokenUsageSummary = {
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
    inputByModality: {text: 0, audio: 0, image: 0, video: 0, document: 0},
    cachedInputByModality: {
      text: 0,
      audio: 0,
      image: 0,
      video: 0,
      document: 0,
    },
    outputByModality: {text: 0, audio: 0, image: 0, video: 0, document: 0},
  },
  inputByModality: {text: 0, audio: 0, image: 0, video: 0, document: 0},
  cachedInputByModality: {text: 0, audio: 0, image: 0, video: 0, document: 0},
  outputByModality: {text: 0, audio: 0, image: 0, video: 0, document: 0},
};

const configModule = {
  getStatus: jest.fn().mockResolvedValue({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
    sessionActive: true,
  }),
  getSectionExpansionState: jest.fn().mockResolvedValue({}),
  saveSectionExpansionState: jest.fn().mockResolvedValue(undefined),
  saveApiKey: jest.fn().mockResolvedValue(undefined),
  saveRuntimeConfig: jest.fn().mockResolvedValue(undefined),
  getLatestTranscriptSnapshot: jest.fn().mockResolvedValue(null),
  clearLatestTranscript: jest.fn().mockResolvedValue(undefined),
  consumePendingLaunchURL: jest.fn().mockResolvedValue(null),
  consumeKeyboardRecoveryHandoff: jest.fn().mockResolvedValue(false),
  resetTokenUsageSummary: jest.fn().mockResolvedValue(undefined),
  getTokenUsageSummary: jest.fn(async () => currentTokenUsageSummary),
  getDebugSnapshot: jest.fn().mockResolvedValue({
    usesAppGroupDefaults: true,
    appGroupIdentifier: 'group.com.holas.plynkeyboard',
    hasApiKey: true,
    keyboardVisible: true,
    keyboardStatus: 'inactive',
    keyboardCommand: 'none',
    keyboardStatusUpdatedAt: 1,
    keyboardCommandUpdatedAt: 1,
    keyboardLaunchDebug: '',
    keyboardDebugLog: '',
    sessionActive: true,
    sessionHeartbeatUpdatedAt: null,
    sessionRecoveryAttemptUpdatedAt: null,
    companionDebugLog: '',
  }),
  clearDebugSnapshot: jest.fn().mockResolvedValue(undefined),
};

const sessionModule = {
  getStatus: jest.fn().mockResolvedValue({isActive: true}),
  startSession: jest.fn().mockResolvedValue({isActive: true}),
  stopSession: jest.fn().mockResolvedValue({isActive: false}),
};

let urlHandler: ((event: {url: string}) => void) | null = null;
let appStateChangeHandlers: Array<(state: string) => void> = [];

async function openSessionDeepLink() {
  jest.useRealTimers();
  expect(urlHandler).toBeTruthy();

  await ReactTestRenderer.act(async () => {
    urlHandler?.({url: 'plyn://session'});
    await flushAsyncWork();
  });
}

const emitAppStateChange = (state: string) => {
  appStateChangeHandlers.forEach(listener => {
    listener(state);
  });
};

beforeEach(() => {
  NativeModules.PlyńConfig = configModule;
  delete NativeModules.PlyńAppConfig;
  delete NativeModules.GemboardConfig;
  NativeModules.PlyńSession = sessionModule;
  NativeModules.PlynSession = sessionModule;

  jest.clearAllMocks();
  Platform.OS = originalPlatform;
  urlHandler = null;
  appStateChangeHandlers = [];

  configModule.getStatus.mockResolvedValue({
    hasApiKey: true,
    platformMode: 'ios-keyboard-extension',
    sessionActive: true,
  });
  configModule.getSectionExpansionState.mockResolvedValue({});
  configModule.saveSectionExpansionState.mockResolvedValue(undefined);
  configModule.getLatestTranscriptSnapshot.mockResolvedValue(null);
  configModule.clearLatestTranscript.mockResolvedValue(undefined);
  configModule.consumePendingLaunchURL.mockResolvedValue(null);
  configModule.consumeKeyboardRecoveryHandoff.mockResolvedValue(false);
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
    keyboardStatusUpdatedAt: 1,
    keyboardCommandUpdatedAt: 1,
    keyboardLaunchDebug: '',
    keyboardDebugLog: '',
    sessionActive: true,
    sessionHeartbeatUpdatedAt: null,
    sessionRecoveryAttemptUpdatedAt: null,
    companionDebugLog: '',
  });
  configModule.clearDebugSnapshot.mockResolvedValue(undefined);
  sessionModule.getStatus.mockResolvedValue({isActive: true});
  sessionModule.startSession.mockResolvedValue({isActive: true});
  sessionModule.stopSession.mockResolvedValue({isActive: false});

  jest.spyOn(Linking, 'getInitialURL').mockResolvedValue(null);
  jest
    .spyOn(Linking, 'addEventListener')
    .mockImplementation((_type, listener) => {
      urlHandler = listener as (event: {url: string}) => void;
      return {remove: jest.fn()};
    });
  jest
    .spyOn(AppState, 'addEventListener')
    .mockImplementation((_type, listener) => {
      const typedListener = listener as (state: string) => void;
      appStateChangeHandlers.push(typedListener);
      return {
        remove: jest.fn(() => {
          appStateChangeHandlers = appStateChangeHandlers.filter(
            currentListener => currentListener !== typedListener,
          );
        }),
      };
    });

  delete (
    globalThis as {__Plyń_ENABLE_NATIVE_STATUS_REFRESH__?: boolean}
  ).__Plyń_ENABLE_NATIVE_STATUS_REFRESH__;
});

afterEach(() => {
  jest.useRealTimers();

  while (mountedTrees.length > 0) {
    const tree = mountedTrees.pop();

    if (!tree) {
      continue;
    }

    try {
      ReactTestRenderer.act(() => {
        tree.unmount();
      });
    } catch {
      // Ignore duplicate or late unmounts from tests that already cleaned up.
    }
  }

  jest.clearAllTimers();
  jest.restoreAllMocks();
});

afterAll(() => {
  Platform.OS = originalPlatform;
});

test('retries the iPhone companion session when opened from the session deep link', async () => {
  Platform.OS = 'ios';

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
    initialLaunchURL: 'plyn://session',
    initialKeyboardRecoveryHandoff: true,
  });

  await waitForKeyboardHandoffPopup(tree, true);

  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();
  expect(findByTestID(tree, 'keyboard-handoff-title').props.children).toBe(
    'Кампаньён актыўны',
  );
  expect(findByTestID(tree, 'keyboard-handoff-close-button')).toBeTruthy();
  expect(mockTrackEvent).toHaveBeenCalledWith('session_recovery_link_opened', {
    platform: 'ios',
  });
  expect(mockTrackEvent).toHaveBeenCalledWith('companion_session_start', {
    platform: 'ios',
    source: 'keyboard_handoff_marker',
    result: 'success',
  });

  await ReactTestRenderer.act(async () => {
    findByTestID(tree, 'keyboard-handoff-close-button').props.onPress();
  });

  expect(queryByTestID(tree, 'keyboard-handoff-popup')).toHaveLength(0);
});

test('keeps the keyboard handoff popup visible when iPhone delivers the same recovery deep link twice', async () => {
  Platform.OS = 'ios';

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
    initialLaunchURL: 'plyn://session',
    initialKeyboardRecoveryHandoff: true,
  });

  await waitForKeyboardHandoffPopup(tree, true);
  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();

  await openSessionDeepLink();

  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();
});

test('shows the keyboard handoff popup when iPhone foreground status consumes the recovery marker before the deep link handler runs', async () => {
  Platform.OS = 'ios';
  (
    globalThis as {__Plyń_ENABLE_NATIVE_STATUS_REFRESH__?: boolean}
  ).__Plyń_ENABLE_NATIVE_STATUS_REFRESH__ = true;

  configModule.getStatus
    .mockResolvedValueOnce({
      hasApiKey: true,
      platformMode: 'ios-keyboard-extension',
      sessionActive: true,
      keyboardRecoveryHandoffPending: false,
    })
    .mockResolvedValueOnce({
      hasApiKey: true,
      platformMode: 'ios-keyboard-extension',
      sessionActive: true,
      keyboardRecoveryHandoffPending: false,
    })
    .mockResolvedValueOnce({
      hasApiKey: true,
      platformMode: 'ios-keyboard-extension',
      sessionActive: true,
      keyboardRecoveryHandoffPending: true,
    });
  configModule.consumeKeyboardRecoveryHandoff.mockResolvedValue(false);

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
  });

  await waitForKeyboardHandoffPopup(tree, false);

  await ReactTestRenderer.act(async () => {
    emitAppStateChange('active');
    await flushAsyncWork();
  });

  await openSessionDeepLink();
  await waitForKeyboardHandoffPopup(tree, true);

  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();
  expect(mockTrackEvent).toHaveBeenCalledWith('companion_session_start', {
    platform: 'ios',
    source: 'keyboard_handoff_marker',
    result: 'success',
  });
});

test('shows the keyboard handoff popup on a cold iPhone launch when the native bridge carries the recovery URL', async () => {
  Platform.OS = 'ios';

  const tree = await renderTrackedAppAndFlushLoosely({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
    initialLaunchURL: 'plyn://session',
    initialKeyboardRecoveryHandoff: true,
  });

  await waitForKeyboardHandoffPopup(tree, true);
  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();
});

test('shows the keyboard handoff popup on a cold iPhone launch from the shared marker even without a React deep link', async () => {
  Platform.OS = 'ios';

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
    initialKeyboardRecoveryHandoff: true,
  });

  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();
  expect(mockTrackEvent).toHaveBeenCalledWith('companion_session_start', {
    platform: 'ios',
    source: 'keyboard_handoff_marker',
    result: 'success',
  });
});

test('does not show the keyboard handoff popup on a normal iPhone launch', async () => {
  Platform.OS = 'ios';

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
  });

  await waitForKeyboardHandoffPopup(tree, false);
  expect(queryByTestID(tree, 'keyboard-handoff-popup')).toHaveLength(0);
});

test('does not show the keyboard handoff popup for a session deep link without a keyboard marker', async () => {
  Platform.OS = 'ios';

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
    initialLaunchURL: 'plyn://session',
  });

  await waitForKeyboardHandoffPopup(tree, false);
  expect(queryByTestID(tree, 'keyboard-handoff-popup')).toHaveLength(0);
});

test('does not show the keyboard handoff popup when iPhone recovery fails', async () => {
  Platform.OS = 'ios';
  sessionModule.getStatus.mockResolvedValueOnce({isActive: false});
  sessionModule.startSession.mockResolvedValue({isActive: false});

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
    initialLaunchURL: 'plyn://session',
    initialKeyboardRecoveryHandoff: true,
  });

  await waitForKeyboardHandoffPopup(tree, false);
  expect(queryByTestID(tree, 'keyboard-handoff-popup')).toHaveLength(0);
});

test('hides the keyboard handoff popup when the iPhone app backgrounds', async () => {
  Platform.OS = 'ios';

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
    initialKeyboardRecoveryHandoff: true,
  });

  await waitForKeyboardHandoffPopup(tree, true);
  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();

  ReactTestRenderer.act(() => {
    emitAppStateChange('background');
  });

  expect(queryByTestID(tree, 'keyboard-handoff-popup')).toHaveLength(0);
});

test('keeps the keyboard handoff popup visible during a transient iPhone inactive transition', async () => {
  Platform.OS = 'ios';

  const tree = await renderTrackedAppAndFlush({
    initialHasApiKey: true,
    initialSessionActive: true,
    initialPlatformMode: 'ios-keyboard-extension',
    initialKeyboardRecoveryHandoff: true,
  });

  await waitForKeyboardHandoffPopup(tree, true);
  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();

  ReactTestRenderer.act(() => {
    emitAppStateChange('inactive');
  });

  expect(findByTestID(tree, 'keyboard-handoff-popup')).toBeTruthy();
});
