import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/antique_theme.dart';
import '../widgets/antique_button.dart';
import '../widgets/gothic_divider.dart';
import '../widgets/parchment_card.dart';
import '../widgets/ornate_corners.dart';
import '../widgets/filigree_watermark.dart';
import '../widgets/ribbon_tab.dart';
import '../widgets/ambiance.dart';
import '../widgets/lettrine.dart';
import '../widgets/page_curl.dart';
import '../widgets/qr_code_card.dart';
import '../services/python_engine.dart';
import '../services/spellchecker_service.dart';
import 'k2000_scanner.dart';

enum LogKind { line, ok, warn, head }

class LogLine {
  final String text;
  final LogKind kind;
  const LogLine(this.text, this.kind);
}

class _ResultCorrection {
  final String? valeur;
  final bool ignoreAll;
  const _ResultCorrection({this.valeur, this.ignoreAll = false});
}

class _AppSettings {
  final String scriptsDir;
  final String pythonPath;
  final String spellLevel;
  final String spellVariant;
  final String texteFont;
  final String titresFont;
  final String texteSize;
  final String titresSize;
  final String interligne;
  const _AppSettings({
    required this.scriptsDir,
    required this.pythonPath,
    required this.spellLevel,
    required this.spellVariant,
    required this.texteFont,
    required this.titresFont,
    required this.texteSize,
    required this.titresSize,
    required this.interligne,
  });
}

