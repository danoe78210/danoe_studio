import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
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
  final String formatLivre;
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
    required this.formatLivre,
    required this.texteFont,
    required this.titresFont,
    required this.texteSize,
    required this.titresSize,
    required this.interligne,
  });
}

const List<String> kPolices = [
  'Aptos',
  'Cinzel',
  'Garamond',
  'Times New Roman',
  'Georgia',
  'Calibri',
  'Arial',
  'Book Antiqua',
  'Palatino Linotype',
  'Cambria',
];
const List<String> kTaillesTexte = [
  '10',
  '10.5',
  '11',
  '11.5',
  '12',
  '13',
  '14'
];
const List<String> kTaillesTitres = [
  '12',
  '13',
  '14',
  '16',
  '18',
  '20',
  '22',
  '24'
];
const List<String> kInterlignes = ['1.0', '1.15', '1.25', '1.5'];

const List<String> kFormats = [
  '12,7 x 20,32 cm (5 x 8 po)',
  '13,34 x 20,32 cm (5,25 x 8 po)',
  '13,97 x 21,59 cm (5,5 x 8,5 po)',
  '15,24 x 22,86 cm (6 x 9 po)',
  '17,78 x 25,4 cm (7 x 10 po)',
  '18,99 x 24,61 cm (7,44 x 9,69 po)',
  '20,32 x 25,4 cm (8 x 10 po)',
  '21 x 29,7 cm (A4)',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.captureMode = false, this.initialPage = 0});

  final bool captureMode;
  final int initialPage;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _defaultScriptsDir = r'C:\Users\danao\Downloads\Python';

  String _scriptsDir = trouverDossierBackend() ?? _defaultScriptsDir;
  String _pythonPath = 'python';
  String _spellLevel = 'default';
  String _spellVariant = 'fr-FR';
  String _modeGeneration = 'exact';
  String _formatLivre = '15,24 x 22,86 cm (6 x 9 po)';
  String _texteFont = 'Aptos';
  String _titresFont = 'Cinzel';
  String _texteSize = '11';
  String _titresSize = '14';
  String _interligne = '1.0';

  late PythonEngine _engine =
      PythonEngine(scriptsDir: _scriptsDir, pythonPath: _pythonPath);
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
  late final AnimationController _flip = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  // ══ INFOS DU LIVRE ══
  final TextEditingController _iEditeur = TextEditingController();
  final TextEditingController _iAutresLivres = TextEditingController();
  int _infosPage = 1;
  bool _iSommaire = true;
  final TextEditingController _iTitre = TextEditingController();
  final TextEditingController _iSousTitre = TextEditingController();
  final TextEditingController _iAuteur = TextEditingController();
  final TextEditingController _iAnnee = TextEditingController();
  final TextEditingController _iIsbn = TextEditingController();
  final TextEditingController _iDepotLegal = TextEditingController();
  final TextEditingController _iCopyright = TextEditingController();
  final TextEditingController _iEdition = TextEditingController();
  final TextEditingController _iSiteWeb = TextEditingController();
  final TextEditingController _iAvertissement = TextEditingController();
  final TextEditingController _iDedicace = TextEditingController();
  final TextEditingController _iEpigraphe = TextEditingController();
  final TextEditingController _iRemerciements = TextEditingController();
  String? _iFrontispice;
  String? _iPreface;
  String? _iPostface;

  String get _configPath {
    final home = Platform.environment['USERPROFILE'] ?? '.';
    return '$home\\danoestudio_config.json';
  }

  String get _configRomanPath => '$_scriptsDir\\Configuration_roman.json';

  // ══ Dossier export à la racine du backend ══
  String get _exportPath => '$_scriptsDir\\export';

  void _assurerExport() {
    try {
      Directory(_exportPath).createSync(recursive: true);
    } catch (_) {}
  }

  /// Déplace tous les fichiers générés (.docx/.pdf/.epub) vers export/
  void _deplacerExports() {
    _assurerExport();
    try {
      final src = Directory(_scriptsDir);
      const exts = ['.docx', '.pdf', '.epub'];
      for (final f in src.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final low = name.toLowerCase();
        if (exts.any((e) => low.endsWith(e))) {
          final dest = '$_exportPath\\$name';
          try {
            if (File(dest).existsSync()) File(dest).deleteSync();
            f.renameSync(dest);
          } catch (_) {
            try {
              f.copySync(dest);
              f.deleteSync();
            } catch (_) {}
          }
        }
      }
      _log('📤 Fichiers rangés dans export/.', kind: LogKind.ok);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _flip.addListener(
        () => setState(() => _turnT = Curves.easeInOut.transform(_flip.value)));
    _flip.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          _page = _cible;
          _turning = false;
        });
      }
    });
    _chargerConfigSync();
    final pythonAutonome = trouverPythonAutonome(_scriptsDir);
    if (_pythonPath == 'python' && pythonAutonome != null) {
      _pythonPath = pythonAutonome;
      _engine = PythonEngine(scriptsDir: _scriptsDir, pythonPath: _pythonPath);
    }
    _assurerExport();
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
    _iTitre.dispose();
    _iSousTitre.dispose();
    _iAuteur.dispose();
    _iAnnee.dispose();
    _iIsbn.dispose();
    _iDepotLegal.dispose();
    _iCopyright.dispose();
    _iEdition.dispose();
    _iSiteWeb.dispose();
    _iAvertissement.dispose();
    _iDedicace.dispose();
    _iEpigraphe.dispose();
    super.dispose();
  }

  void _allerA(int i) {
    if (_turning || i == _page) return;
    if (widget.captureMode) {
      setState(() => _page = i);
      return;
    }
    setState(() {
      _depuis = _page;
      _cible = i;
      _turning = true;
    });
    _flip.forward(from: 0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final editing = focusedContext?.widget is EditableText ||
        focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (editing) return KeyEventResult.ignored;
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
        _scriptsDir = (sv != null && Directory(sv).existsSync())
            ? sv
            : (det ?? sv ?? _defaultScriptsDir);
        _pythonPath = (data['pythonPath'] as String?) ?? 'python';
        _spellLevel = (data['spellLevel'] as String?) ?? 'default';
        _spellVariant = (data['spellVariant'] as String?) ?? 'fr-FR';
        _modeGeneration = (data['modeGeneration'] as String?) ?? 'exact';
        _formatLivre =
            (data['formatLivre'] as String?) ?? '15,24 x 22,86 cm (6 x 9 po)';
        _texteFont = (data['texteFont'] as String?) ?? 'Aptos';
        _titresFont = (data['titresFont'] as String?) ?? 'Cinzel';
        _texteSize = (data['texteSize'] as String?) ?? '11';
        _titresSize = (data['titresSize'] as String?) ?? '14';
        _interligne = (data['interligne'] as String?) ?? '1.0';
        _engine =
            PythonEngine(scriptsDir: _scriptsDir, pythonPath: _pythonPath);
      }
    } catch (_) {}
  }

  void _sauverConfig() {
    try {
      File(_configPath).writeAsStringSync(jsonEncode({
        'scriptsDir': _scriptsDir,
        'pythonPath': _pythonPath,
        'spellLevel': _spellLevel,
        'spellVariant': _spellVariant,
        'modeGeneration': _modeGeneration,
        'formatLivre': _formatLivre,
        'texteFont': _texteFont,
        'titresFont': _titresFont,
        'texteSize': _texteSize,
        'titresSize': _titresSize,
        'interligne': _interligne,
      }));
    } catch (_) {}
  }

  // ══ CORRECTION : écrit « format_livre » (clé lue par les scripts Python) ══
  void _ecrireStylePython() {
    try {
      final f = File(_configRomanPath);
      Map<String, dynamic> d = {};
      if (f.existsSync()) {
        final x = jsonDecode(f.readAsStringSync());
        if (x is Map<String, dynamic>) d = x;
      }
      final style = (d['style'] is Map)
          ? Map<String, dynamic>.from(d['style'] as Map)
          : <String, dynamic>{};
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
      style['format_livre'] =
          _formatLivre; // ✅ clé lue par generer_roman.py / generer_pdf_direct.py
      style['format_kdp'] = _formatLivre;
      d['style'] = style;
      d['format_livre'] = _formatLivre;
      f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(d));
      _log('🎨 Style & format écrits dans Configuration_roman.json.',
          kind: LogKind.ok);
    } catch (e) {
      _log('⚠️ Écriture du style impossible : $e', kind: LogKind.warn);
    }
  }

  void _chargerChapitres() {
    final dir = Directory('$_scriptsDir\\Chapitres');
    if (dir.existsSync()) {
      final liste = <String>[];
      for (final f in dir.listSync().whereType<File>()) {
        final nom = f.uri.pathSegments.last;
        if (nom.toLowerCase().endsWith('.md')) {
          liste.add(nom.substring(0, nom.length - 3));
        }
      }
      liste.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _chapitres = liste;
        if (_chapitre != null && !_chapitres.contains(_chapitre)) {
          _chapitre = _chapitres.isNotEmpty ? _chapitres.first : null;
        } else if (_chapitre == null && _chapitres.isNotEmpty) {
          _chapitre = _chapitres.first;
        }
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
      _iEditeur.text =
          (inf['editeur'] ?? inf['Éditeur'] ?? inf['Editeur'] ?? '').toString();
      _iAutresLivres.text =
          (inf['autres_livres'] ?? inf['Autres livres du même auteur'] ?? '')
              .toString();
      _iRemerciements.text = (inf['remerciements'] ?? '').toString();
      var fr = (inf['frontispice'] ?? '').toString();
      _iFrontispice = fr.isEmpty ? null : fr;
      var pf = (inf['preface'] ?? '').toString();
      _iPreface = pf.isEmpty ? null : pf;
      var po = (inf['postface'] ?? '').toString();
      _iPostface = po.isEmpty ? null : po;
      final sv = inf['sommaire'];
      _iSommaire = sv is bool
          ? sv
          : (sv == null ? true : sv.toString().toLowerCase() != 'false');
      _iAnnee.text = g('année de publication');
      _iIsbn.text = g('isbn');
      _iDepotLegal.text =
          (inf['dépôt légal'] ?? inf['depot_legal'] ?? '').toString();
      _iCopyright.text =
          (inf['mention de copyright'] ?? inf['mention_copyright'] ?? '')
              .toString();
      _iEdition.text = (inf['édition'] ?? inf['edition'] ?? '').toString();
      _iSiteWeb.text = (inf['site web'] ?? inf['site_web'] ?? '').toString();
      _iAvertissement.text =
          (inf['avertissement'] ?? inf['Avertissement'] ?? '').toString();
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
        'dépôt légal': _iDepotLegal.text.trim(),
        'depot_legal': _iDepotLegal.text.trim(),
        'mention de copyright': _iCopyright.text.trim(),
        'mention_copyright': _iCopyright.text.trim(),
        'édition': _iEdition.text.trim(),
        'edition': _iEdition.text.trim(),
        'site web': _iSiteWeb.text.trim(),
        'site_web': _iSiteWeb.text.trim(),
        'avertissement': _iAvertissement.text.trim(),
        'editeur': _iEditeur.text,
        'Éditeur': _iEditeur.text,
        'autres_livres': _iAutresLivres.text,
        'remerciements': _iRemerciements.text,
        'frontispice': _iFrontispice ?? '',
        'preface': _iPreface ?? '',
        'postface': _iPostface ?? '',
        'Autres livres du même auteur': _iAutresLivres.text,
        'sommaire': _iSommaire,
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
        _organisation =
            chap.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
      final t = _organisation[i - 1];
      _organisation[i - 1] = _organisation[i];
      _organisation[i] = t;
    });
    _sauverOrganisation();
  }

  void _descendre(int i) {
    if (i >= _organisation.length - 1) return;
    setState(() {
      final t = _organisation[i + 1];
      _organisation[i + 1] = _organisation[i];
      _organisation[i] = t;
    });
    _sauverOrganisation();
  }

  void _supprimer(int i) {
    final e = _organisation[i];
    setState(() {
      _organisation.removeAt(i);
    });
    _sauverOrganisation();
    _log('🗑 Élément retiré : ${_labelOrg(e)}', kind: LogKind.ok);
  }

  Future<String?> _saisirTexte(String titre, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: AntiqueTheme.leatherDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                title: Text(titre,
                    style: GoogleFonts.cinzel(
                        color: AntiqueTheme.agedGold, fontSize: 16)),
                content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: const TextStyle(color: Color(0xFFE8EAF6)),
                    decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(color: Color(0xFF6B7194)))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, ctrl.text),
                      child: const Text('Ajouter')),
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
    _chargerChapitres();
    if (_chapitres.isEmpty) {
      _log('⚠️ Aucun fichier .md dans le dossier Chapitres.',
          kind: LogKind.warn);
      return;
    }
    final choix = await showDialog<String>(
        context: context,
        builder: (ctx) =>
            _ChoixDialog(titre: 'Choisir un chapitre', items: _chapitres));
    if (choix == null || choix.trim().isEmpty) return;
    setState(() => _organisation.add({
          'type': 'chapitre',
          'fichier_source': choix.trim(),
          'chapitre_ligne1': choix.trim(),
          'titre': choix.trim(),
        }));
    _sauverOrganisation();
    _log('➕ Chapitre ajouté : $choix', kind: LogKind.ok);
  }

  Future<void> _ajouterImage() async {
    final dir = Directory('$_scriptsDir\\Images');
    if (!dir.existsSync()) {
      _log('⚠️ Dossier Images introuvable.', kind: LogKind.warn);
      return;
    }
    final fichiersParNom = <String, String>{};
    for (final f in dir.listSync().whereType<File>()) {
      final nom = f.uri.pathSegments.last;
      final ext = nom.toLowerCase();
      if (ext.endsWith('.png') ||
          ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.webp') ||
          ext.endsWith('.bmp')) {
        final idx = nom.lastIndexOf('.');
        final nomAffiche = idx > 0 ? nom.substring(0, idx) : nom;
        fichiersParNom[nomAffiche] = nom;
      }
    }
    final items = fichiersParNom.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (items.isEmpty) {
      _log('⚠️ Aucune image dans le dossier Images.', kind: LogKind.warn);
      return;
    }
    final choixAffiche = await showDialog<String>(
        context: context,
        builder: (ctx) =>
            _ChoixDialog(titre: 'Choisir une image', items: items));
    if (choixAffiche == null || choixAffiche.trim().isEmpty) return;
    final vraiNom = fichiersParNom[choixAffiche] ?? choixAffiche;
    setState(() => _organisation.add({'type': 'image', 'image': vraiNom}));
    _sauverOrganisation();
    _log('➕ Image ajoutée : $choixAffiche', kind: LogKind.ok);
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
      if (!f.existsSync()) {
        f.writeAsStringSync('# 📥 Journal des erreurs – Danoë Studio\n\n');
      }
      final n = DateTime.now();
      String d2(int v) => v.toString().padLeft(2, '0');
      final ts =
          '${n.year}-${d2(n.month)}-${d2(n.day)} ${d2(n.hour)}:${d2(n.minute)}:${d2(n.second)}';
      final tache = _tacheCourante.isEmpty ? '—' : _tacheCourante;
      final err = texte.replaceFirst('⚠️', '').trim();
      f.writeAsStringSync('### $ts\nTâche : $tache\nErreur : $err\n\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  void _ouvrirJournal() {
    try {
      final f = File(_journalErreursPath);
      if (!f.existsSync()) {
        f.writeAsStringSync(
            '# 📥 Journal des erreurs – Danoë Studio\n\nAucune erreur.\n');
      }
      Process.run('explorer', ['/select,', f.path]);
      _log('📥 Journal ouvert.', kind: LogKind.ok);
    } catch (e) {
      _log('⚠️ Ouverture impossible : $e', kind: LogKind.warn);
    }
  }

  Color _logColor(LogKind k) {
    switch (k) {
      case LogKind.ok:
        return const Color(0xFF9BE0A8);
      case LogKind.warn:
        return const Color(0xFFE08585);
      case LogKind.head:
        return AntiqueTheme.agedGold;
      case LogKind.line:
        return AntiqueTheme.parchment;
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
      var x = val('📖');
      if (x != null) _statOuvrage = x;
      x = val('📐');
      if (x != null) _statFormat = x;
      x = val('🔤');
      if (x != null) _statMots = x;
      x = val('📑');
      if (x != null) _statPages = x;
      x = val('📚');
      if (x != null) _statChapitres = x;
      x = val('🖼');
      if (x != null) _statIllus = x;
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
    if (l.startsWith('🧩') || l.startsWith('📋')) {
      _push(6, 'Configuration');
    } else if (l.startsWith('🎨')) {
      _push(10, 'Style');
    } else if (l.startsWith('📏')) {
      _push(14, 'Marges KDP');
    } else if (l.startsWith('📄') && l.contains('blocs')) {
      _loadedChapters++;
      final t = _chapitres.isEmpty ? 1 : _chapitres.length;
      _push(14 + 31 * (_loadedChapters / t), 'Chargement des chapitres');
    } else if (l.startsWith('📊 Organisation')) {
      _push(48, 'Construction');
    } else if (l.startsWith('🖼')) {
      _push((_progressTarget + 2).clamp(0, 80).toDouble(), 'Illustrations');
    } else if (l.startsWith('✅ Document généré')) {
      _push(85, 'Enregistrement');
    } else if (l.startsWith('✅ TDM')) {
      _push(92, 'Table des matières');
    } else if (l.startsWith('📑 Comptage')) {
      _push(95, 'Comptage des pages');
    } else if (l.startsWith('📊 STATISTIQUES')) {
      _push(100, 'Terminé');
    } else if (l.startsWith('🖨')) {
      _push(30, 'Export PDF');
    } else if (l.startsWith('🖤')) {
      _push(50, 'Noir & blanc');
    } else if (l.startsWith('📑 Export HD')) {
      _push(70, 'Export PDF');
    } else if (l.startsWith('✅ PDF KDP prêt') || l.startsWith('✅ PDF prêt')) {
      _push(100, 'Terminé');
    } else if (l.startsWith('📱')) {
      _push(30, 'Ebook');
    } else if (l.startsWith('✅') && l.toLowerCase().contains('epub')) {
      _push(100, 'Terminé');
    }
  }

  Future<void> _run(String label, Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _tacheCourante = label;
      _progressTarget = 2;
      _phase = 'Démarrage…';
      _loadedChapters = 0;
    });
    _log('▶ $label…', kind: LogKind.head);
    _creep?.cancel();
    _creep = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _progressTarget < 99) {
        setState(() {
          _progressTarget = (_progressTarget + 0.2).clamp(0, 99).toDouble();
        });
      }
    });
    try {
      await task();
      if (!mounted) {
        return;
      }
      setState(() {
        _progressTarget = 100;
        _phase = 'Terminé';
      });
      await Future.delayed(const Duration(milliseconds: 700));
    } catch (e) {
      if (mounted) {
        _log('⚠️ Erreur : $e', kind: LogKind.warn);
        setState(() => _phase = 'Erreur');
      }
    } finally {
      _creep?.cancel();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _runPythonScript(
    String script, {
    List<String> args = const [],
    void Function(String line)? onLine,
  }) async {
    final exitCode =
        await _engine.runScript(script, args: args, onLine: onLine);
    if (exitCode != 0) {
      throw StateError('Le script Python "$script" a échoué (code $exitCode).');
    }
  }

  Future<void> _genererLivre() {
    final rapide = _modeGeneration == 'rapide';
    final args = rapide ? const ['--rapide'] : const <String>[];
    return _run(
        'Génération du livre (mode ${rapide ? "rapide" : "exact"})',
        () =>
            _runPythonScript('generer_roman.py', args: args, onLine: _surLigne)
                .then((_) => _deplacerExports()));
  }

  Future<void> _exportPdf() => _run(
      'Export PDF KDP',
      () => _runPythonScript('generer_pdf_direct.py', onLine: _surLigne)
          .then((_) => _deplacerExports()));

  Future<void> _genererEbook() => _run(
      'Génération EPUB',
      () => _runPythonScript('generer_ebook.py', onLine: _surLigne)
          .then((_) => _deplacerExports()));

  Future<void> _resumesIA() => _run('Résumés IA',
      () => _runPythonScript('IA_Roman.py', onLine: (l) => _log(l)));

  void _surLigne(String l) {
    if (!mounted) return;
    _log(l, kind: l.startsWith('⚠️') ? LogKind.warn : LogKind.line);
    _parseStats(l);
    _trackProgress(l);
  }

  Future<void> _lireResume() async {
    try {
      Directory dir = Directory.current;
      Directory? backend;
      for (int i = 0; i < 6; i++) {
        final cand = Directory(path.join(dir.path, 'backend'));
        if (cand.existsSync() &&
            File(path.join(cand.path, 'generer_roman.py')).existsSync()) {
          backend = cand;
          break;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      if (backend == null) {
        _afficherMsg('Dossier backend introuvable');
        return;
      }
      final resumePath = path.join(backend.path, 'Résumé.md');
      if (!File(resumePath).existsSync()) {
        _afficherMsg(
            '« Résumé.md » introuvable. Générez-le via « Résumés IA » (menu Production).');
        return;
      }
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', resumePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [resumePath]);
      } else {
        await Process.run('xdg-open', [resumePath]);
      }
      _log('📝 Ouverture du résumé : $resumePath');
    } catch (e) {
      _afficherMsg('Erreur ouverture résumé : $e');
    }
  }

  void _afficherMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _fermerLivre() async {
    if (_busy) {
      _afficherMsg(
          'Une opération est en cours. Attendez sa fin avant de fermer le livre.');
      return;
    }
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AntiqueTheme.leatherDark,
        title: Text('Fermer le livre', style: AntiqueTheme.titlePage),
        content: const Text(
          'L’application va se fermer et les caches temporaires seront vidés.',
          style: TextStyle(color: AntiqueTheme.parchment),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    if (confirmer != true) return;

    try {
      final cache = Directory(path.join(_scriptsDir, '_cache_HD'));
      if (cache.existsSync()) {
        for (final entry in cache.listSync()) {
          entry.deleteSync(recursive: true);
        }
      }
    } catch (_) {}
    exit(0);
  }

  Future<void> _lireDocument(String type) async {
    final ext = type == 'word' ? '.docx' : (type == 'pdf' ? '.pdf' : '.epub');
    final dirs = [Directory(_exportPath), Directory(_scriptsDir)];
    List<File> fs = [];
    for (final d in dirs) {
      if (!d.existsSync()) continue;
      final found = d
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith(ext))
          .toList();
      if (found.isNotEmpty) {
        fs = found;
        break;
      }
    }
    if (fs.isEmpty) {
      _log('⚠️ Aucun fichier $ext généré.', kind: LogKind.warn);
      return;
    }
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
      builder: (ctx) => _SettingsDialog(
          initial: _AppSettings(
              scriptsDir: _scriptsDir,
              pythonPath: _pythonPath,
              spellLevel: _spellLevel,
              spellVariant: _spellVariant,
              formatLivre: _formatLivre,
              texteFont: _texteFont,
              titresFont: _titresFont,
              texteSize: _texteSize,
              titresSize: _titresSize,
              interligne: _interligne)),
    );
    if (res == null) return;
    setState(() {
      _scriptsDir = res.scriptsDir;
      _pythonPath = res.pythonPath;
      _spellLevel = res.spellLevel;
      _spellVariant = res.spellVariant;
      _formatLivre = res.formatLivre;
      _texteFont = res.texteFont;
      _titresFont = res.titresFont;
      _texteSize = res.texteSize;
      _titresSize = res.titresSize;
      _interligne = res.interligne;
      _engine = PythonEngine(scriptsDir: _scriptsDir, pythonPath: _pythonPath);
    });
    _sauverConfig();
    _ecrireStylePython();
    _assurerExport();
    _chargerChapitres();
    _log('⚙️ Paramètres sauvegardés.', kind: LogKind.ok);
  }

  Future<void> _corriger() => _run('Vérification orthographique', () async {
        if (_chapitre == null) {
          _log('⚠️ Sélectionnez un chapitre.', kind: LogKind.warn);
          return;
        }
        final chapitreFichier = _chapitre!.toLowerCase().endsWith('.md')
            ? _chapitre!
            : '$_chapitre.md';
        final file = File('$_scriptsDir\\Chapitres\\$chapitreFichier');
        final texte = await file.readAsString();
        _log('🔍 Analyse de « $_chapitre »…', kind: LogKind.head);
        final ms = await _spell.checkText(texte,
            level: _spellLevel,
            variant: _spellVariant,
            onProgress: (f) => _push(10 + 45 * f, 'Analyse LanguageTool'));
        if (ms.isEmpty) {
          _log('✅ Aucune erreur détectée.', kind: LogKind.ok);
          return;
        }
        _log('⚠️ ${ms.length} anomalie(s) détectée(s).', kind: LogKind.warn);
        var tf = texte;
        var nb = 0;
        var ignorer = false;
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
          if (res.ignoreAll) {
            ignorer = true;
            continue;
          }
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
  //  INTERFACE
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AntiqueTheme.inkBlack,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(children: [
          Row(children: [Expanded(child: _mainArea())]),
          Positioned.fill(child: Ambiance(subdued: _busy || _page == 1)),
        ]),
      ),
    );
  }

  Widget _mainArea() {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 1100;
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: 4),
            Opacity(
                opacity: _busy ? 1.0 : 0.0,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ProgressIndicator(
                        target: _progressTarget,
                        phase: _phase,
                        active: _busy))),
            Expanded(
                flex: narrow ? 1 : 6, child: RepaintBoundary(child: _livre())),
            if (!widget.captureMode) ...[
              const SizedBox(height: 10),
              if (narrow)
                SizedBox(height: 96, child: RepaintBoundary(child: _console()))
              else
                Expanded(flex: 4, child: RepaintBoundary(child: _console())),
            ],
          ]));
    });
  }

  static const List<String> _rubanLabels = [
    'Réglages',
    'Informations',
    'Organisation',
    'Correction',
    'Production',
    'Lecture',
    'Registre',
    'Contact',
  ];
  static const List<String> _rubanEmojis = [
    '⚙',
    '📜',
    '',
    '',
    '▶',
    '📖',
    '',
    '🌐',
  ];
  static const List<Color> _rubanCouleurs = [
    Color(0xFFB8860B),
    Color(0xFF7A4A22),
    Color(0xFF4E8577),
    Color(0xFF6B3FA0),
    Color(0xFF8E2A2A),
    Color(0xFF2E4E7E),
    Color(0xFF2F6B3A),
    Color(0xFF6B5A8E),
  ];

  Widget _livre() {
    return LayoutBuilder(builder: (c, cons) {
      final bw = cons.maxWidth;
      final bh = cons.maxHeight;
      const pad = 16.0;
      final pageW = (bw - pad * 2 - 14) / 2;
      final pageH = bh - pad * 2;
      return SizedBox(
          width: bw,
          height: bh,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
                child: Container(
                    decoration: BoxDecoration(
                        gradient: AntiqueTheme.leatherGradient,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF2A180C), width: 2),
                        boxShadow: [
                  BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 18,
                      offset: const Offset(0, 8))
                ]))),
            Positioned(
                left: pad,
                top: pad,
                width: pageW,
                height: pageH,
                child: _parchemin(child: _pageTitre())),
            Positioned(
                left: bw / 2 + 8,
                top: pad,
                width: pageW,
                height: pageH,
                child:
                    _parchemin(child: _pageContenu(_turning ? _cible : _page))),
            if (_turning)
              Positioned(
                  left: bw / 2 + 8,
                  top: pad,
                  width: pageW,
                  height: pageH,
                  child: _feuilleTourne()),
            Positioned(
                left: 6,
                top: 20,
                child: Column(children: [
                  for (var i = 0; i < _rubanLabels.length; i++) ...[
                    RibbonTab(
                        label: _rubanLabels[i],
                        emoji: _rubanEmojis[i],
                        color: _rubanCouleurs[i],
                        active: i == _page,
                        onTap: () => _allerA(i)),
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
    return SizedBox.expand(
        child: Stack(children: [
      FiligreeWatermark(),
      Positioned.fill(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 18, 14),
        child: LayoutBuilder(builder: (context, constraints) {
          final showLettrine = constraints.maxHeight >= 380;
          return Column(children: [
            const Spacer(flex: 2),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('DANOË STUDIO',
                    textAlign: TextAlign.center,
                    style: AntiqueTheme.displayLarge)),
            const SizedBox(height: 10),
            Container(
                width: 140,
                height: 2,
                decoration:
                    const BoxDecoration(gradient: AntiqueTheme.goldGradient)),
            const SizedBox(height: 10),
            Text('— Machine à romans —',
                textAlign: TextAlign.center, style: AntiqueTheme.titlePage),
            if (showLettrine) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Lettrine(
                    letter: 'D',
                    paragraph: "ans un atelier où l'encre rencontre le cuir, "
                        "chaque page attend son histoire."),
              ),
            ],
            const SizedBox(height: 18),
            Text('❦',
                style: TextStyle(fontSize: 28, color: AntiqueTheme.agedGold)),
            const SizedBox(height: 18),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_statOuvrage,
                    textAlign: TextAlign.center,
                    style: AntiqueTheme.titlePage
                        .copyWith(fontSize: 16, fontWeight: FontWeight.w700))),
            const Spacer(flex: 3),
            Text('Ex libris', style: AntiqueTheme.caption),
            const SizedBox(height: 6),
          ]);
        }),
      )),
      Positioned(
          right: 54,
          bottom: 28,
          child: Tooltip(
              message: 'Fermer le livre',
              child: AntiqueButton(
                  label: 'Fermer le livre',
                  icon: Icons.close,
                  compact: true,
                  iconOnly: true,
                  onParchment: true,
                  onTap: _fermerLivre))),
    ]));
  }

  String _statOuvrage = '—';
  String _statFormat = '—';
  String _statMots = '—';
  String _statPages = '—';
  String _statChapitres = '—';
  String _statIllus = '—';
  Widget _pageRegistre() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('REGISTRE'),
        _ligneRegistre('Ouvrage', _statOuvrage),
        _ligneRegistre('Format', _statFormat),
        _ligneRegistre('Mots', _statMots),
        _ligneRegistre('Pages', _statPages),
        _ligneRegistre('Chapitres', _statChapitres),
        _ligneRegistre('Illustr.', _statIllus),
        const SizedBox(height: 8),
        const Center(
            child: Text('❦',
                style: TextStyle(fontSize: 24, color: AntiqueTheme.brass))),
      ]),
    );
  }

  Widget _ligneRegistre(String k, String v) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Text(k,
              style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AntiqueTheme.bloodInk,
                  letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(
              child: Container(
                  height: 1, color: AntiqueTheme.brass.withValues(alpha: 0.4))),
          const SizedBox(width: 8),
          Flexible(
              child: Text(v,
                  overflow: TextOverflow.ellipsis,
                  style: AntiqueTheme.bodyText
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
        ]));
  }

  Widget _pageContenu(int i) {
    switch (i) {
      case 0:
        return _pageReglages();
      case 1:
        return _pageInfos();
      case 2:
        return _pageOrganisation();
      case 3:
        return _pageCorrection(); // Uncommented to enable correction page
      case 4:
        return _pageProduction();
      case 5:
        return _pageLecture();
      case 6:
        return _pageRegistre();
      case 7:
        return _pageContact();
      default:
        return _pageReglages();
    }
  }

  Widget _titrePage(String t) {
    return SectionTitle(title: t);
  }

  // ══ 0. RÉGLAGES ══
  Widget _pageReglages() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('RÉGLAGES'),
        _actionPage('⚙', 'Paramètres', _ouvrirParametres, primary: true),
        _actionPage('📤', 'Dossier export', () => _ouvrirDossier('export')),
        _actionPage('🖼', 'Dossier des images', () => _ouvrirDossier('Images')),
        _actionPage(
            '📁', 'Dossier des chapitres', () => _ouvrirDossier('Chapitres')),
        _actionPage(
            '🌐', 'Dossier traductions', () => _ouvrirDossier('Traductions')),
        _actionPage('📥', 'Journal des erreurs', _ouvrirJournal),
      ]),
    );
  }

  Widget _boutonLivre(String emoji, String label, VoidCallback onTap) {
    return AntiqueButton(
        label: label,
        emoji: emoji,
        compact: true,
        primary: label == 'Enregistrer',
        onParchment: label != 'Enregistrer',
        onTap: onTap);
  }

  Widget _ligneBoutonsLivre(List<Widget> boutons) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: boutons));
  }

  Widget _navigationInfos() {
    const onglets = [
      ('Ⅰ', 'Identité', 1),
      ('Ⅱ', 'Édition', 2),
      ('Ⅲ', 'Mentions', 3),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final onglet in onglets) ...[
            _ongletInfos(
              romain: onglet.$1,
              label: onglet.$2,
              page: onglet.$3,
            ),
            if (onglet.$3 != 3) const SizedBox(width: 18),
          ],
        ],
      ),
    );
  }

  Widget _ongletInfos({
    required String romain,
    required String label,
    required int page,
  }) {
    final active = _infosPage == page;
    final color = active ? AntiqueTheme.bloodInk : AntiqueTheme.inkSepia;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: TextButton(
        onPressed: () => setState(() => _infosPage = page),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$romain  $label',
              style: GoogleFonts.cinzel(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              width: active ? 42 : 16,
              height: active ? 2 : 1,
              color: active
                  ? AntiqueTheme.brass
                  : AntiqueTheme.brass.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageInfos() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _titrePage('INFORMATIONS'),
          _navigationInfos(),
          Expanded(
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    final turn = Tween<double>(
                      begin: math.pi / 2,
                      end: 0,
                    ).animate(animation);
                    return AnimatedBuilder(
                      animation: turn,
                      child: child,
                      builder: (context, child) {
                        final transform = Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(turn.value);
                        return Opacity(
                          opacity: animation.value,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: transform,
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                  child: _contenuInfos(_infosPage)),
            ),
          ),
          const SizedBox(height: 8),
          _ligneBoutonsLivre([
            _boutonLivre('💾', 'Enregistrer', _sauverInfos),
          ]),
          const SizedBox(height: 8),
        ]));
  }

  Widget _contenuInfos(int page) {
    return KeyedSubtree(
      key: ValueKey(page),
      child: switch (page) {
        1 => _pageInfosIdentite(),
        2 => _pageInfosEdition(),
        _ => _pageInfosMentions(),
      },
    );
  }

  Widget _pageInfosIdentite() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _champInfo('Titre complet du roman', _iTitre),
      _champInfo('Sous-titre éventuel', _iSousTitre),
      _champInfo("Nom de l'auteur (couverture)", _iAuteur),
      Row(children: [
        Expanded(child: _champInfo('Année de publication', _iAnnee)),
        const SizedBox(width: 12),
        Expanded(child: _champInfo('ISBN', _iIsbn)),
      ]),
    ]);
  }

  Widget _pageInfosEdition() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _champInfo('Éditeur', _iEditeur),
      _champInfo('Dépôt légal', _iDepotLegal),
      _champInfo('Mention de copyright', _iCopyright),
      _champInfo('Édition', _iEdition),
      _champInfo('Site web', _iSiteWeb),
    ]);
  }

  Widget _pageInfosMentions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _champInfo('Avertissement', _iAvertissement, lines: 3),
      _champInfo('Dédicace', _iDedicace, lines: 2),
      _champInfo('Épigraphe', _iEpigraphe, lines: 2),
      _champInfo('Remerciements', _iRemerciements, lines: 4),
      _champInfo('Autres livres du même auteur', _iAutresLivres, lines: 5),
      _champDropdownImages('Frontispice', _iFrontispice),
      _champDropdownChapitres('Préface', _iPreface),
      _champDropdownChapitres('Postface', _iPostface),
      _caseSommaire(),
      const SizedBox(height: 12),
    ]);
  }

  Widget _caseSommaire() {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                  value: _iSommaire,
                  checkColor: AntiqueTheme.parchment,
                  activeColor: AntiqueTheme.bloodInk,
                  side: const BorderSide(color: AntiqueTheme.brass),
                  onChanged: (v) => setState(() => _iSommaire = v ?? true))),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Sommaire (table des matières dans le livre)',
                  style: GoogleFonts.cinzel(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AntiqueTheme.bloodInk,
                      letterSpacing: 1))),
        ]));
  }

  Widget _champInfo(String label, TextEditingController ctrl, {int lines = 1}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AntiqueTheme.bloodInk,
                  letterSpacing: 1)),
          Theme(
              data: Theme.of(context).copyWith(
                  textSelectionTheme: TextSelectionThemeData(
                      cursorColor: AntiqueTheme.bloodInk,
                      selectionColor:
                          AntiqueTheme.agedGold.withValues(alpha: 0.35),
                      selectionHandleColor: AntiqueTheme.bloodInk)),
              child: TextField(
                  controller: ctrl,
                  maxLines: lines,
                  style: AntiqueTheme.bodyText.copyWith(fontSize: 14),
                  cursorColor: AntiqueTheme.bloodInk,
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: AntiqueTheme.parchment,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      hintStyle: AntiqueTheme.bodyText.copyWith(
                          color: AntiqueTheme.inkSepia.withValues(alpha: 0.65)),
                      labelStyle: AntiqueTheme.bodyText
                          .copyWith(color: AntiqueTheme.inkSepia),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color:
                                  AntiqueTheme.brass.withValues(alpha: 0.8))),
                      focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: AntiqueTheme.bloodInk))))),
        ]));
  }

  // ══ 2. ORGANISATION ══

  Widget _champDropdownImages(String label, String? value) {
    final images = _chargerListeImages();
    final ok = images.contains(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.cinzel(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AntiqueTheme.bloodInk,
                letterSpacing: 1)),
        DropdownButton<String>(
          value: ok ? value : null,
          isExpanded: true,
          hint: Text('— aucun —',
              style:
                  TextStyle(color: AntiqueTheme.brass.withValues(alpha: 0.5))),
          items: [
            for (final img in images)
              DropdownMenuItem<String>(
                  value: img, child: Text(img, overflow: TextOverflow.ellipsis))
          ],
          onChanged: (v) => setState(() {
            if (label == 'Frontispice') _iFrontispice = v;
          }),
          style: AntiqueTheme.bodyText.copyWith(fontSize: 14),
          dropdownColor: AntiqueTheme.parchment,
          icon: Icon(Icons.arrow_drop_down, color: AntiqueTheme.bloodInk),
        ),
      ]),
    );
  }

  Widget _champDropdownChapitres(String label, String? value) {
    final chapitres = _chargerListeChapitres();
    final ok = chapitres.contains(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.cinzel(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AntiqueTheme.bloodInk,
                letterSpacing: 1)),
        DropdownButton<String>(
          value: ok ? value : null,
          isExpanded: true,
          hint: Text('— aucun —',
              style:
                  TextStyle(color: AntiqueTheme.brass.withValues(alpha: 0.5))),
          items: [
            for (final c in chapitres)
              DropdownMenuItem<String>(
                  value: c, child: Text(c, overflow: TextOverflow.ellipsis))
          ],
          onChanged: (v) => setState(() {
            if (label == 'Préface') _iPreface = v;
            if (label == 'Postface') _iPostface = v;
          }),
          style: AntiqueTheme.bodyText.copyWith(fontSize: 14),
          dropdownColor: AntiqueTheme.parchment,
          icon: Icon(Icons.arrow_drop_down, color: AntiqueTheme.bloodInk),
        ),
      ]),
    );
  }

  List<String> _chargerListeImages() {
    final dir = Directory('$_scriptsDir\\Images');
    if (!dir.existsSync()) return [];
    final liste = <String>[];
    for (final f in dir.listSync().whereType<File>()) {
      final nom = f.uri.pathSegments.last;
      final e = nom.toLowerCase();
      if (e.endsWith('.png') ||
          e.endsWith('.jpg') ||
          e.endsWith('.jpeg') ||
          e.endsWith('.webp') ||
          e.endsWith('.bmp')) {
        final i = nom.lastIndexOf('.');
        liste.add(i > 0 ? nom.substring(0, i) : nom);
      }
    }
    liste.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return liste;
  }

  List<String> _chargerListeChapitres() {
    final dir = Directory('$_scriptsDir\\Chapitres');
    if (!dir.existsSync()) return [];
    final liste = <String>[];
    for (final f in dir.listSync().whereType<File>()) {
      final nom = f.uri.pathSegments.last;
      if (nom.toLowerCase().endsWith('.md')) {
        liste.add(nom.substring(0, nom.length - 3));
      }
    }
    liste.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return liste;
  }

  Widget _pageOrganisation() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _titrePage('ORGANISATION'),
          Row(children: [
            Text(
                '${_organisation.length} élément(s) — actes, chapitres & images',
                style: AntiqueTheme.titlePage.copyWith(fontSize: 12)),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Recharger les chapitres et l’organisation',
              child: Tooltip(
                message: 'Recharger les chapitres et l’organisation',
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.space)) {
                      _chargerChapitres();
                      _chargerOrganisation();
                      setState(() {});
                      _log('🔄 Chapitres et organisation rechargés.',
                          kind: LogKind.ok);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: InkWell(
                    onTap: () {
                      _chargerChapitres();
                      _chargerOrganisation();
                      setState(() {});
                      _log('🔄 Chapitres et organisation rechargés.',
                          kind: LogKind.ok);
                    },
                    child: Text('🔄 Recharger',
                        style: GoogleFonts.cinzel(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AntiqueTheme.bloodInk)),
                  ),
                ),
              ),
            ),
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
          Expanded(
              child: ListView.builder(
                  itemCount: _organisation.length,
                  itemBuilder: (c, i) {
                    final e = _organisation[i];
                    final t = (e['type'] ?? '').toString();
                    final icone =
                        t == 'acte' ? '🎭' : (t == 'image' ? '🖼' : '📄');
                    return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                            color: const Color(0x0F000000),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AntiqueTheme.brass, width: 1.1)),
                        child: Row(children: [
                          SizedBox(
                              width: 26,
                              child: Text('$i',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AntiqueTheme.brass))),
                          Text(icone, style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(_labelOrg(e),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AntiqueTheme.bodyText.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700))),
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
    var focused = false;
    final label = s == '🗑' ? 'Supprimer' : 'Déplacer $s';
    return StatefulBuilder(
      builder: (context, setLocalState) => FocusableActionDetector(
        onShowFocusHighlight: (value) {
          focused = value;
          setLocalState(() {});
        },
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            button: true,
            label: label,
            child: Tooltip(
              message: label,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    border: focused
                        ? Border.all(color: AntiqueTheme.candleGlow)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AntiqueTheme.bloodInk,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ajoutBtn(String icone, String label, VoidCallback onTap) {
    var focused = false;
    return StatefulBuilder(
      builder: (context, setLocalState) => FocusableActionDetector(
        onShowFocusHighlight: (value) {
          focused = value;
          setLocalState(() {});
        },
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            button: true,
            label: 'Ajouter $label',
            child: Tooltip(
              message: 'Ajouter $label',
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0x142F6B3A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: focused
                          ? AntiqueTheme.candleGlow
                          : AntiqueTheme.verdigris,
                      width: focused ? 1.8 : 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '+ $icone $label',
                      style: GoogleFonts.cinzel(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AntiqueTheme.verdigris,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══ 3. CORRECTION ══
  Widget _pageCorrection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('CORRECTION'),
        _chapitrePicker(),
        const SizedBox(height: 6),
        _actionPage('📝', 'Corriger le chapitre', _corriger),
      ]),
    );
  }

  // ══ 4. PRODUCTION ══
  Widget _pageProduction() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('PRODUCTION'),
        _modeSelector(),
        const SizedBox(height: 10),
        _actionPage('▶', 'Générer le livre', _genererLivre, primary: true),
        _actionPage('🖨', 'PDF KDP noir & blanc', _exportPdf),
        _actionPage('📱', 'Ebook KDP (EPUB)', _genererEbook),
        _actionPage('🤖', 'Résumés IA', _resumesIA),
      ]),
    );
  }

  // ══ 5. LECTURE ══
  Widget _pageLecture() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titrePage('LECTURE'),
        _actionPage('📖', 'Lire le Word', () => _lireDocument('word'),
            primary: true),
        _actionPage('📄', 'Lire le PDF', () => _lireDocument('pdf')),
        _actionPage('📚', "Lire l'EPUB", () => _lireDocument('epub')),
        _actionPage('📝', 'Lire le résumé', _lireResume),
        const SizedBox(height: 12),
        Text(
            'Ouvre le dernier fichier généré (dossier export)\navec l\'application par défaut de Windows.',
            textAlign: TextAlign.center,
            style: AntiqueTheme.titlePage.copyWith(fontSize: 12)),
      ]),
    );
  }

  // ══ 7. CONTACT ══
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
              color: AntiqueTheme.parchmentMid.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AntiqueTheme.brass.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Restons en contact',
                    style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AntiqueTheme.inkSepia)),
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
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Text('$label : ',
            style: GoogleFonts.cinzel(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AntiqueTheme.inkSepia)),
        Expanded(
            child: Text(value,
                style: GoogleFonts.crimsonText(
                    fontSize: 14,
                    color: AntiqueTheme.inkSepia.withValues(alpha: 0.8)))),
      ]),
    );
  }

  Widget _actionPage(String icone, String label, VoidCallback onTap,
      {bool primary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AntiqueButton(
          label: label,
          emoji: icone,
          primary: primary,
          onParchment: true,
          onTap: onTap),
    );
  }

  Widget _modeSelector() {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: _modeChip('exact', '🎯 Exact')),
          const SizedBox(width: 8),
          Expanded(child: _modeChip('rapide', '⚡ Rapide')),
        ]));
  }

  Widget _modeChip(String mode, String label) {
    final on = _modeGeneration == mode;
    var focused = false;
    void activate() {
      setState(() => _modeGeneration = mode);
      _sauverConfig();
    }

    return StatefulBuilder(
      builder: (context, setLocalState) => FocusableActionDetector(
        onShowFocusHighlight: (value) {
          focused = value;
          setLocalState(() {});
        },
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              activate();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            button: true,
            selected: on,
            label: 'Mode de génération : $label',
            child: GestureDetector(
              onTap: activate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: on ? AntiqueTheme.bloodInk : const Color(0x14000000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: focused
                        ? AntiqueTheme.candleGlow
                        : (on ? AntiqueTheme.bloodInk : AntiqueTheme.brass),
                    width: focused ? 1.8 : 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.cinzel(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          on ? AntiqueTheme.parchment : AntiqueTheme.inkSepia,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chapitrePicker() {
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: const Color(0x14000000),
            borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: AntiqueTheme.parchment,
                style: TextStyle(fontSize: 13, color: AntiqueTheme.inkSepia),
                value: _chapitre,
                items: [
                  for (final c in _chapitres)
                    DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis))
                ],
                onChanged: (v) => setState(() => _chapitre = v))));
  }

  Widget _console() {
    return Container(
        decoration: BoxDecoration(
            color: AntiqueTheme.inkBlack,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AntiqueTheme.leatherDeep, width: 1.5)),
        padding: const EdgeInsets.all(14),
        child: ListView(controller: _scroll, children: [
          for (final l in _logs)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l.text,
                    style: TextStyle(
                        fontSize: 13,
                        color: _logColor(l.kind),
                        fontFamily: 'Consolas'))),
        ]));
  }
}

