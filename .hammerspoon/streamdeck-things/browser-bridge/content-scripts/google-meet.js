// Google Meet call-control handlers for the Stream Deck bridge extension.
// See ../AGENTS.md for the wire protocol and site-handler contract.
//
// There is no public real-time call-control API for Meet, so this drives the
// page the same way a person would: Meet's own documented keyboard shortcuts
// for mic/camera (bound globally, not checked for event.isTrusted, so they
// survive Meet's DOM/class-name churn better than clicking toolbar buttons
// would), and a direct click on the leave-call button (no shortcut exists
// for that one). aria-label text is also used to read mic state back out.

const SITE = 'meet.google.com';
const isMac = navigator.platform.toUpperCase().includes('MAC');

function findButtonByLabel(pattern) {
  for (const btn of document.querySelectorAll('button[aria-label]')) {
    if (pattern.test(btn.getAttribute('aria-label') || '')) return btn;
  }
  return null;
}

function dispatchPrimaryShortcut(key) {
  const opts = {
    key,
    code: `Key${key.toUpperCase()}`,
    ctrlKey: !isMac,
    metaKey: isMac,
    bubbles: true,
    cancelable: true,
  };
  document.dispatchEvent(new KeyboardEvent('keydown', opts));
  document.dispatchEvent(new KeyboardEvent('keyup', opts));
}

const REACTION_WAIT_TIMEOUT_MS = 800;
const REACTION_WAIT_INTERVAL_MS = 30;

// Polls instead of assuming immediate presence - a reaction's tray button
// doesn't exist in the DOM until the tray is opened. See AGENTS.md for why
// sending a reaction needs this whole dance instead of one click like
// hangUp: no keyboard shortcut, a two-step open-then-click, and (below) a
// full mousedown/mouseup/click sequence rather than a bare .click().
function waitForElement(selector) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + REACTION_WAIT_TIMEOUT_MS;
    (function poll() {
      const el = document.querySelector(selector);
      if (el) return resolve(el);
      if (Date.now() >= deadline) return reject(new Error(`no element matching ${selector} appeared`));
      setTimeout(poll, REACTION_WAIT_INTERVAL_MS);
    })();
  });
}

// Confirmed live: a bare .click() opens/closes the tray fine but never
// actually sends the reaction - jsaction binds mousedown/mouseup/click as
// separate handlers and the real send action needs the down/up pair, not
// click alone. This replays all three, same as a real press already does.
function dispatchClickSequence(el) {
  const opts = { bubbles: true, cancelable: true, button: 0 };
  el.dispatchEvent(new MouseEvent('mousedown', opts));
  el.dispatchEvent(new MouseEvent('mouseup', opts));
  el.dispatchEvent(new MouseEvent('click', opts));
}

// Each reaction in the tray is a <button data-emoji="<emoji>"> wrapping a
// decorative <img> with the same attribute - tag-scoped to `button` so this
// hits the real clickable element, not the img (confirmed live: clicking
// the img alone does nothing). `^=` rather than `=` as cheap insurance
// against a variation-selector mismatch on whichever of these end up
// unverified - see AGENTS.md for which emoji are actually confirmed.
async function sendReaction(emoji) {
  const openBtn = findButtonByLabel(/send a reaction/i);
  if (!openBtn) throw new Error('"Send a reaction" button not found');
  openBtn.click();
  const reactionEl = await waitForElement(`button[data-emoji^="${emoji}"]`);
  dispatchClickSequence(reactionEl);
}

const ACTIONS = {
  toggleMic: () => dispatchPrimaryShortcut('d'),
  toggleCamera: () => dispatchPrimaryShortcut('e'),
  hangUp: () => {
    const btn = findButtonByLabel(/leave call/i);
    if (!btn) throw new Error('leave-call button not found');
    btn.click();
  },
  thumbsUp: () => sendReaction('👍'),
  heart: () => sendReaction('💖'), // Meet's "heart" reaction is the sparkling-heart emoji, not ❤️ - confirmed live
  celebrate: () => sendReaction('🎉'),
  clap: () => sendReaction('👏'),
};

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type !== 'command') return;
  const handler = ACTIONS[msg.action];
  if (!handler) {
    sendResponse({ error: `unknown action "${msg.action}"` });
    return;
  }
  Promise.resolve()
    .then(() => handler(msg.params))
    .then(() => sendResponse({ ok: true }))
    .catch((err) => sendResponse({ error: String((err && err.message) || err) }));
  return true; // keep the message channel open - reactions resolve asynchronously
});

// Reflect real mic state back to the plugin — e.g. someone mutes from the
// on-screen toolbar instead of the Stream Deck, the key icon should follow.
//
// Pattern must be the full toggle phrasing, not just /microphone/i - Meet's
// toolbar can also have a mic-source-picker button whose aria-label contains
// "microphone" (e.g. a "Select a microphone" chevron next to the toggle).
// querySelectorAll returns DOM order, so a bare /microphone/i risks
// findButtonByLabel latching onto that picker instead of the actual toggle
// button and then never seeing "turn on"/"turn off" flip - the button
// permanently reads as unmuted no matter what Meet's real state is. Same
// class of bug the camera check below was already hardened against.
let lastMicMuted = null;
function checkMicState() {
  const btn = findButtonByLabel(/turn (on|off) microphone/i);
  if (!btn) return;
  const muted = /turn on/i.test(btn.getAttribute('aria-label') || '');
  if (muted !== lastMicMuted) {
    lastMicMuted = muted;
    chrome.runtime.sendMessage({ type: 'event', event: 'micStateChanged', data: { muted } });
  }
}

// Same idea as checkMicState, for the camera button. Deliberately more
// specific than a bare /camera/i - "camera" alone is broad enough to also
// match other real Meet buttons (camera-switcher, video settings, ...),
// which would make this watch the wrong element and never see it flip
// between "Turn on camera"/"Turn off camera" at all. Requiring the full
// toggle phrasing pins it to the actual toggle button specifically.
let lastCameraOff = null;
function checkCameraState() {
  const btn = findButtonByLabel(/turn (on|off) camera/i);
  if (!btn) return;
  const off = /turn on/i.test(btn.getAttribute('aria-label') || '');
  if (off !== lastCameraOff) {
    lastCameraOff = off;
    chrome.runtime.sendMessage({ type: 'event', event: 'cameraStateChanged', data: { off } });
  }
}

// Reflect whether a call is actually in progress (the in-call toolbar,
// identified by the leave-call button, only exists once joined) — lets the
// native side show a "Meet is active" indicator independent of mic/camera
// state.
let lastCallActive = null;
function checkCallState() {
  const active = !!findButtonByLabel(/leave call/i);
  if (active !== lastCallActive) {
    lastCallActive = active;
    chrome.runtime.sendMessage({ type: 'event', event: 'callStateChanged', data: { active } });
  }
}

function checkState() {
  checkMicState();
  checkCameraState();
  checkCallState();
}
// childList is needed (not just attributes) because joining/leaving a call
// adds/removes the whole toolbar rather than changing an existing button's
// aria-label.
new MutationObserver(checkState).observe(document.body, {
  attributes: true,
  attributeFilter: ['aria-label'],
  childList: true,
  subtree: true,
});
checkState();

function register() {
  chrome.runtime.sendMessage({ type: 'register', site: SITE });
}
register();
setInterval(register, 20000);
