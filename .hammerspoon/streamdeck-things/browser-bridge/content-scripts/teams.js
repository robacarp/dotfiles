// Microsoft Teams web app call-state detection for the Stream Deck bridge
// extension. See ../AGENTS.md for the wire protocol.
//
// Detection only, no actions (yet) - Teams' global keyboard shortcuts for
// mic/camera/leave are official and well documented (Cmd/Ctrl+Shift+M / O /
// H - see support.microsoft.com/en-us/accessibility/teams/keyboard-shortcuts-for-microsoft-teams),
// so adding toggle actions later is low-risk. This file only exists to
// answer "is a call active", for a Stream Deck status light.
//
// UNVERIFIED: the aria-label pattern below hasn't been confirmed against a
// live Teams call - it's a best-effort guess (mirroring the technique
// already proven for Meet) at the hang-up/leave control's label. If the
// indicator never lights up during a real call, inspect that button's
// actual aria-label/data-tid in DevTools and fix the pattern below.

const SITE = 'teams.microsoft.com';

function findButtonByLabel(pattern) {
  for (const btn of document.querySelectorAll('button[aria-label]')) {
    if (pattern.test(btn.getAttribute('aria-label') || '')) return btn;
  }
  return null;
}

let lastCallActive = null;
function checkCallState() {
  const active = !!findButtonByLabel(/hang up|leave/i);
  if (active !== lastCallActive) {
    lastCallActive = active;
    chrome.runtime.sendMessage({ type: 'event', event: 'callStateChanged', data: { active } });
  }
}

// childList is needed (not just attributes) because joining/leaving a call
// adds/removes the whole in-call toolbar rather than changing an existing
// button's aria-label - same reasoning as content-scripts/google-meet.js.
new MutationObserver(checkCallState).observe(document.body, {
  attributes: true,
  attributeFilter: ['aria-label'],
  childList: true,
  subtree: true,
});
checkCallState();

function register() {
  chrome.runtime.sendMessage({ type: 'register', site: SITE });
}
register();
setInterval(register, 20000);
