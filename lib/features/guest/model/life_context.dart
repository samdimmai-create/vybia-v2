/// Life-contexts (S9D) — durable real-world situations that make some otherwise
/// good activities INFEASIBLE, captured implicitly at the orb (situational
/// images, never free text).
///
/// Grounded in the leisure-constraints literature (Crawford, Jackson & Godbey),
/// which sorts what stops people from doing leisure into three families:
///   * intrapersonal — internal/bodily states (a pregnancy, reduced mobility);
///   * interpersonal — who you're with (kids in tow, a dog);
///   * structural    — external resources (a tight budget, no car).
///
/// Each context is a hard FEASIBILITY FILTER (drop the infeasible) AND shifts the
/// TONE of the "pourquoi" (see [toneFr]). See `life_context_rules.dart` for the
/// full context→filter table.
enum LifeContext {
  /// Interpersonal: out with kids → no bars/late-night, gentle pace.
  avecEnfants,

  /// Intrapersonal/structural: pregnant or simply not drinking → no bar/club.
  sansAlcool,

  /// Structural: watching the budget → no splurges.
  budgetSerre,

  /// Intrapersonal: reduced mobility → no high-effort, nothing far.
  mobiliteReduite,

  /// Structural: no car tonight → nothing across town.
  sansVoiture,

  /// Interpersonal: a dog in tow → no pet-unfriendly indoor venues.
  avecAnimal;

  String get labelFr {
    switch (this) {
      case LifeContext.avecEnfants:
        return 'Avec des enfants';
      case LifeContext.sansAlcool:
        return 'Sans alcool';
      case LifeContext.budgetSerre:
        return 'Budget serré';
      case LifeContext.mobiliteReduite:
        return 'Mobilité réduite';
      case LifeContext.sansVoiture:
        return 'Sans voiture';
      case LifeContext.avecAnimal:
        return 'Avec un animal';
    }
  }

  /// The constraint family this context belongs to (for the documented table).
  String get family {
    switch (this) {
      case LifeContext.avecEnfants:
      case LifeContext.avecAnimal:
        return 'interpersonnel';
      case LifeContext.sansAlcool:
      case LifeContext.mobiliteReduite:
        return 'intrapersonnel';
      case LifeContext.budgetSerre:
      case LifeContext.sansVoiture:
        return 'structurel';
    }
  }

  /// A short tone fragment folded into the "pourquoi" when this context is
  /// active, so the reason reads context-aware rather than generic (S9F uses it).
  String get toneFr {
    switch (this) {
      case LifeContext.avecEnfants:
        return 'tranquille avec les petits';
      case LifeContext.sansAlcool:
        return 'aucun verre obligatoire';
      case LifeContext.budgetSerre:
        return 'léger pour le portefeuille';
      case LifeContext.mobiliteReduite:
        return 'sans effort ni dénivelé';
      case LifeContext.sansVoiture:
        return 'à portée sans voiture';
      case LifeContext.avecAnimal:
        return 'ton chien est le bienvenu';
    }
  }

  static LifeContext? byName(String name) {
    for (final c in LifeContext.values) {
      if (c.name == name) return c;
    }
    return null;
  }
}
