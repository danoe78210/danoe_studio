import 'package:flutter_test/flutter_test.dart';
import 'package:danoestudio/main.dart';

void main() {
  test('Le widget racine actuel est disponible', () {
    const app = DanoeStudioApp();

    expect(app, isA<DanoeStudioApp>());
  });
}
