import crashlytics from '@react-native-firebase/crashlytics';
import {Platform} from 'react-native';

let crashlyticsReadyPromise: Promise<void> | null = null;
const shouldUseNativeCrashlytics = !(!__DEV__ && Platform.OS === 'ios');

function logCrashlyticsWarning(message: string, error: unknown) {
  if (!__DEV__) {
    return;
  }

  const details = error instanceof Error ? error.message : String(error);
  console.warn(`[crashlytics] ${message}: ${details}`);
}

export async function initializeCrashlytics() {
  if (!shouldUseNativeCrashlytics) {
    return;
  }

  if (crashlyticsReadyPromise) {
    return crashlyticsReadyPromise;
  }

  crashlyticsReadyPromise = (async () => {
    try {
      await crashlytics().setCrashlyticsCollectionEnabled(true);
      await crashlytics().setAttributes({
        platform: Platform.OS,
        runtime: 'react-native',
      });
      crashlytics().log(`Crashlytics initialized for ${Platform.OS}`);
    } catch (error) {
      logCrashlyticsWarning('failed to initialize crashlytics', error);
      throw error;
    }
  })().catch(() => undefined);

  return crashlyticsReadyPromise;
}

export async function recordNonFatalCrash(error: Error, context: string) {
  if (!shouldUseNativeCrashlytics) {
    return;
  }

  try {
    await initializeCrashlytics();
    crashlytics().log(`Non-fatal Crashlytics error: ${context}`);
    crashlytics().recordError(error);
  } catch (reportingError) {
    logCrashlyticsWarning(`failed to record non-fatal error for ${context}`, reportingError);
  }
}

export function triggerTestCrash() {
  if (!shouldUseNativeCrashlytics) {
    return;
  }

  crashlytics().log(`Triggering test Crashlytics crash from ${Platform.OS}`);
  crashlytics().crash();
}