class _ProgressIndicator extends StatefulWidget {
  final double target;
  final String phase;
  final bool active;
  const _ProgressIndicator({
    required this.target,
    required this.phase,
    required this.active,
  });

  @override
  State<_ProgressIndicator> createState() => _ProgressIndicatorState();
}

class _ProgressIndicatorState extends State<_ProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _animation.repeat();
  }

  @override
  void didUpdateWidget(covariant _ProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _animation.repeat();
    } else if (!widget.active && oldWidget.active) {
      _animation.stop();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.target / 100).clamp(0.0, 1.0);
    final completed = progress >= 1.0;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: AntiqueTheme.leatherGradient,
          border: Border.all(
            color: completed ? AntiqueTheme.verdigris : AntiqueTheme.brass,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: CustomPaint(
                painter: _FolioProgressPainter(
                  progress: progress,
                  animation: _animation.value,
                  completed: completed,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 52,
              child: Text(
                '${widget.target.round()}%',
                textAlign: TextAlign.right,
                style: GoogleFonts.cinzel(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: completed
                      ? AntiqueTheme.verdigris
                      : AntiqueTheme.agedGold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 180,
              child: Text(
                widget.phase,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AntiqueTheme.parchment,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolioProgressPainter extends CustomPainter {
  final double progress;
  final double animation;
  final bool completed;

  const _FolioProgressPainter({
    required this.progress,
    required this.animation,
    required this.completed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final y = size.height / 2;
    final start = 4.0;
    final end = size.width - 4.0;
    final activeEnd = start + (end - start) * progress;
    final ink = Paint()
      ..color = AntiqueTheme.inkSepia.withValues(alpha: 0.72)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = completed ? AntiqueTheme.verdigris : AntiqueTheme.parchment
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final guide = Path()
      ..moveTo(start, y)
      ..quadraticBezierTo(size.width * 0.52, y - 1.5, end, y);
    canvas.drawPath(guide, ink);
    if (progress > 0) {
      final activePath = Path()
        ..moveTo(start, y)
        ..quadraticBezierTo(
            activeEnd * 0.52 + start * 0.48, y - 1.5, activeEnd, y);
      canvas.drawPath(activePath, line);
    }

    final cursorX = activeEnd.clamp(start, end).toDouble();
    final pulse = 0.78 + 0.22 * math.sin(animation * math.pi * 2).abs();
    final featherColor =
        completed ? AntiqueTheme.verdigris : AntiqueTheme.agedGold;
    final featherGlow = Paint()
      ..color = (completed ? AntiqueTheme.verdigris : AntiqueTheme.candleGlow)
          .withValues(alpha: 0.16 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(cursorX, y),
      5.5 * pulse,
      featherGlow,
    );

    canvas.save();
    canvas.translate(cursorX, y);
    canvas.rotate(-0.10 + math.sin(animation * math.pi * 2) * 0.035);

    final feather = Path()
      ..moveTo(1, 2)
      ..cubicTo(-5, -9, -14, -17, -28, -15)
      ..cubicTo(-25, -10, -24, -7, -29, -3)
      ..cubicTo(-23, -4, -19, -1, -17, 3)
      ..cubicTo(-12, 0, -8, 4, -6, 7)
      ..cubicTo(-2, 6, 0, 4, 1, 2)
      ..close();
    canvas.drawPath(
      feather,
      Paint()
        ..color = featherColor.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      feather,
      Paint()
        ..color = AntiqueTheme.inkSepia.withValues(alpha: 0.8)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );

    final shaft = Paint()
      ..color = AntiqueTheme.inkSepia
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-24, 10), const Offset(1, 2), shaft);
    final barb = Paint()
      ..color = AntiqueTheme.parchment.withValues(alpha: 0.65)
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-23, -11), const Offset(-17, -2), barb);
    canvas.drawLine(const Offset(-18, -13), const Offset(-14, -4), barb);
    canvas.drawLine(const Offset(-13, -12), const Offset(-10, -3), barb);
    canvas.drawLine(const Offset(-22, -4), const Offset(-16, 0), barb);
    canvas.drawLine(const Offset(-16, 0), const Offset(-11, 3), barb);
    canvas.drawLine(const Offset(-11, 4), const Offset(-8, 5), barb);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FolioProgressPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      animation != oldDelegate.animation ||
      completed != oldDelegate.completed;
}

class _ChoixDialog extends StatelessWidget {
  final String titre;
  final List<String> items;
  const _ChoixDialog({required this.titre, required this.items});

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: AntiqueTheme.leatherDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
            width: 420,
            height: 380,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(titre,
                      style: GoogleFonts.cinzel(
                          color: AntiqueTheme.agedGold,
                          fontSize: 16,
                          fontWeight: FontWeight.w700))),
              Expanded(
                  child: ListView(children: [
                for (final it in items)
                  ListTile(
                      dense: true,
                      title: Text(it,
                          style: const TextStyle(
                              color: Color(0xFFE8EAF6), fontSize: 13)),
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
    'default': 'Standard (Orthographe & Grammaire)',
    'picky': 'Exigeant (Style, répétitions)'
  };
  static const Map<String, String> _variantLabels = {
    'fr-FR': 'Français (France)',
    'fr-1990': 'Rectifications 1990',
    'fr-CA': 'Français (Canada)',
    'fr-CH': 'Français (Suisse)',
    'fr-BE': 'Français (Belgique)'
  };

  late final TextEditingController _dir =
      TextEditingController(text: widget.initial.scriptsDir);
  late final TextEditingController _py =
      TextEditingController(text: widget.initial.pythonPath);
  late String _level = widget.initial.spellLevel;
  late String _variant = widget.initial.spellVariant;
  late String _formatLivre = widget.initial.formatLivre;
  late String _texteFont = widget.initial.texteFont;
  late String _titresFont = widget.initial.titresFont;
  late String _texteSize = widget.initial.texteSize;
  late String _titresSize = widget.initial.titresSize;
  late String _interligne = widget.initial.interligne;

  @override
  void dispose() {
    _dir.dispose();
    _py.dispose();
    super.dispose();
  }

  String _label(Map<String, String> map, String code, String defaut) =>
      map[code] ?? map[defaut]!;
  void _setCode(
      Map<String, String> map, String label, void Function(String) set) {
    final e = map.entries
        .firstWhere((e) => e.value == label, orElse: () => map.entries.first);
    set(e.key);
  }

  String _dans(List<String> list, String val) =>
      list.contains(val) ? val : list.first;

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: AntiqueTheme.leatherDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
            width: 560,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text("⚙ Paramètres de l'application",
                      style: GoogleFonts.cinzel(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AntiqueTheme.agedGold)),
                  const SizedBox(height: 16),
                  _labelChamp('Dossier des scripts Python (backend)'),
                  TextField(
                      controller: _dir,
                      style: const TextStyle(color: Color(0xFFE8EAF6)),
                      decoration: _inputStyle()),
                  const SizedBox(height: 12),
                  _labelChamp('Exécutable Python'),
                  TextField(
                      controller: _py,
                      style: const TextStyle(color: Color(0xFFE8EAF6)),
                      decoration: _inputStyle()),
                  const SizedBox(height: 12),
                  _labelChamp('Niveau du correcteur'),
                  _dropdown(
                      value: _label(_levelLabels, _level, 'default'),
                      items: _levelLabels.values.toList(),
                      onChanged: (v) => setState(
                          () => _setCode(_levelLabels, v!, (c) => _level = c))),
                  const SizedBox(height: 12),
                  _labelChamp('Variante orthographique'),
                  _dropdown(
                      value: _label(_variantLabels, _variant, 'fr-FR'),
                      items: _variantLabels.values.toList(),
                      onChanged: (v) => setState(() =>
                          _setCode(_variantLabels, v!, (c) => _variant = c))),
                  const SizedBox(height: 16),
                  Text('📖 STYLE & FORMAT DU LIVRE',
                      style: GoogleFonts.cinzel(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AntiqueTheme.agedGold)),
                  const SizedBox(height: 8),
                  _labelChamp('Format du livre final (KDP)'),
                  _dropdown(
                      value: _dans(kFormats, _formatLivre),
                      items: kFormats,
                      onChanged: (v) => setState(() => _formatLivre = v!)),
                  const SizedBox(height: 12),
                  _labelChamp('Police du corps de texte'),
                  _dropdown(
                      value: _dans(kPolices, _texteFont),
                      items: kPolices,
                      onChanged: (v) => setState(() => _texteFont = v!)),
                  const SizedBox(height: 12),
                  _labelChamp('Police des titres & lettrines'),
                  _dropdown(
                      value: _dans(kPolices, _titresFont),
                      items: kPolices,
                      onChanged: (v) => setState(() => _titresFont = v!)),
                  const SizedBox(height: 12),
                  _labelChamp('Taille du corps (pt)'),
                  _dropdown(
                      value: _dans(kTaillesTexte, _texteSize),
                      items: kTaillesTexte,
                      onChanged: (v) => setState(() => _texteSize = v!)),
                  const SizedBox(height: 12),
                  _labelChamp('Taille des titres (pt)'),
                  _dropdown(
                      value: _dans(kTaillesTitres, _titresSize),
                      items: kTaillesTitres,
                      onChanged: (v) => setState(() => _titresSize = v!)),
                  const SizedBox(height: 12),
                  _labelChamp('Interligne du corps'),
                  _dropdown(
                      value: _dans(kInterlignes, _interligne),
                      items: kInterlignes,
                      onChanged: (v) => setState(() => _interligne = v!)),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler')),
                    const SizedBox(width: 8),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AntiqueTheme.verdigris,
                            foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(
                            context,
                            _AppSettings(
                                scriptsDir: _dir.text.trim(),
                                pythonPath: _py.text.trim(),
                                spellLevel: _level,
                                spellVariant: _variant,
                                formatLivre: _formatLivre,
                                texteFont: _texteFont,
                                titresFont: _titresFont,
                                texteSize: _texteSize,
                                titresSize: _titresSize,
                                interligne: _interligne)),
                        child: const Text('Sauvegarder')),
                  ]),
                ]))));
  }

  Widget _labelChamp(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9A8B6F))));

  InputDecoration _inputStyle() => InputDecoration(
      filled: true,
      fillColor: const Color(0xFF1B2036),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)));

  Widget _dropdown(
      {required String value,
      required List<String> items,
      required ValueChanged<String?> onChanged}) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF1B2036),
            borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: const Color(0xFF1B2036),
                style: const TextStyle(color: Color(0xFFE8EAF6)),
                value: value,
                items: [
                  for (final i in items)
                    DropdownMenuItem(value: i, child: Text(i))
                ],
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
    if (widget.match.suggestions.isNotEmpty) {
      _suggestion = widget.match.suggestions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Dialog(
        backgroundColor: AntiqueTheme.leatherDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
            width: 560,
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📝 Correction orthographique',
                      style: GoogleFonts.cinzel(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AntiqueTheme.agedGold)),
                  const SizedBox(height: 12),
                  Text(m.message,
                      style: const TextStyle(color: Color(0xFFFF6B6B))),
                  const SizedBox(height: 12),
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1B2036),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('…${m.contextText}…',
                          style: const TextStyle(color: Color(0xFFC9CDE0)))),
                  const SizedBox(height: 16),
                  if (m.suggestions.isNotEmpty) ...[
                    const Text('Suggestions :',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF6B7194))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                        initialValue: _suggestion,
                        dropdownColor: const Color(0xFF1B2036),
                        style: const TextStyle(color: Color(0xFFE8EAF6)),
                        items: [
                          for (final s in m.suggestions)
                            DropdownMenuItem(value: s, child: Text(s))
                        ],
                        onChanged: (v) => setState(() => _suggestion = v)),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                      controller: _manuel,
                      style: const TextStyle(color: Color(0xFFE8EAF6)),
                      decoration: InputDecoration(
                          labelText: 'Ou modifier manuellement',
                          labelStyle: const TextStyle(color: Color(0xFF6B7194)),
                          filled: true,
                          fillColor: const Color(0xFF1B2036),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 20),
                  Row(children: [
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AntiqueTheme.verdigris,
                            foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(
                            context,
                            _ResultCorrection(
                                valeur: _manuel.text.isNotEmpty
                                    ? _manuel.text
                                    : _suggestion)),
                        child: const Text('Appliquer')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(context, const _ResultCorrection()),
                        child: const Text('Ignorer')),
                    const Spacer(),
                    TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B6B)),
                        onPressed: () => Navigator.pop(
                            context, const _ResultCorrection(ignoreAll: true)),
                        child: const Text('Ignorer tout')),
                  ]),
                ])));
  }
}
