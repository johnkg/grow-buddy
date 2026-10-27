import 'package:flutter/material.dart';
import 'backup.dart';
import 'screens/guide_screen.dart';
import 'screens/my_plants_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/sales_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.load();
  runApp(const GrowBuddyApp());
}

class GrowBuddyApp extends StatelessWidget {
  const GrowBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grow Buddy',
      debugShowCheckedModeBanner: false,
      theme: growBuddyTheme(Brightness.light),
      darkTheme: growBuddyTheme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Plant guide', 'My plants', 'Debug a plant', 'Sales'];
  static const _screens = <Widget>[
    GuideScreen(),
    MyPlantsScreen(),
    DebugScreen(),
    SalesScreen(),
  ];

  Future<void> _openSettings() =>
      showDialog<void>(context: context, builder: (_) => const _SettingsDialog());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Guide'),
          NavigationDestination(icon: Icon(Icons.local_florist_outlined), label: 'My plants'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Debug'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Sales'),
        ],
      ),
    );
  }
}

/// Owns its controllers so they outlive the dialog's exit animation.
class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  final _urlController = TextEditingController(text: Store.instance.serverUrl);
  final _tokenController = TextEditingController(text: Store.instance.appToken);
  String? _backupMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    try {
      final b = Store.instance.exportBackup();
      final saved = await BackupIo.current.save(b.fileName, b.encode());
      _say(saved ? 'Backup saved as ${b.fileName}.' : 'Export cancelled.');
    } catch (_) {
      _say('Could not save the backup file.');
    }
  }

  Future<void> _import() async {
    try {
      final text = await BackupIo.current.pickText();
      if (text == null) return;
      final b = Backup.decode(text);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace your data?'),
          content: Text(
            'This backup has ${b.plants.length} plants and ${b.sales.length} sales. '
            'The ${Store.instance.plants.length} plants and ${Store.instance.sales.length} sales '
            'on this device will be replaced.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace')),
          ],
        ),
      );
      if (ok != true) return;
      await Store.instance.restore(b);
      _say('Restored ${b.plants.length} plants and ${b.sales.length} sales.');
    } on FormatException catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Could not read that file.');
    }
  }

  void _say(String msg) {
    if (mounted) setState(() => _backupMessage = msg);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Photo diagnosis runs through your Grow Buddy server, which holds the Claude API key. '
              'Use http://localhost:8787 when testing on the same computer.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'App token (only if server sets APP_TOKEN)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('Backup', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text(
              'Your plants and sales are stored only on this device (in the browser on the web). '
              'Clearing browser data or switching phones loses them, so export a backup now and then.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.download),
                  label: const Text('Export backup'),
                ),
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.upload),
                  label: const Text('Import backup'),
                ),
              ],
            ),
            if (_backupMessage != null) ...[
              const SizedBox(height: 8),
              Text(_backupMessage!, key: const Key('backupMessage')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await Store.instance.setServer(_urlController.text, _tokenController.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
