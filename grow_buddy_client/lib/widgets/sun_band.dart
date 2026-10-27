import 'package:flutter/material.dart';
import '../theme.dart';

/// 6 am to 6 pm strip. The amber part is the direct afternoon sun the spot gets,
/// counted from noon. The thin bar underneath, when given, is what a plant likes.
class SunBand extends StatelessWidget {
  final double sunHours;
  final int? needMin;
  final int? needMax;
  const SunBand({super.key, required this.sunHours, this.needMin, this.needMax});

  static const _startHour = 6;
  static const _hours = 12;
  static const _noonCell = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final sun = sunHours.clamp(0, (_hours - _noonCell).toDouble());
    const needStart = _noonCell / _hours;
    return Semantics(
      label: 'Your direct sun: ${sunHours.toStringAsFixed(1)} hours from noon.'
          '${needMin == null ? '' : ' This plant likes $needMin to $needMax hours.'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final cell = c.maxWidth / _hours;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: scheme.surfaceContainer)),
                        Positioned(
                          left: cell * _noonCell,
                          top: 0,
                          bottom: 0,
                          width: cell * sun,
                          child: const ColoredBox(color: sunAmber),
                        ),
                        for (var i = 1; i < _hours; i++)
                          Positioned(
                            left: cell * i - 0.5,
                            top: 0,
                            bottom: 0,
                            width: 1,
                            child: ColoredBox(color: scheme.surface.withValues(alpha: 0.6)),
                          ),
                      ],
                    ),
                  ),
                ),
                if (needMin != null && needMax != null) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Positioned(
                          left: c.maxWidth * needStart,
                          width: cell * needMax!,
                          top: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Positioned(
                          left: c.maxWidth * needStart,
                          width: cell * needMin!,
                          top: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in const [_startHour, 9, 12, 15, 18])
                Text(h == 12 ? '12 pm' : h < 12 ? '$h am' : '${h - 12} pm', style: small),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Key(color: sunAmber, label: 'Your sun, ${sunHours.toStringAsFixed(1)} hrs'),
              if (needMin != null)
                _Key(color: scheme.primary, label: 'Plant likes $needMin to $needMax hrs'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final Color color;
  final String label;
  const _Key({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
