import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Alert,
  AppState,
  Image,
  Linking,
  NativeModules,
  Platform,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  useWindowDimensions,
  Text,
  TextInput,
  View,
} from 'react-native';
import {
  emptyTranscriptionCostRates,
  syncRemoteRuntimeConfig,
  type TranscriptionCostRates,
} from './config/remoteConfigService';
import {
  initializeAnalytics,
  trackEvent,
  trackScreenView,
} from './services/analyticsService';
import {
  initializeCrashlytics,
  triggerTestCrash,
} from './services/crashlyticsService';

type NativeStatus = {
  hasApiKey: boolean;
  sessionActive?: boolean;
  platformMode: 'android-ime' | 'ios-keyboard-extension' | 'unsupported';
};

type ConfigModule = {
  getStatus: () => Promise<NativeStatus>;
  getSectionExpansionState: () => Promise<Partial<SectionExpansionState>>;
  saveSectionExpansionState: (state: SectionExpansionState) => Promise<void>;
  saveApiKey: (key: string) => Promise<void>;
  saveRuntimeConfig: (config: {
    model: string;
    systemPrompt: string;
    keyboardCommandTimeout: number;
    keyboardTranscriptionTimeout: number;
  }) => Promise<void>;
  getLatestTranscriptSnapshot: () => Promise<TranscriptSnapshot | null>;
  clearLatestTranscript: () => Promise<void>;
  resetTokenUsageSummary: () => Promise<void>;
  getTokenUsageSummary: () => Promise<TokenUsageSummary>;
};

type ModalityTokenBreakdown = {
  text: number;
  audio: number;
  image: number;
  video: number;
  document: number;
};

type TokenUsageSnapshot = {
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
  totalTokens: number;
  inputByModality: ModalityTokenBreakdown;
  cachedInputByModality: ModalityTokenBreakdown;
  outputByModality: ModalityTokenBreakdown;
};

type TokenUsageSummary = {
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
  totalTokens: number;
  requestCount: number;
  lastRequest: TokenUsageSnapshot;
  inputByModality: ModalityTokenBreakdown;
  cachedInputByModality: ModalityTokenBreakdown;
  outputByModality: ModalityTokenBreakdown;
};

type TranscriptSnapshot = {
  text: string;
  sessionID: string;
  sequence: number;
  isFinal: boolean;
  state:
    | 'recording'
    | 'streamingPartial'
    | 'completed'
    | 'failed'
    | 'timedOut'
    | 'cancelled'
    | 'empty';
  errorCode?: string | null;
  updatedAt: number;
};

type SessionStatus = {
  isActive: boolean;
};

type SectionExpansionState = {
  onboardingExpanded: boolean;
  setupExpanded: boolean;
  tokenSummaryExpanded: boolean;
};

type SessionModule = {
  getStatus: () => Promise<SessionStatus>;
  startSession: () => Promise<SessionStatus>;
  stopSession: () => Promise<SessionStatus>;
};

type StatusKind = 'neutral' | 'success' | 'error';
type AppScreen = 'main' | 'launch-debug';

type AppProps = {
  initialHasApiKey?: boolean;
  initialSessionActive?: boolean;
  initialPlatformMode?: NativeStatus['platformMode'];
};

const API_KEY_URL = 'https://aistudio.google.com/api-keys';
const LAUNCH_SCREEN_BACKGROUND = '#4A5942';
const launchLogoAsset = require('./assets/launch-preview-logo.png');

const fallbackConfigModule: ConfigModule = {
  getStatus: async () => ({
    hasApiKey: false,
    sessionActive: false,
    platformMode:
      Platform.OS === 'ios' ? 'ios-keyboard-extension' : 'android-ime',
  }),
  getSectionExpansionState: async () => ({}),
  saveSectionExpansionState: async () => undefined,
  saveApiKey: async () => undefined,
  saveRuntimeConfig: async () => undefined,
  getLatestTranscriptSnapshot: async () => null,
  clearLatestTranscript: async () => undefined,
  resetTokenUsageSummary: async () => undefined,
  getTokenUsageSummary: async () => emptyTokenUsageSummary,
};

const fallbackSessionModule: SessionModule = {
  getStatus: async () => ({ isActive: false }),
  startSession: async () => ({ isActive: false }),
  stopSession: async () => ({ isActive: false }),
};

const isTestEnvironment = Boolean(process.env.JEST_WORKER_ID);
const emptyModalityBreakdown: ModalityTokenBreakdown = {
  text: 0,
  audio: 0,
  image: 0,
  video: 0,
  document: 0,
};
const emptyTokenUsageSnapshot: TokenUsageSnapshot = {
  inputTokens: 0,
  cachedInputTokens: 0,
  outputTokens: 0,
  totalTokens: 0,
  inputByModality: emptyModalityBreakdown,
  cachedInputByModality: emptyModalityBreakdown,
  outputByModality: emptyModalityBreakdown,
};
const emptyTokenUsageSummary: TokenUsageSummary = {
  inputTokens: 0,
  cachedInputTokens: 0,
  outputTokens: 0,
  totalTokens: 0,
  requestCount: 0,
  lastRequest: emptyTokenUsageSnapshot,
  inputByModality: emptyModalityBreakdown,
  cachedInputByModality: emptyModalityBreakdown,
  outputByModality: emptyModalityBreakdown,
};
const iosSessionRefreshIntervalMs = 5000;
const oneMillionTokens = 1_000_000;

function shouldRunBootstrapRetries() {
  return (
    !isTestEnvironment ||
    Boolean(
      (globalThis as { __Plyń_ENABLE_BOOTSTRAP_RETRIES__?: boolean })
        .__Plyń_ENABLE_BOOTSTRAP_RETRIES__,
    )
  );
}

function getConfigNativeModule() {
  return NativeModules.PlyńAppConfig ?? NativeModules.PlyńConfig ?? null;
}

function getSessionNativeModule() {
  return NativeModules.PlyńSession ?? null;
}

