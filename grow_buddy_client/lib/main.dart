import 'package:flutter/material.dart';
import 'screens/guide_screen.dart';
import 'screens/my_plants_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/sales_screen.dart';
import 'store.dart';

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
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
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
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Guide'),
          NavigationDestination(icon: Icon(Icons.local_florist), label: 'My plants'),
          NavigationDestination(icon: Icon(Icons.healing), label: 'Debug'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Sales'),
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

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
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
