import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import '../../core/theme/app_colors.dart';

/// Which rendering technique the bubble is currently using.
enum RefractionTechnique {
  /// GLSL fragment shader fed by [AnimatedSampler] — true per-pixel refraction.
  shader,

  /// CustomPainter lens (magnification + chromatic ring + highlight). Works
  /// everywhere, including web/CanvasKit where runtime shaders may be unsupported.
  fallback,
}

/// THE universal bubble-over-image effect (live, reusable).
///
/// Renders [image] full-bleed and, wherever [orbCenter] points, refracts the
/// image like a liquid-glass bubble — lens magnification, radial refraction,
/// chromatic rim and a specular highlight (the iOS-lockscreen look).
///
/// Reusable anywhere an image needs the Vybia treatment: emotions screens,
/// recommendation scenes, any image card. Drive [orbCenter] from
/// [VybiaOrb.onPositionChanged]. Pass `null` to rest the lens.
///
/// It tries a GLSL shader first; if the shader can't be loaded or run (e.g. some
/// web/CanvasKit builds) it transparently falls back to a painter-based lens, so
/// the effect is *always* visible. [onTechnique] reports which path is live.
class RefractionBubble extends StatefulWidget {
  const RefractionBubble({
    super.key,
    required this.image,
    required this.orbCenter,
    this.radius = 84,
    this.magnification = 0.55,
    this.active = 1.0,
    this.onTechnique,
  });

  final ImageProvider image;

  /// Lens center in this widget's local coordinates, or null to hide the lens.
  final Offset? orbCenter;

  final double radius;

  /// 0..1 — how much the lens zooms/bends the image beneath it.
  final double magnification;

  /// 0..1 — overall strength (lets the lens fade in/out).
  final double active;

  final ValueChanged<RefractionTechnique>? onTechnique;

  @override
  State<RefractionBubble> createState() => _RefractionBubbleState();
}

class _RefractionBubbleState extends State<RefractionBubble> {
  ui.FragmentShader? _shader;
  ui.Image? _decoded; // for the fallback painter
  ImageStream? _stream;
  ImageStreamListener? _listener;
  RefractionTechnique? _reported;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _resolveImage();
  }

  // S6.2 A/B: `--dart-define=VYBIA_LENS=calm` swaps in the calmer convex lens
  // (bubble_calm.frag) for proof captures. Default 'vif' = the current S6.1
  // shader. Selection is global (every bubble in the app honours it) so the
  // founder compares like-for-like; nothing is made the default here.
  static const String _lensVariant =
      String.fromEnvironment('VYBIA_LENS', defaultValue: 'vif');
  static String get _shaderAsset => _lensVariant == 'calm'
      ? 'assets/shaders/bubble_calm.frag'
      : 'assets/shaders/bubble.frag';

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(_shaderAsset);
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (e) {
      // Web/CanvasKit (or any) failure → stay on the painter fallback.
      debugPrint('RefractionBubble: shader unavailable, using fallback ($e)');
    }
  }

  void _resolveImage() {
    _stream?.removeListener(_listener!);
    final stream = widget.image.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _decoded = info.image);
    });
    _stream = stream..addListener(listener);
    _listener = listener;
  }

  @override
  void didUpdateWidget(covariant RefractionBubble old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _resolveImage();
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _shader?.dispose();
    super.dispose();
  }

  void _report(RefractionTechnique t) {
    if (_reported == t) return;
    _reported = t;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTechnique?.call(t);
    });
  }

  // The shader *loads* on web/CanvasKit but AnimatedSampler does not visibly
  // apply it there (verified by screenshot in S1), so we use the painter lens on
  // web. Native builds use the GLSL shader for true per-pixel refraction.
  bool get _useShader => _shader != null && !kIsWeb && !_kForceFallback;

  @override
  Widget build(BuildContext context) {
    final fullBleed = Image(
      image: widget.image,
      fit: BoxFit.cover,
      // Never gate visibility on a loadingBuilder (a V1 web bug).
      errorBuilder: (_, _, _) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.bgWash),
      ),
    );

    if (_useShader) {
      _report(RefractionTechnique.shader);
      return AnimatedSampler(
        (ui.Image image, Size size, Canvas canvas) {
          final s = _shader!;
          final o = widget.orbCenter ??
              Offset(size.width / 2, size.height / 2);
          s.setFloat(0, size.width);
          s.setFloat(1, size.height);
          s.setFloat(2, o.dx);
          s.setFloat(3, o.dy);
          s.setFloat(4, widget.radius);
          s.setFloat(5, widget.magnification);
          s.setFloat(6, widget.orbCenter == null ? 0.0 : widget.active);
          s.setImageSampler(0, image);
          canvas.drawRect(
            Offset.zero & size,
            Paint()..shader = s,
          );
        },
        child: SizedBox.expand(child: fullBleed),
      );
    }

    // ---- Fallback lens --------------------------------------------------
    _report(RefractionTechnique.fallback);
    return Stack(
      fit: StackFit.expand,
      children: [
        fullBleed,
        if (widget.orbCenter != null && _decoded != null)
          Positioned.fill(
            child: CustomPaint(
              painter: _LensPainter(
                image: _decoded!,
                center: widget.orbCenter!,
                radius: widget.radius,
                magnification: widget.magnification,
                active: widget.active,
              ),
            ),
          ),
      ],
    );
  }
}

/// Flip to force the painter lens even where the shader loads (debug aid).
const bool _kForceFallback = false;

