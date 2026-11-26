import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Insignia «E» para canciones marcadas como explícitas.
class ExplicitBadge extends StatelessWidget {
  final double size;

  const ExplicitBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Explícita',
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: AppTheme.textSecondary,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall / 2),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'E',
            style: AppTheme.caption.copyWith(
              color: AppTheme.bg,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
