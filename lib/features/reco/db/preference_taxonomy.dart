import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// The preference taxonomy, loaded from DATA (`assets/data/preference_taxonomy.json`)
/// rather than hardcoded (S10A) — so the vocabulary the engine, the question bank
/// and the catalog share can grow (new dimensions, motives, life-contexts,
/// kinds) without a code change.
///
/// One entry = `{ id, labelFr, … }`. Helpers expose the labels the UI needs and
/// the allowed-id sets the ingestion + repository validate against.
class PreferenceTaxonomy {
  PreferenceTaxonomy._(this._raw);

  final Map<String, dynamic> _raw;

  static const String asset = 'assets/data/preference_taxonomy.json';

  static PreferenceTaxonomy? _instance;
  static PreferenceTaxonomy get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('PreferenceTaxonomy.load() must run before first use.');
    }
    return i;
  }

  static bool get isLoaded => _instance != null;

  /// Load + parse the bundled taxonomy. Call once before first paint.
  static Future<PreferenceTaxonomy> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(asset);
    return _instance = parse(raw);
  }

  /// Parse from a JSON string (used by tests + the ingestion validator).
  static PreferenceTaxonomy parse(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    return PreferenceTaxonomy._(
        decoded is Map<String, dynamic> ? decoded : const {});
  }

  List<Map<String, dynamic>> _group(String key) {
    final v = _raw[key];
    if (v is! List) return const [];
    return v.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  List<Map<String, dynamic>> get dimensions => _group('dimensions');
  List<Map<String, dynamic>> get motivesLms => _group('motivesLms');
  List<Map<String, dynamic>> get lifeContexts => _group('lifeContexts');
  List<Map<String, dynamic>> get kinds => _group('kinds');
  List<Map<String, dynamic>> get categories => _group('categories');
  List<Map<String, dynamic>> get timeOfDay => _group('timeOfDay');
  List<Map<String, dynamic>> get seasons => _group('seasons');

  /// All allowed ids for a group (e.g. valid `category` or `kind` values).
  Set<String> idsOf(String group) =>
      _group(group).map((e) => '${e['id']}').toSet();

  /// The FR label for an id within a group, or the id itself when unknown.
  String labelFor(String group, String id) {
    for (final e in _group(group)) {
      if ('${e['id']}' == id) return e['labelFr'] as String? ?? id;
    }
    return id;
  }
}
