import remoteConfig from '@react-native-firebase/remote-config';
import {toAnalyticsBool, trackEvent} from '../services/analyticsService';
import {recordNonFatalCrash} from '../services/crashlyticsService';

const REMOTE_CONFIG_KEYS = {
  model: 'gemini_model',
  systemPrompt: 'gemini_system_prompt',
  inputTextCost: 'gemini_cost_input_text',
  inputAudioCost: 'gemini_cost_input_audio',
  inputCacheTextCost: 'gemini_cost_input_cache_text',
  inputCacheAudioCost: 'gemini_cost_input_cache_audio',
  outputTextCost: 'gemini_cost_output_text',
} as const;

export type TranscriptionCostRates = {
  inputText: number;
  inputAudio: number;
  inputCacheText: number;
  inputCacheAudio: number;
  outputText: number;
};

export const emptyTranscriptionCostRates: TranscriptionCostRates = {
  inputText: 0,
  inputAudio: 0,
  inputCacheText: 0,
  inputCacheAudio: 0,
  outputText: 0,
};

type RuntimeConfigModule = {
  saveRuntimeConfig: (config: {model: string; systemPrompt: string}) => Promise<void>;
};

let syncPromise: Promise<TranscriptionCostRates> | null = null;

export const bundledRuntimeConfig = {
  model: 'gemini-3.1-flash-preview',
  systemPrompt:
    'Transcribe supplied audio into Belarusian dictation text only. Return only the final Belarusian transcript.',
} as const;

function normalizeString(value: string | null | undefined) {
  const trimmed = value?.trim() ?? '';
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeNumber(value: string | null | undefined) {
  const trimmed = value?.trim() ?? '';

  if (!trimmed) {
    return 0;
  }

  const parsed = Number(trimmed);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

export async function syncRemoteRuntimeConfig(configModule: RuntimeConfigModule) {
  if (syncPromise) {
    return syncPromise;
  }

  syncPromise = (async () => {
    try {
      const client = remoteConfig();
      await client.setConfigSettings({
        fetchTimeMillis: 10_000,
        minimumFetchIntervalMillis: 0,
      });
      await client.fetchAndActivate();

      const costRates: TranscriptionCostRates = {
        inputText: normalizeNumber(client.getString(REMOTE_CONFIG_KEYS.inputTextCost)),
        inputAudio: normalizeNumber(client.getString(REMOTE_CONFIG_KEYS.inputAudioCost)),
        inputCacheText: normalizeNumber(
          client.getString(REMOTE_CONFIG_KEYS.inputCacheTextCost),
        ),
        inputCacheAudio: normalizeNumber(
          client.getString(REMOTE_CONFIG_KEYS.inputCacheAudioCost),
        ),
        outputText: normalizeNumber(client.getString(REMOTE_CONFIG_KEYS.outputTextCost)),
      };

      const model = normalizeString(client.getString(REMOTE_CONFIG_KEYS.model));
      const systemPrompt = normalizeString(client.getString(REMOTE_CONFIG_KEYS.systemPrompt));

      if (!model || !systemPrompt) {
        await configModule.saveRuntimeConfig(bundledRuntimeConfig);
        await trackEvent('remote_config_sync_result', {
          result: 'fallback',
          has_model: toAnalyticsBool(Boolean(model)),
          has_system_prompt: toAnalyticsBool(Boolean(systemPrompt)),
        });
        return costRates;
      }

      await configModule.saveRuntimeConfig({
        model,
        systemPrompt,
      });
      await trackEvent('remote_config_sync_result', {
        result: 'success',
        has_model: toAnalyticsBool(true),
        has_system_prompt: toAnalyticsBool(true),
      });

      return costRates;
    } catch (error) {
      await recordNonFatalCrash(
        error instanceof Error ? error : new Error(String(error)),
        'remote_config_sync_failed',
      );
      await configModule.saveRuntimeConfig(bundledRuntimeConfig);
      await trackEvent('remote_config_sync_result', {
        result: 'fallback',
        has_model: toAnalyticsBool(false),
        has_system_prompt: toAnalyticsBool(false),
      });
      return emptyTranscriptionCostRates;
    } finally {
      syncPromise = null;
    }
  })();

  return syncPromise;
}

export function __resetRemoteConfigSyncForTests() {
  syncPromise = null;
}
