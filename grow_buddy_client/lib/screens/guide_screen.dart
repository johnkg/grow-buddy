import 'package:flutter/material.dart';
import '../data/plant_guides.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/sun_band.dart';
import '../widgets/text_prompt_dialog.dart';

/// Verdict colours as (background, foreground). Every verdict also has a text label.
(Color, Color) verdictColors(BuildContext context, Verdict v) {
  final s = Theme.of(context).colorScheme;
  switch (v) {
    case Verdict.good:
      return (s.primaryContainer, s.onPrimaryContainer);
    case Verdict.maybe:
      return (sunAmber, onSunAmber);
    case Verdict.poor:
      return (s.errorContainer, s.onErrorContainer);
  }
}

String verdictLabel(Verdict v) {
  switch (v) {
    case Verdict.good:
      return 'Good fit';
    case Verdict.maybe:
      return 'Maybe';
    case Verdict.poor:
      return 'Poor fit';
  }
}

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final hrs = Store.instance.sunHours;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct afternoon sun at my spot: ${hrs.toStringAsFixed(1)} hrs/day',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      SunBand(sunHours: hrs),
                      Slider(
                        value: hrs,
                        min: 0,
                        max: 8,
                        divisions: 16,
                        label: '${hrs.toStringAsFixed(1)} hrs',
                        onChanged: (v) => Store.instance.setSunHours(v),
                      ),
                      Text(
                        'Count hours when sun actually hits the plant directly, not just bright shade.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: plantGuides.length,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemBuilder: (context, i) {
                  final g = plantGuides[i];
                  final fit = checkFit(g, hrs);
                  final (bg, fg) = verdictColors(context, fit.verdict);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: _EmojiTile(g.emoji),
                        title: Text(g.name, style: Theme.of(context).textTheme.titleSmall),
                        subtitle: Text('${g.difficulty} · ${g.timeToSell}'),
                        trailing: Chip(
                          label: Text(verdictLabel(fit.verdict)),
                          backgroundColor: bg,
                          labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w700),
                          side: BorderSide.none,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => PlantDetailScreen(guide: g)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmojiTile extends StatelessWidget {
  final String emoji;
  const _EmojiTile(this.emoji);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 26)),
    );
  }
}

class PlantDetailScreen extends StatelessWidget {
  final PlantGuide guide;
  const PlantDetailScreen({super.key, required this.guide});

  Future<void> _startGrowing(BuildContext context) async {
    final nickname = await showTextPrompt(
      context,
      title: 'Start growing',
      confirmLabel: 'Add',
      initialText: guide.name.split(' ').first,
      labelText: 'Nickname for this plant/batch',
    );
    if (nickname == null || nickname.isEmpty) return;
    await Store.instance.addPlant(MyPlant(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      guideId: guide.id,
      nickname: nickname,
      plantedOn: DateTime.now().toIso8601String(),
    ));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to My plants')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fit = checkFit(guide, Store.instance.sunHours);
    final (bg, fg) = verdictColors(context, fit.verdict);
    final hrs = Store.instance.sunHours;
    return Scaffold(
      appBar: AppBar(title: Text(guide.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startGrowing(context),
        icon: const Icon(Icons.add),
        label: const Text('Start growing'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      verdictLabel(fit.verdict),
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'For afternoon-only sun: ${fit.headline}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SunBand(sunHours: hrs, needMin: guide.minAfternoonHrs, needMax: guide.maxAfternoonHrs),
                  const SizedBox(height: 12),
                  for (final t in fit.tips) Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $t'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section(context, 'Water', guide.water),
          _section(context, 'Soil', guide.soil),
          _section(context, 'Time to sellable', guide.timeToSell),
          _section(context, 'Selling note', guide.sellNote),
          const SizedBox(height: 8),
          Text('How to start', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (var i = 0; i < guide.steps.length; i++)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              title: Text(guide.steps[i]),
            ),
          const SizedBox(height: 8),
          const Text(
            'General guidance only. Your own results at your own spot are the best teacher.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          Text(body),
        ],
      ),
    );
  }
}
