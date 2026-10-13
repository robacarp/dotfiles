#!/usr/bin/env node
// Dependency-free WebSocket test server standing in for Hammerspoon's
// bridge server (streamdeck-media.lua), so background.js can be exercised
// without it. Stop Hammerspoon's listener first - same port. Type a JSON command line and press enter to send it:
//   {"id":"1","type":"command","site":"meet.google.com","action":"toggleMic"}
// Everything the extension sends back (results, events) is printed.
//
// Single-frame text messages only (no fragmentation, no >64KB payloads) —
// plenty for this protocol's small JSON messages, not a general WS server.
'use strict';

const http = require('http');
const crypto = require('crypto');
const readline = require('readline');

const PORT = 17721;
const WS_MAGIC = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

const server = http.createServer((_req, res) => {
  res.writeHead(426, { 'Content-Type': 'text/plain' });
  res.end('This server only speaks WebSocket.\n');
});

let socket = null;

server.on('upgrade', (req, sock) => {
  const key = req.headers['sec-websocket-key'];
  if (!key) {
    sock.destroy();
    return;
  }
  const accept = crypto.createHash('sha1').update(key + WS_MAGIC).digest('base64');
  sock.write(
    'HTTP/1.1 101 Switching Protocols\r\n' +
      'Upgrade: websocket\r\n' +
      'Connection: Upgrade\r\n' +
      `Sec-WebSocket-Accept: ${accept}\r\n\r\n`
  );
  socket = sock;
  console.log('extension connected');

  let buf = Buffer.alloc(0);
  sock.on('data', (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    buf = drainFrames(buf, sock);
  });
  sock.on('close', () => {
    console.log('extension disconnected');
    if (socket === sock) socket = null;
  });
  sock.on('error', () => {});
});

function drainFrames(buf, sock) {
  for (;;) {
    if (buf.length < 2) return buf;
    const fin = (buf[0] & 0x80) !== 0;
    const opcode = buf[0] & 0x0f;
    const masked = (buf[1] & 0x80) !== 0;
    let len = buf[1] & 0x7f;
    let offset = 2;
    if (len === 126) {
      if (buf.length < 4) return buf;
      len = buf.readUInt16BE(2);
      offset = 4;
    } else if (len === 127) {
      if (buf.length < 10) return buf;
      len = Number(buf.readBigUInt64BE(2));
      offset = 10;
    }
    let maskKey = null;
    if (masked) {
      if (buf.length < offset + 4) return buf;
      maskKey = buf.subarray(offset, offset + 4);
      offset += 4;
    }
    if (buf.length < offset + len) return buf;
    const payload = Buffer.from(buf.subarray(offset, offset + len));
    if (masked) {
      for (let i = 0; i < payload.length; i++) payload[i] ^= maskKey[i % 4];
    }
    buf = buf.subarray(offset + len);

    if (opcode === 0x8) {
      sock.end();
      continue;
    }
    if (opcode === 0x1 && fin) {
      console.log('<-', payload.toString('utf8'));
    }
  }
}

function sendText(text) {
  if (!socket) {
    console.log('(no extension connected yet)');
    return;
  }
  const payload = Buffer.from(text, 'utf8');
  let header;
  if (payload.length < 126) {
    header = Buffer.from([0x81, payload.length]);
  } else {
    header = Buffer.alloc(4);
    header[0] = 0x81;
    header[1] = 126;
    header.writeUInt16BE(payload.length, 2);
  }
  socket.write(Buffer.concat([header, payload]));
}

server.listen(PORT, '127.0.0.1', () => {
  console.log(`dev bridge server listening on ws://127.0.0.1:${PORT}/`);
  console.log('type a JSON command and press enter to send it, e.g.:');
  console.log('{"id":"1","type":"command","site":"meet.google.com","action":"toggleMic"}');
});

const rl = readline.createInterface({ input: process.stdin });
rl.on('line', (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  try {
    JSON.parse(trimmed);
  } catch (err) {
    console.log('invalid JSON:', err.message);
    return;
  }
  sendText(trimmed);
});
