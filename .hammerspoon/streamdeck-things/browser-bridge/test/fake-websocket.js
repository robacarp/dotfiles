'use strict';
// Fake WebSocket client standing in for the browser's real one. Tests use
// _open()/_receive() (not part of the real API) to simulate the server side.

class FakeWebSocket {
  constructor(url) {
    this.url = url;
    this.readyState = FakeWebSocket.CONNECTING;
    this._listeners = { open: [], message: [], close: [], error: [] };
    this.sent = [];
    FakeWebSocket.instances.push(this);
  }

  addEventListener(type, fn) {
    (this._listeners[type] ||= []).push(fn);
  }

  send(data) {
    if (this.readyState !== FakeWebSocket.OPEN) {
      throw new Error('FakeWebSocket: send() called while not open');
    }
    this.sent.push(data);
  }

  close() {
    if (this.readyState === FakeWebSocket.CLOSED) return;
    this.readyState = FakeWebSocket.CLOSED;
    for (const fn of this._listeners.close) fn({});
  }

  _open() {
    this.readyState = FakeWebSocket.OPEN;
    for (const fn of this._listeners.open) fn({});
  }

  _receive(data) {
    for (const fn of this._listeners.message) fn({ data });
  }
}

FakeWebSocket.CONNECTING = 0;
FakeWebSocket.OPEN = 1;
FakeWebSocket.CLOSING = 2;
FakeWebSocket.CLOSED = 3;
FakeWebSocket.instances = [];

module.exports = { FakeWebSocket };
