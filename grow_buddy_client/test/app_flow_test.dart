import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grow_buddy/backup.dart';
import 'package:grow_buddy/data/plant_guides.dart';
import 'package:grow_buddy/main.dart';
import 'package:grow_buddy/models.dart';
import 'package:grow_buddy/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _boot(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await Store.instance.load();
  Store.instance.plants.clear();
  Store.instance.sales.clear();
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const GrowBuddyApp());
  await tester.pumpAndSettle();
}

/// Stands in for the file picker: remembers what was saved, hands back whatever [pick] holds.
class _FakeBackupIo implements BackupIo {
  String? savedName;
  String? savedText;
  String? pick;

  @override
  Future<bool> save(String fileName, String text) async {
    savedName = fileName;
    savedText = text;
    return true;
  }

  @override
  Future<String?> pickText() async => pick;
}

MyPlant _plant(
    {String id = 'p1',
    String guideId = 'pothos',
    String nick = 'Potty',
    int plantedDaysAgo = 10,
    int? wateredDaysAgo}) {
  final today = todayYmd();
  return MyPlant(
    id: id,
    guideId: guideId,
    nickname: nick,
    plantedOn: '${addDays(today, -plantedDaysAgo)}T08:00:00.000',
    lastWatered:
        wateredDaysAgo == null ? null : addDays(today, -wateredDaysAgo),
  );
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guide -> start growing -> shows in My plants -> add log',
      (tester) async {
    await _boot(tester);
    expect(find.text('Plant guide'), findsOneWidget);

    await tester.tap(find.textContaining('Snake plant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start growing'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Snakey');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(Store.instance.plants.single.nickname, 'Snakey');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('My plants'));
    await tester.pumpAndSettle();
    expect(find.text('Snakey'), findsOneWidget);

    await tester.tap(find.text('Snakey'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Watered');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Watered'), findsOneWidget);

    await tester.tap(find.text('Ready to sell'));
    await tester.pumpAndSettle();
    expect(Store.instance.plants.single.status, 'ready');
  });

  testWidgets('record a sale updates totals', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record sale'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Pothos 4" pot');
    await tester.enterText(fields.at(1), '2');
    await tester.enterText(fields.at(2), '150');
    await tester.enterText(fields.at(3), '60');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('₱300.00'), findsWidgets);
    expect(find.text('₱240.00'), findsOneWidget);
  });

  testWidgets('diagnose quick check lists causes', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Diagnose'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick check'));
    await tester.pumpAndSettle();
    expect(find.text('Likely causes'), findsOneWidget);
  });

  testWidgets('settings dialog saves server URL', (tester) async {
    await _boot(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'http://example.test:8787');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(Store.instance.serverUrl, 'http://example.test:8787');
  });

  testWidgets(
      'my plants: overdue badge, ready estimate, tap marks watered and logs it',
      (tester) async {
    await _boot(tester);
    final p =
        _plant(wateredDaysAgo: 8); // pothos waters every 5 days -> 3 days late
    Store.instance.plants.add(p);
    await tester.tap(find.text('My plants'));
    await tester.pumpAndSettle();
    expect(find.text('Overdue 3d'), findsOneWidget);
    expect(find.textContaining('Ready ~'), findsOneWidget);

    await tester.tap(find.text('Overdue 3d'));
    await tester.pumpAndSettle();
    expect(find.text('Water in 5d'), findsOneWidget);
    expect(p.lastWatered, todayYmd());
    expect(p.logs.first.text, 'Watered');
  });

  testWidgets(
      'my plants: never-watered plant counts from the planting date; sold plants show no badge',
      (tester) async {
    await _boot(tester);
    Store.instance.plants.add(_plant(plantedDaysAgo: 5)); // due today
    Store.instance.plants.add(_plant(id: 'p2', nick: 'Gone')..status = 'sold');
    await tester.tap(find.text('My plants'));
    await tester.pumpAndSettle();
    expect(find.text('Water today'), findsOneWidget);
    expect(find.textContaining('Water in'), findsNothing);
    expect(find.textContaining('Overdue'), findsNothing);
  });

  testWidgets('plant detail: water button and custom interval', (tester) async {
    await _boot(tester);
    final p = _plant(wateredDaysAgo: 8);
    Store.instance.plants.add(p);
    await tester.tap(find.text('My plants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Potty'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 days overdue'), findsOneWidget);
    expect(find.text('Every 5 days'), findsOneWidget);

    await tester.tap(find.text('Watered today'));
    await tester.pumpAndSettle();
    expect(find.textContaining('In 5 days'), findsOneWidget);

    await tester.tap(find.text('Every 5 days'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter whole days, from 1 to 90.'), findsOneWidget);
    expect(p.waterEveryDays, isNull);

    await tester.tap(find.text('Every 5 days'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(p.waterEveryDays, 2);
    expect(find.text('Every 2 days (yours)'), findsOneWidget);

    await tester.tap(find.text('Every 2 days (yours)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(p.waterEveryDays, isNull);
    expect(find.text('Every 5 days'), findsOneWidget);
  });

  testWidgets('sale linked to a plant marks it sold and feeds the insights',
      (tester) async {
    await _boot(tester);
    final p = _plant();
    Store.instance.plants.add(p);
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record sale'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<MyPlant?>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Potty').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text,
        guideById('pothos')!.name);
    await tester.enterText(fields.at(1), '2');
    await tester.enterText(fields.at(2), '100');
    await tester.enterText(fields.at(3), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final sale = Store.instance.sales.single;
    expect(sale.plantId, 'p1');
    expect(sale.guideId, 'pothos');
    expect(p.status, 'sold');
    expect(find.textContaining('Margin 75%'), findsOneWidget);
    expect(find.textContaining('Potty'),
        findsOneWidget); // plant name on the sale row

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('By month'), findsOneWidget);
    expect(find.text('By plant, best profit first'), findsOneWidget);
    expect(find.text(guideById('pothos')!.name), findsOneWidget);
    expect(find.textContaining('2 sold'), findsWidgets);
  });

  testWidgets('unticking "mark as sold" keeps the plant growing',
      (tester) async {
    await _boot(tester);
    final p = _plant();
    Store.instance.plants.add(p);
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record sale'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<MyPlant?>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Potty').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), '90');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(Store.instance.sales.single.plantId, 'p1');
    expect(p.status, 'growing');
  });

  testWidgets('insights: empty state, and unlinked sales are grouped',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Record a sale to see insights.'), findsOneWidget);

    Store.instance.sales.add(Sale(
      id: 's1',
      item: 'Mystery',
      qty: 1,
      unitPrice: 80,
      cost: 95,
      date: '${todayYmd()}T09:00:00.000',
    ));
    await Store.instance.updatePlant(); // just notifies listeners
    await tester.pumpAndSettle();
    expect(find.text('Not linked to a plant'), findsOneWidget);
    expect(find.textContaining('Pick a plant when recording a sale'),
        findsOneWidget);
  });

  group('backup', () {
    late _FakeBackupIo io;

    setUp(() {
      io = _FakeBackupIo();
      BackupIo.current = io;
    });
    tearDown(() => BackupIo.current = FilePickerBackupIo());

    testWidgets('export hands the whole data set to the file saver',
        (tester) async {
      await _boot(tester);
      Store.instance.plants.add(_plant());
      Store.instance.sunHours = 3;
      await _openSettings(tester);
      await tester.ensureVisible(find.text('Export backup'));
      await tester.tap(find.text('Export backup'));
      await tester.pumpAndSettle();

      expect(io.savedName, startsWith('grow-buddy-backup-'));
      expect(io.savedName, endsWith('.json'));
      final back = Backup.decode(io.savedText!);
      expect(back.plants.single.nickname, 'Potty');
      expect(back.sunHours, 3);
      expect(find.textContaining('Backup saved as grow-buddy-backup-'),
          findsOneWidget);
    });

    testWidgets('import replaces the data after confirming', (tester) async {
      await _boot(tester);
      Store.instance.plants.add(_plant(nick: 'Old'));
      io.pick = Backup(
        plants: [
          _plant(id: 'a', nick: 'New A'),
          _plant(id: 'b', nick: 'New B')
        ],
        sales: [
          Sale(
              id: 's',
              item: 'X',
              qty: 1,
              unitPrice: 10,
              cost: 1,
              date: '2026-10-01T00:00:00.000'),
        ],
        sunHours: 6,
      ).encode();
      await _openSettings(tester);
      await tester.ensureVisible(find.text('Import backup'));
      await tester.tap(find.text('Import backup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This backup has 2 plants and 1 sales'),
          findsOneWidget);
      expect(find.textContaining('The 1 plants and 0 sales'), findsOneWidget);

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(Store.instance.plants.map((p) => p.nickname), ['New A', 'New B']);
      expect(Store.instance.sales.length, 1);
      expect(Store.instance.sunHours, 6);
      expect(find.text('Restored 2 plants and 1 sales.'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation keeps current data',
        (tester) async {
      await _boot(tester);
      Store.instance.plants.add(_plant(nick: 'Old'));
      io.pick = Backup(plants: [], sales: [], sunHours: 4).encode();
      await _openSettings(tester);
      await tester.ensureVisible(find.text('Import backup'));
      await tester.tap(find.text('Import backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(Store.instance.plants.single.nickname, 'Old');
    });

    testWidgets('a bad file shows a message and changes nothing',
        (tester) async {
      await _boot(tester);
      Store.instance.plants.add(_plant(nick: 'Old'));
      io.pick = 'definitely not a backup';
      await _openSettings(tester);
      await tester.ensureVisible(find.text('Import backup'));
      await tester.tap(find.text('Import backup'));
      await tester.pumpAndSettle();
      expect(find.text('That file is not valid JSON.'), findsOneWidget);
      expect(Store.instance.plants.single.nickname, 'Old');
    });

    testWidgets('picking nothing is a quiet no-op', (tester) async {
      await _boot(tester);
      io.pick = null;
      await _openSettings(tester);
      await tester.ensureVisible(find.text('Import backup'));
      await tester.tap(find.text('Import backup'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backupMessage')), findsNothing);
    });
  });
}
