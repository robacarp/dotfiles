'use strict';
// Just enough of a DOM to run content-scripts/google-meet.js under Node's
// vm module — not a general DOM shim, only what that one script touches.

class FakeElement {
  constructor(tag, attrs = {}) {
    this.tag = tag;
    this.attrs = { ...attrs };
    this.clickCount = 0;
    this.dispatchedEventTypes = [];
    this._listeners = {};
  }
  getAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this.attrs, name) ? this.attrs[name] : null;
  }
  setAttribute(name, value) {
    this.attrs[name] = value;
  }
  click() {
    this.clickCount++;
    this.dispatchEvent({ type: 'click' });
  }
  addEventListener(type, fn) {
    (this._listeners[type] ||= []).push(fn);
  }
  dispatchEvent(evt) {
    this.dispatchedEventTypes.push(evt.type);
    for (const fn of this._listeners[evt.type] || []) fn(evt);
    return true;
  }
}

// Minimal attribute-selector engine: 'tag[attr]', 'tag[attr="value"]',
// 'tag[attr^="value"]', '[attr]', '[attr="value"]' - the only shapes
// content-scripts/google-meet.js actually uses. Not a general CSS engine.
function matchesSelector(el, selector) {
  const m = selector.match(/^([a-zA-Z]*)\[([a-zA-Z0-9_-]+)(?:(\^?)="([^"]*)")?\]$/);
  if (!m) throw new Error(`FakeDocument selector engine only supports 'tag[attr(^)="value"]' shapes, got: ${selector}`);
  const [, tag, attr, prefixOp, value] = m;
  if (tag && el.tag !== tag) return false;
  const actual = el.getAttribute(attr);
  if (actual === null) return false;
  if (value !== undefined) {
    if (prefixOp === '^') return actual.startsWith(value);
    return actual === value;
  }
  return true;
}

class FakeDocument {
  constructor() {
    this.elements = [];
    this.body = {};
    this._listeners = {};
  }
  addElement(tag, attrs) {
    const el = new FakeElement(tag, attrs);
    this.elements.push(el);
    return el;
  }
  addButton(attrs) {
    return this.addElement('button', attrs);
  }
  querySelectorAll(selector) {
    return this.elements.filter((el) => matchesSelector(el, selector));
  }
  querySelector(selector) {
    return this.elements.find((el) => matchesSelector(el, selector)) || null;
  }
  addEventListener(type, fn) {
    (this._listeners[type] ||= []).push(fn);
  }
  dispatchEvent(evt) {
    for (const fn of this._listeners[evt.type] || []) fn(evt);
    return true;
  }
}

class FakeKeyboardEvent {
  constructor(type, opts = {}) {
    this.type = type;
    Object.assign(this, opts);
  }
}

class FakeMouseEvent {
  constructor(type, opts = {}) {
    this.type = type;
    Object.assign(this, opts);
  }
}

class FakeMutationObserver {
  constructor(callback) {
    this.callback = callback;
    FakeMutationObserver.instances.push(this);
  }
  observe() {}
  disconnect() {}
  trigger() {
    this.callback([], this);
  }
}
FakeMutationObserver.instances = [];

module.exports = { FakeElement, FakeDocument, FakeKeyboardEvent, FakeMouseEvent, FakeMutationObserver };
