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
        final today = todayYmd();
        final thirsty = plants.where((p) {
          final st = p.watering(guideById(p.guideId), today)?.state;
          return st == WaterState.overdue || st == WaterState.today;
        }).length;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: plants.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return _WaterBanner(count: thirsty);
            final p = plants[i - 1];
            final g = guideById(p.guideId);
            final days = DateTime.now().difference(DateTime.parse(p.plantedOn)).inDays;
            final water = p.watering(g, today);
            final ready = p.readyIn(g, today);
            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  leading: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(g?.emoji ?? '🌱', style: const TextStyle(fontSize: 26)),
                  ),
                  title: Text(p.nickname, style: Theme.of(context).textTheme.titleSmall),
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
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Summary of what needs water now. Hidden when nothing does.
class _WaterBanner extends StatelessWidget {
  final int count;
  const _WaterBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox(height: 4);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.onPrimary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.water_drop_outlined, color: scheme.onPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                count == 1 ? '1 plant needs water' : '$count plants need water',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
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
