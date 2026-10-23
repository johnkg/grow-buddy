import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';

String _money(double v) => '₱${v.toStringAsFixed(2)}';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  Future<void> _addSale(BuildContext context) async {
    final sale = await showDialog<Sale>(context: context, builder: (_) => const _SaleDialog());
    if (sale != null) await Store.instance.addSale(sale);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final sales = Store.instance.sales.reversed.toList();
        final revenue = sales.fold<double>(0, (a, s) => a + s.revenue);
        final cost = sales.fold<double>(0, (a, s) => a + s.cost);
        final profit = revenue - cost;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addSale(context),
            icon: const Icon(Icons.add),
            label: const Text('Record sale'),
          ),
          body: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat(context, 'Revenue', _money(revenue)),
                      _stat(context, 'Costs', _money(cost)),
                      _stat(context, 'Profit', _money(profit)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: sales.isEmpty
                    ? const Center(child: Text('No sales yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: sales.length,
                        itemBuilder: (context, i) {
                          final s = sales[i];
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
                              subtitle: Text(
                                '${s.date.substring(0, 10)}${s.note.isEmpty ? '' : ' · ${s.note}'}',
                              ),
                              trailing: Text(
                                '${_money(s.revenue)}\nprofit ${_money(s.profit)}',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
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

/// Owns its controllers so they outlive the dialog's exit animation.
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Sale(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        item: _item.text.trim(),
        qty: int.parse(_qty.text.trim()),
        unitPrice: double.parse(_price.text.trim()),
        cost: double.parse(_cost.text.trim()),
        date: DateTime.now().toIso8601String(),
        note: _note.text.trim(),
      ),
    );
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