const List<String> kPolices = [
  'Aptos', 'Cinzel', 'Garamond', 'Times New Roman', 'Georgia',
  'Calibri', 'Arial', 'Book Antiqua', 'Palatino Linotype', 'Cambria',
];
const List<String> kTaillesTexte = ['10', '10.5', '11', '11.5', '12', '13', '14'];
const List<String> kTaillesTitres = ['12', '13', '14', '16', '18', '20', '22', '24'];
const List<String> kInterlignes = ['1.0', '1.15', '1.25', '1.5'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const String _defaultScriptsDir = r'C:\Users\danao\Downloads\Python';

  String _scriptsDir = trouverDossierBackend() ?? _defaultScriptsDir;
  String _pythonPath = 'python';
  String _spellLevel = 'default';
  String _spellVariant = 'fr-FR';
  String _modeGeneration = 'exact';
  String _texteFont = 'Aptos';
  String _titresFont = 'Cinzel';
  String _texteSize = '11';
  String _titresSize = '14';
  String _interligne = '1.0';

  late PythonEngine _engine = PythonEngine(scriptsDir: _scriptsDir, pythonPath: _pythonPath);
  final SpellcheckerService _spell = SpellcheckerService();

  final List<LogLine> _logs = [];
  final ScrollController _scroll = ScrollController();
  bool _busy = false;
  String _tacheCourante = '';
  String? _chapitre;
  List<String> _chapitres = [];
  List<Map<String, dynamic>> _organisation = [];
  double _progressTarget = 0;
  String _phase = '';
  int _loadedChapters = 0;
  Timer? _creep;

  int _page = 0;
  int _depuis = 0;
  int _cible = 0;
  bool _turning = false;
  double _turnT = 0;
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  // ══ INFOS DU LIVRE ══
  final TextEditingController _iTitre = TextEditingController();
  final TextEditingController _iSousTitre = TextEditingController();
  final TextEditingController _iAuteur = TextEditingController();
  final TextEditingController _iAnnee = TextEditingController();
  final TextEditingController _iIsbn = TextEditingController();
  final TextEditingController _iDedicace = TextEditingController();
  final TextEditingController _iEpigraphe = TextEditingController();

  String _statOuvrage = '—';
  String _statFormat = '—';
  String _statMots = '—';
  String _statPages = '—';
  String _statChapitres = '—';
  String _statIllus = '—';

  String get _configPath {
    final home = Platform.environment['USERPROFILE'] ?? '.';
    return '$home\\danoestudio_config.json';
  }

  String get _configRomanPath => '$_scriptsDir\\Configuration_roman.json';

  @override
  void initState() {
    super.initState();
    _flip.addListener(() => setState(() => _turnT = Curves.easeInOut.transform(_flip.value)));
    _flip.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() { _page = _cible; _turning = false; });
      }
    });
    _chargerConfigSync();
    _chargerChapitres();
    _chargerOrganisation();
    _chargerInfos();
    _log('✅ Danoë Studio prêt.', kind: LogKind.ok);
    _log('🔧 Backend Python : $_scriptsDir', kind: LogKind.head);
  }

  @override
  void dispose() {
    _creep?.cancel();
    _flip.dispose();
    _scroll.dispose();
    _iTitre.dispose(); _iSousTitre.dispose(); _iAuteur.dispose();
    _iAnnee.dispose(); _iIsbn.dispose(); _iDedicace.dispose(); _iEpigraphe.dispose();
    super.dispose();
  }

  void _allerA(int i) {
    if (_turning || i == _page) return;
    setState(() { _depuis = _page; _cible = i; _turning = true; });
    _flip.forward(from: 0);
  }

  // ══ Navigation clavier ← / → ══
  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final n = _rubanLabels.length;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _allerA((_page + 1) % n);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _allerA((_page + n - 1) % n);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _chargerConfigSync() {
    try {
      final f = File(_configPath);
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        final sv = data['scriptsDir'] as String?;
        final det = trouverDossierBackend();
        _scriptsDir = (sv != null && Directory(sv).existsSync()) ? sv : (det ?? sv ?? _defaultScriptsDir);
        _pythonPath = (data['pythonPath'] as String?) ?? 'python';
        _spellLevel = (data['spellLevel'] as String?) ?? 'default';
        _spellVariant = (data['spellVariant'] as String?) ?? 'fr-FR';
        _modeGeneration = (data['modeGeneration'] as String?) ?? 'exact';
        _texteFont = (data['texteFont'] as String?) ?? 'Aptos';
        _titresFont = (data['titresFont'] as String?) ?? 'Cinzel';
        _texteSize = (data['texteSize'] as String?) ?? '11';
        _titresSize = (data['titresSize'] as String?) ?? '14';
        _interligne = (data['interligne'] as String?) ?? '1.0';
        _engine = PythonEngine(scriptsDir: _scriptsDir, pythonPath: _pythonPath);
      }
    } catch (_) {}
  }

  void _sauverConfig() {
    try {
      File(_configPath).writeAsStringSync(jsonEncode({
        'scriptsDir': _scriptsDir, 'pythonPath': _pythonPath, 'spellLevel': _spellLevel,
        'spellVariant': _spellVariant, 'modeGeneration': _modeGeneration,
        'texteFont': _texteFont, 'titresFont': _titresFont, 'texteSize': _texteSize,
        'titresSize': _titresSize, 'interligne': _interligne,
      }));
    } catch (_) {}
  }

  void _ecrireStylePython() {
    try {
      final f = File(_configRomanPath);
      Map<String, dynamic> d = {};
      if (f.existsSync()) {
        final x = jsonDecode(f.readAsStringSync());
        if (x is Map<String, dynamic>) d = x;
      }
      final style = (d['style'] is Map) ? Map<String, dynamic>.from(d['style'] as Map) : <String, dynamic>{};
      final tt = double.tryParse(_texteSize) ?? 11;
      final tz = double.tryParse(_titresSize) ?? 14;
      style['police_corps'] = _texteFont;
      style['police_titres'] = _titresFont;
      style['police_lettrine'] = _titresFont;
      style['taille_corps_pt'] = tt;
      style['taille_titres_acte_pt'] = tz + 2;
      style['taille_chapitre_ligne1_pt'] = tz;
      style['taille_chapitre_ligne2_pt'] = tz - 1;
      style['taille_sous_chapitre_pt'] = tz - 2;
      style['interligne_corps'] = double.tryParse(_interligne) ?? 1.0;
      d['style'] = style;
      f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(d));
      _log('🎨 Style écrit dans Configuration_roman.json.', kind: LogKind.ok);
    } catch (e) {
      _log('⚠️ Écriture du style impossible : $e', kind: LogKind.warn);
    }
  }

  void _chargerChapitres() {
    final dir = Directory('$_scriptsDir\\Chapitres');
    if (dir.existsSync()) {
      setState(() {
        _chapitres = dir.listSync().whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.endsWith('.md')).toList()..sort();
        if (_chapitres.isNotEmpty) _chapitre = _chapitres.first;
      });
    }
  }

  void _chargerInfos() {
    try {
      final f = File(_configRomanPath);
      if (!f.existsSync()) return;
      final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final inf = (d['informations'] as Map?) ?? {};
      String g(String k) => (inf[k] ?? '').toString();
      _iTitre.text = g('titre complet du roman');
      _iSousTitre.text = g('sous-titre éventuel');
      _iAuteur.text = g("nom de l'auteur (couverture)");
      _iAnnee.text = g('année de publication');
      _iIsbn.text = g('isbn');
      _iDedicace.text = g('dédicace');
      _iEpigraphe.text = g('épigraphe');
    } catch (_) {}
  }

  void _sauverInfos() {
    try {
      final f = File(_configRomanPath);
      Map<String, dynamic> d = {};
      if (f.existsSync()) {
        final x = jsonDecode(f.readAsStringSync());
        if (x is Map<String, dynamic>) d = x;
      }
      d['informations'] = {
        'titre complet du roman': _iTitre.text.trim(),
        'sous-titre éventuel': _iSousTitre.text.trim(),
        "nom de l'auteur (couverture)": _iAuteur.text.trim(),
        'année de publication': _iAnnee.text.trim(),
        'isbn': _iIsbn.text.trim(),
        'dédicace': _iDedicace.text,
        'épigraphe': _iEpigraphe.text,
      };
      f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(d));
      _log('💾 Informations du livre sauvegardées.', kind: LogKind.ok);
    } catch (e) {
      _log('⚠️ Sauvegarde impossible : $e', kind: LogKind.warn);
    }
  }

  void _chargerOrganisation() {
    try {
      final f = File(_configRomanPath);
      if (f.existsSync()) {
        final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        final chap = (d['chapitres'] as List?) ?? [];
        _organisation = chap.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
  }

  void _sauverOrganisation() {
    try {
      final f = File(_configRomanPath);
      Map<String, dynamic> d = {};
      if (f.existsSync()) {
        final x = jsonDecode(f.readAsStringSync());
        if (x is Map<String, dynamic>) d = x;
      }
      d['chapitres'] = _organisation;
      f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(d));
      _log('💾 Organisation sauvegardée.', kind: LogKind.ok);
    } catch (e) {
      _log('⚠️ Sauvegarde impossible : $e', kind: LogKind.warn);
    }
  }

  String _labelOrg(Map<String, dynamic> e) {
    final t = (e['type'] ?? '').toString();
    if (t == 'acte') return (e['acte'] ?? '').toString();
    if (t == 'image') return (e['image'] ?? '').toString();
    final l = (e['titre'] ?? e['fichier_source'] ?? '').toString();
    return l.isEmpty ? '(chapitre)' : l;
  }

  void _monter(int i) {
    if (i <= 0) return;
    setState(() {
      final t = _organisation[i - 1]; _organisation[i - 1] = _organisation[i]; _organisation[i] = t;
    });
    _sauverOrganisation();
  }

  void _descendre(int i) {
    if (i >= _organisation.length - 1) return;
    setState(() {
      final t = _organisation[i + 1]; _organisation[i + 1] = _organisation[i]; _organisation[i] = t;
    });
    _sauverOrganisation();
  }

  void _supprimer(int i) {
    final e = _organisation[i];
    setState(() { _organisation.removeAt(i); });
    _sauverOrganisation();
    _log('🗑 Élément retiré : ${_labelOrg(e)}', kind: LogKind.ok);
  }

  Future<String?> _saisirTexte(String titre, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AntiqueTheme.leatherDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(titre, style: GoogleFonts.cinzel(color: AntiqueTheme.agedGold, fontSize: 16)),
      content: TextField(controller: ctrl, autofocus: true,
        style: const TextStyle(color: Color(0xFFE8EAF6)),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Color(0xFF6B7194)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Ajouter')),
      ]));
  }

  Future<void> _ajouterActe() async {
    final nom = await _saisirTexte('Nouvel acte', "Nom de l'acte");
    if (nom == null || nom.trim().isEmpty) return;
    setState(() => _organisation.add({'type': 'acte', 'acte': nom.trim()}));
    _sauverOrganisation();
    _log('➕ Acte ajouté : $nom', kind: LogKind.ok);
  }

  Future<void> _ajouterChapitre() async {
    final nom = await _saisirTexte('Nouveau chapitre', 'Titre du chapitre');
    if (nom == null || nom.trim().isEmpty) return;
    int maxN = 0;
    for (final e in _organisation) {
      if (e['type'] == 'chapitre') {
        final m = RegExp(r'(\d+)\.').firstMatch((e['fichier_source'] ?? '').toString());
        if (m != null) { final v = int.parse(m.group(1)!); if (v > maxN) maxN = v; }
      }
    }
    final pref = '${maxN + 1}.1';
    try {
      final f = File('$_scriptsDir\\Chapitres\\$pref.md');
      if (!f.existsSync()) f.writeAsStringSync('# $nom\n\n');
    } catch (_) {}
    setState(() => _organisation.add({'type': 'chapitre', 'fichier_source': pref, 'chapitre_ligne1': nom.trim(), 'titre': nom.trim()}));
    _sauverOrganisation();
    _chargerChapitres();
    _log('➕ Chapitre ajouté : $nom', kind: LogKind.ok);
  }

  Future<void> _ajouterImage() async {
    final dir = Directory('$_scriptsDir\\Images');
    if (!dir.existsSync()) { _log('⚠️ Dossier Images introuvable.', kind: LogKind.warn); return; }
    final imgs = dir.listSync().whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.toLowerCase().endsWith('.png') || n.toLowerCase().endsWith('.jpg'))
        .toList()..sort();
    if (imgs.isEmpty) { _log('⚠️ Aucune image dans le dossier Images.', kind: LogKind.warn); return; }
    final choix = await showDialog<String>(context: context,
        builder: (ctx) => _ChoixDialog(titre: 'Choisir une image', items: imgs));
    if (choix == null) return;
    setState(() => _organisation.add({'type': 'image', 'image': choix}));
    _sauverOrganisation();
    _log('➕ Image ajoutée : $choix', kind: LogKind.ok);
  }

  void _log(String text, {LogKind kind = LogKind.line}) {
    setState(() => _logs.add(LogLine(text, kind)));
    if (kind == LogKind.warn) _ecrireErreurMd(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String get _journalErreursPath => '$_scriptsDir\\journal_erreurs.md';

  void _ecrireErreurMd(String texte) {
    try {
      final f = File(_journalErreursPath);
      if (!f.existsSync()) f.writeAsStringSync('# 📥 Journal des erreurs – Danoë Studio\n\n');
      final n = DateTime.now();
      String d2(int v) => v.toString().padLeft(2, '0');
      final ts = '${n.year}-${d2(n.month)}-${d2(n.day)} ${d2(n.hour)}:${d2(n.minute)}:${d2(n.second)}';
      final tache = _tacheCourante.isEmpty ? '—' : _tacheCourante;
      final err = texte.replaceFirst('⚠️', '').trim();
      f.writeAsStringSync('### $ts\nTâche : $tache\nErreur : $err\n\n', mode: FileMode.append);
    } catch (_) {}
  }

  void _ouvrirJournal() {
    try {
      final f = File(_journalErreursPath);
      if (!f.existsSync()) f.writeAsStringSync('# 📥 Journal des erreurs – Danoë Studio\n\nAucune erreur.\n');
      Process.run('explorer', ['/select,', f.path]);
      _log('📥 Journal ouvert.', kind: LogKind.ok);
    } catch (e) {
      _log('⚠️ Ouverture impossible : $e', kind: LogKind.warn);
    }
  }

  Color _logColor(LogKind k) {
    switch (k) {
      case LogKind.ok: return const Color(0xFF9BE0A8);
      case LogKind.warn: return const Color(0xFFE08585);
      case LogKind.head: return AntiqueTheme.agedGold;
      case LogKind.line: return AntiqueTheme.parchment;
    }
  }

  void _parseStats(String line) {
    final l = line.trim();
    String? val(String e) {
      if (!l.startsWith(e)) return null;
      final i = l.indexOf(':');
      return (i != -1) ? l.substring(i + 1).trim() : null;
    }
    setState(() {
      var x = val('📖'); if (x != null) _statOuvrage = x;
      x = val('📐'); if (x != null) _statFormat = x;
      x = val('🔤'); if (x != null) _statMots = x;
      x = val('📑'); if (x != null) _statPages = x;
      x = val('📚'); if (x != null) _statChapitres = x;
      x = val('🖼'); if (x != null) _statIllus = x;
    });
  }

  void _push(double t, String p) {
    setState(() {
      if (t > _progressTarget) _progressTarget = t;
      _phase = p;
    });
  }

  void _trackProgress(String line) {
    final l = line.trim();
    if (l.startsWith('🧩') || l.startsWith('📋')) { _push(6, 'Configuration'); }
    else if (l.startsWith('🎨')) { _push(10, 'Style'); }
    else if (l.startsWith('📏')) { _push(14, 'Marges KDP'); }
    else if (l.startsWith('📄') && l.contains('blocs')) {
      _loadedChapters++;
      final t = _chapitres.isEmpty ? 1 : _chapitres.length;
      _push(14 + 31 * (_loadedChapters / t), 'Chargement des chapitres');
    }
    else if (l.startsWith('📊 Organisation')) { _push(48, 'Construction'); }
    else if (l.startsWith('🖼')) { _push((_progressTarget + 2).clamp(0, 80).toDouble(), 'Illustrations'); }
    else if (l.startsWith('✅ Document généré')) { _push(85, 'Enregistrement'); }
    else if (l.startsWith('✅ TDM')) { _push(92, 'Table des matières'); }
    else if (l.startsWith('📑 Comptage')) { _push(95, 'Comptage des pages'); }
    else if (l.startsWith('📊 STATISTIQUES')) { _push(100, 'Terminé'); }
    else if (l.startsWith('🖨')) { _push(30, 'Export PDF'); }
    else if (l.startsWith('🖤')) { _push(50, 'Noir & blanc'); }
    else if (l.startsWith('📑 Export HD')) { _push(70, 'Export PDF'); }
    else if (l.startsWith('✅ PDF KDP prêt') || l.startsWith('✅ PDF prêt')) { _push(100, 'Terminé'); }
    else if (l.startsWith('📱')) { _push(30, 'Ebook'); }
    else if (l.startsWith('✅') && l.toLowerCase().contains('epub')) { _push(100, 'Terminé'); }
  }

  Future<void> _run(String label, Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true; _tacheCourante = label; _progressTarget = 2;
      _phase = 'Démarrage…'; _loadedChapters = 0;
    });
    _log('▶ $label…', kind: LogKind.head);
    _creep?.cancel();
    _creep = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_progressTarget < 95) {
        setState(() { _progressTarget = (_progressTarget + 0.3).clamp(0, 95).toDouble(); });
      }
    });
    try {
      await task();
      setState(() { _progressTarget = 100; _phase = 'Terminé'; });
      await Future.delayed(const Duration(milliseconds: 700));
    } catch (e) {
      _log('⚠️ Erreur : $e', kind: LogKind.warn);
      setState(() => _phase = 'Erreur');
    } finally {
      _creep?.cancel();
      setState(() => _busy = false);
    }
  }

  Future<void> _genererLivre() {
    final rapide = _modeGeneration == 'rapide';
    final args = rapide ? const ['--rapide'] : const <String>[];
    return _run('Génération du livre (mode ${rapide ? "rapide" : "exact"})',
        () => _engine.runScript('generer_roman.py', args: args, onLine: _surLigne));
  }

  Future<void> _exportPdf() => _run('Export PDF KDP',
      () => _engine.runScript('generer_pdf_direct.py', onLine: _surLigne));

  Future<void> _genererEbook() => _run('Génération EPUB',
      () => _engine.runScript('generer_ebook.py', onLine: _surLigne));

  Future<void> _resumesIA() => _run('Résumés IA',
      () => _engine.runScript('IA_Roman.py', onLine: (l) => _log(l)));

  void _surLigne(String l) {
    _log(l, kind: l.startsWith('⚠️') ? LogKind.warn : LogKind.line);
    _parseStats(l);
    _trackProgress(l);
  }

  Future<void> _lireDocument(String type) async {
    final ext = type == 'word' ? '.docx' : (type == 'pdf' ? '.pdf' : '.epub');
    final dir = Directory(_scriptsDir);
    if (!dir.existsSync()) { _log('⚠️ Dossier backend introuvable.', kind: LogKind.warn); return; }
    final fs = dir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith(ext)).toList();
    if (fs.isEmpty) { _log('⚠️ Aucun fichier $ext généré.', kind: LogKind.warn); return; }
    fs.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    _log('📖 Ouverture : ${fs.first.uri.pathSegments.last}', kind: LogKind.ok);
    try {
      await Process.run(fs.first.path, [], runInShell: true);
    } catch (e) {
      _log('⚠️ Ouverture impossible : $e', kind: LogKind.warn);
    }
  }

  void _ouvrirDossier(String s) {
    final chemin = '$_scriptsDir\\$s';
    try {
      Directory(chemin).createSync(recursive: true);
      Process.run('explorer', [chemin]);
      _log('📂 Ouvert : $s', kind: LogKind.ok);
    } catch (e) {
      _log('⚠️ Ouverture impossible : $e', kind: LogKind.warn);
    }
  }

  Future<void> _ouvrirParametres() async {
    final res = await showDialog<_AppSettings>(
      context: context,
      builder: (ctx) => _SettingsDialog(initial: _AppSettings(
        scriptsDir: _scriptsDir, pythonPath: _pythonPath, spellLevel: _spellLevel,
        spellVariant: _spellVariant, texteFont: _texteFont, titresFont: _titresFont,
        texteSize: _texteSize, titresSize: _titresSize, interligne: _interligne)),
    );
    if (res == null) return;
    setState(() {
      _scriptsDir = res.scriptsDir; _pythonPath = res.pythonPath;
      _spellLevel = res.spellLevel; _spellVariant = res.spellVariant;
      _texteFont = res.texteFont; _titresFont = res.titresFont;
      _texteSize = res.texteSize; _titresSize = res.titresSize; _interligne = res.interligne;
      _engine = PythonEngine(scriptsDir: _scriptsDir, pythonPath: _pythonPath);
    });
    _sauverConfig();
    _ecrireStylePython();
    _chargerChapitres();
    _log('⚙️ Paramètres sauvegardés.', kind: LogKind.ok);
  }

  Future<void> _corriger() => _run('Vérification orthographique', () async {
    if (_chapitre == null) { _log('⚠️ Sélectionnez un chapitre.', kind: LogKind.warn); return; }
    final file = File('$_scriptsDir\\Chapitres\\$_chapitre');
    final texte = await file.readAsString();
    _log('🔍 Analyse de « $_chapitre »…', kind: LogKind.head);
    final ms = await _spell.checkText(texte, level: _spellLevel, variant: _spellVariant,
        onProgress: (f) => _push(10 + 45 * f, 'Analyse LanguageTool'));
    if (ms.isEmpty) { _log('✅ Aucune erreur détectée.', kind: LogKind.ok); return; }
    _log('⚠️ ${ms.length} anomalie(s) détectée(s).', kind: LogKind.warn);
    var tf = texte; var nb = 0; var ignorer = false;
    final tri = [...ms]..sort((a, b) => b.offset.compareTo(a.offset));
    var i = 0;
    for (final m in tri) {
      i++;
      if (ignorer) break;
      _push(60 + 35 * (i / tri.length), 'Correction $i/${tri.length}');
      final err = tf.substring(m.offset, m.offset + m.length);
      _log('  → « $err » : ${m.message}');
      if (!mounted) return;
      final res = await showDialog<_ResultCorrection>(
          context: context, builder: (ctx) => _CorrectionDialog(match: m));
      if (res == null) continue;
      if (res.ignoreAll) { ignorer = true; continue; }
      if (res.valeur != null && res.valeur!.isNotEmpty) {
        tf = tf.replaceRange(m.offset, m.offset + m.length, res.valeur!);
        nb++;
      }
    }
    if (nb > 0) {
      _push(97, 'Sauvegarde');
      await file.writeAsString(tf);
      _log('💾 $nb correction(s) appliquée(s).', kind: LogKind.ok);
    } else {
      _log('ℹ️ Aucune modification appliquée.');
    }
  });

  // ══════════════════════════════════════════════════════════════
  //  INTERFACE — livre avec PageCurl réaliste
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AntiqueTheme.inkBlack,
      body: Focus(
        autofocus: true,
        onKey: _onKey,
        child: Stack(children: [
          Row(children: [Expanded(child: _mainArea())]),
          const Positioned.fill(child: Ambiance()),
        ]),
      ),
    );
  }

  Widget _mainArea() {
    return Padding(padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 4),
        Opacity(opacity: _busy ? 1.0 : 0.0,
          child: Padding(padding: const EdgeInsets.only(bottom: 8),
            child: _ProgressIndicator(target: _progressTarget, phase: _phase))),
        Opacity(opacity: _busy ? 1.0 : 0.0,
          child: Padding(padding: const EdgeInsets.only(bottom: 8),
            child: K2000Scanner(active: _busy, height: 24))),
        Expanded(flex: 6, child: RepaintBoundary(child: _livre())),
        const SizedBox(height: 10),
        Expanded(flex: 4, child: RepaintBoundary(child: _console())),
      ]));
  }

  static const List<String> _rubanLabels = [
    'Informations', 'Organisation', 'Correction', 'Réglages',
    'Production', 'Lecture', 'Registre', 'Contact',
  ];
  static const List<String> _rubanEmojis = [
    '📜', '', '', '⚙', '▶', '📖', '', '🌐',
  ];
  static const List<Color> _rubanCouleurs = [
    Color(0xFF7A4A22), Color(0xFF4E8577), Color(0xFF6B3FA0), Color(0xFFB8860B),
    Color(0xFF8E2A2A), Color(0xFF2E4E7E), Color(0xFF2F6B3A), Color(0xFF6B5A8E),
  ];

  Widget _livre() {
    return LayoutBuilder(builder: (c, cons) {
      final bw = cons.maxWidth;
      final bh = cons.maxHeight;
      const pad = 16.0;
      final pageW = (bw - pad * 2 - 14) / 2;
      final pageH = bh - pad * 2;
      return SizedBox(width: bw, height: bh, child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: Container(decoration: BoxDecoration(
          gradient: AntiqueTheme.leatherGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A180C), width: 2),
          boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: const Offset(0, 8))]))),
        Positioned(left: pad, top: pad, width: pageW, height: pageH,
            child: _parchemin(child: _pageTitre())),
        Positioned(left: bw / 2 + 8, top: pad, width: pageW, height: pageH,
            child: _parchemin(child: _pageContenu(_turning ? _cible : _page))),
        if (_turning)
          Positioned(left: bw / 2 + 8, top: pad, width: pageW, height: pageH,
              child: _feuilleTourne()),
        Positioned(left: 6, top: 20, child: Column(children: [
          for (var i = 0; i < _rubanLabels.length; i++) ...[
            RibbonTab(label: _rubanLabels[i], emoji: _rubanEmojis[i], color: _rubanCouleurs[i],
                active: i == _page, onTap: () => _allerA(i)),
            const SizedBox(height: 12),
          ],
        ])),
      ]));
    });
  }

  Widget _parchemin({required Widget child}) {
    return ParchmentCard(
      padding: EdgeInsets.zero,
      child: OrnatePageCorners(child: child),
    );
  }

  Widget _feuilleTourne() {
    return PageCurl(
      t: _turnT,
      front: _parchemin(child: _pageContenu(_depuis)),
    );
  }

  Widget _pageTitre() {
    return SizedBox.expand(child: Stack(children: [
      FiligreeWatermark(),
      Positioned.fill(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 18, 14),
        child: LayoutBuilder(builder: (context, constraints) {
          final showLettrine = constraints.maxHeight >= 380;
          return Column(children: [
            const Spacer(flex: 2),
            FittedBox(fit: BoxFit.scaleDown,
              child: Text('DANOË STUDIO', textAlign: TextAlign.center,
                style: AntiqueTheme.displayLarge)),
            const SizedBox(height: 10),
            Container(width: 140, height: 2,
              decoration: const BoxDecoration(gradient: AntiqueTheme.goldGradient)),
            const SizedBox(height: 10),
            Text('— Machine à romans —', textAlign: TextAlign.center,
              style: AntiqueTheme.titlePage),
            if (showLettrine) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Lettrine(letter: 'D',
                    paragraph: "ans un atelier où l'encre rencontre le cuir, "
                        "chaque page attend son histoire."),
              ),
            ],
            const SizedBox(height: 18),
            Text('❦', style: TextStyle(fontSize: 28, color: AntiqueTheme.agedGold)),
            const SizedBox(height: 18),
            FittedBox(fit: BoxFit.scaleDown,
              child: Text(_statOuvrage, textAlign: TextAlign.center,
                style: AntiqueTheme.titlePage.copyWith(fontSize: 16, fontWeight: FontWeight.w700))),
            const Spacer(flex: 3),
            Text('Ex libris', style: AntiqueTheme.caption),
            const SizedBox(height: 6),
          ]);
        }),
      )),
    ]));
  }

  Widget _pageRegistre() {
    return Padding(padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('REGISTRE'),
        _ligneRegistre('Ouvrage', _statOuvrage),
        _ligneRegistre('Format', _statFormat),
        _ligneRegistre('Mots', _statMots),
        _ligneRegistre('Pages', _statPages),
        _ligneRegistre('Chapitres', _statChapitres),
        _ligneRegistre('Illustr.', _statIllus),
        const Spacer(),
        const Center(child: Text('❦', style: TextStyle(fontSize: 24, color: AntiqueTheme.brass))),
        const SizedBox(height: 8),
      ]));
  }

  Widget _ligneRegistre(String k, String v) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Text(k, style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w700,
            color: AntiqueTheme.bloodInk, letterSpacing: 1)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AntiqueTheme.brass.withOpacity(0.4))),
        const SizedBox(width: 8),
        Flexible(child: Text(v, overflow: TextOverflow.ellipsis,
            style: AntiqueTheme.bodyText.copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
      ]));
  }

  Widget _pageContenu(int i) {
    switch (i) {
      case 0: return _pageInfos();
      case 1: return _pageOrganisation();
      case 2: return _pageCorrection();
      case 3: return _pageReglages();
      case 4: return _pageProduction();
      case 5: return _pageLecture();
      case 6: return _pageRegistre();
      case 7: return _pageContact();
      default: return _pageInfos();
    }
  }

  Widget _titrePage(String t) {
    return SectionTitle(title: t);
  }

  // ══ 1. INFORMATIONS ══
  Widget _pageInfos() {
    return Padding(padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('INFORMATIONS'),
        Expanded(child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          _champInfo('Titre complet du roman', _iTitre),
          _champInfo('Sous-titre éventuel', _iSousTitre),
          _champInfo("Nom de l'auteur (couverture)", _iAuteur),
          Row(children: [
            Expanded(child: _champInfo('Année de publication', _iAnnee)),
            const SizedBox(width: 12),
            Expanded(child: _champInfo('ISBN', _iIsbn)),
          ]),
          _champInfo('Dédicace', _iDedicace, lines: 2),
          _champInfo('Épigraphe', _iEpigraphe, lines: 2),
          const SizedBox(height: 12),
          AntiqueButton(label: 'Enregistrer les informations', emoji: '💾',
              onParchment: true, onTap: _sauverInfos),
          const SizedBox(height: 8),
        ]))),
      ]));
  }

  Widget _champInfo(String label, TextEditingController ctrl, {int lines = 1}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w700,
            color: AntiqueTheme.bloodInk, letterSpacing: 1)),
        TextField(controller: ctrl, maxLines: lines,
          style: AntiqueTheme.bodyText.copyWith(fontSize: 14),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AntiqueTheme.brass)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AntiqueTheme.bloodInk)))),
      ]));
  }

  // ══ 2. ORGANISATION ══
  Widget _pageOrganisation() {
    return Padding(padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('ORGANISATION'),
        Row(children: [
          Text('${_organisation.length} élément(s) — actes, chapitres & images',
            style: AntiqueTheme.titlePage.copyWith(fontSize: 12)),
          const Spacer(),
          InkWell(onTap: () { _chargerOrganisation(); setState(() {});
              _log('🔄 Organisation rechargée.', kind: LogKind.ok); },
            child: Text('🔄 Recharger',
              style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AntiqueTheme.bloodInk))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ajoutBtn('🎭', 'Acte', _ajouterActe)),
          const SizedBox(width: 8),
          Expanded(child: _ajoutBtn('📄', 'Chapitre', _ajouterChapitre)),
          const SizedBox(width: 8),
          Expanded(child: _ajoutBtn('🖼', 'Image', _ajouterImage)),
        ]),
        const SizedBox(height: 10),
        Expanded(child: ListView.builder(
          itemCount: _organisation.length,
          itemBuilder: (c, i) {
            final e = _organisation[i];
            final t = (e['type'] ?? '').toString();
            final icone = t == 'acte' ? '🎭' : (t == 'image' ? '🖼' : '📄');
            return Container(margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: const Color(0x0F000000),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AntiqueTheme.brass, width: 1.1)),
              child: Row(children: [
                SizedBox(width: 26, child: Text('$i',
                  style: TextStyle(fontSize: 11, color: AntiqueTheme.brass))),
                Text(icone, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 10),
                Expanded(child: Text(_labelOrg(e), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AntiqueTheme.bodyText.copyWith(fontSize: 13, fontWeight: FontWeight.w700))),
                _miniBtn('▲', () => _monter(i)),
                const SizedBox(width: 4),
                _miniBtn('▼', () => _descendre(i)),
                const SizedBox(width: 8),
                _miniBtn('🗑', () => _supprimer(i)),
              ]));
          })),
      ]));
  }

  Widget _miniBtn(String s, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(4),
      child: Padding(padding: const EdgeInsets.all(5),
        child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
            color: AntiqueTheme.bloodInk))));
  }

  Widget _ajoutBtn(String icone, String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: const Color(0x142F6B3A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AntiqueTheme.verdigris, width: 1.2)),
        child: Center(child: Text('+ $icone $label',
          style: GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w700,
              color: AntiqueTheme.verdigris)))));
  }

  // ══ 3. CORRECTION ══
  Widget _pageCorrection() {
    return Padding(padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('CORRECTION'),
        _chapitrePicker(),
        const SizedBox(height: 6),
        _actionPage('📝', 'Corriger le chapitre', _corriger),
        const Spacer(),
      ]));
  }

  // ══ 4. RÉGLAGES ══
  Widget _pageReglages() {
    return Padding(padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('RÉGLAGES'),
        _actionPage('⚙', 'Paramètres', _ouvrirParametres),
        _actionPage('🖼', 'Dossier des images', () => _ouvrirDossier('Images')),
        _actionPage('📁', 'Dossier des chapitres', () => _ouvrirDossier('Chapitres')),
        _actionPage('🌐', 'Dossier traductions', () => _ouvrirDossier('Traductions')),
        _actionPage('📥', 'Journal des erreurs', _ouvrirJournal),
        const Spacer(),
      ]));
  }

  // ══ 5. PRODUCTION ══
  Widget _pageProduction() {
    return Padding(padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('PRODUCTION'),
        _modeSelector(),
        const SizedBox(height: 10),
        _actionPage('▶', 'Générer le livre', _genererLivre),
        _actionPage('🖨', 'PDF KDP noir & blanc', _exportPdf),
        _actionPage('📱', 'Ebook KDP (EPUB)', _genererEbook),
        _actionPage('🤖', 'Résumés IA', _resumesIA),
        const Spacer(),
      ]));
  }

  // ══ 6. LECTURE ══
  Widget _pageLecture() {
    return Padding(padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('LECTURE'),
        _actionPage('📖', 'Lire le Word', () => _lireDocument('word')),
        _actionPage('📄', 'Lire le PDF', () => _lireDocument('pdf')),
        _actionPage('📚', "Lire l'EPUB", () => _lireDocument('epub')),
        const Spacer(),
        Text('Ouvre le dernier fichier généré avec\nl\'application par défaut de Windows.',
            textAlign: TextAlign.center, style: AntiqueTheme.titlePage.copyWith(fontSize: 12)),
        const SizedBox(height: 8),
      ]));
  }

  // ══ 7. CONTACT (NOUVEAU) ══
  Widget _pageContact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titrePage('CONTACT'),
          const SizedBox(height: 20),
          QrCodeCard(
            url: 'https://danoeecrivain.net/',
            title: 'Visitez mon site',
            subtitle: 'Scannez pour découvrir mes autres œuvres et projets',
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AntiqueTheme.parchmentMid.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AntiqueTheme.brass.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restons en contact',
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AntiqueTheme.inkSepia,
                  ),
                ),
                const SizedBox(height: 12),
                _contactLine('📧', 'Email', 'contact@danoeecrivain.net'),
                _contactLine('🌐', 'Site web', 'danoeecrivain.net'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactLine(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(
            '$label : ',
            style: GoogleFonts.cinzel(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AntiqueTheme.inkSepia,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.crimsonText(
                fontSize: 14,
                color: AntiqueTheme.inkSepia.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPage(String icone, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AntiqueButton(label: label, emoji: icone, onParchment: true, onTap: onTap),
    );
  }

  Widget _modeSelector() {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: _modeChip('exact', '🎯 Exact')),
        const SizedBox(width: 8),
        Expanded(child: _modeChip('rapide', '⚡ Rapide')),
      ]));
  }

  Widget _modeChip(String mode, String label) {
    final on = _modeGeneration == mode;
    return GestureDetector(
      onTap: () { setState(() => _modeGeneration = mode); _sauverConfig(); },
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on ? AntiqueTheme.bloodInk : const Color(0x14000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? AntiqueTheme.bloodInk : AntiqueTheme.brass, width: 1.2)),
        child: Center(child: Text(label,
            style: GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w700,
                color: on ? AntiqueTheme.parchment : AntiqueTheme.inkSepia)))));
  }

  Widget _chapitrePicker() {
    return Container(margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0x14000000), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        isExpanded: true, dropdownColor: AntiqueTheme.parchment,
        style: TextStyle(fontSize: 13, color: AntiqueTheme.inkSepia), value: _chapitre,
        items: [for (final c in _chapitres) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))],
        onChanged: (v) => setState(() => _chapitre = v))));
  }

  Widget _console() {
    return Container(
      decoration: BoxDecoration(color: AntiqueTheme.inkBlack,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AntiqueTheme.leatherDeep, width: 1.5)),
      padding: const EdgeInsets.all(14),
      child: ListView(controller: _scroll, children: [
        for (final l in _logs)
          Padding(padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(l.text, style: TextStyle(fontSize: 13, color: _logColor(l.kind), fontFamily: 'Consolas'))),
      ]));
  }
}

