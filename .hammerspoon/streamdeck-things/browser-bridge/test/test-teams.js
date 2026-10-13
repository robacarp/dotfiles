'use strict';
// Loads the real content-scripts/teams.js source into a fresh vm context
// per test. See test-google-meet.js for the loose-assert rationale (vm
// sandbox objects are a different realm from this file's literals).
const assert = require('node:assert');
const vm = require('vm');
const fs = require('fs');
const path = require('path');
const { test, summary } = require('./harness');
const { FakeDocument, FakeMutationObserver } = require('./fake-dom');

const SRC = fs.readFileSync(path.join(__dirname, '..', 'content-scripts', 'teams.js'), 'utf8');

function load({ buttons = [] } = {}) {
  FakeMutationObserver.instances.length = 0;
  const document = new FakeDocument();
  for (const attrs of buttons) document.addButton(attrs);

  const sentMessages = [];
  const chrome = {
    runtime: {
      onMessage: { addListener: () => {} },
      sendMessage: (msg) => sentMessages.push(msg),
    },
  };
  const sandbox = {
    console,
    document,
    MutationObserver: FakeMutationObserver,
    chrome,
    setInterval: () => 0,
  };
  vm.createContext(sandbox);
  vm.runInContext(SRC, sandbox, { filename: 'teams.js' });
  return { document, sentMessages };
}

test('registers on load', () => {
  const { sentMessages } = load();
  assert.equal(
    sentMessages.some((m) => m.type === 'register' && m.site === 'teams.microsoft.com'),
    true
  );
});

test('call state reflects presence of a hang-up/leave button', () => {
  const { document, sentMessages } = load({ buttons: [] });
  const events = () => sentMessages.filter((m) => m.type === 'event' && m.event === 'callStateChanged');

  assert.equal(events().length, 1, 'initial state emitted on load');
  assert.deepEqual(events()[0].data, { active: false });

  document.addButton({ 'aria-label': 'Hang up' });
  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 2);
  assert.deepEqual(events()[1].data, { active: true });

  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 2, 'no duplicate event for an unchanged state');

  document.elements[0].setAttribute('aria-label', 'Show reactions');
  FakeMutationObserver.instances[0].trigger();
  assert.equal(events().length, 3);
  assert.deepEqual(events()[2].data, { active: false });
});

summary();
