import 'package:flutter/material.dart';
import '../care.dart';
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
            final today = todayYmd();
            final days = DateTime.now().difference(DateTime.parse(p.plantedOn)).inDays;
            final water = p.watering(g, today);
            final ready = p.readyIn(g, today);
            return ListTile(
              leading: Text(g?.emoji ?? '🌱', style: const TextStyle(fontSize: 28)),
              title: Text(p.nickname),
              isThreeLine: ready != null,
              subtitle: Text(
                '${g?.name ?? p.guideId} · day $days · ${p.status}'
                '${ready == null ? '' : '\n${readyLabel(ready)}'}',
              ),
              trailing: water == null
                  ? const Icon(Icons.chevron_right)
                  : _WaterChip(status: water, onTap: () => Store.instance.markWatered(p)),
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

/// Tapping it marks the plant watered today.
class _WaterChip extends StatelessWidget {
  final WateringStatus status;
  final VoidCallback onTap;
  const _WaterChip({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status.state) {
      WaterState.overdue => (scheme.errorContainer, scheme.onErrorContainer),
      WaterState.today => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      WaterState.ok => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    return ActionChip(
      avatar: Icon(Icons.water_drop, size: 16, color: fg),
      label: Text(waterBadge(status), style: TextStyle(color: fg)),
      backgroundColor: bg,
      side: BorderSide.none,
      tooltip: 'Mark watered today',
      onPressed: onTap,
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

  Future<void> _editInterval(BuildContext context, MyPlant p, PlantGuide? g) async {
    final text = await showTextPrompt(
      context,
      title: 'Water every how many days?',
      confirmLabel: 'Save',
      initialText: '${p.wateringInterval(g) ?? ''}',
      labelText: 'Days between waterings',
      hintText: g == null ? null : 'Empty = guide default (${g.waterEveryDays})',
      keyboardType: TextInputType.number,
      autofocus: true,
    );
    if (text == null) return;
    if (text.isEmpty) return Store.instance.setWaterEvery(p, null);
    final days = int.tryParse(text);
    if (days == null || days < 1 || days > 90) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter whole days, from 1 to 90.')),
        );
      }
      return;
    }
    await Store.instance.setWaterEvery(p, days);
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
        final today = todayYmd();
        final water = p.watering(g, today);
        final ready = p.readyIn(g, today);
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
              const SizedBox(height: 16),
              if (g != null) Text('Water: ${g.water}'),
              if (water != null) ...[
                const SizedBox(height: 8),
                Text('Next watering: ${waterSentence(water)}'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => Store.instance.markWatered(p),
                      icon: const Icon(Icons.water_drop),
                      label: const Text('Watered today'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editInterval(context, p, g),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(
                        'Every ${p.wateringInterval(g)} days${p.waterEveryDays == null ? '' : ' (yours)'}',
                      ),
                    ),
                  ],
                ),
              ],
              if (g != null) ...[
                const SizedBox(height: 16),
                Text('Time to sellable: ${g.timeToSell}'),
                if (ready != null) ...[
                  const SizedBox(height: 4),
                  Text(readyLabel(ready)),
                ],
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
