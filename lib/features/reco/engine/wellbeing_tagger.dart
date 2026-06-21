import '../../guest/model/dimension.dart';
import '../model/activity.dart';
import '../model/availability.dart';
import '../model/wellbeing.dart';

/// Deterministically derives an activity's [WellbeingTags] from the attributes
/// it already carries — on-device, explainable, no LLM (S11A).
///
/// Like [LeisureMotivation], this is a READOUT of existing data (category +
/// motive affinity + taste axes + effort + availability), not four new numbers
/// hand-authored on every catalog row. So the whole 20-row seed and the 200+
/// DB rows gain the hedonic/eudaimonic axis and the happiness traits for free,
/// and can never drift out of sync with the activity they describe. A
/// [CatalogEntry] may still PERSIST an override (e.g. a future Claude pass), in
/// which case the engine prefers that.
///
/// Every formula below cites the principle it encodes (see S11 doctrine /
/// reports/s11_research_grounded_scoring.md).
class WellbeingTagger {
  const WellbeingTagger._();

  /// Derive the wellbeing tags for [a], or return its persisted override.
  static WellbeingTags of(Activity a) {
    final override = a.wellbeing;
    if (override != null) return override;

    final m = a.motives; // (hedonic, relaxation, eudaimonic)
    final social = a.tag(Dimension.social);
    final vibe = a.tag(Dimension.vibe);
    final budgetNorm = (a.budget / 3).clamp(0.0, 1.0);

    double c(double v) => v.clamp(0.0, 1.0).toDouble();

    // ---- Hedonic ↔ eudaimonic axis (Ryan & Deci; Huta & Ryan) ------------
    // Meaning/growth (eudaimonic) pushes toward 1; pleasure (hedonic) AND
    // recovery/detachment (relaxation) — both HEDONIC wellbeing — pull toward 0.
    var he = 0.5 + 0.5 * (m.eudaimonic - m.hedonic) - 0.15 * m.relaxation;
    he += _categoryEudaimoniaBias(a.category);

    // ---- Happiness-raising traits (Lyubomirsky positive-activity model) ----
    // Social support: connection with others — driven by the social axis, the
    // liveliness of the vibe, and inherently-gathering categories.
    final socialSupport =
        c(0.6 * social + 0.2 * vibe + _categorySocialBias(a.category));

    // Intrinsic appeal: enjoyed for its own sake — high when meaningful or
    // restorative and NOT a spendy means-to-an-end; some categories are
    // inherently intrinsic (nature, creative, culture, wellness).
    final intrinsicAppeal = c(0.35 * m.eudaimonic +
        0.25 * m.relaxation +
        0.2 * (1 - budgetNorm) +
        _categoryIntrinsicBias(a.category));

    // Flexibility: adaptable / low-commitment — high when effort is low and the
    // item is a drop-in static row; fixed-time live items (a film start, an
    // event) and high-effort outings are the least flexible.
    final flexibility = c(0.5 * (1 - a.effortLevel) +
        0.25 * (a.availability == Availability.live ? 0.2 : 1.0) +
        _categoryFlexibilityBias(a.category));

    return WellbeingTags(
      hedoniaEudaimonia: c(he),
      socialSupport: socialSupport,
      intrinsicAppeal: intrinsicAppeal,
      flexibility: flexibility,
    );
  }

  /// Cultural/creative leisure leans eudaimonic (learning, meaning); sensory/
  /// social leisure (café, nightlife, food) leans hedonic.
  static double _categoryEudaimoniaBias(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.culture:
      case ActivityCategory.creative:
        return 0.15;
      case ActivityCategory.nature:
      case ActivityCategory.wellness:
        return 0.07;
      case ActivityCategory.active:
        return 0.02;
      case ActivityCategory.cafe:
      case ActivityCategory.food:
        return -0.08;
      case ActivityCategory.nightlife:
        return -0.12;
    }
  }

  static double _categorySocialBias(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.nightlife:
      case ActivityCategory.food:
        return 0.18;
      case ActivityCategory.cafe:
        return 0.1;
      case ActivityCategory.active:
        return 0.05;
      case ActivityCategory.culture:
      case ActivityCategory.creative:
      case ActivityCategory.nature:
      case ActivityCategory.wellness:
        return 0.0;
    }
  }

  static double _categoryIntrinsicBias(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.nature:
      case ActivityCategory.creative:
        return 0.2;
      case ActivityCategory.culture:
      case ActivityCategory.wellness:
        return 0.15;
      case ActivityCategory.active:
        return 0.1;
      case ActivityCategory.cafe:
        return 0.05;
      case ActivityCategory.food:
      case ActivityCategory.nightlife:
        return 0.0;
    }
  }

  static double _categoryFlexibilityBias(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.cafe:
      case ActivityCategory.nature:
        return 0.18;
      case ActivityCategory.food:
        return 0.1;
      case ActivityCategory.wellness:
      case ActivityCategory.active:
        return 0.05;
      case ActivityCategory.culture:
        return -0.05;
      case ActivityCategory.creative:
      case ActivityCategory.nightlife:
        return -0.1;
    }
  }
}
