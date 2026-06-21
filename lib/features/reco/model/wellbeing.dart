/// Research-grounded wellbeing tags carried by every activity (S11A).
///
/// These four numbers encode the leisure-wellbeing literature so the
/// deterministic scorer can reason about *what an activity does for a person*,
/// not just whether its taste axes line up:
///
///  * [hedoniaEudaimonia] — where the activity sits on the **hedonic ↔
///    eudaimonic** wellbeing axis (Ryan & Deci; Huta & Ryan). `0.0` = purely
///    HEDONIC (pleasure, fun, detachment, escape — "I just want to unwind");
///    `1.0` = purely EUDAIMONIC (meaning, growth, learning, self-reflection,
///    relatedness — "I want to become / discover"). Most activities sit in
///    between. The scorer matches this to the guest's *current* motive/mood:
///    tired/escape → hedonic end; curious/growth → eudaimonic end.
///
///  The remaining three are **happiness-raising activity traits** (Lyubomirsky;
///  positive-activity model): the qualities that make leisure actually lift
///  wellbeing, each `0..1`:
///
///  * [socialSupport]   — how much the activity connects you with others
///    (socially supported activities raise happiness more).
///  * [intrinsicAppeal] — how self-rewarding / intrinsically motivating it is
///    (done for its own sake, not as a means to an end).
///  * [flexibility]     — how adaptable & low-commitment it is (easy to fit to
///    your day; flexible activities sustain wellbeing better than rigid ones).
///
/// All four are pure data — derived deterministically by `WellbeingTagger`
/// (engine/wellbeing_tagger.dart) from an activity's category + motive + taste
/// axes, or overridden by a persisted value on a [CatalogEntry] (S10 schema).
class WellbeingTags {
  const WellbeingTags({
    required this.hedoniaEudaimonia,
    required this.socialSupport,
    required this.intrinsicAppeal,
    required this.flexibility,
  });

  /// 0 = hedonic (pleasure/escape) … 1 = eudaimonic (meaning/growth).
  final double hedoniaEudaimonia;

  /// 0..1 — connects you with others (happiness trait).
  final double socialSupport;

  /// 0..1 — enjoyed for its own sake (happiness trait).
  final double intrinsicAppeal;

  /// 0..1 — adaptable, low-commitment, easy to fit in (happiness trait).
  final double flexibility;

  /// The mean of the three happiness-raising traits — the activity's overall
  /// "happiness-trait fit", before matching it to a particular guest.
  double get happinessTrait =>
      (socialSupport + intrinsicAppeal + flexibility) / 3;

  Map<String, dynamic> toJson() => {
        'hedoniaEudaimonia': hedoniaEudaimonia,
        'socialSupport': socialSupport,
        'intrinsicAppeal': intrinsicAppeal,
        'flexibility': flexibility,
      };

  /// Parse a persisted tag set; null when the essential axis is missing so a
  /// record simply falls back to deterministic derivation.
  static WellbeingTags? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final he = (raw['hedoniaEudaimonia'] as num?)?.toDouble();
    if (he == null) return null;
    double c(String k, double d) => (raw[k] as num?)?.toDouble() ?? d;
    return WellbeingTags(
      hedoniaEudaimonia: he.clamp(0.0, 1.0).toDouble(),
      socialSupport: c('socialSupport', 0.5).clamp(0.0, 1.0).toDouble(),
      intrinsicAppeal: c('intrinsicAppeal', 0.5).clamp(0.0, 1.0).toDouble(),
      flexibility: c('flexibility', 0.5).clamp(0.0, 1.0).toDouble(),
    );
  }
}
