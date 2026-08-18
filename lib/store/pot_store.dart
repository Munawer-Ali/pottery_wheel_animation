import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../model/pot.dart';

class PotStore extends ChangeNotifier {
  PotStore._();

  static final PotStore instance = PotStore._();

  final List<Pot> _pots = <Pot>[];
  File? _file;

  List<Pot> get pots => List<Pot>.unmodifiable(_pots);

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pots.json');
      _file = file;
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      _pots
        ..clear()
        ..addAll(raw
            .map((e) => Pot.tryFromJson(e as Map<String, dynamic>))
            .whereType<Pot>());
      notifyListeners();
    } catch (e) {
      debugPrint('PotStore: keeping pieces in memory only ($e)');
    }
  }

  Future<void> save(Pot pot) async {
    final copy = pot.duplicate(id: pot.id);
    final at = _pots.indexWhere((p) => p.id == pot.id);
    if (at >= 0) {
      _pots[at] = copy;
    } else {
      _pots.insert(0, copy);
    }
    notifyListeners();
    await _persist();
  }

  bool contains(String id) => _pots.any((p) => p.id == id);

  Future<void> delete(String id) async {
    _pots.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(
        jsonEncode(_pots.map((p) => p.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('PotStore: could not write pots.json ($e)');
    }
  }
}
