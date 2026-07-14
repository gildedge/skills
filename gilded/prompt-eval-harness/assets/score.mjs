/**
 * score.mjs — deterministic completeness + accuracy scoring. Zero deps.
 *
 * completeness: fraction of expected leaf fields present in actual.
 * accuracy:     of present fields, fraction whose value matches expected.
 * For arrays, match items by a stable key and report precision/recall, plus a
 * hard check that every expected item flagged required is present.
 */

export const THRESHOLDS = {
  completeness: 0.9,
  accuracy: 0.85,
  requiredMissesAllowed: 0, // any missing required field => case fails
};

const norm = (v) =>
  typeof v === 'string' ? v.trim().toLowerCase().replace(/\s+/g, ' ') : v;

function valueMatches(expected, actual) {
  if (typeof expected === 'number' && typeof actual === 'number') {
    return Math.abs(expected - actual) <= Math.max(1e-9, Math.abs(expected) * 0.01);
  }
  if (typeof expected === 'boolean' || Array.isArray(expected)) {
    return JSON.stringify(norm(expected)) === JSON.stringify(norm(actual));
  }
  return norm(expected) === norm(actual);
}

/** Score a flat object case (partial expectation: only listed keys are checked). */
export function scoreObject(expected, actual) {
  const keys = Object.keys(expected);
  let present = 0;
  let correct = 0;
  const misses = [];
  for (const k of keys) {
    const has = actual != null && Object.prototype.hasOwnProperty.call(actual, k);
    if (!has) { misses.push({ key: k, reason: 'missing' }); continue; }
    present++;
    if (valueMatches(expected[k], actual[k])) correct++;
    else misses.push({ key: k, reason: 'mismatch', expected: expected[k], actual: actual[k] });
  }
  return {
    completeness: keys.length ? present / keys.length : 1,
    accuracy: present ? correct / present : 0,
    misses,
  };
}

/**
 * Score an array feature (e.g. form-works fields[]). Match by `keyField`.
 * expectedItems may carry `required: true` to force a hard presence check.
 */
export function scoreArray(expectedItems, actualItems, keyField = 'id') {
  const actualByKey = new Map((actualItems ?? []).map((it) => [norm(it?.[keyField]), it]));
  let matched = 0;
  let correct = 0;
  let requiredMisses = 0;
  const misses = [];
  for (const exp of expectedItems) {
    const act = actualByKey.get(norm(exp[keyField]));
    if (!act) {
      misses.push({ key: exp[keyField], reason: 'missing' });
      if (exp.required) requiredMisses++;
      continue;
    }
    matched++;
    // `keyField` and `required` are control fields for matching/presence, not
    // data to score — the item is already matched by key, and `required` drives
    // the hard-miss check below. Score only the remaining data fields.
    const dataExp = { ...exp };
    delete dataExp[keyField];
    delete dataExp.required;
    const s = Object.keys(dataExp).length ? scoreObject(dataExp, act) : { accuracy: 1, completeness: 1, misses: [] };
    if (s.accuracy >= 0.999 && s.completeness >= 0.999) correct++;
    else misses.push({ key: exp[keyField], reason: 'field-mismatch', detail: s.misses });
  }
  const recall = expectedItems.length ? matched / expectedItems.length : 1;
  const precision = actualItems?.length ? matched / actualItems.length : 0;
  return {
    completeness: recall,
    accuracy: matched ? correct / matched : 0,
    precision,
    recall,
    requiredMisses,
    misses,
  };
}

/** Apply the gate. Returns { pass, reasons }. */
export function gate(score, thresholds = THRESHOLDS) {
  const reasons = [];
  if (score.completeness < thresholds.completeness)
    reasons.push(`completeness ${score.completeness.toFixed(2)} < ${thresholds.completeness}`);
  if (score.accuracy < thresholds.accuracy)
    reasons.push(`accuracy ${score.accuracy.toFixed(2)} < ${thresholds.accuracy}`);
  if ((score.requiredMisses ?? 0) > thresholds.requiredMissesAllowed)
    reasons.push(`${score.requiredMisses} required field(s) missing`);
  return { pass: reasons.length === 0, reasons };
}