class _ProgressIndicator extends StatelessWidget {
  final double target;
  final String phase;
  const _ProgressIndicator({required this.target, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: LinearProgressIndicator(value: (target / 100).clamp(0.0, 1.0),
          backgroundColor: AntiqueTheme.leatherDark,
          valueColor: const AlwaysStoppedAnimation(AntiqueTheme.agedGold),
          minHeight: 8)),
      const SizedBox(width: 14),
      SizedBox(width: 60, child: Text('${target.round()}%',
          style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: AntiqueTheme.agedGold))),
      const SizedBox(width: 12),
      Expanded(child: Text(phase, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: AntiqueTheme.parchment))),
    ]);
  }
}

class _ChoixDialog extends StatelessWidget {
  final String titre;
  final List<String> items;
  const _ChoixDialog({required this.titre, required this.items});

  @override
  Widget build(BuildContext context) {
    return Dialog(backgroundColor: AntiqueTheme.leatherDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(width: 420, height: 380, child: Column(children: [
        Padding(padding: const EdgeInsets.all(14),
          child: Text(titre, style: GoogleFonts.cinzel(color: AntiqueTheme.agedGold, fontSize: 16, fontWeight: FontWeight.w700))),
        Expanded(child: ListView(children: [
          for (final it in items)
            ListTile(dense: true, title: Text(it, style: const TextStyle(color: Color(0xFFE8EAF6), fontSize: 13)),
              onTap: () => Navigator.pop(context, it)),
        ])),
      ])));
  }
}

