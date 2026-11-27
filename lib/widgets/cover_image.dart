import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Carátula decodificada al tamaño en que se muestra, no al original.
///
/// `Image.memory` decodifica la imagen completa aunque se pinte en una
/// miniatura de 48 px. Aquí se pide como máximo el doble del lado en
/// pantalla (en píxeles físicos): el margen ×2 deja que una portada
/// apaisada (16:9) siga nítida con `BoxFit.cover`, y nunca se agranda una
/// imagen más pequeña que eso.
class CoverImage extends StatelessWidget {
  final Uint8List bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool gaplessPlayback;

  const CoverImage(
    this.bytes, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.gaplessPlayback = true,
  });

  static double? _finite(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;

  @override
  Widget build(BuildContext context) {
    final fixedWidth = _finite(width);
    final fixedHeight = _finite(height);
    if (fixedWidth != null && fixedHeight != null) {
      return _image(context, math.max(fixedWidth, fixedHeight));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          fixedWidth ?? _finite(constraints.maxWidth) ?? 0,
          fixedHeight ?? _finite(constraints.maxHeight) ?? 0,
        );
        return _image(context, side);
      },
    );
  }

  Widget _image(BuildContext context, double logicalSide) {
    ImageProvider provider = MemoryImage(bytes);
    if (logicalSide > 0) {
      final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      final box = (logicalSide * ratio * 2).ceil();
      provider = ResizeImage(
        provider,
        width: box,
        height: box,
        policy: ResizeImagePolicy.fit,
      );
    }
    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: gaplessPlayback,
    );
  }
}
