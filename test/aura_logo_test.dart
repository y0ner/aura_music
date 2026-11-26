import 'package:aura_music/theme/app_theme.dart';
import 'package:aura_music/widgets/aura_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AuraMark, AuraAppIcon y AuraWordmark se pintan a 24, 48 y 200 px sin excepciones',
    (WidgetTester tester) async {
      for (final double size in <double>[24, 48, 200]) {
        for (final AuraMarkStyle style in AuraMarkStyle.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Center(
                  child: AuraMark(
                    size: size,
                    style: style,
                    color: style == AuraMarkStyle.mono
                        ? AppTheme.brandRose
                        : null,
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(AuraMark)), Size.square(size));
        }

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(child: AuraAppIcon(size: size)),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(AuraAppIcon)), Size.square(size));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox.square(
                  dimension: size,
                  child: const FittedBox(child: AuraWordmark()),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(AuraWordmark), findsOneWidget);
      }
    },
  );

  testWidgets(
    'AuraWordmark expone la etiqueta semántica «Aura» y muestra el texto «Aura»',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: Center(child: AuraWordmark())),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Aura'), findsOneWidget);
        expect(find.bySemanticsLabel('Aura'), findsOneWidget);

        final SemanticsNode node = tester.getSemantics(
          find.byType(AuraWordmark),
        );
        expect(node.label, 'Aura');
        expect(node.childrenCount, 0);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'AuraMark(style: AuraMarkStyle.mono) sin color usa AppTheme.textPrimary',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: AuraMark(size: 48, style: AuraMarkStyle.mono),
            ),
          ),
        ),
      );

      final Finder customPaint = find.descendant(
        of: find.byType(AuraMark),
        matching: find.byType(CustomPaint),
      );
      expect(customPaint, findsOneWidget);
      expect(
        customPaint,
        paints
          ..path(color: AppTheme.textPrimary, style: PaintingStyle.stroke)
          ..path(color: AppTheme.textPrimary, style: PaintingStyle.fill)
          ..path(color: AppTheme.textPrimary, style: PaintingStyle.stroke),
      );
    },
  );
}