function createConfigModule(fallbackStatus: NativeStatus): ConfigModule {
  return {
    ...fallbackConfigModule,
    getStatus: async () => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.getStatus) {
        return nativeModule.getStatus();
      }

      return fallbackStatus;
    },
    saveApiKey: async key => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.saveApiKey) {
        return nativeModule.saveApiKey(key);
      }
    },
    saveRuntimeConfig: async config => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.saveRuntimeConfig) {
        return nativeModule.saveRuntimeConfig(config);
      }
    },
    getSectionExpansionState: async () => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.getSectionExpansionState) {
        return nativeModule.getSectionExpansionState();
      }

      return {};
    },
    saveSectionExpansionState: async state => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.saveSectionExpansionState) {
        return nativeModule.saveSectionExpansionState(state);
      }
    },
    getLatestTranscriptSnapshot: async () => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.getLatestTranscriptSnapshot) {
        return nativeModule.getLatestTranscriptSnapshot();
      }

      return null;
    },
    clearLatestTranscript: async () => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.clearLatestTranscript) {
        return nativeModule.clearLatestTranscript();
      }
    },
    resetTokenUsageSummary: async () => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.resetTokenUsageSummary) {
        return nativeModule.resetTokenUsageSummary();
      }
    },
    getTokenUsageSummary: async () => {
      const nativeModule = getConfigNativeModule();

      if (nativeModule?.getTokenUsageSummary) {
        return normalizeTokenUsageSummary(
          await nativeModule.getTokenUsageSummary(),
        );
      }

      return fallbackConfigModule.getTokenUsageSummary();
    },
  };
}

function createSessionModule(fallbackSessionActive: boolean): SessionModule {
  return {
    ...fallbackSessionModule,
    getStatus: async () => {
      const nativeModule = getSessionNativeModule();

      if (nativeModule?.getStatus) {
        return nativeModule.getStatus();
      }

      return { isActive: fallbackSessionActive };
    },
    startSession: async () => {
      const nativeModule = getSessionNativeModule();

      if (nativeModule?.startSession) {
        return nativeModule.startSession();
      }

      return { isActive: fallbackSessionActive };
    },
    stopSession: async () => {
      const nativeModule = getSessionNativeModule();

      if (nativeModule?.stopSession) {
        return nativeModule.stopSession();
      }

      return { isActive: false };
    },
  };
}

