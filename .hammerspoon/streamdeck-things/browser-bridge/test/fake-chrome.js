'use strict';
// Minimal fake of the chrome.* surface background.js touches. Records what
// it's told so tests can assert on it, and exposes test-only methods
// (dispatchToBackground/removeTab/fireAlarm) to drive the listeners
// background.js registers.

function createFakeChrome() {
  const messageListeners = [];
  const alarmListeners = [];
  const removedListeners = [];
  const alarms = new Map();
  const sentToTabs = [];
  const updatedTabs = [];
  const updatedWindows = [];
  let sendMessageImpl = async () => ({ ok: true });
  let getTabImpl = async (tabId) => ({ id: tabId, windowId: 100 + tabId });

  const chrome = {
    runtime: {
      onMessage: {
        addListener(fn) {
          messageListeners.push(fn);
        },
      },
    },
    tabs: {
      async sendMessage(tabId, message) {
        sentToTabs.push({ tabId, message });
        return sendMessageImpl(tabId, message);
      },
      async get(tabId) {
        return getTabImpl(tabId);
      },
      async update(tabId, props) {
        updatedTabs.push({ tabId, props });
      },
      onRemoved: {
        addListener(fn) {
          removedListeners.push(fn);
        },
      },
    },
    windows: {
      async update(windowId, props) {
        updatedWindows.push({ windowId, props });
      },
    },
    alarms: {
      create(name, opts) {
        alarms.set(name, opts);
      },
      onAlarm: {
        addListener(fn) {
          alarmListeners.push(fn);
        },
      },
    },
  };

  return {
    chrome,
    alarms,
    sentToTabs,
    updatedTabs,
    updatedWindows,
    setSendMessageImpl(fn) {
      sendMessageImpl = fn;
    },
    setGetTabImpl(fn) {
      getTabImpl = fn;
    },
    dispatchToBackground(message, sender) {
      for (const fn of messageListeners) fn(message, sender, () => {});
    },
    removeTab(tabId) {
      for (const fn of removedListeners) fn(tabId);
    },
    fireAlarm(name) {
      for (const fn of alarmListeners) fn({ name });
    },
  };
}

module.exports = { createFakeChrome };
