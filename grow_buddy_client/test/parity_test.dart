import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grow_buddy/data/plant_guides.dart';
import 'package:grow_buddy/data/symptoms.dart';
import 'package:grow_buddy/models.dart';

// Checks that the Dart logic gives the same answers as the tested JS logic in
// grow_buddy_server. Fixture made by `npm run gen` in the server folder.
void main() {
  final fx = jsonDecode(File('test/fixtures/parity.json').readAsStringSync())
      as Map<String, dynamic>;

  test('same number of plants as the JSON data', () {
    expect(plantGuides.length, fx['plantCount']);
  });

  test('checkFit matches JS for every plant and hour', () {
    for (final raw in fx['fits'] as List) {
      final e = raw as Map<String, dynamic>;
      final g = guideById(e['id'] as String)!;
      final hrs = (e['hrs'] as num).toDouble();
      final f = checkFit(g, hrs);
      final why = '${e['id']} @ $hrs hrs';
      expect(f.verdict.name, e['verdict'], reason: why);
      expect(f.headline, e['headline'], reason: why);
      expect(f.tips, (e['tips'] as List).cast<String>(), reason: why);
    }
  });

  test('rankCauses matches JS order and scores', () {
    for (final raw in fx['ranks'] as List) {
      final e = raw as Map<String, dynamic>;
      final selected = (e['symptoms'] as List).cast<String>().toSet();
      final r = rankCauses(selected);
      final order = (e['order'] as List).cast<String>();
      final scores = (e['scores'] as List).cast<num>();
      expect(r.map((x) => x.cause.id).toList(), order, reason: '${e['symptoms']}');
      for (var i = 0; i < r.length; i++) {
        expect(r[i].score, closeTo(scores[i].toDouble(), 1e-9), reason: '${e['symptoms']}');
      }
    }
  });

  test('guide care numbers are sane for every plant', () {
    for (final g in plantGuides) {
      expect(g.waterEveryDays, inInclusiveRange(1, 30), reason: g.id);
      expect(g.daysToSellMin, lessThanOrEqualTo(g.daysToSellMax), reason: g.id);
    }
  });

  test('dayNumber and addDays match JS', () {
    for (final raw in fx['dates'] as List) {
      final e = raw as Map<String, dynamic>;
      final why = '${e['ymd']} + ${e['n']}';
      expect(dayNumber(e['ymd'] as String), e['day'], reason: why);
      expect(addDays(e['ymd'] as String, e['n'] as int), e['plus'], reason: why);
    }
  });

  test('wateringStatus matches JS', () {
    for (final raw in fx['water'] as List) {
      final e = raw as Map<String, dynamic>;
      final w = wateringStatus(e['last'] as String, e['every'] as int, e['today'] as String);
      final why = '${e['last']} every ${e['every']}';
      expect(w.dueOn, e['dueOn'], reason: why);
      expect(w.daysUntil, e['daysUntil'], reason: why);
      expect(w.state.name, e['state'], reason: why);
    }
  });

  test('readyEstimate matches JS', () {
    for (final raw in fx['ready'] as List) {
      final e = raw as Map<String, dynamic>;
      final r = readyEstimate(
          e['planted'] as String, e['lo'] as int, e['hi'] as int, e['today'] as String);
      final why = '${e['planted']} ${e['lo']}-${e['hi']}';
      expect(r.earliest, e['earliest'], reason: why);
      expect(r.latest, e['latest'], reason: why);
      expect(r.daysToEarliest, e['daysToEarliest'], reason: why);
      expect(r.phase.name, e['phase'], reason: why);
    }
  });

  test('sales summary, by month and by variety match JS', () {
    void sameRows(List<SalesRow> got, List want, String why) {
      expect(got.map((r) => r.key).toList(), want.map((r) => r['key']).toList(), reason: why);
      for (var i = 0; i < got.length; i++) {
        final w = want[i] as Map<String, dynamic>;
        expect(got[i].qty, w['qty'], reason: why);
        expect(got[i].revenue, closeTo((w['revenue'] as num).toDouble(), 1e-9), reason: why);
        expect(got[i].cost, closeTo((w['cost'] as num).toDouble(), 1e-9), reason: why);
        expect(got[i].profit, closeTo((w['profit'] as num).toDouble(), 1e-9), reason: why);
      }
    }

    for (final raw in fx['salesCases'] as List) {
      final e = raw as Map<String, dynamic>;
      final sales = (e['sales'] as List)
          .map((x) => Sale.fromJson(x as Map<String, dynamic>))
          .toList();
      final why = '${sales.length} sales';
      final sum = salesSummary(sales);
      final want = e['summary'] as Map<String, dynamic>;
      expect(sum.revenue, closeTo((want['revenue'] as num).toDouble(), 1e-9), reason: why);
      expect(sum.cost, closeTo((want['cost'] as num).toDouble(), 1e-9), reason: why);
      expect(sum.profit, closeTo((want['profit'] as num).toDouble(), 1e-9), reason: why);
      final m = margin(sum);
      if (e['margin'] == null) {
        expect(m, isNull, reason: why);
      } else {
        expect(m, closeTo((e['margin'] as num).toDouble(), 1e-9), reason: why);
      }
      sameRows(salesByMonth(sales), e['byMonth'] as List, 'month, $why');
      sameRows(salesByVariety(sales), e['byVariety'] as List, 'variety, $why');
    }
  });
}