function App({
  initialHasApiKey = false,
  initialSessionActive = false,
  initialPlatformMode = 'unsupported',
}: AppProps): React.JSX.Element {
  const { height } = useWindowDimensions();
  const configModule = useMemo<ConfigModule>(
    () =>
      createConfigModule({
        hasApiKey: initialHasApiKey,
        sessionActive: initialSessionActive,
        platformMode: initialPlatformMode,
      }),
    [initialHasApiKey, initialPlatformMode, initialSessionActive],
  );
  const sessionModule = useMemo<SessionModule>(
    () => createSessionModule(initialSessionActive),
    [initialSessionActive],
  );
  const [apiKey, setApiKey] = useState('');
  const [draft, setDraft] = useState('');
  const [statusMessage, setStatusMessage] = useState('Правяраю стан Plyń...');
  const [statusKind, setStatusKind] = useState<StatusKind>('neutral');
  const [setupExpanded, setSetupExpanded] = useState(true);
  const [onboardingExpanded, setOnboardingExpanded] = useState(true);
  const [tokenSummaryExpanded, setTokenSummaryExpanded] = useState(false);
  const [hasApiKey, setHasApiKey] = useState(initialHasApiKey);
  const [_platformMode, setPlatformMode] =
    useState<NativeStatus['platformMode']>(initialPlatformMode);
  const [saving, setSaving] = useState(false);
  const [sessionActive, setSessionActive] = useState(initialSessionActive);
  const [sessionBusy, setSessionBusy] = useState(false);
  const [tokenUsageSummary, setTokenUsageSummary] = useState<TokenUsageSummary>(
    emptyTokenUsageSummary,
  );
  const [transcriptionCostRates, setTranscriptionCostRates] =
    useState<TranscriptionCostRates>(emptyTranscriptionCostRates);
  const [currentScreen, setCurrentScreen] = useState<AppScreen>('main');
  const sectionStateHydratedRef = useRef(false);

  const refreshTokenUsageSummary = useCallback(async () => {
    try {
      const nextSummary = await configModule.getTokenUsageSummary();

      setTokenUsageSummary(current =>
        areTokenUsageSummariesEqual(current, nextSummary)
          ? current
          : nextSummary,
      );
    } catch {
      // Keep the last known totals if the native bridge refresh fails.
    }
  }, [configModule]);

  const handleResetTokenUsageSummary = useCallback(async () => {
    try {
      await configModule.resetTokenUsageSummary();
      await refreshTokenUsageSummary();
    } catch {
      // Keep the current token summary visible if the reset bridge fails.
    }
  }, [configModule, refreshTokenUsageSummary]);

  useEffect(() => {
    let active = true;
    const retryTimers: ReturnType<typeof setTimeout>[] = [];

    const loadStatus = async () => {
      try {
        const status = await configModule.getStatus();
        const hasConfigModule = Boolean(getConfigNativeModule()?.getStatus);
        const hasSessionModule = Boolean(getSessionNativeModule()?.getStatus);
        const resolvedHasApiKey = hasConfigModule
          ? status.hasApiKey
          : initialHasApiKey;
        const resolvedSessionActive = hasConfigModule
          ? status.sessionActive ?? false
          : initialSessionActive;
        const resolvedPlatformMode = hasConfigModule
          ? status.platformMode
          : initialPlatformMode;
        const currentSession = await syncSessionState({
          hasApiKey: resolvedHasApiKey,
          initialSessionActive:
            resolvedSessionActive ||
            (!hasSessionModule && initialSessionActive),
          canStart: true,
          statusMessagePrefix: null,
          sessionModule,
        });

        if (!active) {
          return;
        }

        setHasApiKey(resolvedHasApiKey);
        setPlatformMode(resolvedPlatformMode);
        setSessionActive(currentSession);
        setStatusKind('neutral');
        setStatusMessage(
          buildStatusMessage({
            hasApiKey: resolvedHasApiKey,
            sessionActive: currentSession,
          }),
        );
      } catch (error) {
        if (!active) {
          return;
        }

        setStatusKind('error');
        setStatusMessage(getErrorMessage(error));
      }
    };

    loadStatus();
    void refreshTokenUsageSummary();

    if (shouldRunBootstrapRetries()) {
      [250, 1000, 2500].forEach(delay => {
        retryTimers.push(
          setTimeout(() => {
            if (active) {
              void loadStatus();
            }
          }, delay),
        );
      });
    }

    return () => {
      active = false;
      retryTimers.forEach(clearTimeout);
    };
  }, [
    configModule,
    initialHasApiKey,
    initialPlatformMode,
    initialSessionActive,
    refreshTokenUsageSummary,
    sessionModule,
  ]);

  useEffect(() => {
    if (isTestEnvironment) {
      return;
    }

    let cancelled = false;

    const refreshNativeStatus = async () => {
      try {
        const nativeConfigModule = getConfigNativeModule();

        if (!nativeConfigModule?.getStatus) {
          return;
        }

        const status = await configModule.getStatus();

        if (cancelled) {
          return;
        }

        setHasApiKey(current =>
          current === status.hasApiKey ? current : status.hasApiKey,
        );
        await refreshTokenUsageSummary();
      } catch {
        // Keep the last known UI state when a background refresh fails.
      }
    };

    const subscription = AppState.addEventListener('change', state => {
      if (state === 'active') {
        void refreshNativeStatus();
      }
    });

    void refreshNativeStatus();

    return () => {
      cancelled = true;
      subscription.remove();
    };
  }, [configModule, refreshTokenUsageSummary]);

  useEffect(() => {
    void initializeAnalytics();
  }, []);

  useEffect(() => {
    void initializeCrashlytics();
  }, []);

  useEffect(() => {
    void (async () => {
      const nextRates = await syncRemoteRuntimeConfig(configModule);
      setTranscriptionCostRates(nextRates);
    })();
  }, [configModule]);

  useEffect(() => {
    void trackScreenView('main');
  }, []);

  useEffect(() => {
    let active = true;

    const loadSectionExpansionState = async () => {
      try {
        const savedState = await configModule.getSectionExpansionState();

        if (!active) {
          return;
        }

        if (typeof savedState.onboardingExpanded === 'boolean') {
          setOnboardingExpanded(savedState.onboardingExpanded);
        }

        if (typeof savedState.setupExpanded === 'boolean') {
          setSetupExpanded(savedState.setupExpanded);
        }

        if (typeof savedState.tokenSummaryExpanded === 'boolean') {
          setTokenSummaryExpanded(savedState.tokenSummaryExpanded);
        }
      } catch {
        // Keep default section visibility if local state cannot be restored.
      } finally {
        if (active) {
          sectionStateHydratedRef.current = true;
        }
      }
    };

    void loadSectionExpansionState();

    return () => {
      active = false;
    };
  }, [configModule]);

  useEffect(() => {
    if (!sectionStateHydratedRef.current) {
      return;
    }

    void configModule.saveSectionExpansionState({
      onboardingExpanded,
      setupExpanded,
      tokenSummaryExpanded,
    });
  }, [configModule, onboardingExpanded, setupExpanded, tokenSummaryExpanded]);

  useEffect(() => {
    if (Platform.OS !== 'ios' || isTestEnvironment) {
      return;
    }

    let cancelled = false;

    const refreshSession = async () => {
      try {
        const nativeSessionModule = getSessionNativeModule();

        if (!nativeSessionModule?.getStatus) {
          return;
        }

        const sessionStatus = await sessionModule.getStatus();

        if (cancelled) {
          return;
        }

        setSessionActive(current =>
          current === sessionStatus.isActive ? current : sessionStatus.isActive,
        );
      } catch {
        // Keep the last known UI state when the session bridge refresh fails.
      }
    };

    const subscription = AppState.addEventListener('change', state => {
      if (state === 'active') {
        void refreshSession();
      }
    });

    const interval = setInterval(() => {
      void refreshSession();
    }, iosSessionRefreshIntervalMs);

    void refreshSession();

    return () => {
      cancelled = true;
      subscription.remove();
      clearInterval(interval);
    };
  }, [sessionModule]);

  useEffect(() => {
    let active = true;

    const handleUrl = async (url: string | null) => {
      if (!url || Platform.OS !== 'ios') {
        return;
      }

      if (isLaunchDebugUrl(url)) {
        setCurrentScreen('launch-debug');
        return;
      }

      if (__DEV__ && isCrashlyticsTestUrl(url)) {
        triggerTestCrash();
        return;
      }

      if (!isSessionUrl(url)) {
        return;
      }

      setSessionBusy(true);

      try {
        const nextStatus = await sessionModule.startSession();

        if (!active) {
          return;
        }

        setSessionActive(nextStatus.isActive);
        setStatusKind(nextStatus.isActive ? 'success' : 'error');
        setStatusMessage(
          nextStatus.isActive
            ? 'Кампаньён зноў актыўны. Вярніцеся да клавіятуры.'
            : 'Не ўдалося аднавіць кампаньён.',
        );
        await trackEvent('session_recovery_link_opened', {
          platform: 'ios',
        });
        await trackEvent('companion_session_start', {
          platform: 'ios',
          source: 'deep_link_retry',
          result: nextStatus.isActive ? 'success' : 'error',
        });
      } catch (error) {
        if (active) {
          setStatusKind('error');
          setStatusMessage(getErrorMessage(error));
        }

        await trackEvent('session_recovery_link_opened', {
          platform: 'ios',
        });
        await trackEvent('companion_session_start', {
          platform: 'ios',
          source: 'deep_link_retry',
          result: 'error',
        });
      } finally {
        if (active) {
          setSessionBusy(false);
        }
      }
    };

    void Linking.getInitialURL().then(handleUrl);
    const subscription = Linking.addEventListener('url', event => {
      void handleUrl(event.url);
    });

    return () => {
      active = false;
      subscription.remove();
    };
  }, [sessionModule]);

  useEffect(() => {
    setStatusMessage(current => {
      if (
        statusKind === 'error' ||
        current === 'Кампаньён зноў актыўны. Вярніцеся да клавіятуры.' ||
        current.startsWith('API-ключ захаваны')
      ) {
        return current;
      }

      setStatusKind('neutral');
      return buildStatusMessage({
        hasApiKey,
        sessionActive,
      });
    });
  }, [hasApiKey, sessionActive, statusKind]);

  const handleSaveKey = async () => {
    if (!apiKey.trim()) {
      setStatusKind('error');
      setStatusMessage('Устаўце API-ключ Gemini перад захаваннем.');
      return;
    }

    setSaving(true);
    const platform = getAnalyticsPlatform();
    await trackEvent('api_key_save_attempt', {
      platform,
      source: 'single_page',
    });

    try {
      await configModule.saveApiKey(apiKey.trim());
      setHasApiKey(true);
      setApiKey('');

      await trackEvent('api_key_save_result', {
        platform,
        result: 'success',
      });

      if (Platform.OS === 'ios') {
        try {
          const nextSessionStatus = await sessionModule.startSession();
          setSessionActive(nextSessionStatus.isActive);
          setStatusKind('success');
          setStatusMessage(
            nextSessionStatus.isActive
              ? 'API-ключ захаваны, кампаньён актыўны.'
              : 'API-ключ захаваны, але кампаньён не запусціўся.',
          );
          await trackEvent('companion_session_start', {
            platform,
            source: 'settings_save',
            result: nextSessionStatus.isActive ? 'success' : 'error',
          });
        } catch {
          setSessionActive(false);
          setStatusKind('success');
          setStatusMessage('API-ключ захаваны, але кампаньён не запусціўся.');
          await trackEvent('companion_session_start', {
            platform,
            source: 'settings_save',
            result: 'error',
          });
        }

        return;
      }

      setSessionActive(false);
      setStatusKind('success');
      setStatusMessage('API-ключ захаваны на гэтай прыладзе.');
    } catch (error) {
      setStatusKind('error');
      setStatusMessage(getErrorMessage(error));
      await trackEvent('api_key_save_result', {
        platform,
        result: 'error',
      });
    } finally {
      setSaving(false);
    }
  };

  const handleAndroidEnableHint = () => {
    void trackEvent('keyboard_enable_help_opened', {
      platform: 'android',
    });
    Alert.alert(
      'Уключыць Plyń на Android',
      'Пасля захавання API-ключа адкрыйце Налады Android > Сістэма > Клавіятура > Экранная клавіятура і ўключыце Plyń. Потым выберыце яе праз пераключальнік клавіятур.',
    );
  };

  const handleIosEnableHint = () => {
    void trackEvent('keyboard_enable_help_opened', {
      platform: 'ios',
    });
    Alert.alert(
      'Уключыць Plyń на iPhone',
      'Адкрыйце Налады > Асноўныя > Клавіятура > Клавіятуры > Дадаць новую клавіятуру, выберыце Plyń, а потым уключыце Поўны доступ, каб пашырэнне магло чытаць агульныя налады і апошні транскрыпт.',
    );
  };

  const handleSessionToggle = async () => {
    setSessionBusy(true);
    const platform = getAnalyticsPlatform();

    try {
      const nextStatus = sessionActive
        ? await sessionModule.stopSession()
        : await sessionModule.startSession();
      setSessionActive(nextStatus.isActive);
      setStatusKind(nextStatus.isActive ? 'success' : 'neutral');
      setStatusMessage(
        nextStatus.isActive ? 'Кампаньён актыўны' : 'Кампаньён спынены',
      );

      if (sessionActive) {
        await trackEvent('companion_session_stop', {
          platform,
          source: 'manual_toggle',
        });
      } else {
        await trackEvent('companion_session_start', {
          platform,
          source: 'manual_toggle',
          result: nextStatus.isActive ? 'success' : 'error',
        });
      }
    } catch (error) {
      setStatusKind('error');
      setStatusMessage(getErrorMessage(error));

      if (!sessionActive) {
        await trackEvent('companion_session_start', {
          platform,
          source: 'manual_toggle',
          result: 'error',
        });
      }
    } finally {
      setSessionBusy(false);
    }
  };

  const handleOpenApiKeyPage = async () => {
    await Linking.openURL(API_KEY_URL);
  };

  if (currentScreen === 'launch-debug') {
    return (
      <View
        testID="launch-debug-screen"
        style={styles.launchDebugScreen}
        accessibilityLabel="Папярэдні прагляд загрузачнага экрана Plyń"
      >
        <StatusBar
          barStyle="dark-content"
          backgroundColor={LAUNCH_SCREEN_BACKGROUND}
        />
        <View style={styles.launchDebugCanvas}>
          <Image
            source={launchLogoAsset}
            style={styles.launchDebugLogo}
            resizeMode="contain"
          />
        </View>
      </View>
    );
  }

  return (
    <View style={styles.safeArea}>
      <StatusBar barStyle="dark-content" />
      <ScrollView
        style={styles.safeArea}
        contentContainerStyle={[
          styles.screen,
          {
            paddingTop:
              Platform.OS === 'android' ? 18 : Math.max(18, height * 0.04),
          },
        ]}
        keyboardShouldPersistTaps="handled"
        contentInsetAdjustmentBehavior="always"
      >
        <View style={styles.onboardingCard}>
          <Pressable
            testID="onboarding-toggle"
            accessibilityLabel={
              onboardingExpanded
                ? 'Схаваць раздзел Як гэта працуе'
                : 'Паказаць раздзел Як гэта працуе'
            }
            style={({ pressed }) => [
              styles.tokenSummaryHeader,
              pressed && styles.inlineTogglePressed,
            ]}
            onPress={() => setOnboardingExpanded(current => !current)}
          >
            <Text style={styles.sectionTitle}>Як гэта працуе</Text>
            <Text style={styles.tokenSummaryChevron}>
              {onboardingExpanded ? '↑' : '↓'}
            </Text>
          </Pressable>
          {onboardingExpanded ? (
            <View testID="onboarding-content" style={styles.expandableContent}>
              <Text style={styles.infoLead}>
                Plyń дапамагае хутка пераўтвараць голас у беларускі тэкст.
              </Text>
              <Text style={styles.infoCopy}>
                Калі кампаньён актыўны, запіс хутчэй апрацоўваецца і вяртаецца
                гатовым тэкстам без лішніх крокаў.
              </Text>

              {Platform.OS === 'android' ? (
                <Pressable
                  testID="android-enable-help-button"
                  accessibilityLabel="Уключыць клавіятуру Android"
                  style={({ pressed }) => [
                    styles.secondaryButton,
                    pressed && styles.secondaryButtonPressed,
                  ]}
                  onPress={handleAndroidEnableHint}
                >
                  <Text style={styles.secondaryButtonLabel}>
                    Як уключыць клавіятуру Android
                  </Text>
                </Pressable>
              ) : null}

              {Platform.OS === 'ios' ? (
                <Pressable
                  testID="ios-enable-help-button"
                  accessibilityLabel="Уключыць клавіятуру iPhone"
                  style={({ pressed }) => [
                    styles.secondaryButton,
                    pressed && styles.secondaryButtonPressed,
                  ]}
                  onPress={handleIosEnableHint}
                >
                  <Text style={styles.secondaryButtonLabel}>
                    Як уключыць клавіятуру iPhone
                  </Text>
                </Pressable>
              ) : null}

              {Platform.OS === 'ios' ? (
                <Pressable
                  testID="session-toggle-button"
                  accessibilityLabel={
                    sessionActive ? 'Спыніць кампаньён' : 'Запусціць кампаньён'
                  }
                  disabled={sessionBusy || !hasApiKey}
                  style={({ pressed }) => [
                    styles.secondaryButton,
                    pressed && styles.secondaryButtonPressed,
                    (sessionBusy || !hasApiKey) && styles.buttonDisabled,
                  ]}
                  onPress={handleSessionToggle}
                >
                  <Text style={styles.secondaryButtonLabel}>
                    {sessionBusy
                      ? 'Абнаўляю кампаньён...'
                      : sessionActive
                      ? 'Спыніць кампаньён'
                      : 'Запусціць кампаньён'}
                  </Text>
                </Pressable>
              ) : null}
            </View>
          ) : null}
        </View>

        <View style={styles.heroCard}>
          <Pressable
            testID="setup-toggle"
            accessibilityLabel={
              setupExpanded
                ? 'Схаваць раздзел Наладзьце Plyń'
                : 'Паказаць раздзел Наладзьце Plyń'
            }
            style={({ pressed }) => [
              styles.tokenSummaryHeader,
              pressed && styles.inlineTogglePressed,
            ]}
            onPress={() => setSetupExpanded(current => !current)}
          >
            <Text style={styles.sectionTitle}>Наладзьце Plyń</Text>
            <Text style={styles.tokenSummaryChevron}>
              {setupExpanded ? '↑' : '↓'}
            </Text>
          </Pressable>
          <Text style={styles.tokenSummaryCaption}>
            Дадайце API-ключ і праверце, ці гатовая праграма да дыктоўкі.
          </Text>

          {setupExpanded ? (
            <View testID="setup-content" style={styles.expandableContent}>
              <Pressable
                testID="api-key-help-link"
                accessibilityLabel="Адкрыць старонку для атрымання API-ключа Gemini"
                style={({ pressed }) => [
                  styles.linkRow,
                  pressed && styles.linkRowPressed,
                ]}
                onPress={() => {
                  void handleOpenApiKeyPage();
                }}
              >
                <Text style={styles.linkLabel}>Дзе атрымаць API-ключ</Text>
                <Text style={styles.linkUrl}>aistudio.google.com/api-keys</Text>
              </Pressable>

              <View style={styles.statusRow}>
                <View
                  testID="session-status-dot"
                  style={[
                    styles.statusDot,
                    sessionActive
                      ? styles.statusDotActive
                      : styles.statusDotInactive,
                  ]}
                />
                <Text testID="session-status-label" style={styles.statusLabel}>
                  {Platform.OS === 'ios'
                    ? sessionActive
                      ? 'Кампаньён актыўны'
                      : 'Кампаньён неактыўны'
                    : hasApiKey
                    ? 'Gemini гатовы'
                    : 'Патрэбны ключ Gemini'}
                </Text>
              </View>

              <View style={styles.settingsStatusRow}>
                <View
                  testID="api-key-status-dot"
                  style={[
                    styles.settingsStatusDot,
                    hasApiKey
                      ? styles.settingsStatusDotSaved
                      : styles.settingsStatusDotMissing,
                  ]}
                />
                <Text
                  testID="api-key-status-label"
                  style={styles.settingsStatusText}
                >
                  {hasApiKey
                    ? 'API-ключ захаваны на гэтай прыладзе'
                    : 'API-ключ яшчэ не захаваны'}
                </Text>
              </View>

              <TextInput
                testID="api-key-input"
                autoCapitalize="none"
                autoCorrect={false}
                placeholder="Устаўце API-ключ Gemini"
                placeholderTextColor="#8b7f75"
                secureTextEntry
                style={styles.input}
                value={apiKey}
                onChangeText={setApiKey}
              />

              <Pressable
                testID="save-api-key-button"
                accessibilityLabel="Захаваць API-ключ"
                disabled={saving}
                style={({ pressed }) => [
                  styles.primaryButton,
                  pressed && styles.primaryButtonPressed,
                  saving && styles.buttonDisabled,
                ]}
                onPress={handleSaveKey}
              >
                <Text style={styles.primaryButtonLabel}>
                  {saving ? 'Захоўваецца...' : 'Захаваць API-ключ'}
                </Text>
              </Pressable>

              <Text
                testID="setup-status-message"
                style={[
                  styles.statusMessage,
                  statusKind === 'error' ? styles.statusMessageError : null,
                  statusKind === 'success' ? styles.statusMessageSuccess : null,
                ]}
              >
                {statusMessage}
              </Text>
            </View>
          ) : null}
        </View>

        <View style={styles.settingsCard}>
          <Text style={styles.settingsTitle}>Чарнавік</Text>
          <TextInput
            multiline
            testID="draft-input"
            placeholder="Пачніце дыктоўку або пішыце ўручную"
            placeholderTextColor="#8b7f75"
            style={styles.composer}
            value={draft}
            onChangeText={setDraft}
          />
        </View>

        <View style={styles.tokenSummaryCard}>
          <Pressable
            testID="token-summary-toggle"
            accessibilityLabel={
              tokenSummaryExpanded
                ? 'Схаваць кошт транскрыпцыі'
                : 'Паказаць кошт транскрыпцыі'
            }
            style={({ pressed }) => [
              styles.tokenSummaryHeader,
              pressed && styles.inlineTogglePressed,
            ]}
            onPress={() => setTokenSummaryExpanded(current => !current)}
          >
            <Text style={styles.tokenSummaryTitle}>Кошт транскрыпцыі</Text>
            <Text style={styles.tokenSummaryChevron}>
              {tokenSummaryExpanded ? '↑' : '↓'}
            </Text>
          </Pressable>
          <Text style={styles.tokenSummaryCaption}>
            Апошні паспяховы запыт, назапашаныя сумы і сярэднія значэнні для
            гэтай прылады.
          </Text>

          {tokenSummaryExpanded ? (
            <View
              testID="token-summary-content"
              style={styles.expandableContent}
            >
              <View style={styles.tokenSummaryColumnHeader}>
                <Pressable
                  testID="token-summary-reset-button"
                  accessibilityLabel="Скінуць статыстыку транскрыпцыі"
                  style={({pressed}) => [
                    styles.tokenSummaryResetButton,
                    pressed && styles.inlineTogglePressed,
                  ]}
                  onPress={() => {
                    void handleResetTokenUsageSummary();
                  }}
                >
                  <Text style={styles.tokenSummaryResetButtonText}>Скінуць</Text>
                </Pressable>
                <Text style={styles.tokenSummaryColumnTitle}>токены/$</Text>
              </View>
              {renderTokenSummarySection({
                testID: 'token-summary-last-request-section',
                title: 'Апошні запыт',
                summary: tokenUsageSummary.lastRequest,
                transcriptionCostRates,
              })}
              {renderTokenSummarySection({
                testID: 'token-summary-total-section',
                title: 'Усяго',
                summary: tokenUsageSummary,
                transcriptionCostRates,
              })}
              {renderTokenSummarySection({
                testID: 'token-summary-average-section',
                title: 'Сярэдняе на запыт',
                summary: getAverageTokenUsageSnapshot(tokenUsageSummary),
                transcriptionCostRates,
              })}
            </View>
          ) : null}
        </View>
      </ScrollView>
    </View>
  );
}

