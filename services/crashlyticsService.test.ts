import {Platform} from 'react-native';
import crashlytics from '@react-native-firebase/crashlytics';
import {
  initializeCrashlytics,
  recordNonFatalCrash,
  triggerTestCrash,
} from './crashlyticsService';

jest.mock('@react-native-firebase/crashlytics', () => {
  const instance = {
    setCrashlyticsCollectionEnabled: jest.fn().mockResolvedValue(undefined),
    setAttributes: jest.fn().mockResolvedValue(undefined),
    log: jest.fn(),
    recordError: jest.fn(),
    crash: jest.fn(),
  };

  return {
    __esModule: true,
    default: jest.fn(() => instance),
  };
});

const crashlyticsInstance = crashlytics();
const originalPlatform = Platform.OS;

describe('crashlyticsService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    Platform.OS = originalPlatform;
  });

  afterAll(() => {
    Platform.OS = originalPlatform;
  });

  test('initializes Crashlytics collection and platform attributes', async () => {
    Platform.OS = 'android';

    await initializeCrashlytics();

    expect(crashlyticsInstance.setCrashlyticsCollectionEnabled).toHaveBeenCalledWith(true);
    expect(crashlyticsInstance.setAttributes).toHaveBeenCalledWith({
      platform: 'android',
      runtime: 'react-native',
    });
    expect(crashlyticsInstance.log).toHaveBeenCalledWith('Crashlytics initialized for android');
  });

  test('triggers a test crash after logging the verification action', () => {
    Platform.OS = 'ios';

    triggerTestCrash();

    expect(crashlyticsInstance.log).toHaveBeenCalledWith('Triggering test Crashlytics crash from ios');
    expect(crashlyticsInstance.crash).toHaveBeenCalledTimes(1);
  });

  test('records a non-fatal Crashlytics error without crashing the app', async () => {
    Platform.OS = 'android';
    const error = new Error('remote config offline');

    await recordNonFatalCrash(error, 'remote_config_sync_failed');

    expect(crashlyticsInstance.log).toHaveBeenCalledWith(
      'Non-fatal Crashlytics error: remote_config_sync_failed',
    );
    expect(crashlyticsInstance.recordError).toHaveBeenCalledWith(error);
    expect(crashlyticsInstance.crash).not.toHaveBeenCalled();
  });
});
