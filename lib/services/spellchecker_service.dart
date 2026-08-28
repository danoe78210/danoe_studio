import 'dart:convert';
import 'package:http/http.dart' as http;

class SpellMatch {
  final String message;
  final String contextText;
  final int offset;
  final int length;
  final List<String> suggestions;

  const SpellMatch({
    required this.message,
    required this.contextText,
    required this.offset,
    required this.length,
    required this.suggestions,
  });

  factory SpellMatch.fromJson(Map<String, dynamic> m, int base) {
    final ctx = (m['context'] as Map<String, dynamic>?) ?? {};
    final reps = (m['replacements'] as List?) ?? [];
    return SpellMatch(
      message: (m['message'] as String?) ?? '',
      contextText: (ctx['text'] as String?) ?? '',
      offset: ((m['offset'] as int?) ?? 0) + base,
      length: (m['length'] as int?) ?? 0,
      suggestions:
          reps.take(5).map((r) => (r['value'] as String?) ?? '').toList(),
    );
  }
}

class _Chunk {
  final String text;
  final int offset;
  const _Chunk(this.text, this.offset);
}

class SpellcheckerService {
  static const String _url = 'https://api.languagetool.org/v2/check';

  /// Vérifie un texte long (découpage automatique).
  /// [onProgress] reçoit une fraction 0.0 → 1.0 au fil des chunks.
  Future<List<SpellMatch>> checkText(
    String texte, {
    String level = 'default',
    String variant = 'fr-FR',
    void Function(double fraction)? onProgress,
  }) async {
    final resultats = <SpellMatch>[];
    final chunks = _decouper(texte, 5000);

    for (var i = 0; i < chunks.length; i++) {
      onProgress?.call(chunks.isEmpty ? 0 : i / chunks.length);
      final chunk = chunks[i];
      final body = <String, String>{
        'text': chunk.text,
        'level': level,
        if (variant.isNotEmpty)
          ...{'language': 'auto', 'preferredVariants': variant}
        else
          ...{'language': 'fr'},
      };

      try {
        final resp = await http.post(Uri.parse(_url), body: body);
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          for (final m in (data['matches'] as List? ?? [])) {
            resultats
                .add(SpellMatch.fromJson(m as Map<String, dynamic>, chunk.offset));
          }
        }
      } catch (_) {
        // On continue avec les autres chunks
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    onProgress?.call(1.0);
    return resultats;
  }

  List<_Chunk> _decouper(String texte, int max) {
    final chunks = <_Chunk>[];
    var debut = 0;
    while (debut < texte.length) {
      var fin = (debut + max > texte.length) ? texte.length : debut + max;
      if (fin < texte.length) {
        final idx = texte.lastIndexOf('\n\n', fin);
        if (idx > debut + max ~/ 2) {
          fin = idx + 2;
        } else {
          final sp = texte.lastIndexOf(' ', fin);
          if (sp > debut) fin = sp + 1;
        }
      }
      chunks.add(_Chunk(texte.substring(debut, fin), debut));
      debut = fin;
    }
    return chunks;
  }
}