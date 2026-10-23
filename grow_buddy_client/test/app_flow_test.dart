import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grow_buddy/main.dart';
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

void main() {
  testWidgets('guide -> start growing -> shows in My plants -> add log', (tester) async {
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

  testWidgets('debug quick check lists causes', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Debug'));
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
    await tester.enterText(find.byType(TextField).first, 'http://example.test:8787');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(Store.instance.serverUrl, 'http://example.test:8787');
  });
}
