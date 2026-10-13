// Local WebSocket bridge: connects OUT to a Stream Deck plugin's server (the
// plugin hosts the socket; this extension is the client) and relays commands
// to whichever tab most recently registered for the target site.
// See AGENTS.md for the wire protocol.

const BRIDGE_PORT = 17721;
const BRIDGE_URL = `ws://127.0.0.1:${BRIDGE_PORT}/`;
const RECONNECT_ALARM = 'streamdeck-bridge-reconnect';

let ws = null;
const tabsBySite = new Map(); // hostname -> tabId

function connect() {
  if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) return;
  try {
    ws = new WebSocket(BRIDGE_URL);
  } catch {
    ws = null;
    return;
  }
  ws.addEventListener('open', () => {
    ws.send(JSON.stringify({ type: 'hello', extension: 'streamdeck-bridge', version: '0.1.0' }));
  });
  ws.addEventListener('message', (event) => handleMessage(event.data));
  ws.addEventListener('close', () => {
    ws = null;
  });
  ws.addEventListener('error', () => {
    try {
      ws.close();
    } catch {
      // already closed
    }
  });
}

async function handleMessage(raw) {
  let msg;
  try {
    msg = JSON.parse(raw);
  } catch {
    return;
  }
  if (msg.type === 'command') {
    await handleCommand(msg);
  } else if (msg.type === 'focusTab') {
    await handleFocusTab(msg);
  }
}

async function handleCommand(msg) {
  const { id, site, action, params } = msg;
  const tabId = tabsBySite.get(site);
  if (tabId == null) {
    reply(id, false, null, `no open tab registered for "${site}"`);
    return;
  }
  try {
    const response = await chrome.tabs.sendMessage(tabId, { type: 'command', action, params });
    if (response && response.error) {
      reply(id, false, null, response.error);
    } else {
      reply(id, true, response ?? null, null);
    }
  } catch (err) {
    reply(id, false, null, String((err && err.message) || err));
  }
}

// Unlike `command`, this isn't forwarded to the content script - a page's
// own JS can't raise its browser window or switch tabs, that's an
// extension-privileged (chrome.tabs/chrome.windows) operation, so it's
// handled here directly instead.
async function handleFocusTab(msg) {
  const { id, site } = msg;
  const tabId = tabsBySite.get(site);
  if (tabId == null) {
    reply(id, false, null, `no open tab registered for "${site}"`);
    return;
  }
  try {
    const tab = await chrome.tabs.get(tabId);
    await chrome.windows.update(tab.windowId, { focused: true });
    await chrome.tabs.update(tabId, { active: true });
    reply(id, true, null, null);
  } catch (err) {
    reply(id, false, null, String((err && err.message) || err));
  }
}

function reply(id, ok, data, error) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify({ type: 'result', id, ok, data, error }));
}

function emitEvent(site, eventName, data) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify({ type: 'event', site, event: eventName, data }));
}

chrome.runtime.onMessage.addListener((msg, sender) => {
  if (!sender.tab || !sender.tab.url) return;
  let site;
  try {
    site = new URL(sender.tab.url).hostname;
  } catch {
    return;
  }
  if (msg.type === 'register') {
    tabsBySite.set(site, sender.tab.id);
    connect();
  } else if (msg.type === 'event') {
    emitEvent(site, msg.event, msg.data);
  }
});

chrome.tabs.onRemoved.addListener((closedTabId) => {
  for (const [site, tabId] of tabsBySite) {
    if (tabId === closedTabId) tabsBySite.delete(site);
  }
});

// MV3 service workers (and Firefox's equivalent event page) get killed after
// ~30s idle, which would silently drop the socket. A recurring alarm is the
// documented keepalive/reconnect mechanism; content scripts also re-register
// every 20s (see google-meet.js), which independently wakes this worker
// whenever a relevant tab is actually open.
chrome.alarms.create(RECONNECT_ALARM, { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === RECONNECT_ALARM) connect();
});

connect();
