class PlantGuide {
  final String id;
  final String name;
  final String emoji;
  final String difficulty; // Easy / Medium / Hard
  final int minAfternoonHrs; // comfortable direct afternoon sun, low end
  final int maxAfternoonHrs; // comfortable direct afternoon sun, high end
  final bool heatSensitive; // afternoon sun is the hottest, scorches easily
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
  List<LogEntry> logs;

  MyPlant({
    required this.id,
    required this.guideId,
    required this.nickname,
    required this.plantedOn,
    this.status = 'growing',
    List<LogEntry>? logs,
  }) : logs = logs ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'guideId': guideId,
        'nickname': nickname,
        'plantedOn': plantedOn,
        'status': status,
        'logs': logs.map((l) => l.toJson()).toList(),
      };

  factory MyPlant.fromJson(Map<String, dynamic> j) => MyPlant(
        id: j['id'] as String,
        guideId: j['guideId'] as String,
        nickname: j['nickname'] as String,
        plantedOn: j['plantedOn'] as String,
        status: (j['status'] as String?) ?? 'growing',
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

  Sale({
    required this.id,
    required this.item,
    required this.qty,
    required this.unitPrice,
    required this.cost,
    required this.date,
    this.note = '',
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
      };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: j['id'] as String,
        item: j['item'] as String,
        qty: (j['qty'] as num).toInt(),
        unitPrice: (j['unitPrice'] as num).toDouble(),
        cost: (j['cost'] as num).toDouble(),
        date: j['date'] as String,
        note: (j['note'] as String?) ?? '',
      );
}
