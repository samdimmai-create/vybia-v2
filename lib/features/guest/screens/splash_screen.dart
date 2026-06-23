import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/orb/orb_painter.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/water_transition.dart';
import '../state/guest_controller.dart';

/// Brief liquid-orb moment, then auto-continues. No interaction.
///
/// S17A: the splash plays the SIGNATURE water transition — the calm sea-glass
/// water rises out of the breathing orb and fills the screen (the app
/// "surfacing" from water) — the EXACT same [WaterReveal] the hold-to-home
/// return uses, so launch and return read as one brand gesture. The orb is the
/// seed the water swells from; it recedes as the water rises, the wordmark
/// floating above throughout.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _reveal; // the water rising 0→1
  Timer? _go;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _go = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      // S16A: a first-time guest (no saved profile) FILES straight to value —
      // the mood capture → adaptive questions → reco reveal — skipping the
      // abstract 4-direction hub. A returning guest lands on the calm Accueil
      // hub (they already know what they want). Hold-to-home keeps the hub one
      // gesture away from anywhere.
      final returning = GuestScope.of(context).returning;
      Navigator.of(context).pushReplacementNamed(
        returning ? AppRouter.accueil : AppRouter.welcome,
      );
    });
  }

  @override
  void dispose() {
    _go?.cancel();
    _pulse.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final center = Offset(size.width / 2, size.height * 0.42);
          return Stack(
            fit: StackFit.expand,
            children: [
              // The pre-surface ambient wash.
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.bgWash),
                child: SizedBox.expand(),
              ),
              // The signature water rising out of the orb to fill the screen.
              AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) => WaterReveal(
                  progress: _reveal.value,
                  center: center,
                  seedRadius: 66,
                ),
              ),
              // The breathing orb is the seed; it recedes as the water rises.
              Align(
                alignment: const Alignment(0, -0.16),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulse, _reveal]),
                  builder: (context, _) => Opacity(
                    opacity: (1.0 - _reveal.value).clamp(0.0, 1.0).toDouble(),
                    child: SizedBox(
                      width: 132,
                      height: 132,
                      child: CustomPaint(
                        painter: OrbPainter(
                          pulse: _pulse.value,
                          opacity: 1,
                          reach: 0,
                          direction: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The wordmark floats above the water throughout.
              Align(
                alignment: const Alignment(0, 0.34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Vybia',
                        style:
                            t.displayLarge?.copyWith(color: AppColors.pearl)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Ton concierge d’instants.', style: t.bodyLarge),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
