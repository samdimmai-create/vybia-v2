import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/bubble/refraction_bubble.dart';
import '../../../components/orb/vybia_orb.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_labels.dart';

/// The universal guest scene: a full-bleed situational [image] always wearing
/// the Vybia bubble treatment, driven entirely by the orb.
///
/// An ambient refraction lens gently drifts so every image is *visibly* a
/// liquid-glass bubble (the brand non-negotiable, and screenshot-able headless).
/// On contact the lens is born at the finger, follows it, and the orb's life
/// force [presence] intensifies the refraction; on release it dissolves back to
/// the ambient drift. Committing a direction past threshold fires [onDirection].
class SceneScaffold extends StatefulWidget {
  const SceneScaffold({
    super.key,
    required this.image,
    required this.headline,
    required this.onDirection,
    this.prompt,
    this.left,
    this.right,
    this.up,
    this.down,
    this.lensRadius = 84,
  });

  final String image;
  final String headline;
  final String? prompt;
  final ValueChanged<OrbDirection> onDirection;
  final String? left;
  final String? right;
  final String? up;
  final String? down;
  final double lensRadius;

  @override
  State<SceneScaffold> createState() => _SceneScaffoldState();
}

class _SceneScaffoldState extends State<SceneScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;
  Offset? _orb; // live finger position; null when resting
  double _presence = 0; // orb life force 0..1

  static const double _ambient = 0.5; // every image always shows the bubble

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  /// Gentle Lissajous path used when no finger is down.
  Offset _idle(Size size) {
    final t = _drift.value * 2 * math.pi;
    final cx = size.width / 2 + math.cos(t) * size.width * 0.20;
    final cy = size.height * 0.46 + math.sin(t * 1.3) * size.height * 0.14;
    return Offset(cx, cy);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return VybiaOrb(
            showOrb: false, // the refraction bubble IS the orb here
            onPositionChanged: (p) => setState(() => _orb = p),
            onPresence: (v) => setState(() => _presence = v),
            onDirection: widget.onDirection,
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, _) {
                final pressing = _orb != null;
                final center = _orb ?? _idle(size);
                // Continuous floor (every image stays a bubble) lifted to full
                // strength on contact — no flicker on release.
                final active = pressing
                    ? (_ambient + (1 - _ambient) * _presence)
                        .clamp(0.0, 1.0)
                        .toDouble()
                    : _ambient;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RefractionBubble(
                      image: AssetImage(widget.image),
                      orbCenter: center,
                      radius: widget.lensRadius,
                      magnification: 0.55,
                      active: active,
                    ),
                    _TopScrim(headline: widget.headline, prompt: widget.prompt),
                    EdgeLabels(
                      left: widget.left,
                      right: widget.right,
                      up: widget.up,
                      down: widget.down,
                    ),
                    if (widget.prompt != null)
                      _hintChip(t, 'Touche, glisse, et choisis ta direction'),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _hintChip(TextTheme t, String label) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.huge),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: AppColors.pearl.withValues(alpha: 0.25)),
              ),
              child: Text(
                label,
                style: t.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Headline + optional prompt floated on a top legibility scrim.
class _TopScrim extends StatelessWidget {
  const _TopScrim({required this.headline, this.prompt});

  final String headline;
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.bg.withValues(alpha: 0.72),
                AppColors.bg.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: t.displayMedium?.copyWith(
                    color: AppColors.pearl,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 14)
                    ],
                  ),
                ),
                if (prompt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    prompt!,
                    style: t.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 8)
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
