import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The proxy URL, baked at cloud-build time via
/// `--dart-define=PROXY_URL=https://…workers.dev`. It is NOT a secret (it does
/// not expose the Anthropic key — that lives only inside the worker), so it is
/// safe to ship in the public bundle. Empty when unset → the app stays fully
/// deterministic (templated copy only).
const String kProxyUrl = String.fromEnvironment('PROXY_URL');

/// True when a proxy is configured — the only signal the app uses to decide
/// whether to attempt LLM generation at all.
bool get isLlmConfigured => kProxyUrl.isNotEmpty;

/// A thin, fail-safe client for the Vybia Claude proxy (S15B).
///
/// It POSTs `{system, context, task}` to the proxy and returns the generated
/// text — or `null` on ANY problem (no config, timeout, network, non-2xx, bad
/// JSON, empty text). The caller treats `null` as "use the deterministic
/// fallback", so a flaky or absent proxy never breaks the app and never blocks
/// the snappy ≤3-min feel.
///
/// A small in-memory cache keyed on the exact request keeps the loop snappy
/// within a session (the same card doesn't re-call), while cross-session
/// freshness is preserved naturally — the cache resets on reload, so each run
/// gets new wording.
class LlmClient {
  LlmClient({
    String? proxyUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 4),
    this.maxCache = 64,
  })  : proxyUrl = proxyUrl ?? kProxyUrl,
        _http = httpClient ?? http.Client();

  final String proxyUrl;
  final Duration timeout;
  final int maxCache;
  final http.Client _http;

  final Map<String, String> _cache = {};

  bool get configured => proxyUrl.isNotEmpty;

  /// Generate a short piece of text from the engine's real context, or `null`
  /// on any failure. [maxTokens] is a hint; the proxy caps it low regardless.
  Future<String?> generate({
    required String system,
    required String task,
    Object? context,
    int maxTokens = 120,
    String? cacheKey,
  }) async {
    if (!configured) return null;

    final key = cacheKey ?? '$system|$task|${jsonEncode(context)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final r = await _http
          .post(
            Uri.parse(proxyUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system': system,
              'task': task,
              'context': context,
              'maxTokens': maxTokens,
            }),
          )
          .timeout(timeout);
      if (r.statusCode != 200) return null;
      final decoded = jsonDecode(r.body);
      if (decoded is! Map) return null;
      final text = decoded['text'];
      if (text is! String) return null;
      final trimmed = text.trim();
      if (trimmed.isEmpty) return null;
      _remember(key, trimmed);
      return trimmed;
    } catch (_) {
      // Timeout, socket, JSON — all degrade to the deterministic fallback.
      return null;
    }
  }

  void _remember(String key, String value) {
    if (_cache.length >= maxCache) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  void dispose() => _http.close();
}