class _SettingsDialog extends StatefulWidget {
  final _AppSettings initial;
  const _SettingsDialog({required this.initial});
  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  static const Map<String, String> _levelLabels = {
    'default': 'Standard (Orthographe & Grammaire)', 'picky': 'Exigeant (Style, répétitions)'};
  static const Map<String, String> _variantLabels = {
    'fr-FR': 'Français (France)', 'fr-1990': 'Rectifications 1990', 'fr-CA': 'Français (Canada)',
    'fr-CH': 'Français (Suisse)', 'fr-BE': 'Français (Belgique)'};

  late final TextEditingController _dir = TextEditingController(text: widget.initial.scriptsDir);
  late final TextEditingController _py = TextEditingController(text: widget.initial.pythonPath);
  late String _level = widget.initial.spellLevel;
  late String _variant = widget.initial.spellVariant;
  late String _texteFont = widget.initial.texteFont;
  late String _titresFont = widget.initial.titresFont;
  late String _texteSize = widget.initial.texteSize;
  late String _titresSize = widget.initial.titresSize;
  late String _interligne = widget.initial.interligne;

  @override
  void dispose() { _dir.dispose(); _py.dispose(); super.dispose(); }

  String _label(Map<String, String> map, String code, String defaut) => map[code] ?? map[defaut]!;
  void _setCode(Map<String, String> map, String label, void Function(String) set) {
    final e = map.entries.firstWhere((e) => e.value == label, orElse: () => map.entries.first);
    set(e.key);
  }
  String _dans(List<String> list, String val) => list.contains(val) ? val : list.first;