function renderTokenSummaryRows(rows: Array<[string, number, number]>) {
  return rows.map(([label, value, rate]) => (
    <View key={label} style={styles.tokenSummaryRow}>
      <Text style={styles.tokenSummaryLabel}>{label}</Text>
      <Text style={styles.tokenSummaryValue}>
        {formatTokenCost(value, rate)}
      </Text>
    </View>
  ));
}

function getInputTokenSummaryRows(
  summary: TokenUsageSummary | TokenUsageSnapshot,
  transcriptionCostRates: TranscriptionCostRates,
): Array<[string, number, number]> {
  return [
    ['Text', summary.inputByModality.text, transcriptionCostRates.inputText],
    ['Audio', summary.inputByModality.audio, transcriptionCostRates.inputAudio],
    [
      'Cached text',
      summary.cachedInputByModality.text,
      transcriptionCostRates.inputCacheText,
    ],
    [
      'Cached audio',
      summary.cachedInputByModality.audio,
      transcriptionCostRates.inputCacheAudio,
    ],
  ];
}

function getOutputTokenSummaryRows(
  summary: TokenUsageSummary | TokenUsageSnapshot,
  transcriptionCostRates: TranscriptionCostRates,
): Array<[string, number, number]> {
  return [
    [
      'Text',
      getOutputTextTokenCount(summary),
      transcriptionCostRates.outputText,
    ],
  ];
}

