#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""appliquer_correctif.py – FICHIER UNIQUE de correctifs (idempotent).
1) regles_mise_en_page.json + regles.py ;
2) generer_roman.py ;
3) generer_pdf_direct.py ;
4) home_screen.dart : pages défilantes, progression 99 %, « Lire le résumé » CORRIGÉ.
Usage : python appliquer_correctif.py"""
import os, re, json, shutil, ast

BASE  = os.path.dirname(os.path.abspath(__file__))
ROMAN = os.path.join(BASE, 'generer_roman.py')
PDF   = os.path.join(BASE, 'generer_pdf_direct.py')
DART  = os.path.join(BASE, '..', 'lib', 'ui', 'home_screen.dart')
JSONR = os.path.join(BASE, 'regles_mise_en_page.json')
PYR   = os.path.join(BASE, 'regles.py')

def bak(p):
    if os.path.isfile(p): shutil.copyfile(p, p + '.bak')

def entre(src, a, b, new):
    if a not in src or b not in src: return src, False
    i = src.index(a); j = src.index(b)
    return src[:i] + new + src[j:], True

def supprimer_fonction_dart(src, signature):
    """Supprime une fonction Dart par comptage d'accolades."""
    i = src.find(signature)
    if i == -1: return src, False
    j = src.find('{', i)
    if j == -1: return src, False
    depth = 0; k = j
    while k < len(src):
        if src[k] == '{': depth += 1
        elif src[k] == '}':
            depth -= 1
            if depth == 0: return src[:i] + src[k+1:], True
        k += 1
    return src, False

def inserer_avant_lire_document(s, bloc):
    for a in ('Future<void> _lireDocument(', 'Future _lireDocument(', 'void _lireDocument('):
        if a in s:
            return s.replace(a, bloc + a, 1), True
    return s, False

# ══ 1. SOURCE DE VÉRITÉ ══
REGLES = {"version": "1.1",
  "formats_livre": [["5 x 8 po",12.7,20.32],["5.06 x 7.81 po",12.85,19.84],["5.25 x 8 po",13.34,20.32],
    ["5.5 x 8.5 po",13.97,21.59],["6 x 9 po",15.24,22.86],["6.14 x 9.21 po",15.6,23.4],["7 x 10 po",17.78,25.4],
    ["8 x 10 po",20.32,25.4],["8.5 x 8.5 po",21.59,21.59],["8.5 x 11 po",21.59,27.94],["A4",21.0,29.7]],
  "marges_kdp": {"bareme_po": [[150,0.375],[300,0.5],[500,0.625],[700,0.75],[828,0.875]], "garde_po": 0.125, "symetriques": True}}

MODULE = '''"""regles.py – règles partagées (source : regles_mise_en_page.json)."""
import os, re, json
BASE = os.path.dirname(os.path.abspath(__file__))
try:
    with open(os.path.join(BASE, 'regles_mise_en_page.json'), encoding='utf-8') as f: REGLES = json.load(f)
except Exception: REGLES = {}
FORMATS_LIVRE = [(n, float(w), float(h)) for n, w, h in REGLES.get('formats_livre', [['6 x 9 po',15.24,22.86]])]
def dimensions_pour_format(label):
    s = str(label).lower().strip().replace(',', '.')
    for nom, w, h in FORMATS_LIVRE:
        if nom.lower() in s or s == nom.lower().replace(' po', ''): return w, h
    if 'a4' in s: return 21.0, 29.7
    m = re.search(r'(\\d+(?:\\.\\d+)?)\\s*x\\s*(\\d+(?:\\.\\d+)?)', s)
    if m:
        w, h = float(m.group(1)), float(m.group(2))
        if 'mm' in s: return w/10.0, h/10.0
        if 'cm' in s: return w, h
        return w*2.54, h*2.54
    return 17.78, 25.4
_M = REGLES.get('marges_kdp', {})
BAREME_KDP = [(int(m), float(g)) for m, g in _M.get('bareme_po', [(828,0.875)])]
GARDE = float(_M.get('garde_po', 0.125))
def gouttiere_kdp_pour(p):
    for maxi, g in BAREME_KDP:
        if p <= maxi: return g
    return BAREME_KDP[-1][1]
def marge_kdp_pour(p): return gouttiere_kdp_pour(p) + GARDE
'''

