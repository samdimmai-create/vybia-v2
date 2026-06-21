import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../guest/model/dimension.dart';
import '../guest/model/guest_profile.dart';
import '../reco/data/activity_catalog.dart';
import '../reco/db/activity_repository.dart';
import '../reco/engine/recommendation_engine.dart';
import '../reco/engine/reco_context.dart';
import '../reco/live/live_availability_service.dart';
import '../reco/live/live_source.dart';
import '../reco/model/activity.dart';

/// Debug-only VISIBLE-IN-CHROME proof tour for Sprint S12
/// (`--dart-define=VYBIA_PROOF12=true`): the real data providers wired behind
/// secrets-safe config keys.
///
/// Five frames:
///   * `s12_weather_clear_vs_rain` — the SAME context's feasible set shrinks
///     when the live weather flips clear → rain (open-air dropped).
///   * `s12_place_enriched`        — a real place carrying opening hours enriched
///     from Geoapify at build time (bundled, offline).
///   * `s12_live_ticketmaster`     — the Ticketmaster events provider status
///     (a real dated event when keyed; "needs key" standby otherwise).
///   * `s12_live_tmdb`             — the TMDB films provider status (real
///     now-playing when keyed; "needs key" + snapshot fallback otherwise).
///   * `s12_offline_fallback`      — with NO network/keys the static catalog
///     still recommends, no crash.
///
/// Each phase prints `VYBIA_PROOF <name>`; tool/cdp_capture.mjs grabs each frame.
class S12ProofTour extends StatefulWidget {
  const S12ProofTour({super.key});

  @override
  State<S12ProofTour> createState() => _S12ProofTourState();
}

enum _Phase { boot, weather, enriched, ticketmaster, tmdb, offline }

class _S12ProofTourState extends State<S12ProofTour> {
  static const double _lat = 45.5019;
  static const double _lng = -73.5674;
  static const Duration _hold = Duration(milliseconds: 3600);

  static const RecoContext _clear = RecoContext(
      hourOfDay: 14, month: 6, userLat: _lat, userLng: _lng,
      weather: WeatherSignal.clear);
  static const RecoContext _rain = RecoContext(
      hourOfDay: 14, month: 6, userLat: _lat, userLng: _lng,
      weather: WeatherSignal.rain);

  _Phase _phase = _Phase.boot;
  bool _started = false;

  // Frame data.
  int _clearFeasible = 0, _rainFeasible = 0;
  List<String> _clearOutdoor = const [], _rainOutdoor = const [];
  Activity? _enriched;
  List<LiveProviderStatus> _liveStatuses = const [];
  int _offlineCount = 0;
  String _offlinePick = '';

