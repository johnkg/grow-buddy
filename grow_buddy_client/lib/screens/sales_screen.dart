import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/plant_guides.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool _insights = false;

  Future<void> _addSale(BuildContext context) async {
    final r = await showDialog<(Sale, bool)>(
        context: context, builder: (_) => const _SaleDialog());
    if (r != null) await Store.instance.addSale(r.$1, markPlantSold: r.$2);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final all = Store.instance.sales;
        final sales = all.reversed.toList();
        final summary = salesSummary(all);
        final m = margin(summary);
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addSale(context),
            icon: const Icon(Icons.add),
            label: const Text('Record sale'),
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _SummaryHero(summary: summary, margin: m),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: false,
                        label: Text('Sales'),
                        icon: Icon(Icons.receipt_long)),
                    ButtonSegment(
                        value: true,
                        label: Text('Insights'),
                        icon: Icon(Icons.bar_chart)),
                  ],
                  selected: {_insights},
                  onSelectionChanged: (s) =>
                      setState(() => _insights = s.first),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                  child: _insights ? _Insights(sales: all) : _history(sales)),
            ],
          ),
        );
      },
    );
  }

  Widget _history(List<Sale> sales) {
    if (sales.isEmpty) return const Center(child: Text('No sales yet.'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: sales.length,
      itemBuilder: (context, i) {
        final s = sales[i];
        final plant =
            Store.instance.plants.where((p) => p.id == s.plantId).firstOrNull;
        final extras = [
          s.date.substring(0, 10),
          if (plant != null) plant.nickname,
          if (s.note.isNotEmpty) s.note,
        ];
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Dismissible(
              key: ValueKey(s.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: scheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: Icon(Icons.delete, color: scheme.onError),
              ),
              onDismissed: (_) => Store.instance.removeSale(s.id),
              child: ColoredBox(
                  color: scheme.surfaceContainerLowest,
                  child: ListTile(
                    title: Text('${s.qty} × ${s.item}'),
                    subtitle: Text(extras.join(' · ')),
                    trailing: Text(
                      '${money(s.revenue)}\nprofit ${money(s.profit)}',
                      textAlign: TextAlign.right,
                    ),
                  )),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryHero extends StatelessWidget {
  final SalesSummary summary;
  final double? margin;
  const _SummaryHero({required this.summary, required this.margin});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final soft = scheme.onPrimary.withValues(alpha: 0.8);
    Widget small(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: soft)),
              Text(value,
                  style: theme.titleSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profit', style: TextStyle(fontSize: 14, color: soft)),
        Text(
          money(summary.profit),
          style: theme.headlineMedium?.copyWith(
            color: scheme.onPrimary,
            fontSize: 40,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            small('Revenue', money(summary.revenue)),
            small('Costs', money(summary.cost)),
          ],
        ),
        if (margin != null) ...[
          const SizedBox(height: 8),
          Text('Margin ${(margin! * 100).round()}%',
              style: TextStyle(fontSize: 13, color: soft)),
        ],
      ],
    );
  }
}

/// Month-by-month bars and a best-sellers list, from the shared salesByMonth / salesByVariety logic.
class _Insights extends StatelessWidget {
  final List<Sale> sales;
  const _Insights({required this.sales});

  String _varietyName(String key) {
    if (key == 'other') return 'Not linked to a plant';
    return guideById(key)?.name ?? key;
  }

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Center(child: Text('Record a sale to see insights.'));
    }
    final theme = Theme.of(context);
    final months = salesByMonth(sales);
    final recent =
        months.length > 6 ? months.sublist(months.length - 6) : months;
    final maxRevenue = recent.fold<double>(0, (a, r) => math.max(a, r.revenue));
    final varieties = salesByVariety(sales);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        Text('By month', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final r in recent.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(monthLabel(r.key)),
                    const Spacer(),
                    Text(money(r.revenue)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: maxRevenue > 0 ? r.revenue / maxRevenue : 0,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  color: r.revenue == maxRevenue
                      ? sunAmber
                      : theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                ),
                const SizedBox(height: 2),
                Text(
                  'profit ${money(r.profit)} · ${r.qty} sold',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: r.profit < 0 ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text('By plant, best profit first', style: theme.textTheme.titleMedium),
        for (var i = 0; i < varieties.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Text(
              varieties[i].key == 'other'
                  ? '🪴'
                  : (guideById(varieties[i].key)?.emoji ?? '🪴'),
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(_varietyName(varieties[i].key)),
            subtitle: Text(
                '${varieties[i].qty} sold · revenue ${money(varieties[i].revenue)}'),
            trailing: Text(
              '${i == 0 && varieties.length > 1 ? '★ ' : ''}${money(varieties[i].profit)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: varieties[i].profit < 0 ? theme.colorScheme.error : null,
              ),
            ),
          ),
        if (varieties.any((v) => v.key == 'other'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pick a plant when recording a sale to get per-plant numbers.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Owns its controllers so they outlive the dialog's exit animation.
/// Pops with (sale, markPlantSold).
class _SaleDialog extends StatefulWidget {
  const _SaleDialog();

  @override
  State<_SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<_SaleDialog> {
  final _item = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final List<MyPlant> _plants =
      Store.instance.plants.where((p) => p.status != 'sold').toList();
  MyPlant? _plant;
  bool _markSold = true;

  @override
  void dispose() {
    _item.dispose();
    _qty.dispose();
    _price.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _numCheck(String? v) =>
      (v == null || double.tryParse(v.trim()) == null)
          ? 'Enter a number'
          : null;

  void _pickPlant(MyPlant? p) {
    setState(() {
      _plant = p;
      if (p != null && _item.text.trim().isEmpty) {
        _item.text = guideById(p.guideId)?.name ?? p.nickname;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      Sale(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        item: _item.text.trim(),
        qty: int.parse(_qty.text.trim()),
        unitPrice: double.parse(_price.text.trim()),
        cost: double.parse(_cost.text.trim()),
        date: DateTime.now().toIso8601String(),
        note: _note.text.trim(),
        plantId: _plant?.id,
        guideId: _plant?.guideId,
      ),
      _plant != null && _markSold,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record sale'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_plants.isNotEmpty)
                DropdownButtonFormField<MyPlant?>(
                  initialValue: _plant,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'From my plants (optional)'),
                  items: [
                    const DropdownMenuItem<MyPlant?>(
                        value: null, child: Text('Not linked')),
                    for (final p in _plants)
                      DropdownMenuItem<MyPlant?>(
                        value: p,
                        child: Text(
                          '${guideById(p.guideId)?.emoji ?? '🌱'} ${p.nickname}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _pickPlant,
                ),
              if (_plant != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Mark this plant as sold'),
                  subtitle: const Text('Untick if you still have more of it'),
                  value: _markSold,
                  onChanged: (v) => setState(() => _markSold = v ?? true),
                ),
              TextFormField(
                controller: _item,
                decoration: const InputDecoration(
                    labelText: 'Item (e.g. Pothos 4" pot)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (v) => (int.tryParse((v ?? '').trim()) == null)
                    ? 'Whole number'
                    : null,
              ),
              TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price each (₱)'),
                validator: _numCheck,
              ),
              TextFormField(
                controller: _cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Total cost (pot, soil, seeds...) (₱)'),
                validator: _numCheck,
              ),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
