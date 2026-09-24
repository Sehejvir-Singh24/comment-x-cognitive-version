'use strict';

// Descriptive exercise measures. These are not clinical scores or validated biomarkers.
function computeDigitalBiomarkers(records) {
  const valid = Array.isArray(records) ? records : [];
  const median = values => {
    if (!values.length) return null;
    const sorted = [...values].sort((a, b) => a - b);
    const middle = Math.floor(sorted.length / 2);
    return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  };
  const responseTimes = valid
    .filter(record => record.kind !== 'medicineRecall')
    .map(record => record.responseMs)
    .filter(ms => Number.isFinite(ms) && ms > 0);
  const hintTimes = valid
    .map(record => record.firstHintMs)
    .filter(ms => Number.isFinite(ms) && ms >= 0);
  const video = valid.filter(record => record.kind === 'videoRecall');
  const immediate = video.filter(record => /_q\d+$/.test(record.entryId || ''));
  const delayed = video.filter(record => /_delayed$/.test(record.entryId || ''));
  const accuracy = group => group.length
    ? Math.round(100 * group.filter(record => record.correct === true).length / group.length)
    : null;
  const immediateAccuracy = accuracy(immediate);
  const delayedAccuracy = accuracy(delayed);
  return {
    responseTime: { medianMs: median(responseTimes), count: responseTimes.length },
    firstHintTime: { medianMs: median(hintTimes), count: hintTimes.length },
    immediate: { accuracy: immediateAccuracy, count: immediate.length },
    delayed: { accuracy: delayedAccuracy, count: delayed.length },
    accuracyGap: immediateAccuracy === null || delayedAccuracy === null
      ? null : delayedAccuracy - immediateAccuracy,
    orientation: null // Phone context history remains local and is not synced.
  };
}

if (typeof module !== 'undefined') module.exports = { computeDigitalBiomarkers };
