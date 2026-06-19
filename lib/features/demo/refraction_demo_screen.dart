import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/bubble/refraction_bubble.dart';
import '../../components/orb/vybia_orb.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// S1 proof-of-concept surface for the universal refraction bubble.
///
/// A full-bleed image with the orb-driven liquid-glass lens on top. When no
/// finger is down the lens gently drifts so the refraction is always visible
/// (and screenshot-able); while the orb is dragged the lens snaps to the finger.
/// A swipe (orb commit) left/right cycles the background image to prove the
/// effect is universal across different photos.
class RefractionDemoScreen extends StatefulWidget {
  const RefractionDemoScreen({super.key});

  @override
  State<RefractionDemoScreen> createState() => _RefractionDemoScreenState();
}

class _RefractionDemoScreenState extends State<RefractionDemoScreen>
    with SingleTickerProviderStateMixin {
  static const _images = <(String, String)>[
    ('assets/images/recos/walk_night.jpg', 'Ville la nuit'),
    ('assets/images/recos/rooftop.jpg', 'Grand air'),
    ('assets/images/recos/cafe.jpg', 'Cocon intérieur'),
  ];

  late final AnimationController _drift;
  int _index = 0;
  Offset? _orb; // live finger position, null when not pressing
  RefractionTechnique? _technique;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  /// Gentle Lissajous path used when the user isn't dragging.
  Offset _idle(Size size) {
    final t = _drift.value * 2 * math.pi;
    final cx = size.width / 2 + math.cos(t) * size.width * 0.22;
    final cy = size.height / 2 + math.sin(t * 1.3) * size.height * 0.16;
    return Offset(cx, cy);
  }

  void _cycle(OrbDirection d) {
    if (d == OrbDirection.left) {
      setState(() => _index = (_index - 1 + _images.length) % _images.length);
    } else if (d == OrbDirection.right) {
      setState(() => _index = (_index + 1) % _images.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (asset, caption) = _images[_index];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return AnimatedBuilder(
            animation: _drift,
            builder: (context, _) {
              final center = _orb ?? _idle(size);
              return VybiaOrb(
                showOrb: false, // the refraction bubble IS the orb here
                onPositionChanged: (p) => setState(() => _orb = p),
                onDirection: _cycle,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RefractionBubble(
                      image: AssetImage(asset),
                      orbCenter: center,
                      radius: 104,
                      magnification: 0.5,
                      onTechnique: (tech) {
                        if (_technique != tech) {
                          setState(() => _technique = tech);
                        }
                      },
                    ),
                    _Overlay(caption: caption, technique: _technique),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.caption, required this.technique});

  final String caption;
  final RefractionTechnique? technique;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final techLabel = switch (technique) {
      RefractionTechnique.shader => 'Rendu : shader GLSL',
      RefractionTechnique.fallback => 'Rendu : lentille (fallback)',
      null => 'Rendu : …',
    };
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bulle Vybia',
                style: t.displayMedium?.copyWith(
                  color: AppColors.pearl,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _chip(caption, AppColors.accent),
              const SizedBox(height: AppSpacing.xs),
              _chip(techLabel, AppColors.champagne),
              const Spacer(),
              Center(
                child: _chip(
                  'Touche et glisse — la bulle réfracte l’image',
                  AppColors.pearl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