function renderTokenSummarySection({
  testID,
  title,
  summary,
  transcriptionCostRates,
}: {
  testID: string;
  title: string;
  summary: TokenUsageSummary | TokenUsageSnapshot;
  transcriptionCostRates: TranscriptionCostRates;
}) {
  return (
    <View testID={testID} style={styles.tokenSummarySection}>
      <Text style={styles.tokenSummarySectionTitle}>{title}</Text>
      <Text style={styles.tokenSummarySubsectionTitle}>IN</Text>
      {renderTokenSummaryRows(
        getInputTokenSummaryRows(summary, transcriptionCostRates),
      )}
      <Text style={styles.tokenSummarySubsectionTitle}>OUT</Text>
      {renderTokenSummaryRows(
        getOutputTokenSummaryRows(summary, transcriptionCostRates),
      )}
    </View>
  );
}

async function syncSessionState({
  hasApiKey,
  initialSessionActive,
  canStart,
  statusMessagePrefix,
  sessionModule,
}: {
  hasApiKey: boolean;
  initialSessionActive: boolean;
  canStart: boolean;
  statusMessagePrefix: string | null;
  sessionModule: SessionModule;
}) {
  if (Platform.OS !== 'ios') {
    return false;
  }

  if (initialSessionActive) {
    return true;
  }

  const sessionStatus = await sessionModule.getStatus();
  if (!hasApiKey || sessionStatus.isActive || !canStart) {
    return sessionStatus.isActive;
  }

  const nextStatus = await sessionModule.startSession();
  await trackEvent('companion_session_start', {
    platform: 'ios',
    source: 'auto_start',
    result: nextStatus.isActive ? 'success' : 'error',
  });
  void statusMessagePrefix;
  return nextStatus.isActive;
}

