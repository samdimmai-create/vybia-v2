import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/orb/orb_painter.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../state/guest_controller.dart';

/// Brief liquid-orb moment, then auto-continues to Welcome. No interaction.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _go;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.bgWash),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: OrbPainter(
                      pulse: _pulse.value,
                      opacity: 1,
                      reach: 0,
                      direction: null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Vybia',
                  style: t.displayLarge?.copyWith(color: AppColors.pearl)),
              const SizedBox(height: AppSpacing.xs),
              Text('Ton concierge d’instants.', style: t.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
