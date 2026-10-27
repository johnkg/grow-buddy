class PlantGuide {
  final String id;
  final String name;
  final String emoji;
  final String difficulty; // Easy / Medium / Hard
  final int minAfternoonHrs; // comfortable direct afternoon sun, low end
  final int maxAfternoonHrs; // comfortable direct afternoon sun, high end
  final bool heatSensitive; // afternoon sun is the hottest, scorches easily
  final int waterEveryDays; // typical days between waterings (general knowledge, not verified)
  final int daysToSellMin; // usual days from start to a sellable plant, low end
  final int daysToSellMax; // high end
  final String water;
  final String soil;
  final String timeToSell;
  final String sellNote;
  final List<String> steps;
  final List<String> afternoonTips;

  const PlantGuide({
    required this.id,
    required this.name,
    required this.emoji,
    required this.difficulty,
    required this.minAfternoonHrs,
    required this.maxAfternoonHrs,
    required this.heatSensitive,
    required this.waterEveryDays,
    required this.daysToSellMin,
    required this.daysToSellMax,
    required this.water,
    required this.soil,
    required this.timeToSell,
    required this.sellNote,
    required this.steps,
    required this.afternoonTips,
  });
}

enum Verdict { good, maybe, poor }

class Fit {
  final Verdict verdict;
  final String headline;
  final List<String> tips;
  const Fit(this.verdict, this.headline, this.tips);
}

/// Afternoon sun is hotter and harsher than morning sun, so the check is
/// stricter for heat-sensitive plants.
Fit checkFit(PlantGuide p, double hrs) {
  final tips = <String>[];
  final range = '${p.minAfternoonHrs}-${p.maxAfternoonHrs} hrs';
  if (hrs < p.minAfternoonHrs) {
    final gap = p.minAfternoonHrs - hrs;
    tips.add('${p.name} likes about $range of direct sun. You have ${hrs.toStringAsFixed(1)}.');
    tips.add('Use the brightest spot, add a light-colored wall or reflector nearby, or pick a lower-light plant.');
    tips.addAll(p.afternoonTips);
    return Fit(gap <= 1 ? Verdict.maybe : Verdict.poor, 'Not enough sun', tips);
  }
  if (hrs > p.maxAfternoonHrs) {
    final gap = hrs - p.maxAfternoonHrs;
    tips.add('${p.name} is happiest with about $range of direct sun. You have ${hrs.toStringAsFixed(1)}.');
    tips.add('Put 30-50% shade cloth over the plant during the hottest hours, or move it back from the sun.');
    tips.addAll(p.afternoonTips);
    return Fit(gap <= 1 ? Verdict.maybe : Verdict.poor, 'Too much afternoon sun', tips);
  }
  if (p.heatSensitive && hrs >= 4) {
    tips.add('Light amount is OK, but afternoon sun is hot and ${p.name} scorches easily.');
    tips.add('Shade cloth or a spot with filtered light will protect it.');
    tips.addAll(p.afternoonTips);
    return Fit(Verdict.maybe, 'Works with some protection', tips);
  }
  tips.add('Your afternoon sun is within the $range ${p.name} likes.');
  tips.addAll(p.afternoonTips);
  return Fit(Verdict.good, 'Good fit', tips);
}

class LogEntry {
  final String date; // ISO
  final String text;
  LogEntry(this.date, this.text);
  Map<String, dynamic> toJson() => {'date': date, 'text': text};
  factory LogEntry.fromJson(Map<String, dynamic> j) =>
      LogEntry(j['date'] as String, j['text'] as String);
}

class MyPlant {
  final String id;
  final String guideId;
  String nickname;
  final String plantedOn; // ISO
  String status; // growing / ready / sold
  String? lastWatered; // YYYY-MM-DD; null = never marked, counts from plantedOn
  int? waterEveryDays; // overrides the guide's interval
  List<LogEntry> logs;

  MyPlant({
    required this.id,
    required this.guideId,
    required this.nickname,
    required this.plantedOn,
    this.status = 'growing',
    this.lastWatered,
    this.waterEveryDays,
    List<LogEntry>? logs,
  }) : logs = logs ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'guideId': guideId,
        'nickname': nickname,
        'plantedOn': plantedOn,
        'status': status,
        if (lastWatered != null) 'lastWatered': lastWatered,
        if (waterEveryDays != null) 'waterEveryDays': waterEveryDays,
        'logs': logs.map((l) => l.toJson()).toList(),
      };

  factory MyPlant.fromJson(Map<String, dynamic> j) => MyPlant(
        id: j['id'] as String,
        guideId: j['guideId'] as String,
        nickname: j['nickname'] as String,
        plantedOn: j['plantedOn'] as String,
        status: (j['status'] as String?) ?? 'growing',
        lastWatered: j['lastWatered'] as String?,
        waterEveryDays: (j['waterEveryDays'] as num?)?.toInt(),
        logs: ((j['logs'] as List?) ?? [])
            .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Sale {
  final String id;
  final String item;
  final int qty;
  final double unitPrice;
  final double cost; // total cost for this batch (pot, soil, seeds...)
  final String date; // ISO
  final String note;
  final String? plantId; // MyPlant this sale came from, if linked (plant may be removed later)
  final String? guideId; // plant variety, kept so per-variety stats survive removing the plant

  Sale({
    required this.id,
    required this.item,
    required this.qty,
    required this.unitPrice,
    required this.cost,
    required this.date,
    this.note = '',
    this.plantId,
    this.guideId,
  });

  double get revenue => qty * unitPrice;
  double get profit => revenue - cost;

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'qty': qty,
        'unitPrice': unitPrice,
        'cost': cost,
        'date': date,
        'note': note,
        if (plantId != null) 'plantId': plantId,
        if (guideId != null) 'guideId': guideId,
      };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: j['id'] as String,
        item: j['item'] as String,
        qty: (j['qty'] as num).toInt(),
        unitPrice: (j['unitPrice'] as num).toDouble(),
        cost: (j['cost'] as num).toDouble(),
        date: j['date'] as String,
        note: (j['note'] as String?) ?? '',
        plantId: j['plantId'] as String?,
        guideId: j['guideId'] as String?,
      );
}