function formatTokenCount(value: number) {
  return String(value);
}

function formatDollarAmount(value: number) {
  return value.toFixed(4);
}

function formatTokenCost(tokens: number, rate: number) {
  return `${formatTokenCount(tokens)} / ${formatDollarAmount(
    (tokens / oneMillionTokens) * rate,
  )}$`;
}

function normalizeModalityBreakdown(
  value?: Partial<ModalityTokenBreakdown> | null,
): ModalityTokenBreakdown {
  return {
    text: value?.text ?? 0,
    audio: value?.audio ?? 0,
    image: value?.image ?? 0,
    video: value?.video ?? 0,
    document: value?.document ?? 0,
  };
}

function getModalityBreakdownTotal(value: ModalityTokenBreakdown) {
  return value.text + value.audio + value.image + value.video + value.document;
}

function normalizeModalBreakdownWithRemainder(
  totalTokens: number,
  value: Partial<ModalityTokenBreakdown> | null | undefined,
  fallbackModality: keyof ModalityTokenBreakdown,
): ModalityTokenBreakdown {
  const normalized = normalizeModalityBreakdown(value);
  const remainder = totalTokens - getModalityBreakdownTotal(normalized);

  if (remainder <= 0) {
    return normalized;
  }

  return {
    ...normalized,
    [fallbackModality]: normalized[fallbackModality] + remainder,
  };
}

function normalizeTokenUsageSnapshot(
  value?: Partial<TokenUsageSnapshot> | null,
): TokenUsageSnapshot {
  const inputTokens = value?.inputTokens ?? 0;
  const cachedInputTokens = value?.cachedInputTokens ?? 0;
  const outputTokens = value?.outputTokens ?? 0;

  return {
    inputTokens,
    cachedInputTokens,
    outputTokens,
    totalTokens: value?.totalTokens ?? 0,
    inputByModality: normalizeModalBreakdownWithRemainder(
      inputTokens,
      value?.inputByModality,
      'audio',
    ),
    cachedInputByModality: normalizeModalBreakdownWithRemainder(
      cachedInputTokens,
      value?.cachedInputByModality,
      'audio',
    ),
    outputByModality: normalizeModalBreakdownWithRemainder(
      outputTokens,
      value?.outputByModality,
      'text',
    ),
  };
}