def ecrire_partages():
    with open(JSONR, 'w', encoding='utf-8') as f: json.dump(REGLES, f, ensure_ascii=False, indent=2)
    with open(PYR, 'w', encoding='utf-8') as f: f.write(MODULE)
    print('   ✅ regles écrits')

# ══ 2. generer_roman.py ══
def patcher_roman():
    if not os.path.isfile(ROMAN): return
    s = open(ROMAN, encoding='utf-8').read(); mod = False
    if 'def _lire_json_brut' not in s:
        s = s.replace('def lire_infos():', "def _lire_json_brut():\n    try:\n        import json\n        return json.load(open(CHEMIN_CONFIG_JSON, encoding='utf-8'))\n    except Exception:\n        return None\n\ndef lire_infos():", 1)
        A = "def lire_infos():\n    infos = {l: '' for l in CHAMPS_LABELS}\n    source = 'défaut'\n"
        s = s.replace(A, A + "    ji = (_lire_json_brut() or {}).get('informations', {}) or {}\n    for label in CHAMPS_LABELS:\n        for k, v in ji.items():\n            if v and nettoyer(k).lower().startswith(CORRESPONDANCES[label]):\n                infos[label] = nettoyer(v); source = 'JSON'; break\n", 1); mod = True
    if 'if nom.lower() in s or s == nom' not in s:
        s, r = entre(s, 'def dimensions_pour_format(label):', 'def verifier_formats():',
"""def dimensions_pour_format(label):
    s = str(label).lower().strip().replace(',', '.')
    for nom, w, h in FORMATS_LIVRE:
        if nom.lower() in s or s == nom.lower().replace(' po', ''):
            return w, h
    if 'a4' in s:
        return 21.0, 29.7
    m = re.search(r'(\\d+(?:\\.\\d+)?)\\s*x\\s*(\\d+(?:\\.\\d+)?)', s)
    if m:
        w, h = float(m.group(1)), float(m.group(2))
        if 'mm' in s: return w / 10.0, h / 10.0
        if 'cm' in s: return w, h
        return w * 2.54, h * 2.54
    return 17.78, 25.4

"""); mod = mod or r
    if 'pages = d.ComputeStatistics(2)' not in s:
        s = s.replace("        d.Save()\n        d.Close(False)\n        d = None\n        print('   ✅ TDM et champs mis à jour dans le fichier final.')",
                      "        d.Save()\n        pages = d.ComputeStatistics(2)\n        d.Close(False)\n        d = None\n        print('   ✅ TDM et champs mis à jour dans le fichier final.')\n        return pages", 1); mod = True
    if "max_l = max(6.0, min(14.0, STYLE['largeur_cm'] - 4.0))" not in s:
        s = s.replace('max_l = largeur_illustration()', "max_l = max(6.0, min(14.0, STYLE['largeur_cm'] - 4.0))", 1); mod = True
    if mod:
        bak(ROMAN); open(ROMAN, 'w', encoding='utf-8').write(s); print('   ✅ generer_roman.py patché')

