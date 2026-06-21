import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/catalog_entry.dart';
import '../model/activity_kind.dart';
import 'live_cinema_provider.dart';
import 'live_events_provider.dart';
import 'live_source.dart';
import 'live_streaming_provider.dart';
import 'live_ticketmaster_provider.dart';

/// How a provider's last fetch went — surfaced for the report/proof and the UX.
enum LiveFetchState {
  /// Returned one or more items.
  ok,

  /// Reachable but nothing available right now.
  empty,

  /// Skipped: not configured (e.g. TMDB without a key).
  needsKey,

  /// Unreachable / errored / timed out → degraded to fallback.
  failed,
}

/// The outcome of one provider's last run.
class LiveProviderStatus {
  const LiveProviderStatus({
    required this.id,
    required this.label,
    required this.state,
    this.count = 0,
    this.note,
  });

  final String id;
  final String label;
  final LiveFetchState state;
  final int count;
  final String? note;

  String get summary {
    switch (state) {
      case LiveFetchState.ok:
        return '$label — $count item(s) en direct';
      case LiveFetchState.empty:
        return '$label — rien de disponible maintenant';
      case LiveFetchState.needsKey:
        return '$label — clé manquante${note == null ? '' : ' ($note)'}';
      case LiveFetchState.failed:
        return '$label — source injoignable → repli statique';
    }
  }
}

/// The LIVE availability layer's safe front door (S10.1B).
///
/// Fans a [LiveQuery] out to every [LiveSourceProvider], each wrapped in a SHORT
/// timeout and a catch-all so ONE slow/broken source can never block or crash the
/// loop. Successful items are merged and CACHED for the session (one fetch per
/// coarse moment). The recommender blends these live candidates with the always-
/// present static pool; whatever a provider couldn't supply degrades to the
/// snapshot fallback upstream. The app works fully OFFLINE: with no network every
/// provider simply fails/empties and only static recommendations show.
class LiveAvailabilityService {
  LiveAvailabilityService(this.providers);

  /// The standard production set: keyless Montréal open-data events + the keyed
  /// Ticketmaster events (blended/deduped) + the TMDB streaming seam + the
  /// cinema-showtimes stub. Keyed sources stay dormant until their key exists.
  factory LiveAvailabilityService.standard({HttpGet? httpGet}) {
    return LiveAvailabilityService([
      LiveEventsProvider(httpGet: httpGet),
      LiveTicketmasterProvider(httpGet: httpGet),
      LiveStreamingProvider(httpGet: httpGet),
      const LiveCinemaProvider(),
    ]);
  }

  final List<LiveSourceProvider> providers;

  /// Per-provider outcome of the last [fetchAvailableNow] (for report/proof/UX).
  final Map<String, LiveProviderStatus> statuses = {};

  /// Outer guard on top of each provider's own internal timeout.
  Duration perProviderTimeout = const Duration(seconds: 6);

  List<CatalogEntry>? _cache;
  String? _cacheKey;

  /// The kinds that returned at least one fresh live item last fetch — the
  /// recommender uses this to know which live kinds to serve fresh vs fall back.
  Set<ActivityKind> get freshKinds => {
        for (final s in statuses.values)
          if (s.state == LiveFetchState.ok) _kindOf(s.id),
      };

  ActivityKind _kindOf(String providerId) =>
      providers.firstWhere((p) => p.id == providerId).kind;

  /// Fetch everything available now. Never throws; returns the merged set (which
  /// may be empty offline). Cached per coarse moment for the session.
  Future<List<CatalogEntry>> fetchAvailableNow(LiveQuery q) async {
    final key = _keyFor(q);
    if (_cache != null && _cacheKey == key) return _cache!;

    final results = await Future.wait(providers.map((p) => _runOne(p, q)));
    // Blend every source, deduping events that two providers both report (e.g.
    // a concert in BOTH the Montréal open-data feed AND Ticketmaster). First
    // occurrence wins — provider order in [standard] decides precedence.
    final merged = <CatalogEntry>[];
    final seen = <String>{};
    for (final list in results) {
      for (final e in list) {
        final dedupeKey = '${e.kind.name}|${_normTitle(e.name)}';
        if (seen.add(dedupeKey)) merged.add(e);
      }
    }
    _cache = merged;
    _cacheKey = key;
    return merged;
  }

  /// Normalised title for dedupe: lowercase, accent/punct-insensitive.
  static String _normTitle(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  Future<List<CatalogEntry>> _runOne(LiveSourceProvider p, LiveQuery q) async {
    if (!p.isConfigured) {
      statuses[p.id] = LiveProviderStatus(
        id: p.id,
        label: p.label,
        state: LiveFetchState.needsKey,
        note: p.needsKeyNote,
      );
      return const [];
    }
    try {
      final items =
          await p.fetchAvailableNow(q).timeout(perProviderTimeout);
      statuses[p.id] = LiveProviderStatus(
        id: p.id,
        label: p.label,
        state: items.isEmpty ? LiveFetchState.empty : LiveFetchState.ok,
        count: items.length,
      );
      return items;
    } catch (e) {
      if (kDebugMode) debugPrint('[live] ${p.id} failed → fallback: $e');
      statuses[p.id] = LiveProviderStatus(
        id: p.id,
        label: p.label,
        state: LiveFetchState.failed,
      );
      return const [];
    }
  }

  String _keyFor(LiveQuery q) {
    final day = '${q.when.year}-${q.when.month}-${q.when.day}';
    final loc = q.lat == null
        ? 'noloc'
        : '${q.lat!.toStringAsFixed(2)},${q.lng!.toStringAsFixed(2)}';
    final ctx = (q.contexts.map((c) => c.name).toList()..sort()).join('+');
    return '$day|$loc|$ctx|${q.limit}';
  }

  /// Drop the session cache (tests / a manual refresh).
  void clearCache() {
    _cache = null;
    _cacheKey = null;
  }
}