function normalizeTokenUsageSummary(
  value?: Partial<TokenUsageSummary> | null,
): TokenUsageSummary {
  const inputTokens = value?.inputTokens ?? 0;
  const cachedInputTokens = value?.cachedInputTokens ?? 0;
  const outputTokens = value?.outputTokens ?? 0;

  return {
    inputTokens,
    cachedInputTokens,
    outputTokens,
    totalTokens: value?.totalTokens ?? 0,
    requestCount: value?.requestCount ?? 0,
    lastRequest: normalizeTokenUsageSnapshot(value?.lastRequest),
    inputByModality: normalizeModalBreakdownWithRemainder(
      inputTokens,
      value?.inputByModality,
      'audio',
    ),
    cachedInputByModality: normalizeModalBreakdownWithRemainder(
      cachedInputTokens,
      value?.cachedInputByModality,
      'audio',
    ),
    outputByModality: normalizeModalBreakdownWithRemainder(
      outputTokens,
      value?.outputByModality,
      'text',
    ),
  };
}

function areModalityBreakdownsEqual(
  left: ModalityTokenBreakdown,
  right: ModalityTokenBreakdown,
) {
  return (
    left.text === right.text &&
    left.audio === right.audio &&
    left.image === right.image &&
    left.video === right.video &&
    left.document === right.document
  );
}

function areTokenUsageSummariesEqual(
  left: TokenUsageSummary,
  right: TokenUsageSummary,
) {
  return (
    left.inputTokens === right.inputTokens &&
    left.cachedInputTokens === right.cachedInputTokens &&
    left.outputTokens === right.outputTokens &&
    left.totalTokens === right.totalTokens &&
    left.requestCount === right.requestCount &&
    left.lastRequest.inputTokens === right.lastRequest.inputTokens &&
    left.lastRequest.cachedInputTokens === right.lastRequest.cachedInputTokens &&
    left.lastRequest.outputTokens === right.lastRequest.outputTokens &&
    left.lastRequest.totalTokens === right.lastRequest.totalTokens &&
    areModalityBreakdownsEqual(
      left.lastRequest.inputByModality,
      right.lastRequest.inputByModality,
    ) &&
    areModalityBreakdownsEqual(
      left.lastRequest.cachedInputByModality,
      right.lastRequest.cachedInputByModality,
    ) &&
    areModalityBreakdownsEqual(
      left.lastRequest.outputByModality,
      right.lastRequest.outputByModality,
    ) &&
    areModalityBreakdownsEqual(left.inputByModality, right.inputByModality) &&
    areModalityBreakdownsEqual(
      left.cachedInputByModality,
      right.cachedInputByModality,
    ) &&
    areModalityBreakdownsEqual(left.outputByModality, right.outputByModality)
  );
}

function getOutputTextTokenCount(summary: TokenUsageSummary | TokenUsageSnapshot) {
  const explicitOutputTotal = Object.values(summary.outputByModality).reduce(
    (total, value) => total + value,
    0,
  );

  if (explicitOutputTotal > 0) {
    return summary.outputByModality.text;
  }

  return summary.outputTokens;
}

function getAveragePerRequest(total: number, requestCount: number) {
  if (requestCount <= 0) {
    return 0;
  }

  return Math.round(total / requestCount);
}

function getAverageTokenUsageSnapshot(
  summary: TokenUsageSummary,
): TokenUsageSnapshot {
  return {
    inputTokens: getAveragePerRequest(summary.inputTokens, summary.requestCount),
    cachedInputTokens: getAveragePerRequest(
      summary.cachedInputTokens,
      summary.requestCount,
    ),
    outputTokens: getAveragePerRequest(
      summary.outputTokens,
      summary.requestCount,
    ),
    totalTokens: getAveragePerRequest(summary.totalTokens, summary.requestCount),
    inputByModality: {
      text: getAveragePerRequest(
        summary.inputByModality.text,
        summary.requestCount,
      ),
      audio: getAveragePerRequest(
        summary.inputByModality.audio,
        summary.requestCount,
      ),
      image: getAveragePerRequest(
        summary.inputByModality.image,
        summary.requestCount,
      ),
      video: getAveragePerRequest(
        summary.inputByModality.video,
        summary.requestCount,
      ),
      document: getAveragePerRequest(
        summary.inputByModality.document,
        summary.requestCount,
      ),
    },
    cachedInputByModality: {
      text: getAveragePerRequest(
        summary.cachedInputByModality.text,
        summary.requestCount,
      ),
      audio: getAveragePerRequest(
        summary.cachedInputByModality.audio,
        summary.requestCount,
      ),
      image: getAveragePerRequest(
        summary.cachedInputByModality.image,
        summary.requestCount,
      ),
      video: getAveragePerRequest(
        summary.cachedInputByModality.video,
        summary.requestCount,
      ),
      document: getAveragePerRequest(
        summary.cachedInputByModality.document,
        summary.requestCount,
      ),
    },
    outputByModality: {
      text: getAveragePerRequest(
        getOutputTextTokenCount(summary),
        summary.requestCount,
      ),
      audio: getAveragePerRequest(
        summary.outputByModality.audio,
        summary.requestCount,
      ),
      image: getAveragePerRequest(
        summary.outputByModality.image,
        summary.requestCount,
      ),
      video: getAveragePerRequest(
        summary.outputByModality.video,
        summary.requestCount,
      ),
      document: getAveragePerRequest(
        summary.outputByModality.document,
        summary.requestCount,
      ),
    },
  };
}

function getAnalyticsPlatform() {
  return Platform.OS === 'ios' ? 'ios' : 'android';
}

function isSessionUrl(url: string) {
  return /^plyn:\/\/session(?:\/|$)/i.test(url);
}

function isLaunchDebugUrl(url: string) {
  return /^plyn:\/\/debug\/launch(?:\/|$|\?)/i.test(url);
}

function isCrashlyticsTestUrl(url: string) {
  return /^plyn:\/\/crashlytics-test(?:\/|$)/i.test(url);
}

