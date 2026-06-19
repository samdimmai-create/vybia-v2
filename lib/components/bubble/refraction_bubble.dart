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
    this.radius = 96,
    this.magnification = 0.45,
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

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('assets/shaders/bubble.frag');
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

/// Painter lens: draws the magnified, glass-finished bubble at [center].
/// (The background image is drawn by the widget behind this painter.)
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

  @override
  void paint(Canvas canvas, Size size) {
    if (active <= 0.001) return;
    final src = _coverSrc(size);
    final dst = Offset.zero & size;
    final zoom = 1.0 + magnification * 0.9; // e.g. 0.45 → ~1.4x

    // ---- Magnified image inside the lens --------------------------------
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.translate(center.dx, center.dy);
    canvas.scale(zoom);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    // ---- Glass finish (clipped to the lens, in screen space) ------------
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Curvature darkening toward the rim.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            AppColors.bg.withValues(alpha: 0.30 * active),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Specular highlight, upper-left.
    final hl = center + Offset(-radius * 0.32, -radius * 0.34);
    canvas.drawCircle(
      hl,
      radius * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.pearl.withValues(alpha: 0.40 * active),
            AppColors.pearl.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: hl, radius: radius * 0.7)),
    );

    // Chromatic fringe ring near the rim.
    canvas.drawCircle(
      center,
      radius * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
        ..color = AppColors.edgeRight.withValues(alpha: 0.34 * active),
    );
    canvas.drawCircle(
      center,
      radius * 0.99,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
        ..color = AppColors.edgeLeft.withValues(alpha: 0.28 * active),
    );
    canvas.restore();

    // ---- Sea-glass rim light --------------------------------------------
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = AppColors.accent.withValues(alpha: 0.55 * active),
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
