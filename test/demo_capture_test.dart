import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:danoestudio/main.dart';

void main() {
  for (final capture in const [
    ('01-reglages.png', 0, 'Réglages'),
    ('02-informations.png', 1, 'Informations'),
    ('03-organisation.png', 2, 'Organisation'),
    ('04-correction.png', 3, 'Correction'),
    ('05-production.png', 4, 'Production'),
    ('06-lecture.png', 5, 'Lecture'),
    ('07-registre.png', 6, 'Registre'),
    ('08-contact.png', 7, 'Contact'),
  ]) {
    testWidgets('capture ${capture.$3}', (tester) async {
      const surfaceSize = Size(1600, 1000);
      // final captureKey = GlobalKey();
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: RepaintBoundary(
            // key: captureKey,
            child: DanoeStudioApp(
              captureMode: true,
              initialPage: capture.$2,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(capture.$3), findsWidgets);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  }
}