# ══ 3. generer_pdf_direct.py ══
BLOC_WORD = '''def _convert_word_pdf(docx_path, pdf_path):
    import win32com.client
    word = win32com.client.Dispatch('Word.Application'); word.Visible = False
    try: word.DisplayAlerts = 0; word.AutomationSecurity = 3
    except Exception: pass
    d = word.Documents.Open(os.path.abspath(docx_path), False, True, False)
    try: d.ExportAsFixedFormat(os.path.abspath(pdf_path), 17, False, 0)
    finally: d.Close(False); word.Quit()

def generer_depuis_word():
    import glob, subprocess, time
    c = glob.glob(os.path.join(BASE, '*_KDP.docx')) + glob.glob(os.path.join(BASE, 'export', '*_KDP.docx'))
    if not c: return False
    dx = max(c, key=os.path.getmtime); pf = os.path.splitext(dx)[0] + '.pdf'
    for _ in range(5):
        try:
            if os.path.exists(pf): os.remove(pf)
            break
        except Exception: time.sleep(0.3)
    print('   🖨 Conversion Word→PDF (vos modifs incluses)…')
    try:
        r = subprocess.run([sys.executable, os.path.abspath(__file__), '--convert', dx, pf], timeout=180, capture_output=True, text=True)
        if r.returncode == 0 and os.path.isfile(pf):
            print('✅ PDF KDP prêt (converti depuis Word) : ' + pf); return True
        return False
    except subprocess.TimeoutExpired:
        print('   ⚠️ Word trop lent (>180 s) → génération directe.'); return False

'''

LIRE_INFOS_PDF = '''def lire_infos():
    infos = {}
    j = _lire_json()
    for cle, val in ((j or {}).get('informations', {}) or {}).items():
        if val: infos[cle.lower()] = nettoyer(val)
    if not infos:
        try:
            from openpyxl import load_workbook
            wb = load_workbook(CHEMIN_CONFIG, data_only=True)
            ws = wb['Informations']
            for row in ws.iter_rows(values_only=True):
                if row and row[0]: infos[nettoyer(row[0]).lower()] = nettoyer(row[1])
        except Exception:
            pass
    return infos

'''

CORR_PDF = """CORR_PAR_PREFIXE = {
'1.1': [('E t si', 'Et si'), ('XIIe siècle', 'XIIᵉ siècle')],
'2.1': [('une par inhérente', 'une part inhérente'), ('me pousser à', 'me pousse à'),
('l’Étranger. il observe', 'l’Étranger. Il observe'), ('L’ombre, m’observe.', 'L’ombre m’observe.'),
('pas d’atmosphère se dissipe', 'pas d’atmosphère qui se dissipe')],
'2.2': [('Ute tension insupportable', 'Une tension insupportable'), ('Ute chance de naître', 'Une chance de naître'),
('Mon regard se live', 'Mon regard se lève'), ('ma traversé ,', 'ma traversée,'), ('ma traversé,', 'ma traversée,'),
('La Lumiere éclate', 'La lumière éclate'), ('Je le survole.', 'Je la survole.'),
('s’harmonise, créé une', 's’harmonise, crée une'), ('fait créé une', 'fait crée une'), ('Nunael', 'Nunaël'),
('me défier ainsi ?', 'me défier ainsi ? »'), ('Quand il sera trop tard ?', 'Quand il sera trop tard ? »'),
('si la fin est toujours la même ?', 'si la fin est toujours la même ? »'),
('« Mais ils auront existé.', '« Mais ils auront existé. »'), ('je combats !', 'je combats ! »'),
('même si je ne peux pas l’anéantir.', 'même si je ne peux pas l’anéantir. »'), ('a créé …. Et', 'a créé… Et')],
}
"""

