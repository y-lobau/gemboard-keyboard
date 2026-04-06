import analytics from '@react-native-firebase/analytics';
import {Platform} from 'react-native';

export type AnalyticsParams = Record<string, string | number>;

let analyticsReadyPromise: Promise<void> | null = null;
const shouldUseNativeAnalytics = !(!__DEV__ && Platform.OS === 'ios');

function logAnalyticsWarning(message: string, error: unknown) {
  if (!__DEV__) {
    return;
  }

  const details = error instanceof Error ? error.message : String(error);
  // Surface Firebase Analytics failures while debugging instead of swallowing them silently.
  console.warn(`[analytics] ${message}: ${details}`);
}

export async function initializeAnalytics() {
  if (!shouldUseNativeAnalytics) {
    return;
  }

  if (analyticsReadyPromise) {
    return analyticsReadyPromise;
  }

  analyticsReadyPromise = (async () => {
    try {
      await analytics().setAnalyticsCollectionEnabled(true);
      await analytics().logEvent('analytics_initialized', {
        platform: Platform.OS,
      });
    } catch (error) {
      logAnalyticsWarning('failed to initialize analytics', error);
      throw error;
    }
  })().catch(() => undefined);

  return analyticsReadyPromise;
}

async function ensureAnalyticsReady() {
  if (!shouldUseNativeAnalytics) {
    return;
  }

  try {
    await initializeAnalytics();
  } catch {
    return;
  }
}

export async function trackScreenView(screenName: string) {
  if (!shouldUseNativeAnalytics) {
    return;
  }

  try {
    await ensureAnalyticsReady();
    await analytics().logScreenView({
      screen_name: screenName,
      screen_class: 'App',
    });
  } catch (error) {
    logAnalyticsWarning(`failed to log screen view ${screenName}`, error);
    return;
  }
}

export async function trackEvent(name: string, params: AnalyticsParams = {}) {
  if (!shouldUseNativeAnalytics) {
    return;
  }

  try {
    await ensureAnalyticsReady();
    await analytics().logEvent(name, params);
  } catch (error) {
    logAnalyticsWarning(`failed to log event ${name}`, error);
    return;
  }
}

export function getLatencyBucket(latencyMs: number) {
  if (latencyMs < 1_000) {
    return 'lt_1000';
  }

  if (latencyMs < 2_000) {
    return '1000_1999';
  }

  if (latencyMs < 4_000) {
    return '2000_3999';
  }

  if (latencyMs < 8_000) {
    return '4000_7999';
  }

  return '8000_plus';
}

export function getOutputSizeBucket(outputChars: number) {
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
}

export function toAnalyticsBool(value: boolean) {
  return value ? 'true' : 'false';
}