// ---- Dates, care schedule and sales stats. Mirror grow_buddy_server/src/core.js. ----
// Dates are 'YYYY-MM-DD' strings (first 10 chars of an ISO timestamp): whole-day math, no timezone.

List<int> _parseYmd(String ymd) {
  final p = ymd.substring(0, 10).split('-').map(int.parse).toList();
  return [p[0], p[1], p[2]];
}

/// Whole days since 1970-01-01 for a 'YYYY-MM-DD' string.
int dayNumber(String ymd) {
  final p = _parseYmd(ymd);
  return DateTime.utc(p[0], p[1], p[2]).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

/// 'YYYY-MM-DD' plus n days (n may be negative).
String addDays(String ymd, int n) {
  final p = _parseYmd(ymd);
  final d = DateTime.utc(p[0], p[1], p[2] + n);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// Today in the device's local time, as 'YYYY-MM-DD'.
String todayYmd() => DateTime.now().toIso8601String().substring(0, 10);

enum WaterState { overdue, today, ok }

class WateringStatus {
  final String dueOn;
  final int daysUntil; // negative when overdue
  final WaterState state;
  const WateringStatus(this.dueOn, this.daysUntil, this.state);
}

WateringStatus wateringStatus(String lastWatered, int everyDays, String today) {
  final dueOn = addDays(lastWatered, everyDays);
  final daysUntil = dayNumber(dueOn) - dayNumber(today);
  final state = daysUntil < 0
      ? WaterState.overdue
      : daysUntil == 0
          ? WaterState.today
          : WaterState.ok;
  return WateringStatus(dueOn, daysUntil, state);
}

enum ReadyPhase { notYet, window, late }

class ReadyEstimate {
  final String earliest;
  final String latest;
  final int daysToEarliest;
  final ReadyPhase phase;
  const ReadyEstimate(this.earliest, this.latest, this.daysToEarliest, this.phase);
}

/// Usual sell window for a plant started on [plantedOn].
ReadyEstimate readyEstimate(String plantedOn, int minDays, int maxDays, String today) {
  final earliest = addDays(plantedOn, minDays);
  final latest = addDays(plantedOn, maxDays);
  final daysToEarliest = dayNumber(earliest) - dayNumber(today);
  final daysToLatest = dayNumber(latest) - dayNumber(today);
  final phase = daysToEarliest > 0
      ? ReadyPhase.notYet
      : daysToLatest >= 0
          ? ReadyPhase.window
          : ReadyPhase.late;
  return ReadyEstimate(earliest, latest, daysToEarliest, phase);
}

class SalesSummary {
  final double revenue;
  final double cost;
  final double profit;
  const SalesSummary(this.revenue, this.cost, this.profit);
}

SalesSummary salesSummary(Iterable<Sale> sales) {
  var revenue = 0.0;
  var cost = 0.0;
  for (final s in sales) {
    revenue += s.qty * s.unitPrice;
    cost += s.cost;
  }
  return SalesSummary(revenue, cost, revenue - cost);
}

/// Margin as a fraction of revenue, or null when there is no revenue.
double? margin(SalesSummary s) => s.revenue > 0 ? s.profit / s.revenue : null;

/// One row of a sales breakdown (a month, or a plant variety).
class SalesRow {
  final String key;
  int qty = 0;
  double revenue = 0;
  double cost = 0;
  double profit = 0;
  SalesRow(this.key);
}

void _addTo(Map<String, SalesRow> map, String key, Sale s) {
  final row = map.putIfAbsent(key, () => SalesRow(key));
  row.qty += s.qty;
  row.revenue += s.qty * s.unitPrice;
  row.cost += s.cost;
  row.profit = row.revenue - row.cost;
}

/// Totals per calendar month ('YYYY-MM' from sale.date), oldest first.
List<SalesRow> salesByMonth(Iterable<Sale> sales) {
  final map = <String, SalesRow>{};
  for (final s in sales) {
    _addTo(map, s.date.substring(0, 7), s);
  }
  return map.values.toList()..sort((a, b) => a.key.compareTo(b.key));
}

/// Totals per plant variety (sale.guideId, or 'other' when not linked), most profit first.
List<SalesRow> salesByVariety(Iterable<Sale> sales) {
  final map = <String, SalesRow>{};
  for (final s in sales) {
    final g = s.guideId;
    _addTo(map, (g == null || g.isEmpty) ? 'other' : g, s);
  }
  return map.values.toList()
    ..sort((a, b) {
      final d = b.profit - a.profit;
      if (d.abs() > 1e-9) return d > 0 ? 1 : -1;
      return a.key.compareTo(b.key);
    });
}
