'use strict';
// Tiny test runner: no framework, just enough to collect pass/fail and set
// a non-zero exit code. `test()` accepts sync or async fn.

let passed = 0;
let failed = 0;
const pending = [];

function test(name, fn) {
  const run = (async () => {
    try {
      await fn();
      passed++;
      console.log(`  ok - ${name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL - ${name}`);
      console.log(`    ${(err && err.message) || err}`);
    }
  })();
  pending.push(run);
}

async function summary() {
  await Promise.all(pending);
  console.log(`${passed} passed, ${failed} failed`);
  if (failed > 0) process.exitCode = 1;
}

module.exports = { test, summary };
