'use strict';
// Loads the real background.js source into a fresh vm context per test
// (fake chrome + fake WebSocket injected as globals), so its routing logic
// is exercised without a real browser.

const assert = require('node:assert/strict');
const vm = require('vm');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const { test, summary } = require('./harness');
const { createFakeChrome } = require('./fake-chrome');
const { FakeWebSocket } = require('./fake-websocket');

const SRC = fs.readFileSync(path.join(__dirname, '..', 'background.js'), 'utf8');

function flush() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function load() {
  FakeWebSocket.instances.length = 0;
  const fake = createFakeChrome();
  const sandbox = { console, URL, JSON, Map, chrome: fake.chrome, WebSocket: FakeWebSocket };
  vm.createContext(sandbox);
  vm.runInContext(SRC, sandbox, { filename: 'background.js' });
  return { fake, ws: FakeWebSocket.instances[0] };
}

function openedLoad() {
  const rig = load();
  rig.ws._open();
  return rig;
}

test('sends a hello on connect', () => {
  const { ws } = openedLoad();
  assert.equal(JSON.parse(ws.sent[0]).type, 'hello');
});

test('routes a command to the tab registered for its site', async () => {
  const { fake, ws } = openedLoad();
  fake.dispatchToBackground(
    { type: 'register', site: 'meet.google.com' },
    { tab: { id: 7, url: 'https://meet.google.com/abc-defg-hij' } }
  );
  fake.setSendMessageImpl(async () => ({ ok: true }));
  ws._receive(JSON.stringify({ id: '1', type: 'command', site: 'meet.google.com', action: 'toggleMic' }));
  await flush();

  assert.equal(fake.sentToTabs.length, 1);
  assert.equal(fake.sentToTabs[0].tabId, 7);
  assert.equal(fake.sentToTabs[0].message.action, 'toggleMic');
  const reply = JSON.parse(ws.sent.at(-1));
  assert.equal(reply.type, 'result');
  assert.equal(reply.id, '1');
  assert.equal(reply.ok, true);
});

test('a command for an unregistered site replies ok:false with a descriptive error', async () => {
  const { ws } = openedLoad();
  ws._receive(JSON.stringify({ id: '2', type: 'command', site: 'meet.google.com', action: 'toggleMic' }));
  await flush();

  const reply = JSON.parse(ws.sent.at(-1));
  assert.equal(reply.ok, false);
  assert.match(reply.error, /no open tab registered/);
});

test('a rejected chrome.tabs.sendMessage (stale tab, no content script) becomes an ok:false result', async () => {
  const { fake, ws } = openedLoad();
  fake.dispatchToBackground(
    { type: 'register', site: 'meet.google.com' },
    { tab: { id: 9, url: 'https://meet.google.com/xyz' } }
  );
  fake.setSendMessageImpl(async () => {
    throw new Error('Could not establish connection. Receiving end does not exist.');
  });
  ws._receive(JSON.stringify({ id: '3', type: 'command', site: 'meet.google.com', action: 'toggleMic' }));
  await flush();

  const reply = JSON.parse(ws.sent.at(-1));
  assert.equal(reply.ok, false);
  assert.match(reply.error, /Receiving end does not exist/);
});

test('an error response from the content script is surfaced as ok:false', async () => {
  const { fake, ws } = openedLoad();
  fake.dispatchToBackground(
    { type: 'register', site: 'meet.google.com' },
    { tab: { id: 5, url: 'https://meet.google.com/xyz' } }
  );
  fake.setSendMessageImpl(async () => ({ error: 'leave-call button not found' }));
  ws._receive(JSON.stringify({ id: '4', type: 'command', site: 'meet.google.com', action: 'hangUp' }));
  await flush();

  const reply = JSON.parse(ws.sent.at(-1));
  assert.equal(reply.ok, false);
  assert.equal(reply.error, 'leave-call button not found');
});

test('a content-script event is relayed tagged with the sender tab hostname', () => {
  const { fake, ws } = openedLoad();
  fake.dispatchToBackground(
    { type: 'event', event: 'micStateChanged', data: { muted: true } },
    { tab: { id: 7, url: 'https://meet.google.com/abc-defg-hij' } }
  );

  const relayed = JSON.parse(ws.sent.at(-1));
  assert.equal(relayed.type, 'event');
  assert.equal(relayed.site, 'meet.google.com');
  assert.equal(relayed.event, 'micStateChanged');
  assert.deepEqual(relayed.data, { muted: true });
});

test('closing a registered tab clears its routing entry', async () => {
  const { fake, ws } = openedLoad();
  fake.dispatchToBackground(
    { type: 'register', site: 'meet.google.com' },
    { tab: { id: 7, url: 'https://meet.google.com/abc-defg-hij' } }
  );
  fake.removeTab(7);
  ws._receive(JSON.stringify({ id: '5', type: 'command', site: 'meet.google.com', action: 'toggleMic' }));
  await flush();

  const reply = JSON.parse(ws.sent.at(-1));
  assert.equal(reply.ok, false);
  assert.match(reply.error, /no open tab registered/);
});

test('focusTab focuses the registered tab\'s window and activates the tab', async () => {
  const { fake, ws } = openedLoad();
  fake.dispatchToBackground(
    { type: 'register', site: 'meet.google.com' },
    { tab: { id: 7, url: 'https://meet.google.com/abc-defg-hij' } }
  );
  ws._receive(JSON.stringify({ id: '6', type: 'focusTab', site: 'meet.google.com' }));
  await flush();

  assert.equal(fake.updatedWindows.length, 1);
  assert.equal(fake.updatedWindows[0].windowId, 107);
  assert.equal(fake.updatedWindows[0].props.focused, true);
  assert.equal(fake.updatedTabs.length, 1);
  assert.equal(fake.updatedTabs[0].tabId, 7);
  assert.equal(fake.updatedTabs[0].props.active, true);
  const reply = JSON.parse(ws.sent.at(-1));
  assert.equal(reply.type, 'result');
  assert.equal(reply.id, '6');
  assert.equal(reply.ok, true);
});

test('focusTab for an unregistered site replies ok:false with a descriptive error', async () => {
  const { ws } = openedLoad();
  ws._receive(JSON.stringify({ id: '7', type: 'focusTab', site: 'meet.google.com' }));
  await flush();

  const reply = JSON.parse(ws.sent.at(-1));
  assert.equal(reply.ok, false);
  assert.match(reply.error, /no open tab registered/);
});

test('a non-command message on the socket is ignored', async () => {
  const { ws } = openedLoad();
  const before = ws.sent.length;
  ws._receive(JSON.stringify({ type: 'something-else' }));
  await flush();

  assert.equal(ws.sent.length, before);
});

test('the reconnect alarm opens a new socket after the old one closes', () => {
  const { fake, ws } = openedLoad();
  ws.close();
  fake.fireAlarm('streamdeck-bridge-reconnect');

  assert.equal(FakeWebSocket.instances.length, 2);
  assert.notEqual(FakeWebSocket.instances[1], ws);
});

summary();