LIM = """_tit = INFOS.get('titre complet du roman', '') or 'Titre'
    _aut = INFOS.get("nom de l'auteur (couverture)", '') or 'Auteur'
    _ann = INFOS.get('année de publication', '2026')
    lim = [Paragraph(escape(_tit.upper()), st_acte),
    Paragraph(escape(INFOS.get('sous-titre éventuel', '') or ''), st_ch2),
    Spacer(1, 2 * cm), Paragraph(escape(_aut), st_ch2), PageBreak()]
    # page copyright (identique au Word)
    _cop = [Paragraph(escape((_tit + ' – ' + INFOS['sous-titre éventuel']) if INFOS.get('sous-titre éventuel') else _tit), st_lim)]
    _cop.append(Spacer(1, 0.6 * cm))
    _cop.append(Paragraph(escape(INFOS.get('mention de copyright', '') or ('© ' + _ann + ' ' + _aut + '. Tous droits réservés.')), st_lim))
    _cop.append(Spacer(1, 0.3 * cm))
    _meta = ' – '.join(x for x in [INFOS.get('édition', ''), _ann] if x)
    if _meta: _cop.append(Paragraph(escape(_meta), st_lim))
    if INFOS.get('isbn'): _cop.append(Paragraph('ISBN : ' + escape(INFOS['isbn']), st_lim))
    if INFOS.get('dépôt légal'): _cop.append(Paragraph('Dépôt légal : ' + escape(INFOS['dépôt légal']), st_lim))
    if INFOS.get("maison d'édition"):
        _cop.append(Spacer(1, 0.3 * cm)); _cop.append(Paragraph(escape(INFOS["maison d'édition"]), st_lim))
    _cop.append(Spacer(1, 0.6 * cm))
    for _t in ['Toute reproduction, même partielle, est interdite sans l’autorisation',
    'préalable de l’auteur, conformément aux dispositions de la législation',
    'en vigueur sur la propriété intellectuelle.']:
        _cop.append(Paragraph(escape(_t), st_lim))
    if INFOS.get('site web'):
        _cop.append(Spacer(1, 0.3 * cm)); _cop.append(Paragraph(escape(INFOS['site web']), st_lim))
    lim += _cop
    if INFOS.get('dédicace'):
        lim += [PageBreak()] + [Paragraph(escape(x), st_ch2) for x in INFOS['dédicace'].splitlines() if x.strip()]
    if INFOS.get('épigraphe'):
        lim += [PageBreak()] + [Paragraph(escape(x), st_ch2) for x in INFOS['épigraphe'].splitlines() if x.strip()]
    """

def patcher_pdf():
    if not os.path.isfile(PDF): return
    s = open(PDF, encoding='utf-8').read(); mod = False
    if 'if not infos:' not in s:
        s, r = entre(s, 'def lire_infos():', 'def lire_organisation():', LIRE_INFOS_PDF); mod = mod or r
    if 'CORR_PAR_PREFIXE = {' not in s:
        s = s.replace('META_RE = re.compile(', CORR_PDF + 'META_RE = re.compile(', 1)
        s = s.replace('for a, b in CORRECTIONS_COMMUNES: texte = texte.replace(a, b)',
                      'for a, b in CORRECTIONS_COMMUNES: texte = texte.replace(a, b)\n    for pref, corr in CORR_PAR_PREFIXE.items():\n        if fichier.startswith(pref):\n            for a, b in corr: texte = texte.replace(a, b)', 1); mod = True
    if "img.hAlign = 'CENTER'" not in s:
        s = s.replace('st.append(RLImage(ch_hd, width=w_cm * cm, height=h_cm * cm))',
                      "img = RLImage(ch_hd, width=w_cm * cm, height=h_cm * cm); img.hAlign = 'CENTER'; st.append(img)", 1); mod = True
    if 'm_sym = gut + 0.125' not in s:
        s = s.replace('MARGES = (gut * 72, out * 72, 1.9 * cm, 1.9 * cm)',
                      'm_sym = gut + 0.125\n    MARGES = (m_sym * 72, m_sym * 72, 1.9 * cm, 1.9 * cm)', 1); mod = True
    if 'p < (debut_num or 1)' not in s:
        s = s.replace("toc.append(Paragraph(f'{escape(t)} {\".\" * pts} {p - (debut_num or 1) + 1}', st_toc))",
                      "toc.append(Paragraph(f'{escape(t)} {\".\" * pts} {p if p < (debut_num or 1) else p - (debut_num or 1) + 1}', st_toc))", 1); mod = True
    if 'page copyright (identique au Word)' not in s:
        s, r = entre(s, "lim = [Paragraph(escape((INFOS.get('titre complet du roman', '') or 'Titre').upper()), st_acte),",
                     "segments.append({'type': 'lim', 'story': lim, 'entete': None})", LIM); mod = mod or r
    if 'def generer_depuis_word' not in s:
        s = s.replace('def main():', BLOC_WORD + "def main():\n    if '--direct' not in sys.argv[1:] and generer_depuis_word():\n        return\n", 1)
        s = s.replace("if __name__ == '__main__':\n    main()",
                      "if __name__ == '__main__':\n    if '--convert' in sys.argv[1:]:\n        _i = sys.argv.index('--convert')\n        _convert_word_pdf(sys.argv[_i + 1], sys.argv[_i + 2])\n    else:\n        main()", 1); mod = True
    if mod:
        bak(PDF); open(PDF, 'w', encoding='utf-8').write(s); print('   ✅ generer_pdf_direct.py patché')

