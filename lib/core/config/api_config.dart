/// Central, secrets-safe configuration for the keyed data providers (S12A).
///
/// SECURITY CONTRACT: every API key is read ONLY from a build/run-time
/// `--dart-define` via [String.fromEnvironment] — it is NEVER hardcoded, NEVER
/// printed, NEVER committed. A key that is absent yields an empty string, and
/// the provider that depends on it must DEGRADE GRACEFULLY (empty result + a
/// clear "needs key" status, no crash). Nothing here ever surfaces a key value.
///
/// Pass keys at run/build time, e.g.:
/// ```
/// flutter run -d chrome \
///   --dart-define=TMDB_KEY=… \
///   --dart-define=TICKETMASTER_KEY=…
/// ```
/// (Geoapify/Foursquare are used by the BUILD-TIME enrichment scripts — see
/// `tool/enrich_places_*.mjs` — so their keys are read from the shell env there,
/// not at app runtime; they are still surfaced here for a complete status view.)
class ApiConfig {
  const ApiConfig._();

  // ---- Raw keys (empty string when the define is absent) ----
  static const String geoapifyKey = String.fromEnvironment('GEOAPIFY_KEY');
  static const String foursquareKey = String.fromEnvironment('FOURSQUARE_KEY');
  static const String tmdbKey = String.fromEnvironment('TMDB_KEY');
  static const String ticketmasterKey =
      String.fromEnvironment('TICKETMASTER_KEY');

  // ---- Presence flags (never expose the key itself) ----
  static bool get hasGeoapify => geoapifyKey.isNotEmpty;
  static bool get hasFoursquare => foursquareKey.isNotEmpty;
  static bool get hasTmdb => tmdbKey.isNotEmpty;
  static bool get hasTicketmaster => ticketmasterKey.isNotEmpty;

  /// Per-source status, for the report/proof and any dev/status surface.
  static List<KeyedSourceStatus> get statuses => [
        KeyedSourceStatus(
          source: KeyedSource.geoapify,
          present: hasGeoapify,
        ),
        KeyedSourceStatus(
          source: KeyedSource.foursquare,
          present: hasFoursquare,
        ),
        KeyedSourceStatus(source: KeyedSource.tmdb, present: hasTmdb),
        KeyedSourceStatus(
          source: KeyedSource.ticketmaster,
          present: hasTicketmaster,
        ),
      ];
}

/// A keyed data source Vybia can wire, and where its key is consumed.
enum KeyedSource {
  geoapify(
    'Geoapify Places',
    KeyStage.build,
    'GEOAPIFY_KEY',
    'Horaires, note/popularité, catégorie fine, meilleures coordonnées pour nos '
        'lieux statiques (enrichi au build, reste hors-ligne au runtime).',
  ),
  foursquare(
    'Foursquare Places',
    KeyStage.build,
    'FOURSQUARE_KEY',
    'Lieux réels supplémentaires + attributs riches (enrichi au build, reste '
        'hors-ligne au runtime).',
  ),
  tmdb(
    'TMDB — films',
    KeyStage.live,
    'TMDB_KEY',
    'Films à l’affiche + plateformes de streaming pour la région, affiches '
        'réelles. Sans clé → repli sur l’instantané, jamais de crash.',
  ),
  ticketmaster(
    'Ticketmaster — événements',
    KeyStage.live,
    'TICKETMASTER_KEY',
    'Concerts/sports/arts/théâtre avec dates réelles, fusionnés avec les '
        'données ouvertes de Montréal. Sans clé → uniquement l’open-data.',
  );

  const KeyedSource(this.label, this.stage, this.envName, this.unlocks);

  final String label;
  final KeyStage stage;

  /// The `--dart-define` / env variable name (never the value).
  final String envName;
  final String unlocks;
}

/// When a source's key is consumed: at BUILD time (offline enrichment scripts)
/// or at LIVE runtime (the in-app live availability layer).
enum KeyStage { build, live }

/// A source's key presence + what it unlocks — safe to print (no key value).
class KeyedSourceStatus {
  const KeyedSourceStatus({required this.source, required this.present});

  final KeyedSource source;
  final bool present;

  String get summary {
    final state = present ? 'clé présente' : 'clé absente → repli gracieux';
    return '${source.label} [${source.stage.name}] — $state';
  }
}
