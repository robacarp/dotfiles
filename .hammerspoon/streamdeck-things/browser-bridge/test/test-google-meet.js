'use strict';
// Loads the real content-scripts/google-meet.js source into a fresh vm
// context per test (fake document/navigator/chrome injected as globals).

// Loose (not /strict) assert: objects built inside the vm sandbox have a
// different Object prototype than this file's literals (separate realm), so
// assert.deepStrictEqual would reject structurally-identical objects as
// "not reference-equal". Loose deepEqual ignores prototype, which is what
// we actually want to check here.
const assert = require('node:assert');
const vm = require('vm');
const fs = require('fs');
const path = require('path');
const { test, summary } = require('./harness');
const { FakeDocument, FakeKeyboardEvent, FakeMouseEvent, FakeMutationObserver } = require('./fake-dom');

const SRC = fs.readFileSync(path.join(__dirname, '..', 'content-scripts', 'google-meet.js'), 'utf8');

function load({ platform = 'MacIntel', buttons = [] } = {}) {
  FakeMutationObserver.instances.length = 0;
  const document = new FakeDocument();
  for (const attrs of buttons) document.addButton(attrs);

  const sentMessages = [];
  const messageListeners = [];
  const chrome = {
    runtime: {
      onMessage: { addListener: (fn) => messageListeners.push(fn) },
      sendMessage: (msg) => sentMessages.push(msg),
    },
  };
  const sandbox = {
    console,
    document,
    navigator: { platform },
    KeyboardEvent: FakeKeyboardEvent,
    MouseEvent: FakeMouseEvent,
    MutationObserver: FakeMutationObserver,
    chrome,
    setInterval: () => 0, // no real periodic re-registration timer in tests
    setTimeout, // real Node timer - thumbsUp's waitForButton polls with it
  };
  vm.createContext(sandbox);
  vm.runInContext(SRC, sandbox, { filename: 'google-meet.js' });
  return { document, sentMessages, messageListeners };
}

// The listener now always responds via a resolved/rejected Promise (see
// "return true" in google-meet.js) so thumbsUp's async wait works the same
// way a sync action's response does - sendCommand has to wait for that
// callback rather than reading a same-tick return value.
function sendCommand(messageListeners, message) {
  return new Promise((resolve) => {
    for (const fn of messageListeners) fn(message, {}, resolve);
  });
}

test('registers on load', () => {
  const { sentMessages } = load();
  assert.equal(
    sentMessages.some((m) => m.type === 'register' && m.site === 'meet.google.com'),
    true
  );
});

test('toggleMic on Mac dispatches Cmd+D', async () => {
  const { document, messageListeners } = load({ platform: 'MacIntel' });
  const seen = [];
  document.addEventListener('keydown', (e) => seen.push(e));
  document.addEventListener('keyup', (e) => seen.push(e));

  const response = await sendCommand(messageListeners, { type: 'command', action: 'toggleMic' });

  assert.deepEqual(response, { ok: true });
  assert.equal(seen.length, 2);
  for (const e of seen) {
    assert.equal(e.key, 'd');
    assert.equal(e.metaKey, true);
    assert.equal(e.ctrlKey, false);
  }
});

test('toggleMic on Windows dispatches Ctrl+D', async () => {
  const { document, messageListeners } = load({ platform: 'Win32' });
  const seen = [];
  document.addEventListener('keydown', (e) => seen.push(e));

  await sendCommand(messageListeners, { type: 'command', action: 'toggleMic' });

  assert.equal(seen[0].ctrlKey, true);
  assert.equal(seen[0].metaKey, false);
});

test('toggleCamera dispatches the "e" key', async () => {
  const { document, messageListeners } = load({ platform: 'Win32' });
  const seen = [];
  document.addEventListener('keydown', (e) => seen.push(e));

  await sendCommand(messageListeners, { type: 'command', action: 'toggleCamera' });

  assert.equal(seen[0].key, 'e');
});

test('hangUp clicks only the leave-call button', async () => {
  const { document, messageListeners } = load({
    buttons: [
      { 'aria-label': 'Turn off microphone' },
      { 'aria-label': 'Leave call' },
      { 'aria-label': 'Show everyone' },
    ],
  });

  const response = await sendCommand(messageListeners, { type: 'command', action: 'hangUp' });

  assert.deepEqual(response, { ok: true });
  const clicked = document.elements.filter((el) => el.clickCount > 0);
  assert.equal(clicked.length, 1);
  assert.equal(clicked[0].getAttribute('aria-label'), 'Leave call');
});

test('hangUp with no matching button reports an error instead of throwing', async () => {
  const { messageListeners } = load({ buttons: [] });
  const response = await sendCommand(messageListeners, { type: 'command', action: 'hangUp' });
  assert.deepEqual(response, { error: 'leave-call button not found' });
});

test('unknown action reports an error naming it', async () => {
  const { messageListeners } = load();
  const response = await sendCommand(messageListeners, { type: 'command', action: 'doTheThing' });
  assert.deepEqual(response, { error: 'unknown action "doTheThing"' });
});

// All reaction actions share one implementation (sendReaction in
// google-meet.js), so one test body covers all of them rather than
// duplicating it per emoji.
const REACTIONS = [
  { action: 'thumbsUp', emoji: '👍' },
  { action: 'heart', emoji: '💖' },
  { action: 'celebrate', emoji: '🎉' },
  { action: 'clap', emoji: '👏' },
];

