'use strict';
// Core app logic. Mirrors the Dart code in lib/models.dart and lib/data/symptoms.dart.

/** @returns {{verdict:'good'|'maybe'|'poor', headline:string, tips:string[]}} */
function checkFit(p, hrs) {
  const range = `${p.minAfternoonHrs}-${p.maxAfternoonHrs} hrs`;
  const have = Number(hrs).toFixed(1);
  const tips = [];
  if (hrs < p.minAfternoonHrs) {
    const gap = p.minAfternoonHrs - hrs;
    tips.push(`${p.name} likes about ${range} of direct sun. You have ${have}.`);
    tips.push('Use the brightest spot, add a light-colored wall or reflector nearby, or pick a lower-light plant.');
    tips.push(...p.afternoonTips);
    return { verdict: gap <= 1 ? 'maybe' : 'poor', headline: 'Not enough sun', tips };
  }
  if (hrs > p.maxAfternoonHrs) {
    const gap = hrs - p.maxAfternoonHrs;
    tips.push(`${p.name} is happiest with about ${range} of direct sun. You have ${have}.`);
    tips.push('Put 30-50% shade cloth over the plant during the hottest hours, or move it back from the sun.');
    tips.push(...p.afternoonTips);
    return { verdict: gap <= 1 ? 'maybe' : 'poor', headline: 'Too much afternoon sun', tips };
  }
  if (p.heatSensitive && hrs >= 4) {
    tips.push(`Light amount is OK, but afternoon sun is hot and ${p.name} scorches easily.`);
    tips.push('Shade cloth or a spot with filtered light will protect it.');
    tips.push(...p.afternoonTips);
    return { verdict: 'maybe', headline: 'Works with some protection', tips };
  }
  tips.push(`Your afternoon sun is within the ${range} ${p.name} likes.`);
  tips.push(...p.afternoonTips);
  return { verdict: 'good', headline: 'Good fit', tips };
}

/**
 * Rank causes by how many selected symptoms point at them.
 * Each symptom hands out a total weight of 1, split by position (earlier causes
 * weigh more), so a symptom with a single possible cause counts for more than
 * one that could be many things.
 */
function rankCauses(selected, data) {
  const sel = new Set(selected);
  const scores = new Map();
  for (const s of data.symptoms) {
    if (!sel.has(s.id)) continue;
    const n = s.causes.length;
    const total = (n * (n + 1)) / 2;
    s.causes.forEach((cid, i) => {
      scores.set(cid, (scores.get(cid) || 0) + (n - i) / total);
    });
  }
  return [...scores.entries()]
    .map(([id, score]) => ({ id, score, ...data.causes[id] }))
    .sort((a, b) => {
      const d = b.score - a.score;
      return Math.abs(d) > 1e-9 ? d : a.id.localeCompare(b.id);
    });
}

/** Sales totals. sale: {qty, unitPrice, cost}. */
function salesSummary(sales) {
  let revenue = 0;
  let cost = 0;
  for (const s of sales) {
    revenue += s.qty * s.unitPrice;
    cost += s.cost;
  }
  return { revenue, cost, profit: revenue - cost };
}

/** Margin as a fraction of revenue, or null when there is no revenue. */
function margin(summary) {
  return summary.revenue > 0 ? summary.profit / summary.revenue : null;
}

module.exports = { checkFit, rankCauses, salesSummary, margin };