# ══ 4. home_screen.dart ══
FN_RESUME = '''  Future<void> _lireResume() async {
    try {
      Directory dir = Directory.current;
      Directory? backend;
      for (int i = 0; i < 6; i++) {
        final cand = Directory(path.join(dir.path, 'backend'));
        if (cand.existsSync() && File(path.join(cand.path, 'generer_roman.py')).existsSync()) { backend = cand; break; }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      if (backend == null) { _afficherMsg('Dossier backend introuvable'); return; }
      final resumePath = path.join(backend.path, 'Résumé.md');
      if (!File(resumePath).existsSync()) { _afficherMsg('« Résumé.md » introuvable. Générez-le via « Résumés IA » (menu Production).'); return; }
      if (Platform.isWindows) { await Process.run('cmd', ['/c', 'start', '', resumePath]); }
      else if (Platform.isMacOS) { await Process.run('open', [resumePath]); }
      else { await Process.run('xdg-open', [resumePath]); }
      _log('📝 Ouverture du résumé : ' + resumePath);
    } catch (e) { _afficherMsg('Erreur ouverture résumé : ' + e.toString()); }
  }

'''

FN_AFFICHER = '''  void _afficherMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

'''

def _dart_page(nom, corps):
    return ("  Widget " + nom + "() {\n    return SingleChildScrollView(\n"
            "      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),\n"
            "      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n        "
            + ",\n        ".join(corps) + ",\n      ]),\n    );\n  }\n\n")

