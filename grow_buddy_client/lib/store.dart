import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup.dart';
import 'models.dart';

/// Local-only storage (browser localStorage on web, prefs on mobile).
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  late SharedPreferences _prefs;
  List<MyPlant> plants = [];
  List<Sale> sales = [];
  double sunHours = 4; // direct afternoon sun hours at the growing spot
  String serverUrl = 'http://localhost:8787'; // Grow Buddy backend
  String appToken = ''; // optional shared secret for the backend

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    plants = _decode(_prefs.getString('plants'), MyPlant.fromJson);
    sales = _decode(_prefs.getString('sales'), Sale.fromJson);
    sunHours = _prefs.getDouble('sunHours') ?? 4;
    serverUrl = _prefs.getString('serverUrl') ?? 'http://localhost:8787';
    appToken = _prefs.getString('appToken') ?? '';
  }

  List<T> _decode<T>(String? raw, T Function(Map<String, dynamic>) f) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => f(e as Map<String, dynamic>)).toList();
  }

  Future<void> _save() async {
    await _prefs.setString('plants', jsonEncode(plants.map((p) => p.toJson()).toList()));
    await _prefs.setString('sales', jsonEncode(sales.map((s) => s.toJson()).toList()));
    await _prefs.setDouble('sunHours', sunHours);
    await _prefs.setString('serverUrl', serverUrl);
    await _prefs.setString('appToken', appToken);
    notifyListeners();
  }

  Future<void> setSunHours(double v) async {
    sunHours = v;
    await _save();
  }

  Future<void> setServer(String url, String token) async {
    serverUrl = url.trim();
    appToken = token.trim();
    await _save();
  }

  Future<void> addPlant(MyPlant p) async {
    plants.add(p);
    await _save();
  }

  Future<void> removePlant(String id) async {
    plants.removeWhere((p) => p.id == id);
    await _save();
  }

  Future<void> updatePlant() => _save(); // after mutating a MyPlant in place

  Future<void> markWatered(MyPlant p) async {
    final now = DateTime.now().toIso8601String();
    p.lastWatered = now.substring(0, 10);
    p.logs.insert(0, LogEntry(now, 'Watered'));
    await _save();
  }

  /// null goes back to the guide's interval.
  Future<void> setWaterEvery(MyPlant p, int? days) async {
    p.waterEveryDays = days;
    await _save();
  }

  Backup exportBackup() => Backup(plants: plants, sales: sales, sunHours: sunHours);

  /// Replaces all plants, sales and the sun-hours setting.
  Future<void> restore(Backup b) async {
    plants = b.plants;
    sales = b.sales;
    sunHours = b.sunHours;
    await _save();
  }

  /// [markPlantSold] flips the linked plant (if any) to 'sold' in the same save.
  Future<void> addSale(Sale s, {bool markPlantSold = false}) async {
    sales.add(s);
    if (markPlantSold && s.plantId != null) {
      for (final p in plants.where((p) => p.id == s.plantId)) {
        p.status = 'sold';
      }
    }
    await _save();
  }

  Future<void> removeSale(String id) async {
    sales.removeWhere((s) => s.id == id);
    await _save();
  }
}
