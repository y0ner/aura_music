import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Estilos visuales disponibles para el isotipo [AuraMark].
enum AuraMarkStyle {
  /// Trazo de la «A» con el degradado de marca y triángulo de reproducción blanco.
  gradient,

  /// Isotipo completamente blanco sobre fondo oscuro o de color.
  white,

  /// Isotipo monocromo teñido con un color específico (por defecto blanco).
  mono,
}

/// Pinta la «A» con el triángulo de reproducción en un lienzo normalizado 100 × 100.
void _paintAuraMark(
  Canvas canvas, {
  required AuraMarkStyle style,
  Color? color,
}) {
  final Path aPath = Path()
    ..moveTo(20, 82)
    ..lineTo(50, 18)
    ..lineTo(80, 82);

  final Color monoColor = color ?? AppTheme.textPrimary;
  final Paint aPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 13
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  switch (style) {
    case AuraMarkStyle.gradient:
      aPaint.shader = AppTheme.brandGradient.createShader(aPath.getBounds());
    case AuraMarkStyle.white:
      aPaint.color = AppTheme.textPrimary;
    case AuraMarkStyle.mono:
      aPaint.color = monoColor;
  }
  canvas.drawPath(aPath, aPaint);

  final Path playPath = Path()
    ..moveTo(45, 56.5)
    ..lineTo(45, 71.5)
    ..lineTo(59, 64)
    ..close();

  final Color playColor = switch (style) {
    AuraMarkStyle.gradient || AuraMarkStyle.white => AppTheme.textPrimary,
    AuraMarkStyle.mono => monoColor,
  };

  // Se usan instancias distintas de Paint para que cada drawPath conserve
  // su estilo propio en el árbol de grabación de pruebas y en la GPU.
  canvas.drawPath(
    playPath,
    Paint()
      ..style = PaintingStyle.fill
      ..color = playColor,
  );
  canvas.drawPath(
    playPath,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = playColor,
  );
}

/// Prepara una transformación proporcional de un lienzo 100 × 100 centrado.
void _paintNormalizedCanvas(
  Canvas canvas,
  Size size,
  void Function(Canvas canvas) draw,
) {
  final double side = math.min(size.width, size.height);
  if (side <= 0) {
    return;
  }
  final double scale = side / 100.0;
  canvas.save();
  canvas.translate(
    (size.width - side) / 2.0,
    (size.height - side) / 2.0,
  );
  canvas.scale(scale, scale);
  draw(canvas);
  canvas.restore();
}

/// Isotipo «A·Play» de Aura sin fondo.
///
/// Dibuja únicamente la «A» de trazo redondeado y su travesaño en forma de
/// triángulo de reproducción dentro de un cuadro de lado [size].
class AuraMark extends StatelessWidget {
  /// Tamaño del lado del isotipo en píxeles lógicos.
  final double size;

  /// Variante cromática del isotipo.
  final AuraMarkStyle style;

  /// Color usado cuando [style] es [AuraMarkStyle.mono].
  /// Si se omite, se usa [AppTheme.textPrimary].
  final Color? color;

  const AuraMark({
    super.key,
    this.size = 30,
    this.style = AuraMarkStyle.gradient,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _AuraMarkPainter(style: style, color: color),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('size', size, defaultValue: 30));
    properties.add(
      EnumProperty<AuraMarkStyle>(
        'style',
        style,
        defaultValue: AuraMarkStyle.gradient,
      ),
    );
    properties.add(ColorProperty('color', color, defaultValue: null));
  }
}

class _AuraMarkPainter extends CustomPainter {
  final AuraMarkStyle style;
  final Color? color;

  const _AuraMarkPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    _paintNormalizedCanvas(
      canvas,
      size,
      (c) => _paintAuraMark(c, style: style, color: color),
    );
  }

  @override
  bool shouldRepaint(covariant _AuraMarkPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.color != color;
  }
}

/// Icono completo de Aura: fondo oscuro redondeado, brillo radial y la «A» al 68 %.
class AuraAppIcon extends StatelessWidget {
  /// Tamaño del lado del icono en píxeles lógicos.
  final double size;

  const AuraAppIcon({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _AuraAppIconPainter()),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('size', size, defaultValue: 96));
  }
}

class _AuraAppIconPainter extends CustomPainter {
  const _AuraAppIconPainter();

  static final RadialGradient _glowGradient = RadialGradient(
    center: const Alignment(0, 0.24),
    radius: 0.55,
    colors: [
      AppTheme.brandRose.withValues(alpha: 0.42),
      AppTheme.brandViolet.withValues(alpha: 0.14),
      AppTheme.brandViolet.withValues(alpha: 0),
    ],
    stops: const [0, 0.55, 1],
  );

  @override
  void paint(Canvas canvas, Size size) {
    _paintNormalizedCanvas(canvas, size, (c) {
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      final RRect roundedBox = RRect.fromRectAndRadius(
        bounds,
        const Radius.circular(23),
      );

      c.drawRRect(roundedBox, Paint()..color = AppTheme.brandInk);
      c.drawRRect(
        roundedBox,
        Paint()..shader = _glowGradient.createShader(bounds),
      );

      c.save();
      c.translate(16, 16);
      c.scale(0.68, 0.68);
      _paintAuraMark(c, style: AuraMarkStyle.gradient);
      c.restore();
    });
  }

  @override
  bool shouldRepaint(covariant _AuraAppIconPainter oldDelegate) => false;
}

/// Logotipo horizontal de Aura: isotipo de 30 px, espacio de 8 px y texto «Aura».
///
/// Expone un único nodo semántico con la etiqueta «Aura» para lectores de pantalla.
class AuraWordmark extends StatelessWidget {
  const AuraWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Aura',
      excludeSemantics: true,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuraMark(size: 30),
          SizedBox(width: AppTheme.space8),
          Text('Aura', style: AppTheme.wordmark),
        ],
      ),
    );
  }
}