function buildStatusMessage({
  hasApiKey,
  sessionActive,
}: {
  hasApiKey: boolean;
  sessionActive: boolean;
}) {
  if (!hasApiKey) {
    return 'Захавайце API-ключ Gemini, каб наладзіць Plyń.';
  }

  if (Platform.OS === 'ios') {
    return sessionActive
      ? 'Кампаньён актыўны і гатовы для выкарыстання.'
      : 'Кампаньён спынены. Яго можна аднавіць з праграмы або з клавіятуры.';
  }

  return 'Чарнавік гатовы. Рэдагаванне і дыктоўка даступныя праз клавіятуру Plyń.';
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return 'Падчас звароту да Gemini нешта пайшло не так.';
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#f2ece3',
  },
  launchDebugScreen: {
    flex: 1,
    backgroundColor: LAUNCH_SCREEN_BACKGROUND,
  },
  launchDebugCanvas: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  launchDebugLogo: {
    width: 320,
    height: 320,
    maxWidth: '100%',
  },
  screen: {
    paddingHorizontal: 18,
    paddingTop: 10,
    paddingBottom: 18,
    gap: 16,
    backgroundColor: '#f2ece3',
    flexGrow: 1,
  },
  heroCard: {
    borderRadius: 30,
    padding: 22,
    backgroundColor: '#fcf8f2',
    borderWidth: 1,
    borderColor: '#e1d5c6',
    gap: 12,
  },
  eyebrow: {
    color: '#7d6c5f',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
  lead: {
    color: '#5e5349',
    fontSize: 16,
    lineHeight: 23,
  },
  linkRow: {
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#d8c7b3',
    backgroundColor: '#f6eee3',
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 4,
  },
  linkRowPressed: {
    opacity: 0.84,
  },
  linkLabel: {
    color: '#2d241e',
    fontSize: 15,
    fontWeight: '700',
  },
  linkUrl: {
    color: '#7d6c5f',
    fontSize: 13,
    lineHeight: 18,
  },
  onboardingCard: {
    borderRadius: 28,
    padding: 18,
    backgroundColor: '#fff8ef',
    borderWidth: 1,
    borderColor: '#e7d8c0',
    gap: 10,
  },
  sectionTitle: {
    color: '#2d241e',
    fontSize: 20,
    fontWeight: '700',
  },
  infoLead: {
    color: '#4e4136',
    fontSize: 15,
    lineHeight: 22,
    fontWeight: '600',
  },
  infoCopy: {
    color: '#6a5c50',
    fontSize: 14,
    lineHeight: 20,
  },
  inlineToggle: {
    alignSelf: 'flex-start',
    borderRadius: 999,
    backgroundColor: '#efe2cf',
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  inlineTogglePressed: {
    opacity: 0.84,
  },
  inlineToggleLabel: {
    color: '#4e4136',
    fontSize: 14,
    fontWeight: '700',
  },
  expandableContent: {
    gap: 10,
    paddingTop: 2,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  statusDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  statusDotActive: {
    backgroundColor: '#3f8f59',
  },
  statusDotInactive: {
    backgroundColor: '#c95743',
  },
  statusLabel: {
    color: '#2d241e',
    fontSize: 15,
    fontWeight: '700',
  },
  statusMessage: {
    color: '#5e5349',
    fontSize: 14,
    lineHeight: 20,
  },
  statusMessageError: {
    color: '#b24632',
    fontWeight: '700',
  },
  statusMessageSuccess: {
    color: '#2f7a49',
  },
  platformCopy: {
    color: '#7d6c5f',
    fontSize: 13,
    lineHeight: 18,
  },
  composerCard: {
    borderRadius: 34,
    backgroundColor: '#fffdf9',
    borderWidth: 1,
    borderColor: '#e1d5c6',
    overflow: 'hidden',
    minHeight: 220,
  },
  composer: {
    minHeight: 180,
    color: '#2d241e',
    fontSize: 17,
    lineHeight: 24,
    paddingHorizontal: 4,
    paddingTop: 8,
    paddingBottom: 4,
    textAlignVertical: 'top',
  },
  settingsCard: {
    borderRadius: 28,
    padding: 18,
    backgroundColor: '#fcf8f2',
    borderWidth: 1,
    borderColor: '#e1d5c6',
    gap: 8,
  },
  settingsTitle: {
    color: '#2d241e',
    fontSize: 18,
    fontWeight: '700',
  },
  tokenSummaryCard: {
    borderRadius: 28,
    padding: 18,
    backgroundColor: '#fff8ef',
    borderWidth: 1,
    borderColor: '#e7d8c0',
    gap: 10,
  },
  tokenSummaryHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  tokenSummaryTitle: {
    color: '#2d241e',
    fontSize: 18,
    fontWeight: '700',
  },
  tokenSummaryChevron: {
    color: '#6a5c50',
    fontSize: 18,
    fontWeight: '700',
  },
  tokenSummaryCaption: {
    color: '#6a5c50',
    fontSize: 13,
    lineHeight: 18,
  },
  tokenSummarySectionTitle: {
    marginTop: 10,
    color: '#5a4738',
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },
  tokenSummaryColumnHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  tokenSummaryResetButton: {
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 5,
    backgroundColor: '#f4e8d7',
    borderWidth: 1,
    borderColor: '#ddccb2',
  },
  tokenSummaryResetButtonText: {
    color: '#6a5c50',
    fontSize: 12,
    fontWeight: '700',
  },
  tokenSummaryColumnTitle: {
    color: '#6a5c50',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'lowercase',
  },
  tokenSummarySection: {
    gap: 8,
  },
  tokenSummaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  tokenSummaryLabel: {
    color: '#5e5349',
    fontSize: 14,
    flex: 1,
  },
  tokenSummaryValue: {
    color: '#2d241e',
    fontSize: 15,
    fontWeight: '700',
  },
  tokenSummarySubsectionTitle: {
    color: '#7a695c',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
  },
  settingsStatusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  settingsStatusDot: {
    width: 10,
    height: 10,
    borderRadius: 999,
  },
  settingsStatusDotSaved: {
    backgroundColor: '#3f8f59',
  },
  settingsStatusDotMissing: {
    backgroundColor: '#c95743',
  },
  settingsStatusText: {
    color: '#5e5349',
    fontSize: 14,
    fontWeight: '600',
  },
  input: {
    backgroundColor: '#fffdf9',
    borderRadius: 18,
    borderWidth: 1,
    borderColor: '#e1d5c6',
    color: '#2d241e',
    fontSize: 16,
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  primaryButton: {
    borderRadius: 999,
    backgroundColor: '#4f7c5e',
    paddingHorizontal: 18,
    paddingVertical: 14,
  },
  primaryButtonPressed: {
    opacity: 0.9,
  },
  primaryButtonLabel: {
    color: '#f8f4ec',
    fontSize: 15,
    fontWeight: '700',
    textAlign: 'center',
  },
  secondaryButton: {
    borderRadius: 999,
    borderWidth: 1,
    borderColor: '#d7c8b5',
    paddingHorizontal: 18,
    paddingVertical: 14,
  },
  secondaryButtonPressed: {
    opacity: 0.86,
  },
  secondaryButtonLabel: {
    color: '#4e4136',
    fontSize: 15,
    fontWeight: '600',
    textAlign: 'center',
  },
  buttonDisabled: {
    opacity: 0.5,
  },
});

export default App;
