import '../model/activity.dart';
import 'catalog_entry.dart';

/// The enrichment seam (S10E): read a record, propose a patch that fills the
/// gaps, then [ActivityRepository.enrichActivity] writes it back + persists.
///
/// This is the EXACT shape a future Claude-backed provider takes — same
/// signature, same patch contract — so swapping the deterministic stub below for
/// a model call changes nothing else in the app. No network here by design: the
/// engine runs fully offline; the only network is the build-time ingestion.
abstract class EnrichmentService {
  /// Propose the fields to fill for [e] as a JSON patch (the same keys as
  /// [CatalogEntry.toJson]). An empty map means "nothing to add" — the record is
  /// already complete enough. Must be pure + side-effect free.
  Future<Map<String, dynamic>> proposeEnrichment(CatalogEntry e);
}

/// Deterministic, on-device enrichment provider — fills ONE missing field at a
/// time from local rules, so the read → enrich → save loop is real, testable,
/// and reproducible without any model. Order is fixed (description, then
/// neighbourhood, then time-of-day, then a confidence nudge) so the same record
/// always produces the same next patch.
class LocalRuleEnrichmentProvider implements EnrichmentService {
  const LocalRuleEnrichmentProvider();

  @override
  Future<Map<String, dynamic>> proposeEnrichment(CatalogEntry e) async {
    // 1. A missing/short French description → a fitting templated sentence.
    if (e.descFr.trim().length < 12) {
      return {'descFr': _describe(e)};
    }
    // 2. A geo record with no neighbourhood → the home city.
    if (e.hasLocation && (e.neighbourhood == null || e.neighbourhood!.isEmpty)) {
      return {'neighbourhood': 'Montréal'};
    }
    // 3. No time-of-day fit → infer from the category.
    if (e.timeOfDay.isEmpty) {
      return {'timeOfDay': _timeOfDayFor(e.category)};
    }
    // 4. Otherwise a small confidence nudge (capped) — never invents facts.
    if (e.confidence < 0.85) {
      final next = (e.confidence + 0.15).clamp(0.0, 0.85);
      if (next > e.confidence) return {'confidence': next};
    }
    return const {}; // complete enough
  }

  String _describe(CatalogEntry e) {
    final what = e.category.labelFr.toLowerCase();
    final where = (e.neighbourhood != null && e.neighbourhood!.isNotEmpty)
        ? ' à ${e.neighbourhood}'
        : '';
    return '${e.name} — une option $what$where pour ce moment.';
  }

  List<String> _timeOfDayFor(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.nightlife:
        return const ['soir', 'nuit'];
      case ActivityCategory.cafe:
        return const ['matin', 'apresMidi'];
      case ActivityCategory.food:
        return const ['apresMidi', 'soir'];
      case ActivityCategory.nature:
      case ActivityCategory.active:
        return const ['matin', 'apresMidi'];
      case ActivityCategory.culture:
      case ActivityCategory.creative:
        return const ['apresMidi', 'soir'];
      case ActivityCategory.wellness:
        return const ['matin', 'apresMidi', 'soir'];
    }
  }
}