/// Painter lens: the web-safe WATER + ICE + GLASS bubble at [center].
/// (The background image is drawn full-bleed by the widget behind this painter;
/// this painter refracts a copy of it inside the lens and lays the glass on
/// top.)
///
/// The refraction is genuinely *non-uniform* and radial: the image is resampled
/// in concentric annuli whose zoom rises toward the centre on a convex
/// (barrel/droplet) curve, so the middle bulges like a water drop and the rim
/// compresses — not a flat uniform magnification. On top of that sit a frosted
/// icy rim, layered glass speculars and a subtle chromatic dispersion fringe.
class _LensPainter extends CustomPainter {
  _LensPainter({
    required this.image,
    required this.center,
    required this.radius,
    required this.magnification,
    required this.active,
  });

  final ui.Image image;
  final Offset center;
  final double radius;
  final double magnification;
  final double active;

  /// Number of concentric refraction annuli. More = smoother droplet curve.
  static const int _rings = 14;

  /// Source rect of [image] that covers [dst] (BoxFit.cover).
  Rect _coverSrc(Size dst) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale =
        (dst.width / iw) > (dst.height / ih) ? dst.width / iw : dst.height / ih;
    final w = dst.width / scale;
    final h = dst.height / scale;
    return Rect.fromLTWH((iw - w) / 2, (ih - h) / 2, w, h);
  }

  /// Convex droplet zoom for the band whose outer edge is at normalized
  /// radius [t] (0 = centre, 1 = rim). Centre bulges most; rim ≈ no zoom.
  double _zoomAt(double t) {
    final bulge = 1.0 - t * t; // convex falloff
    return 1.0 + magnification * 0.95 * bulge;
  }

  void _drawScaledImage(Canvas canvas, Size size, double zoom, [Paint? paint]) {
    final src = _coverSrc(size);
    final dst = Offset.zero & size;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(zoom);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawImageRect(
      image,
      src,
      dst,
      paint ?? (Paint()..filterQuality = FilterQuality.high),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (active <= 0.001) return;
    // Scale + fade in with presence so the bubble is born on contact and gone
    // on release in lockstep with the orb (never an instant pop).
    final r = radius * (0.64 + 0.36 * active);

    // ---- 1. Non-uniform radial refraction (the water droplet) -----------
    // Draw the image once per annulus, outermost first, each clipped to its
    // outer radius and resampled at that band's droplet zoom. Inner (more
    // magnified) bands paint over outer ones, yielding a continuous bulge.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
    for (var i = _rings; i >= 1; i--) {
      final t = i / _rings; // outer edge of this band, 0..1
      final ringR = r * t;
      canvas.save();
      canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: center, radius: ringR)));
      _drawScaledImage(canvas, size, _zoomAt(t));
      canvas.restore();
    }
    canvas.restore();

    // ---- 2. Chromatic dispersion at the rim -----------------------------
    // Split a faint red/blue copy of the rim band so light fringes like glass.
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: r))
      ..addOval(Rect.fromCircle(center: center, radius: r * 0.78)));
    final disp = r * 0.012;
    final rimZoom = _zoomAt(0.92);
    canvas.save();
    canvas.translate(disp, 0);
    _drawScaledImage(
      canvas,
      size,
      rimZoom,
      Paint()
        ..filterQuality = FilterQuality.high
        ..blendMode = BlendMode.plus
        ..colorFilter = const ColorFilter.mode(
            Color(0x33FF2A2A), BlendMode.modulate),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-disp, 0);
    _drawScaledImage(
      canvas,
      size,
      rimZoom,
      Paint()
        ..filterQuality = FilterQuality.high
        ..blendMode = BlendMode.plus
        ..colorFilter = const ColorFilter.mode(
            Color(0x332AB6FF), BlendMode.modulate),
    );
    canvas.restore();
    canvas.restore();

    // ---- 3. Glass + ice finish (clipped to the lens) --------------------
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    // Curvature darkening toward the rim (the dome reads as a lens).
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            AppColors.bg.withValues(alpha: 0.34 * active),
          ],
          stops: const [0.0, 0.68, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Frosted ICY rim band — a blurred bright ring hugging the inside edge.
    canvas.drawCircle(
      center,
      r * 0.9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08)
        ..color = AppColors.pearl.withValues(alpha: 0.16 * active),
    );

    // Cool sea-glass inner tint, concentrated lower-right (refracted depth).
    final depth = center + Offset(r * 0.34, r * 0.36);
    canvas.drawCircle(
      depth,
      r * 0.8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.18 * active),
            AppColors.accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: depth, radius: r * 0.8)),
    );

    // Primary soft glass shine, upper-left.
    final hl = center + Offset(-r * 0.34, -r * 0.36);
    canvas.drawCircle(
      hl,
      r * 0.72,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.pearl.withValues(alpha: 0.5 * active),
            AppColors.pearl.withValues(alpha: 0.12 * active),
            AppColors.pearl.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: hl, radius: r * 0.72)),
    );

    // Sharp specular hotspot — the wet glass kick.
    final hot = center + Offset(-r * 0.4, -r * 0.44);
    canvas.drawCircle(
      hot,
      r * 0.14,
      Paint()
        ..color = AppColors.pearl.withValues(alpha: 0.85 * active)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
    );

    // Curved highlight streak along the upper rim (ice glare).
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.82),
      math.pi * 1.06,
      math.pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
        ..color = AppColors.pearl.withValues(alpha: 0.45 * active),
    );
    canvas.restore();

    // ---- 4. Rim lights (sea-glass + crisp edge) -------------------------
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = AppColors.accent.withValues(alpha: 0.5 * active),
    );
    canvas.drawCircle(
      center,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = AppColors.pearl.withValues(alpha: 0.5 * active),
    );
  }

  @override
  bool shouldRepaint(covariant _LensPainter old) =>
      old.image != image ||
      old.center != center ||
      old.radius != radius ||
      old.magnification != magnification ||
      old.active != active;
}