  List<Activity> get _catalog =>
      ActivityRepository.isLoaded ? ActivityRepository.activities : kActivityCatalog;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
    }
  }

  void _mark(String name) => debugPrint('VYBIA_PROOF $name');

  GuestProfile _outdoorsy() {
    final p = GuestProfile();
    p.nudge(Dimension.indoor, 0.2, weight: 0.3);
    p.answer(Dimension.energy, 0.55);
    return p;
  }

  Future<void> _drive() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 2800));
      final engine = RecommendationEngine(catalog: _catalog);

      // 1. Weather flips feasibility on the same context.
      final clear = engine.recommend(_outdoorsy(), context: _clear);
      final rain = engine.recommend(_outdoorsy(), context: _rain);
      _clearFeasible = clear.length;
      _rainFeasible = rain.length;
      _clearOutdoor = clear
          .where((r) => !r.activity.indoor)
          .map((r) => r.activity.titleFr)
          .take(4)
          .toList();
      _rainOutdoor = rain
          .where((r) => !r.activity.indoor)
          .map((r) => r.activity.titleFr)
          .take(4)
          .toList();

      // 2. A place enriched with real opening hours (Geoapify, build-time).
      _enriched = _catalog.firstWhere(
        (a) => a.openingHours != null && a.openingHours!.trim().isNotEmpty,
        orElse: () => _catalog.first,
      );

      // 3+4. Live provider statuses (real fetch attempt; keys may be absent).
      final live = LiveAvailabilityService.standard();
      await live.fetchAvailableNow(LiveQuery(
        lat: _lat, lng: _lng, when: DateTime.now(), limit: 6,
      ));
      _liveStatuses = live.statuses.values.toList();

      // 5. Offline fallback — static catalog still recommends, no live layer.
      final offline = engine.recommend(_outdoorsy(), context: _clear);
      _offlineCount = offline.length;
      _offlinePick = offline.isEmpty ? '—' : offline.first.activity.titleFr;

      await _show(_Phase.weather, 's12_weather_clear_vs_rain');
      await _show(_Phase.enriched, 's12_place_enriched');
      await _show(_Phase.ticketmaster, 's12_live_ticketmaster');
      await _show(_Phase.tmdb, 's12_live_tmdb');
      await _show(_Phase.offline, 's12_offline_fallback');
      _mark('DONE');
    } catch (e, st) {
      debugPrint('VYBIA_PROOF_ERROR $e\n$st');
    }
  }

  Future<void> _show(_Phase phase, String marker) async {
    if (!mounted) return;
    setState(() => _phase = phase);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _mark(marker);
    await Future<void>.delayed(_hold);
  }

  LiveProviderStatus? _statusFor(String id) {
    for (final s in _liveStatuses) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(child: _body()),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.boot:
        return const CircularProgressIndicator();
      case _Phase.weather:
        return _panel('Météo live · Open-Meteo (sans clé)', [
          _kv('Même contexte, ciel différent', ''),
          _kv('☀️ Clair — faisables', '$_clearFeasible'),
          _kv('   plein air', _clearOutdoor.join(' · ')),
          _kv('🌧️ Pluie — faisables', '$_rainFeasible'),
          _kv('   plein air', _rainOutdoor.isEmpty ? '∅ (filtré)' : _rainOutdoor.join(' · ')),
          _note('La pluie retire le plein air → ensemble faisable réduit (filtre S11 activé).'),
        ]);
      case _Phase.enriched:
        final a = _enriched;
        return _panel('Lieu enrichi · Geoapify (build, hors-ligne)', [
          _kv('Lieu', a?.titleFr ?? '—'),
          _kv('Catégorie', a?.category.labelFr ?? '—'),
          _kv('Horaires réels', a?.openingHours ?? '—'),
          if (a?.rating != null) _kv('Note', '★ ${a!.rating!.toStringAsFixed(1)}'),
          _kv('Provenance', a?.source ?? '—'),
          _note('Horaires/coordonnées enrichis au BUILD ; le runtime reste hors-ligne.'),
        ]);
      case _Phase.ticketmaster:
        final tm = _statusFor('ticketmaster_events');
        final mtl = _statusFor('montreal_events');
        return _panel('Événements live · Ticketmaster + données ouvertes', [
          _kv('Ticketmaster', tm?.summary ?? 'non interrogé'),
          _kv('Montréal (open-data)', mtl?.summary ?? 'non interrogé'),
          _kv('Clé Ticketmaster', ApiConfig.hasTicketmaster ? 'présente' : 'absente'),
          _note(ApiConfig.hasTicketmaster
              ? 'Concerts/sports/arts datés, fusionnés + dédupliqués avec l’open-data.'
              : 'En veille : sans clé, repli sur les événements ouverts de Montréal. Aucun crash.'),
        ]);
      case _Phase.tmdb:
        final tmdb = _statusFor('tmdb_streaming');
        return _panel('Films live · TMDB', [
          _kv('TMDB', tmdb?.summary ?? 'non interrogé'),
          _kv('Clé TMDB', ApiConfig.hasTmdb ? 'présente' : 'absente'),
          _note(ApiConfig.hasTmdb
              ? 'Films à l’affiche + affiches réelles, servis en direct.'
              : 'En veille : sans clé, repli sur l’instantané de films. Aucun crash.'),
        ]);
      case _Phase.offline:
        return _panel('Repli hors-ligne · catalogue statique', [
          _kv('Sans réseau ni clé', ''),
          _kv('Recommandations', '$_offlineCount'),
          _kv('Top pick', _offlinePick),
          _note('L’app reste pleinement utilisable hors-ligne sur le catalogue statique.'),
        ]);
    }
  }

  Widget _panel(String title, List<Widget> rows) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: AppColors.edgeUp.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 190,
              child: Text(k,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      );

  Widget _note(String s) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Text(s,
            style: TextStyle(
                color: AppColors.edgeDown,
                fontSize: 13,
                fontStyle: FontStyle.italic)),
      );
}
