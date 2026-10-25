import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:grow_buddy/backup.dart';
import 'package:grow_buddy/models.dart';

Backup _sample() => Backup(
      plants: [
        MyPlant(
          id: 'p1',
          guideId: 'pothos',
          nickname: 'Potty',
          plantedOn: '2026-10-01T08:00:00.000',
          lastWatered: '2026-10-20',
          waterEveryDays: 4,
          logs: [LogEntry('2026-10-20T08:00:00.000', 'Watered')],
        ),
        MyPlant(id: 'p2', guideId: 'aloe', nickname: 'Aloe', plantedOn: '2026-10-05T08:00:00.000'),
      ],
      sales: [
        Sale(
          id: 's1',
          item: 'Pothos',
          qty: 2,
          unitPrice: 120.5,
          cost: 40,
          date: '2026-10-22T09:00:00.000',
          note: 'FB buyer',
          plantId: 'p1',
          guideId: 'pothos',
        ),
      ],
      sunHours: 3.5,
      exportedAt: '2026-10-25T10:00:00.000',
    );

void main() {
  test('encode then decode keeps everything', () {
    final back = Backup.decode(_sample().encode());
    expect(back.sunHours, 3.5);
    expect(back.exportedAt, '2026-10-25T10:00:00.000');
    expect(back.plants.length, 2);
    final p = back.plants.first;
    expect(p.nickname, 'Potty');
    expect(p.lastWatered, '2026-10-20');
    expect(p.waterEveryDays, 4);
    expect(p.logs.single.text, 'Watered');
    expect(back.plants.last.lastWatered, isNull);
    expect(back.plants.last.waterEveryDays, isNull);
    final s = back.sales.single;
    expect(s.unitPrice, 120.5);
    expect(s.plantId, 'p1');
    expect(s.guideId, 'pothos');
  });

  test('file name carries the export date', () {
    expect(_sample().fileName, 'grow-buddy-backup-2026-10-25.json');
  });

  test('never exports the server URL or app token', () {
    final text = _sample().encode();
    expect(text, isNot(contains('appToken')));
    expect(text, isNot(contains('serverUrl')));
  });

  test('older data without the newer fields still loads', () {
    final old = jsonEncode({
      'app': 'grow_buddy',
      'version': 1,
      'plants': [
        {'id': 'a', 'guideId': 'aloe', 'nickname': 'A', 'plantedOn': '2026-01-01T00:00:00.000'}
      ],
      'sales': [
        {
          'id': 's',
          'item': 'Aloe',
          'qty': 1,
          'unitPrice': 50,
          'cost': 10,
          'date': '2026-01-02T00:00:00.000'
        }
      ],
    });
    final b = Backup.decode(old);
    expect(b.plants.single.status, 'growing');
    expect(b.sales.single.plantId, isNull);
    expect(b.sunHours, 4);
  });

  test('rejects things that are not a Grow Buddy backup', () {
    void bad(String raw, String message) {
      expect(
        () => Backup.decode(raw),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', message)),
        reason: raw,
      );
    }

    bad('not json', 'That file is not valid JSON.');
    bad('[1,2]', 'That file is not a Grow Buddy backup.');
    bad('{"app":"other","version":1}', 'That file is not a Grow Buddy backup.');
    bad('{"app":"grow_buddy","version":99,"plants":[],"sales":[]}',
        'This backup is from a newer Grow Buddy. Update the app first.');
    bad('{"app":"grow_buddy","version":1}', 'The backup file is damaged or incomplete.');
    bad('{"app":"grow_buddy","version":1,"plants":[{"id":1}],"sales":[]}',
        'The backup file is damaged or incomplete.');
  });
}
