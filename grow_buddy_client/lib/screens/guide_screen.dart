import 'package:flutter/material.dart';
import '../data/plant_guides.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/text_prompt_dialog.dart';

Color verdictColor(Verdict v) {
  switch (v) {
    case Verdict.good:
      return Colors.green;
    case Verdict.maybe:
      return Colors.orange;
    case Verdict.poor:
      return Colors.red;
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
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct afternoon sun at my spot: ${hrs.toStringAsFixed(1)} hrs/day',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Slider(
                      value: hrs,
                      min: 0,
                      max: 8,
                      divisions: 16,
                      label: '${hrs.toStringAsFixed(1)} hrs',
                      onChanged: (v) => Store.instance.setSunHours(v),
                    ),
                    const Text(
                      'Count hours when sun actually hits the plant directly, not just bright shade.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: plantGuides.length,
                itemBuilder: (context, i) {
                  final g = plantGuides[i];
                  final fit = checkFit(g, hrs);
                  return ListTile(
                    leading: Text(g.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(g.name),
                    subtitle: Text('${g.difficulty} · ${g.timeToSell}'),
                    trailing: Chip(
                      label: Text(verdictLabel(fit.verdict)),
                      backgroundColor: verdictColor(fit.verdict).withValues(alpha: 0.2),
                      side: BorderSide(color: verdictColor(fit.verdict)),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => PlantDetailScreen(guide: g)),
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
    final color = verdictColor(fit.verdict);
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
            color: color.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${verdictLabel(fit.verdict)} for afternoon-only sun: ${fit.headline}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
                  ),
                  const SizedBox(height: 8),
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