for (const { action, emoji } of REACTIONS) {
  test(`${action} opens the reaction tray then clicks its reaction`, async () => {
    const { document, messageListeners } = load({
      buttons: [{ 'aria-label': 'Send a reaction' }],
    });

    // The tray's own reaction elements don't exist yet - sendReaction must
    // wait for one to appear rather than fail immediately, so it's added
    // on a delay here to actually exercise that wait. Real markup is a
    // <button> wrapping a decorative <img>, both carrying the same
    // data-emoji attribute - both are added here so the test guards
    // against regressing onto the img.
    setTimeout(() => {
      document.addElement('button', { 'data-emoji': emoji, 'aria-label': emoji, role: 'button' });
      document.addElement('img', { 'data-emoji': emoji, 'aria-label': emoji });
    }, 10);

    const response = await sendCommand(messageListeners, { type: 'command', action });

    assert.deepEqual(response, { ok: true });
    const openBtn = document.elements.find((el) => el.getAttribute('aria-label') === 'Send a reaction');
    const reactionBtn = document.elements.find((el) => el.tag === 'button' && el.getAttribute('data-emoji') === emoji);
    const reactionImg = document.elements.find((el) => el.tag === 'img' && el.getAttribute('data-emoji') === emoji);
    assert.equal(openBtn.clickCount, 1);
    // dispatchClickSequence fires the full down/up/click trio (a bare
    // click alone opened the tray but never actually sent the reaction).
    assert.deepEqual(reactionBtn.dispatchedEventTypes, ['mousedown', 'mouseup', 'click']);
    assert.deepEqual(reactionImg.dispatchedEventTypes, [], 'must target the wrapping button, not the decorative img');
  });
}

test('a reaction reports an error when the "Send a reaction" button is missing', async () => {
  const { messageListeners } = load({ buttons: [] });
  const response = await sendCommand(messageListeners, { type: 'command', action: 'thumbsUp' });
  assert.deepEqual(response, { error: '"Send a reaction" button not found' });
});

test('a reaction reports an error if it never appears in the tray', async () => {
  const { messageListeners } = load({ buttons: [{ 'aria-label': 'Send a reaction' }] });
  const response = await sendCommand(messageListeners, { type: 'command', action: 'thumbsUp' });
  assert.equal(response.error.startsWith('no element matching'), true);
});

test('mic state changes are emitted once per change, not per mutation', () => {
  const { document, sentMessages } = load({ buttons: [{ 'aria-label': 'Turn off microphone' }] });
  const events = () => sentMessages.filter((m) => m.type === 'event' && m.event === 'micStateChanged');

  assert.equal(events().length, 1);
  assert.deepEqual(events()[0].data, { muted: false });

  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 1, 'no duplicate event for an unchanged state');

  document.elements[0].setAttribute('aria-label', 'Turn on microphone');
  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 2);
  assert.deepEqual(events()[1].data, { muted: true });
});

test('camera state changes are emitted once per change, not per mutation', () => {
  const { document, sentMessages } = load({ buttons: [{ 'aria-label': 'Turn off camera' }] });
  const events = () => sentMessages.filter((m) => m.type === 'event' && m.event === 'cameraStateChanged');

  assert.equal(events().length, 1);
  assert.deepEqual(events()[0].data, { off: false });

  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 1, 'no duplicate event for an unchanged state');

  document.elements[0].setAttribute('aria-label', 'Turn on camera');
  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 2);
  assert.deepEqual(events()[1].data, { off: true });
});

test('mic state ignores other microphone-related buttons and follows the actual toggle', () => {
  const { document, sentMessages } = load({
    buttons: [
      { 'aria-label': 'Camera & microphone settings' },
      { 'aria-label': 'Turn off microphone' },
    ],
  });
  const events = () => sentMessages.filter((m) => m.type === 'event' && m.event === 'micStateChanged');

  assert.equal(events().length, 1);
  assert.deepEqual(events()[0].data, { muted: false });

  document.elements[1].setAttribute('aria-label', 'Turn on microphone');
  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 2, 'the decoy button never changing must not suppress the real toggle firing');
  assert.deepEqual(events()[1].data, { muted: true });
});

test('camera state ignores other camera-related buttons and follows the actual toggle', () => {
  const { document, sentMessages } = load({
    buttons: [
      { 'aria-label': 'Switch camera' },
      { 'aria-label': 'Camera & microphone settings' },
      { 'aria-label': 'Turn off camera' },
    ],
  });
  const events = () => sentMessages.filter((m) => m.type === 'event' && m.event === 'cameraStateChanged');

  assert.equal(events().length, 1);
  assert.deepEqual(events()[0].data, { off: false });

  document.elements[2].setAttribute('aria-label', 'Turn on camera');
  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 2, 'the decoy buttons never changing must not suppress the real toggle firing');
  assert.deepEqual(events()[1].data, { off: true });
});

test('call state reflects presence of the leave-call button', () => {
  const { document, sentMessages } = load({ buttons: [] });
  const events = () => sentMessages.filter((m) => m.type === 'event' && m.event === 'callStateChanged');

  assert.equal(events().length, 1, 'initial state emitted on load');
  assert.deepEqual(events()[0].data, { active: false });

  document.addButton({ 'aria-label': 'Leave call' });
  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 2);
  assert.deepEqual(events()[1].data, { active: true });

  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 2, 'no duplicate event for an unchanged state');
});

summary();