def patcher_dart():
    if not os.path.isfile(DART): return
    s = open(DART, encoding='utf-8').read(); mod = False
    if "import 'dart:io';" not in s:
        s = s.replace('import ', "import 'dart:io';\nimport ", 1); mod = True
    if 'package:path/path.dart' not in s:
        s = s.replace("import 'dart:io';", "import 'dart:io';\nimport 'package:path/path.dart' as path;", 1); mod = True
    if 'if (_progressTarget < 99) {' not in s:
        s = s.replace('if (_progressTarget < 95) {', 'if (_progressTarget < 99) {', 1)
        s = s.replace('(_progressTarget + 0.3).clamp(0, 95)', '(_progressTarget + 0.2).clamp(0, 99)', 1); mod = True
    pages = {
      '_pageReglages': ["_titrePage('RÉGLAGES')", "_actionPage('⚙', 'Paramètres', _ouvrirParametres)",
        "_actionPage('📤', 'Dossier export', () => _ouvrirDossier('export'))",
        "_actionPage('🖼', 'Dossier des images', () => _ouvrirDossier('Images'))",
        "_actionPage('📁', 'Dossier des chapitres', () => _ouvrirDossier('Chapitres'))",
        "_actionPage('🌐', 'Dossier traductions', () => _ouvrirDossier('Traductions'))",
        "_actionPage('📥', 'Journal des erreurs', _ouvrirJournal)"],
      '_pageCorrection': ["_titrePage('CORRECTION')", "_chapitrePicker()", "const SizedBox(height: 6)",
        "_actionPage('📝', 'Corriger le chapitre', _corriger)"],
      '_pageProduction': ["_titrePage('PRODUCTION')", "_modeSelector()", "const SizedBox(height: 10)",
        "_actionPage('▶', 'Générer le livre', _genererLivre)", "_actionPage('🖨', 'PDF KDP noir & blanc', _exportPdf)",
        "_actionPage('📱', 'Ebook KDP (EPUB)', _genererEbook)", "_actionPage('🤖', 'Résumés IA', _resumesIA)"],
      '_pageLecture': ["_titrePage('LECTURE')", "_actionPage('📖', 'Lire le Word', () => _lireDocument('word'))",
        "_actionPage('📄', 'Lire le PDF', () => _lireDocument('pdf'))", "_actionPage('📚', \"Lire l'EPUB\", () => _lireDocument('epub'))",
        "_actionPage('📝', 'Lire le résumé', _lireResume)"],
      '_pageRegistre': ["_titrePage('REGISTRE')", "_ligneRegistre('Ouvrage', _statOuvrage)", "_ligneRegistre('Format', _statFormat)",
        "_ligneRegistre('Mots', _statMots)", "_ligneRegistre('Pages', _statPages)", "_ligneRegistre('Chapitres', _statChapitres)",
        "_ligneRegistre('Illustr.', _statIllus)"],
    }
    fins = {'_pageReglages': '  // ══ 1. INFORMATIONS', '_pageCorrection': '  // ══ 4. PRODUCTION',
            '_pageProduction': '  // ══ 5. LECTURE', '_pageLecture': '  // ══ 7. CONTACT',
            '_pageRegistre': 'Widget _ligneRegistre'}
    for nom, corps in pages.items():
        a = 'Widget ' + nom + '() {'
        if a in s and 'return SingleChildScrollView' not in s[s.index(a):s.index(a) + 200]:
            s, r = entre(s, a, fins[nom], _dart_page(nom, corps)); mod = mod or r
    if "Lire le résumé" not in s:
        a_epub = "_actionPage('📚', \"Lire l'EPUB\", () => _lireDocument('epub')),"
        if a_epub in s:
            s = s.replace(a_epub, a_epub + "\n        _actionPage('📝', 'Lire le résumé', _lireResume),", 1); mod = True
    # Répare la fonction _lireResume cassée (méthodes inexistantes)
    if '_trouverDossierBackend' in s or '_afficherErreur' in s:
        s, _ = supprimer_fonction_dart(s, 'Future<void> _lireResume()')
        s, ok = inserer_avant_lire_document(s, FN_RESUME); mod = mod or ok
        if 'void _afficherMsg(' not in s:
            s, ok2 = inserer_avant_lire_document(s, FN_AFFICHER); mod = mod or ok2
        print('   🔧 _lireResume() réparé (suppression des méthodes inexistantes)')
    elif 'Future<void> _lireResume()' not in s:
        s, ok = inserer_avant_lire_document(s, FN_RESUME); mod = mod or ok
        if 'void _afficherMsg(' not in s:
            s, ok2 = inserer_avant_lire_document(s, FN_AFFICHER); mod = mod or ok2
    if mod:
        bak(DART); open(DART, 'w', encoding='utf-8').write(s)
        print('   ✅ home_screen.dart patché (dont « Lire le résumé » corrigé)')

# ══ 5. EXÉCUTION + CONTRÔLE ══
def main():
    print('📐 appliquer_correctif.py – application des correctifs…')
    ecrire_partages(); patcher_roman(); patcher_pdf(); patcher_dart()
    ok = True
    for f in (PYR, ROMAN, PDF):
        if os.path.isfile(f):
            try:
                ast.parse(open(f, encoding='utf-8').read()); print('   ✅ syntaxe OK : ' + os.path.basename(f))
            except SyntaxError as e:
                ok = False; print(f'   ⚠️  SYNTAXE {os.path.basename(f)} ligne {e.lineno} : {e.msg}')
    print('🎯 Terminé.' if ok else '🎯 Terminé avec avertissements.')

if __name__ == '__main__':
    main()