  @override
  Widget build(BuildContext context) {
    return Dialog(backgroundColor: AntiqueTheme.leatherDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 560, padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("⚙ Paramètres de l'application",
              style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: AntiqueTheme.agedGold)),
          const SizedBox(height: 16),
          _labelChamp('Dossier des scripts Python (backend)'),
          TextField(controller: _dir, style: const TextStyle(color: Color(0xFFE8EAF6)), decoration: _inputStyle()),
          const SizedBox(height: 12),
          _labelChamp('Exécutable Python'),
          TextField(controller: _py, style: const TextStyle(color: Color(0xFFE8EAF6)), decoration: _inputStyle()),
          const SizedBox(height: 12),
          _labelChamp('Niveau du correcteur'),
          _dropdown(value: _label(_levelLabels, _level, 'default'), items: _levelLabels.values.toList(),
              onChanged: (v) => setState(() => _setCode(_levelLabels, v!, (c) => _level = c))),
          const SizedBox(height: 12),
          _labelChamp('Variante orthographique'),
          _dropdown(value: _label(_variantLabels, _variant, 'fr-FR'), items: _variantLabels.values.toList(),
              onChanged: (v) => setState(() => _setCode(_variantLabels, v!, (c) => _variant = c))),
          const SizedBox(height: 16),
          Text('📖 STYLE DU LIVRE',
              style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w700, color: AntiqueTheme.agedGold)),
          const SizedBox(height: 8),
          _labelChamp('Police du corps de texte'),
          _dropdown(value: _dans(kPolices, _texteFont), items: kPolices,
              onChanged: (v) => setState(() => _texteFont = v!)),
          const SizedBox(height: 12),
          _labelChamp('Police des titres & lettrines'),
          _dropdown(value: _dans(kPolices, _titresFont), items: kPolices,
              onChanged: (v) => setState(() => _titresFont = v!)),
          const SizedBox(height: 12),
          _labelChamp('Taille du corps (pt)'),
          _dropdown(value: _dans(kTaillesTexte, _texteSize), items: kTaillesTexte,
              onChanged: (v) => setState(() => _texteSize = v!)),
          const SizedBox(height: 12),
          _labelChamp('Taille des titres (pt)'),
          _dropdown(value: _dans(kTaillesTitres, _titresSize), items: kTaillesTitres,
              onChanged: (v) => setState(() => _titresSize = v!)),
          const SizedBox(height: 12),
          _labelChamp('Interligne du corps'),
          _dropdown(value: _dans(kInterlignes, _interligne), items: kInterlignes,
              onChanged: (v) => setState(() => _interligne = v!)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AntiqueTheme.verdigris, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(context, _AppSettings(
                scriptsDir: _dir.text.trim(), pythonPath: _py.text.trim(), spellLevel: _level,
                spellVariant: _variant, texteFont: _texteFont, titresFont: _titresFont,
                texteSize: _texteSize, titresSize: _titresSize, interligne: _interligne)),
              child: const Text('Sauvegarder')),
          ]),
        ]))));
  }

  Widget _labelChamp(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: const TextStyle(fontSize: 12, color: Color(0xFF9A8B6F))));

  InputDecoration _inputStyle() => InputDecoration(filled: true, fillColor: const Color(0xFF1B2036),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)));

  Widget _dropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFF1B2036), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        isExpanded: true, dropdownColor: const Color(0xFF1B2036),
        style: const TextStyle(color: Color(0xFFE8EAF6)), value: value,
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
        onChanged: onChanged)));
  }
}

