import React from 'react';
import {Pressable, StyleSheet, Text, View} from 'react-native';

type BannerState = 'ready' | 'recording' | 'processing' | 'setup' | 'session' | 'error';

type Props = {
  state: BannerState;
  statusText: string;
  waveSamples: number[];
  micDisabled?: boolean;
  deleteDisabled?: boolean;
  onDeletePress: () => void;
  onMicPressIn: () => void;
  onMicPressOut: () => void;
};

export function CompanionRecordingBanner({
  state,
  statusText,
  waveSamples,
  micDisabled = false,
  deleteDisabled = false,
  onDeletePress,
  onMicPressIn,
  onMicPressOut,
}: Props) {
  const appearance = getAppearance(state);

  return (
    <View style={styles.root}>
      <View style={styles.surface}>
        <View style={styles.controlsRow}>
          <Pressable
            accessibilityLabel="Сцерці апошняе слова"
            testID="companion-delete-button"
            disabled={deleteDisabled}
            style={({pressed}) => [styles.sideButton, deleteDisabled && styles.buttonDisabled, pressed && !deleteDisabled && styles.sideButtonPressed]}
            onPress={onDeletePress}>
            <Text style={styles.sideButtonSymbol}>⌫</Text>
          </Pressable>

          <View style={styles.waveContainer}>
            <View style={styles.waveRow}>
              {waveSamples.map((sample, index) => (
                <View
                  key={`${index}-${sample}`}
                  style={[
                    styles.waveBar,
                    {
                      height: 10 + sample * 36,
                      backgroundColor: appearance.waveColor,
                      opacity: appearance.waveOpacity,
                    },
                  ]}
                />
              ))}
            </View>
          </View>

          <Pressable
            accessibilityLabel="Утрымлівайце, каб гаварыць"
            testID="companion-mic-button"
            disabled={micDisabled}
            style={({pressed}) => [
              styles.micButton,
              {backgroundColor: appearance.micBackground},
              micDisabled && styles.buttonDisabled,
              (pressed || state === 'recording') && !micDisabled && styles.micButtonPressed,
            ]}
            onPressIn={onMicPressIn}
            onTouchEnd={onMicPressOut}
            onTouchCancel={() => undefined}>
            <Text style={[styles.micButtonSymbol, {color: appearance.micTint}]}>{appearance.micSymbol}</Text>
          </Pressable>
        </View>
      </View>

      <Text testID="companion-status-label" style={[styles.statusLabel, {color: appearance.statusColor}]}>{statusText}</Text>
    </View>
  );
}

function getAppearance(state: BannerState) {
  switch (state) {
    case 'recording':
      return {
        statusColor: '#3b2d23',
        micBackground: '#f7836d',
        micTint: '#ffffff',
        micSymbol: '■',
        waveColor: '#ffffff',
        waveOpacity: 1,
      };
    case 'processing':
      return {
        statusColor: '#5f4a2f',
        micBackground: '#47484d',
        micTint: '#d3d5db',
        micSymbol: '⋯',
        waveColor: '#e9c46a',
        waveOpacity: 0.95,
      };
    case 'setup':
    case 'session':
      return {
        statusColor: '#6a5228',
        micBackground: '#f2d18a',
        micTint: '#1f2023',
        micSymbol: '↗',
        waveColor: '#f2d18a',
        waveOpacity: 0.9,
      };
    case 'error':
      return {
        statusColor: '#9d3f31',
        micBackground: '#f7836d',
        micTint: '#ffffff',
        micSymbol: '!',
        waveColor: '#f7836d',
        waveOpacity: 0.95,
      };
    case 'ready':
    default:
      return {
        statusColor: '#4c4034',
        micBackground: '#ffffff',
        micTint: '#18191c',
        micSymbol: '●',
        waveColor: '#bfc5d1',
        waveOpacity: 0.9,
      };
  }
}

const styles = StyleSheet.create({
  root: {
    gap: 8,
  },
  surface: {
    height: 92,
    borderRadius: 24,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.06)',
    backgroundColor: '#1f2023',
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  controlsRow: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  sideButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#36373b',
  },
  sideButtonPressed: {
    opacity: 0.82,
  },
  sideButtonSymbol: {
    color: '#f8fafc',
    fontSize: 21,
    fontWeight: '700',
  },
  waveContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  waveRow: {
    minHeight: 56,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
  },
  waveBar: {
    width: 6,
    borderRadius: 3,
  },
  micButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  micButtonPressed: {
    transform: [{scale: 0.98}],
  },
  micButtonSymbol: {
    fontSize: 22,
    fontWeight: '700',
    lineHeight: 24,
  },
  statusLabel: {
    textAlign: 'center',
    fontSize: 13,
    fontWeight: '600',
    lineHeight: 18,
  },
  buttonDisabled: {
    opacity: 0.4,
  },
});
