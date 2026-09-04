import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Localise le dossier backend Python (backend\), en mode debug ET release.
String? trouverDossierBackend() {
  final candidats = <String>[];

  // 1) Dossier courant (flutter run → racine du projet)
  candidats.add(Directory.current.path);

  // 2) Remontée depuis l'exécutable (mode release / exe)
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidats.add(dir.path);
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }

  final sep = Platform.pathSeparator;
  for (final base in candidats) {
    final sous = '$base${sep}backend';
    if (File('$sous${sep}generer_roman.py').existsSync()) return sous;
    if (File('$base${sep}generer_roman.py').existsSync()) return base;
  }
  return null;
}

/// Retourne le Python embarqué placé à côté du dossier backend, s'il existe.
String? trouverPythonAutonome(String scriptsDir) {
  final python =
      File('${Directory(scriptsDir).parent.path}${Platform.pathSeparator}python'
          '${Platform.pathSeparator}python.exe');
  return python.existsSync() ? python.path : null;
}

/// Pont entre Flutter et le moteur Python.
class PythonEngine {
  final String pythonPath;
  final String scriptsDir;

  PythonEngine({this.pythonPath = 'python', required this.scriptsDir});

  /// Lance un script Python et diffuse sa sortie ligne par ligne.
  Future<int> runScript(
    String script, {
    List<String> args = const [],
    void Function(String line)? onLine,
  }) async {
    final process = await Process.start(
      pythonPath,
      ['$scriptsDir\\$script', ...args],
      workingDirectory: scriptsDir,
      runInShell: true,
      // ── CORRECTION UnicodeEncodeError ──────────────────────────
      // Force Python à écrire stdout/stderr en UTF-8 (emojis 🧩📖…),
      // car en sous-processus la sortie est un pipe en cp1252 sinon.
      environment: {
        ...Platform.environment,
        'PYTHONIOENCODING': 'utf-8',
        'PYTHONUTF8': '1',
      },
      // ───────────────────────────────────────────────────────────
    );

    const decoder = Utf8Decoder(allowMalformed: true);
    process.stdout
        .transform(decoder)
        .transform(const LineSplitter())
        .listen((l) => onLine?.call(l));
    process.stderr
        .transform(decoder)
        .transform(const LineSplitter())
        .listen((l) => onLine?.call('⚠️ $l'));

    return process.exitCode;
  }
}