class _CorrectionDialog extends StatefulWidget {
  final SpellMatch match;
  const _CorrectionDialog({required this.match});
  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  String? _suggestion;
  final TextEditingController _manuel = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.match.suggestions.isNotEmpty) _suggestion = widget.match.suggestions.first;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Dialog(backgroundColor: AntiqueTheme.leatherDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 560, padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('📝 Correction orthographique',
            style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: AntiqueTheme.agedGold)),
        const SizedBox(height: 12),
        Text(m.message, style: const TextStyle(color: Color(0xFFFF6B6B))),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1B2036), borderRadius: BorderRadius.circular(8)),
          child: Text('…${m.contextText}…', style: const TextStyle(color: Color(0xFFC9CDE0)))),
        const SizedBox(height: 16),
        if (m.suggestions.isNotEmpty) ...[
          const Text('Suggestions :', style: TextStyle(fontSize: 12, color: Color(0xFF6B7194))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(initialValue: _suggestion,
            dropdownColor: const Color(0xFF1B2036),
            style: const TextStyle(color: Color(0xFFE8EAF6)),
            items: [for (final s in m.suggestions) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) => setState(() => _suggestion = v)),
        ],
        const SizedBox(height: 8),
        TextField(controller: _manuel, style: const TextStyle(color: Color(0xFFE8EAF6)),
          decoration: InputDecoration(labelText: 'Ou modifier manuellement',
            labelStyle: const TextStyle(color: Color(0xFF6B7194)), filled: true,
            fillColor: const Color(0xFF1B2036),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 20),
        Row(children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AntiqueTheme.verdigris, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, _ResultCorrection(
                valeur: _manuel.text.isNotEmpty ? _manuel.text : _suggestion)),
            child: const Text('Appliquer')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => Navigator.pop(context, const _ResultCorrection()),
              child: const Text('Ignorer')),
          const Spacer(),
          TextButton(style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            onPressed: () => Navigator.pop(context, const _ResultCorrection(ignoreAll: true)),
            child: const Text('Ignorer tout')),
        ]),
      ])));
  }
}