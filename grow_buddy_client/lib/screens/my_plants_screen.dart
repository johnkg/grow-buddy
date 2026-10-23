import 'package:flutter/material.dart';
import '../data/plant_guides.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/text_prompt_dialog.dart';

String _ymd(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;

class MyPlantsScreen extends StatelessWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final plants = Store.instance.plants;
        if (plants.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No plants yet. Open the Guide tab, pick a plant, and tap "Start growing".',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: plants.length,
          itemBuilder: (context, i) {
            final p = plants[i];
            final g = guideById(p.guideId);
            final days = DateTime.now().difference(DateTime.parse(p.plantedOn)).inDays;
            return ListTile(
              leading: Text(g?.emoji ?? '🌱', style: const TextStyle(fontSize: 28)),
              title: Text(p.nickname),
              subtitle: Text('${g?.name ?? p.guideId} · day $days · ${p.status}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => MyPlantDetail(plantId: p.id)),
              ),
            );
          },
        );
      },
    );
  }
}

class MyPlantDetail extends StatelessWidget {
  final String plantId;
  const MyPlantDetail({super.key, required this.plantId});

  Future<void> _addLog(BuildContext context, MyPlant p) async {
    final text = await showTextPrompt(
      context,
      title: 'Add log entry',
      confirmLabel: 'Save',
      hintText: 'Watered, repotted, new leaf, pests seen...',
      maxLines: 3,
      autofocus: true,
    );
    if (text == null || text.isEmpty) return;
    p.logs.insert(0, LogEntry(DateTime.now().toIso8601String(), text));
    await Store.instance.updatePlant();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final matches = Store.instance.plants.where((x) => x.id == plantId);
        if (matches.isEmpty) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Plant removed')));
        }
        final p = matches.first;
        final g = guideById(p.guideId);
        return Scaffold(
          appBar: AppBar(
            title: Text(p.nickname),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove plant',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove this plant?'),
                      content: const Text('Its log will be deleted too.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await Store.instance.removePlant(p.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addLog(context, p),
            icon: const Icon(Icons.edit_note),
            label: const Text('Add log'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text('${g?.emoji ?? '🌱'} ${g?.name ?? p.guideId}',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('Started ${_ymd(p.plantedOn)}'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'growing', label: Text('Growing')),
                  ButtonSegment(value: 'ready', label: Text('Ready to sell')),
                  ButtonSegment(value: 'sold', label: Text('Sold')),
                ],
                selected: {p.status},
                onSelectionChanged: (s) async {
                  p.status = s.first;
                  await Store.instance.updatePlant();
                },
              ),
              if (g != null) ...[
                const SizedBox(height: 16),
                Text('Water: ${g.water}'),
                const SizedBox(height: 4),
                Text('Time to sellable: ${g.timeToSell}'),
              ],
              const SizedBox(height: 16),
              Text('Log', style: Theme.of(context).textTheme.titleMedium),
              if (p.logs.isEmpty) const Text('No entries yet.'),
              for (final l in p.logs)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.text),
                  subtitle: Text(_ymd(l.date)),
                ),
            ],
          ),
        );
      },
    );
  }
}
