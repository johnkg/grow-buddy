import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/plant_guides.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool _insights = false;

  Future<void> _addSale(BuildContext context) async {
    final r = await showDialog<(Sale, bool)>(context: context, builder: (_) => const _SaleDialog());
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
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat(context, 'Revenue', money(summary.revenue)),
                          _stat(context, 'Costs', money(summary.cost)),
                          _stat(context, 'Profit', money(summary.profit)),
                        ],
                      ),
                      if (m != null) ...[
                        const SizedBox(height: 4),
                        Text('Margin ${(m * 100).round()}%', style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sales'), icon: Icon(Icons.receipt_long)),
                    ButtonSegment(value: true, label: Text('Insights'), icon: Icon(Icons.bar_chart)),
                  ],
                  selected: {_insights},
                  onSelectionChanged: (s) => setState(() => _insights = s.first),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _insights ? _Insights(sales: all) : _history(sales)),
            ],
          ),
        );
      },
    );
  }

  Widget _history(List<Sale> sales) {
    if (sales.isEmpty) return const Center(child: Text('No sales yet.'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: sales.length,
      itemBuilder: (context, i) {
        final s = sales[i];
        final plant = Store.instance.plants.where((p) => p.id == s.plantId).firstOrNull;
        final extras = [
          s.date.substring(0, 10),
          if (plant != null) plant.nickname,
          if (s.note.isNotEmpty) s.note,
        ];
        return Dismissible(
          key: ValueKey(s.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => Store.instance.removeSale(s.id),
          child: ListTile(
            title: Text('${s.qty} × ${s.item}'),
            subtitle: Text(extras.join(' · ')),
            trailing: Text(
              '${money(s.revenue)}\nprofit ${money(s.profit)}',
              textAlign: TextAlign.right,
            ),
          ),
        );
      },
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
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
    final recent = months.length > 6 ? months.sublist(months.length - 6) : months;
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
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
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
              varieties[i].key == 'other' ? '🪴' : (guideById(varieties[i].key)?.emoji ?? '🪴'),
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(_varietyName(varieties[i].key)),
            subtitle: Text('${varieties[i].qty} sold · revenue ${money(varieties[i].revenue)}'),
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
      (v == null || double.tryParse(v.trim()) == null) ? 'Enter a number' : null;

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
                  decoration: const InputDecoration(labelText: 'From my plants (optional)'),
                  items: [
                    const DropdownMenuItem<MyPlant?>(value: null, child: Text('Not linked')),
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
                decoration: const InputDecoration(labelText: 'Item (e.g. Pothos 4" pot)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (v) => (int.tryParse((v ?? '').trim()) == null) ? 'Whole number' : null,
              ),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price each (₱)'),
                validator: _numCheck,
              ),
              TextFormField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total cost (pot, soil, seeds...) (₱)'),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
