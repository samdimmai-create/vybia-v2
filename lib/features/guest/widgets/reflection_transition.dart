import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/bubble/refraction_bubble.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// One slide of the reflection transition: an illustrative image and the short
/// French line it stands for (a captured preference / plan choice).
class ReflectionSlide {
  const ReflectionSlide({required this.image, required this.label});

  final String image;
  final String label;
}

/// S8.1E — the calm "Vybia réfléchit" bridge.
///
/// A short, self-contained slideshow that reassures the guest their inputs were
/// captured before it hands off to the result. Reused by BOTH flows: before the
/// recommendations (exploration) and inside the planification flow. Each slide
/// is one of the existing high-quality images wearing the universal refraction
/// bubble (the brand non-negotiable), cross-fading on a calm sea-glass field.
///
/// It is deliberately BRIEF (≈ [perSlide] × slides, a couple of seconds) and
/// SKIPPABLE on touch, so it never fights the ≤ 3-minute product target.
class ReflectionTransition extends StatefulWidget {
  const ReflectionTransition({
    super.key,
    required this.slides,
    required this.onDone,
    this.title = 'Vybia réfléchit',
    this.perSlide = const Duration(milliseconds: 850),
  });

  final List<ReflectionSlide> slides;
  final VoidCallback onDone;
  final String title;
  final Duration perSlide;

  @override
  State<ReflectionTransition> createState() => _ReflectionTransitionState();
}

class _ReflectionTransitionState extends State<ReflectionTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;
  Timer? _timer;
  int _i = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    if (widget.slides.isEmpty) {
      // Nothing to show — bridge through on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _timer = Timer.periodic(widget.perSlide, (_) => _advance());
    }
  }

  void _advance() {
    if (_done) return;
    if (_i >= widget.slides.length - 1) {
      _finish();
    } else {
      setState(() => _i++);
    }
  }

  /// Tap anywhere → skip straight to the result.
  void _skip() => _finish();

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final slide = widget.slides.isEmpty ? null : widget.slides[_i];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The illustrative slide wearing the universal bubble, cross-faded.
            if (slide != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: AnimatedBuilder(
                  key: ValueKey(slide.image + slide.label),
                  animation: _drift,
                  builder: (context, _) {
                    final tt = _drift.value * 2 * math.pi;
                    return LayoutBuilder(
                      builder: (context, c) {
                        final center = Offset(
                          c.maxWidth * (0.5 + 0.18 * math.cos(tt)),
                          c.maxHeight * (0.46 + 0.12 * math.sin(tt * 1.3)),
                        );
                        return RefractionBubble(
                          image: AssetImage(slide.image),
                          orbCenter: center,
                          radius: 44,
                          magnification: 0.8,
                          active: 0.7,
                        );
                      },
                    );
                  },
                ),
              ),
            // Calm legibility wash, top + bottom.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC0E1518),
                    Color(0x330E1518),
                    Color(0xCC0E1518),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.title}…',
                      textAlign: TextAlign.center,
                      style: t.displaySmall?.copyWith(
                        color: AppColors.pearl,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 12)
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (slide != null)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Text(
                          slide.label,
                          key: ValueKey(slide.label),
                          textAlign: TextAlign.center,
                          style: t.titleMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 8)
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    // Progress dots.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var k = 0; k < widget.slides.length; k++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: k <= _i
                                  ? AppColors.accent
                                  : AppColors.accent.withValues(alpha: 0.25),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Skip affordance.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text(
                    'touche pour passer',
                    style:
                        t.labelSmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
