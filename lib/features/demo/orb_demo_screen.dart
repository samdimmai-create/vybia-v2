import 'package:flutter/material.dart';

import '../../components/orb/vybia_orb.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/edge_labels.dart';

/// Temporary S0 demo surface: shows the orb living on the sea-glass field and
/// echoes the last committed direction so the interaction can be eyeballed and
/// screenshotted.
class OrbDemoScreen extends StatefulWidget {
  const OrbDemoScreen({super.key});

  @override
  State<OrbDemoScreen> createState() => _OrbDemoScreenState();
}

class _OrbDemoScreenState extends State<OrbDemoScreen> {
  OrbDirection? _last;

  String get _lastLabel {
    switch (_last) {
      case OrbDirection.left:
        return 'Explorer';
      case OrbDirection.right:
        return 'Planifier';
      case OrbDirection.up:
        return 'Mon profil';
      case OrbDirection.down:
        return 'Mes plans';
      case null:
        return 'Touche et glisse';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: VybiaOrb(
        onDirection: (d) => setState(() => _last = d),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.bgWash),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Centerpiece copy.
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Vybia',
                        style: t.displayLarge?.copyWith(
                          color: AppColors.pearl,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Ton concierge d’instants.',
                        textAlign: TextAlign.center,
                        style: t.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Container(
                          key: ValueKey(_lastLabel),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _last == null
                                ? _lastLabel
                                : 'Direction : $_lastLabel',
                            style: t.labelLarge?.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned.fill(
                child: EdgeLabels(
                  left: 'Explorer',
                  right: 'Planifier',
                  up: 'Profil',
                  down: 'Mes plans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
