import React from 'react';
import {NativeModules, Platform, TextInput} from 'react-native';
import ReactTestRenderer from 'react-test-renderer';
import App from '../App';

const originalPlatform = Platform.OS;
const configModule = {
  getStatus: jest.fn().mockResolvedValue({
    hasApiKey: false,
    platformMode: 'android-ime',
  }),
  saveApiKey: jest.fn().mockResolvedValue(undefined),
};
const speechModule = {
  startRecording: jest.fn().mockResolvedValue(undefined),
  stopRecording: jest.fn().mockResolvedValue('transcribed message'),
};

beforeEach(() => {
  NativeModules.GemboardConfig = configModule;
  NativeModules.GemboardSpeech = speechModule;
  jest.clearAllMocks();
  Platform.OS = originalPlatform;
});

afterAll(() => {
  Platform.OS = originalPlatform;
});

test('renders the setup flow and composer', async () => {
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  expect(tree!.root.findByProps({children: 'Gemboard'})).toBeTruthy();
  expect(tree!.root.findByProps({children: 'Save API key'})).toBeTruthy();
  expect(tree!.root.findByProps({placeholder: 'Type here or use speech'})).toBeTruthy();
});

test('saves the Gemini API key through the native bridge', async () => {
  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const inputs = tree!.root.findAllByType(TextInput);

  await ReactTestRenderer.act(async () => {
    inputs[0].props.onChangeText('gemini-token');
  });

  const saveButton = tree!.root.find(node => node.props.accessibilityLabel === 'Save API key' && typeof node.props.onPress === 'function');

  await ReactTestRenderer.act(async () => {
    await saveButton!.props.onPress();
  });

  expect(configModule.saveApiKey).toHaveBeenCalledWith('gemini-token');
  expect(tree!.root.findByProps({children: 'API key saved on this device.'})).toBeTruthy();
});

test('press-and-hold speech inserts a transcript on iOS', async () => {
  Platform.OS = 'ios';
  configModule.getStatus.mockResolvedValueOnce({
    hasApiKey: true,
    platformMode: 'ios-accessory',
  });

  let tree: ReactTestRenderer.ReactTestRenderer;

  await ReactTestRenderer.act(async () => {
    tree = ReactTestRenderer.create(<App />);
  });

  const holdButton = tree!.root.find(
    node =>
      node.props.accessibilityLabel === 'Hold to speak' &&
      typeof node.props.onPressIn === 'function' &&
      typeof node.props.onPressOut === 'function',
  );

  await ReactTestRenderer.act(async () => {
    await holdButton!.props.onPressIn();
  });

  await ReactTestRenderer.act(async () => {
    await holdButton!.props.onPressOut();
  });

  expect(speechModule.startRecording).toHaveBeenCalledTimes(1);
  expect(speechModule.stopRecording).toHaveBeenCalledTimes(1);

  const composer = tree!.root.findAllByType(TextInput).find(input => input.props.placeholder === 'Type here or use speech');
  expect(composer!.props.value).toContain('transcribed message');
});
