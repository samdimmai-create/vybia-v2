import 'dart:async';

import 'package:http/http.dart' as http;

import '../../guest/model/life_context.dart';
import '../db/catalog_entry.dart';
import '../model/activity_kind.dart';

/// A minimal HTTP getter the live providers depend on, injectable so tests run
/// fully offline with a fake. Returns the response body, or null on any failure
/// (non-200, timeout, network/CORS error) — providers never see an exception.
typedef HttpGet = Future<String?> Function(Uri uri, {Duration timeout});

/// The real getter (S10.1B). Used in production; replaced by a fake in tests.
/// On web this rides the browser fetch (CORS-gated); on VM it is a normal call.
Future<String?> httpGetDefault(
  Uri uri, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    final r = await http.get(uri).timeout(timeout);
    if (r.statusCode == 200) return r.body;
  } catch (_) {/* swallow — caller degrades to fallback */}
  return null;
}

/// The moment a live fetch is for: where, when, under which life-contexts, and
/// how many items are wanted. Mirrors what the engine already knows so live
/// candidates are projected for the SAME scoring.
class LiveQuery {
  const LiveQuery({
    this.lat,
    this.lng,
    required this.when,
    this.contexts = const {},
    this.limit = 6,
  });

  final double? lat;
  final double? lng;
  final DateTime when;
  final Set<LifeContext> contexts;
  final int limit;
}

/// One source of TIME-SENSITIVE recommendations (S10.1B).
///
/// A provider knows how to answer "what of MY [kind] is ACTUALLY available right
/// now?" and returns the answer already projected into our [CatalogEntry] schema
/// (availability == live), so the very same scorer + mood/ambiance match applies
/// to a live event or film as to a static café. Implementations must be SAFE:
/// short timeout, never throw (return [] instead) — the service double-guards.
abstract class LiveSourceProvider {
  /// Stable id for caching / status reporting (e.g. `montreal_events`).
  String get id;

  /// Human-readable French label for the report/UX.
  String get label;

  /// The kind this provider serves.
  ActivityKind get kind;

  /// Whether this provider can actually fetch right now. Keyless providers are
  /// always configured; keyed ones (TMDB) are configured only once a key exists.
  bool get isConfigured;

  /// For the report: what a key/credential would unlock, or null when keyless.
  String? get needsKeyNote => null;

  /// Items actually available now, projected to our schema. Returns [] on any
  /// failure or when nothing is available — NEVER throws.
  Future<List<CatalogEntry>> fetchAvailableNow(LiveQuery q);
}
