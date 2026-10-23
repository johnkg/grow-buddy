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
}
