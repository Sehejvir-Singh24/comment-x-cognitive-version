'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { computeDigitalBiomarkers } = require('./biomarkers');

test('computes only observed timings and separates immediate from delayed recall', () => {
  const metrics = computeDigitalBiomarkers([
    { kind: 'familyRecognition', responseMs: 2000, firstHintMs: 800, correct: true },
    { kind: 'familyRecognition', responseMs: 4000, firstHintMs: 1800, correct: false },
    { kind: 'videoRecall', entryId: 'bihu_q0', responseMs: 3000, correct: true },
    { kind: 'videoRecall', entryId: 'bihu_q1', responseMs: 1000, correct: false },
    { kind: 'videoRecall', entryId: 'bihu_delayed', responseMs: 5000, correct: true },
    { kind: 'medicineRecall', responseMs: 0, correct: true },
  ]);
  assert.deepEqual(metrics.responseTime, { medianMs: 3000, count: 5 });
  assert.deepEqual(metrics.firstHintTime, { medianMs: 1300, count: 2 });
  assert.deepEqual(metrics.immediate, { accuracy: 50, count: 2 });
  assert.deepEqual(metrics.delayed, { accuracy: 100, count: 1 });
  assert.equal(metrics.accuracyGap, 50);
  assert.equal(metrics.orientation, null);
});

test('missing and legacy fields do not become zero scores', () => {
  const metrics = computeDigitalBiomarkers([
    { kind: 'videoRecall', entryId: 'bihu_q0', correct: true, responseMs: 0 },
  ]);
  assert.equal(metrics.responseTime.medianMs, null);
  assert.equal(metrics.firstHintTime.medianMs, null);
  assert.equal(metrics.delayed.accuracy, null);
  assert.equal(metrics.accuracyGap, null);
});
