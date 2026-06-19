import 'package:flutter/material.dart';

import '../../components/orb/orb_painter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Static preview of the orb's living look (the exact [OrbPainter] used by the
/// interactive orb), so its render can be screenshotted without driving a
/// pointer. Used by the visual-test harness at route `/orb`.
class OrbPreviewScreen extends StatefulWidget {
  const OrbPreviewScreen({super.key});

  @override
  State<OrbPreviewScreen> createState() => _OrbPreviewScreenState();
}

class _OrbPreviewScreenState extends State<OrbPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
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
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(
                    painter: OrbPainter(
                      pulse: 0.32, // a pleasing static phase for the still
                      opacity: 1.0,
                      reach: 0.5,
                      direction: OrbDirection.right,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Orbe Vybia', style: t.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Naît sous le doigt · suit · s’engage · se dissout',
                style: t.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
