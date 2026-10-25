'use strict';
// Core app logic. Mirrors the Dart code in lib/models.dart and lib/data/symptoms.dart.
// Dates are 'YYYY-MM-DD' strings (callers pass the first 10 chars of an ISO timestamp), so JS and
// Dart do the same whole-day arithmetic with no timezone involved.

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

function parseYmd(ymd) {
  const [y, m, d] = ymd.slice(0, 10).split('-').map(Number);
  return [y, m - 1, d];
}

const DAY_MS = 86400000;

/** Whole days since 1970-01-01 for a 'YYYY-MM-DD' string. */
function dayNumber(ymd) {
  return Math.round(Date.UTC(...parseYmd(ymd)) / DAY_MS);
}

/** 'YYYY-MM-DD' plus n days (n may be negative). */
function addDays(ymd, n) {
  const [y, m, d] = parseYmd(ymd);
  return new Date(Date.UTC(y, m, d + n)).toISOString().slice(0, 10);
}

/**
 * When a plant is next due for water. state: 'overdue' (past due), 'today', or 'ok'.
 * daysUntil is negative when overdue.
 */
function wateringStatus(lastWatered, everyDays, today) {
  const dueOn = addDays(lastWatered, everyDays);
  const daysUntil = dayNumber(dueOn) - dayNumber(today);
  const state = daysUntil < 0 ? 'overdue' : daysUntil === 0 ? 'today' : 'ok';
  return { dueOn, daysUntil, state };
}

/**
 * Usual sell window for a plant started on plantedOn.
 * phase: 'notYet' (before the window), 'window' (inside it, inclusive), 'late' (past it).
 */
function readyEstimate(plantedOn, minDays, maxDays, today) {
  const earliest = addDays(plantedOn, minDays);
  const latest = addDays(plantedOn, maxDays);
  const daysToEarliest = dayNumber(earliest) - dayNumber(today);
  const daysToLatest = dayNumber(latest) - dayNumber(today);
  const phase = daysToEarliest > 0 ? 'notYet' : daysToLatest >= 0 ? 'window' : 'late';
  return { earliest, latest, daysToEarliest, phase };
}

function addTo(map, key, s) {
  const row = map.get(key) || { key, qty: 0, revenue: 0, cost: 0, profit: 0 };
  row.qty += s.qty;
  row.revenue += s.qty * s.unitPrice;
  row.cost += s.cost;
  row.profit = row.revenue - row.cost;
  map.set(key, row);
}

/** Totals per calendar month ('YYYY-MM' from sale.date), oldest first. */
function salesByMonth(sales) {
  const map = new Map();
  for (const s of sales) addTo(map, s.date.slice(0, 7), s);
  return [...map.values()].sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
}

/** Totals per plant variety (sale.guideId, or 'other' when not linked), most profit first. */
function salesByVariety(sales) {
  const map = new Map();
  for (const s of sales) addTo(map, s.guideId || 'other', s);
  return [...map.values()].sort((a, b) => {
    const d = b.profit - a.profit;
    return Math.abs(d) > 1e-9 ? d : a.key < b.key ? -1 : a.key > b.key ? 1 : 0;
  });
}

module.exports = {
  checkFit, rankCauses, salesSummary, margin,
  dayNumber, addDays, wateringStatus, readyEstimate, salesByMonth, salesByVariety,
};
