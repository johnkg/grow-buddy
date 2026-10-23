import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/plant_guides.dart';
import '../data/symptoms.dart';
import '../services/ai_diagnosis.dart';
import '../store.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String? _plantChoice; // 'my:<id>' or 'guide:<id>' or null
  final Set<String> _selected = {};
  final _notes = TextEditingController();
  Uint8List? _photo;
  String _photoMime = 'image/jpeg';
  List<RankedCause>? _ranked;
  String? _aiResult;
  String? _aiError;
  bool _loading = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String _plantName() {
    final c = _plantChoice;
    if (c == null) return 'Unknown plant';
    if (c.startsWith('my:')) {
      final id = c.substring(3);
      for (final p in Store.instance.plants) {
        if (p.id == id) {
          final g = guideById(p.guideId);
          return g?.name ?? p.nickname;
        }
      }
    } else if (c.startsWith('guide:')) {
      return guideById(c.substring(6))?.name ?? 'Unknown plant';
    }
    return 'Unknown plant';
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final name = x.name.toLowerCase();
    setState(() {
      _photo = bytes;
      _photoMime = name.endsWith('.png') ? 'image/png' : 'image/jpeg';
    });
  }

  void _runRules() {
    setState(() {
      _ranked = rankCauses(_selected);
    });
  }

  Future<void> _runAi() async {
    final url = Store.instance.serverUrl;
    if (url.isEmpty) {
      setState(() => _aiError = 'Set the server URL in Settings (gear icon) first.');
      return;
    }
    setState(() {
      _loading = true;
      _aiError = null;
      _aiResult = null;
    });
    try {
      final labels = symptoms.where((s) => _selected.contains(s.id)).map((s) => s.label).toList();
      final r = await AiDiagnosis.diagnose(
        serverUrl: url,
        appToken: Store.instance.appToken,
        plantName: _plantName(),
        afternoonSunHrs: Store.instance.sunHours,
        symptoms: labels,
        notes: _notes.text,
        photoBytes: _photo,
        photoMime: _photoMime,
      );
      setState(() => _aiResult = r);
    } catch (e) {
      setState(() => _aiError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myPlants = Store.instance.plants;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Which plant?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _plantChoice,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('Pick one (optional)'),
          items: [
            for (final p in myPlants)
              DropdownMenuItem(value: 'my:${p.id}', child: Text('Mine: ${p.nickname}')),
            for (final g in plantGuides)
              DropdownMenuItem(value: 'guide:${g.id}', child: Text(g.name)),
          ],
          onChanged: (v) => setState(() => _plantChoice = v),
        ),
        const SizedBox(height: 16),
        Text('What do you see?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in symptoms)
              FilterChip(
                label: Text(s.label),
                selected: _selected.contains(s.id),
                onSelected: (on) => setState(() {
                  if (on) {
                    _selected.add(s.id);
                  } else {
                    _selected.remove(s.id);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Extra notes (how often you water, recent changes, pot type...)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: const Text('Photo'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Camera'),
            ),
            if (_photo != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: () => setState(() => _photo = null), child: const Text('Remove')),
            ],
          ],
        ),
        if (_photo != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_photo!, height: 180, fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: _selected.isEmpty ? null : _runRules,
                child: const Text('Quick check'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _loading ? null : _runAi,
                child: Text(_loading ? 'Thinking...' : 'Ask AI'),
              ),
            ),
          ],
        ),
        if (_aiError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_aiError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_aiResult != null)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(_aiResult!),
            ),
          ),
        if (_ranked != null) ...[
          const SizedBox(height: 16),
          Text('Likely causes', style: Theme.of(context).textTheme.titleMedium),
          if (_ranked!.isEmpty) const Text('Nothing matched.'),
          for (final r in _ranked!.take(5))
            Card(
              child: ExpansionTile(
                title: Text(r.cause.title),
                subtitle: Text(r.cause.why),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('What to do: ${r.cause.fix}')],
              ),
            ),
        ],
      ],
    );
  }
}
