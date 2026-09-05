import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:danoestudio/main.dart';
import 'package:danoestudio/widgets/antique_button.dart';
import 'package:danoestudio/widgets/ribbon_tab.dart';

void main() {
  test('Le widget racine actuel est disponible', () {
    const app = DanoeStudioApp();

    expect(app, isA<DanoeStudioApp>());
  });

  testWidgets('AntiqueButton accepte le clavier et expose son état',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AntiqueButton(label: 'Informations', onTap: () => taps++),
      ),
    );

    await tester.tap(find.byType(AntiqueButton));
    expect(taps, 1);

    await tester.pumpWidget(
      const MaterialApp(
        home: AntiqueButton(
          label: 'Informations',
          onTap: _noop,
          enabled: false,
        ),
      ),
    );
    await tester.tap(find.byType(AntiqueButton));
    final semantics = tester.getSemantics(find.byType(AntiqueButton));

    expect(taps, 1);
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
  });

  testWidgets('AntiqueButton iconOnly affiche son icône sans son libellé',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AntiqueButton(
          label: 'Réglages',
          icon: Icons.settings,
          iconOnly: true,
          onTap: _noop,
        ),
      ),
    );

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.text('Réglages'), findsNothing);
    expect(
      tester.getSemantics(find.byType(AntiqueButton)).label,
      'Réglages',
    );
  });

  testWidgets('AntiqueButton actif expose sa sélection', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AntiqueButton(
          label: 'Identité du livre',
          active: true,
          onParchment: true,
          onTap: _noop,
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(AntiqueButton));

    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isSelected, ui.Tristate.isTrue);
  });

  testWidgets('AntiqueButton active son action avec Entrée après focus',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AntiqueButton(label: 'Exporter', onTap: () => taps++),
      ),
    );

    Focus.of(
      tester.element(find.byKey(const ValueKey('antique-button-focus'))),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(taps, 1);
  });

  testWidgets('RibbonTab active son action avec Espace après focus',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: RibbonTab(
          label: 'Manuscrit',
          color: Colors.brown,
          onTap: () => taps++,
        ),
      ),
    );

    Focus.of(
      tester.element(find.byKey(const ValueKey('ribbon-tab-focus'))),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(taps, 1);
  });
}

void _noop() {}
