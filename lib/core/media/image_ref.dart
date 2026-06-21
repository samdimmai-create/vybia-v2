import 'package:flutter/widgets.dart';

/// Resolve a catalog image reference to an [ImageProvider] (S10.1B).
///
/// Static catalog rows carry a bundled asset path (`assets/images/…`) and resolve
/// to an [AssetImage]; LIVE items (e.g. a TMDB film poster) carry an `http(s)`
/// URL from their source and resolve to a [NetworkImage]. Everything downstream
/// (the universal bubble, the reflection, the plans list) renders both the same
/// way — and [BubbleImage]'s errorBuilder still degrades a broken URL to the
/// brand wash, so a dead live image never blanks the scene.
ImageProvider imageProviderFor(String ref) {
  if (ref.startsWith('http://') || ref.startsWith('https://')) {
    return NetworkImage(ref);
  }
  return AssetImage(ref);
}
