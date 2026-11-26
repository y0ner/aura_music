import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'aura_logo.dart';

/// Barra superior de Inicio con el logotipo de Aura, buscar y ajustes.
class InicioHeader extends StatelessWidget {
  final VoidCallback? onSearchPressed;
  final VoidCallback? onSettingsPressed;

  const InicioHeader({
    super.key,
    this.onSearchPressed,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.pagePadding,
        AppTheme.space8,
        AppTheme.space4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AuraWordmark(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onSearchPressed,
                tooltip: 'Buscar',
                icon: const Icon(
                  Icons.search,
                  color: AppTheme.textPrimary,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: AppTheme.minTouch,
                  height: AppTheme.minTouch,
                ),
              ),
              IconButton(
                onPressed: onSettingsPressed,
                tooltip: 'Ajustes',
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppTheme.textPrimary,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: AppTheme.minTouch,
                  height: AppTheme.minTouch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
