# ══ BLOCS DE REMPLACEMENT POUR LE PDF ══
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

LIM_PDF = """_tit = INFOS.get('titre complet du roman', '') or 'Titre'
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

# ══ PATCH DU GÉNÉRATEUR PDF ══
def patcher_pdf():
    if not os.path.isfile(PDF): return
    s = open(PDF, encoding='utf-8').read(); mod = False

    # 1) lire_infos : Excel en repli SEULEMENT si le JSON n'a rien donné
    if 'if not infos:' not in s:
        s, r = entre(s, 'def lire_infos():', 'def lire_organisation():', LIRE_INFOS_PDF)
        mod = mod or r; print('   • lire_infos : Excel en repli uniquement')

    # 2) corrections typo par chapitre (parité Word)
    if 'CORR_PAR_PREFIXE = {' not in s:
        s = s.replace('META_RE = re.compile(', CORR_PDF + 'META_RE = re.compile(', 1)
        s = s.replace('for a, b in CORRECTIONS_COMMUNES: texte = texte.replace(a, b)',
                      'for a, b in CORRECTIONS_COMMUNES: texte = texte.replace(a, b)\n'
                      '    for pref, corr in CORR_PAR_PREFIXE.items():\n'
                      '        if fichier.startswith(pref):\n'
                      '            for a, b in corr: texte = texte.replace(a, b)', 1)
        mod = True; print('   • corrections par chapitre ajoutées')

    # 3) images centrées horizontalement
    if "img.hAlign = 'CENTER'" not in s:
        s = s.replace('st.append(RLImage(ch_hd, width=w_cm * cm, height=h_cm * cm))',
                      "img = RLImage(ch_hd, width=w_cm * cm, height=h_cm * cm); img.hAlign = 'CENTER'; st.append(img)", 1)
        mod = True; print('   • images centrées')

    # 4) marges KDP SYMÉTRIQUES (comme Word : gouttière + 0,125 des 2 côtés)
    if 'm_sym = gut + 0.125' not in s:
        s = s.replace('MARGES = (gut * 72, out * 72, 1.9 * cm, 1.9 * cm)',
                      'm_sym = gut + 0.125\n    MARGES = (m_sym * 72, m_sym * 72, 1.9 * cm, 1.9 * cm)', 1)
        mod = True; print('   • marges symétriques')

    # 5) page copyright complète (identique au Word)
    if 'page copyright (identique au Word)' not in s:
        s, r = entre(s, "lim = [Paragraph(escape((INFOS.get('titre complet du roman', '') or 'Titre').upper()), st_acte),",
                     "segments.append({'type': 'lim', 'story': lim, 'entete': None})", LIM_PDF)
        mod = mod or r; print('   • page copyright complète')

    # 6) TDM sans numéros négatifs
    if 'p < (debut_num or 1)' not in s:
        s = s.replace("toc.append(Paragraph(f'{escape(t)} {\".\" * pts} {p - (debut_num or 1) + 1}', st_toc))",
                      "toc.append(Paragraph(f'{escape(t)} {\".\" * pts} {p if p < (debut_num or 1) else p - (debut_num or 1) + 1}', st_toc))", 1)
        mod = True; print('   • TDM sans négatifs')

    # 7) conversion Word→PDF (le PDF reflète vos modifs Word) ; --direct = moteur rapide
    if 'def generer_depuis_word' not in s:
        s = s.replace('def main():', BLOC_WORD + "def main():\n    if '--direct' not in sys.argv[1:] and generer_depuis_word():\n        return\n", 1)
        s = s.replace("if __name__ == '__main__':\n    main()",
                      "if __name__ == '__main__':\n    if '--convert' in sys.argv[1:]:\n        _i = sys.argv.index('--convert')\n        _convert_word_pdf(sys.argv[_i + 1], sys.argv[_i + 2])\n    else:\n        main()", 1)
        mod = True; print('   • conversion Word→PDF (garde-fou 180 s)')

    if mod:
        bak(PDF); open(PDF, 'w', encoding='utf-8').write(s)
        print('   ✅ generer_pdf_direct.py patché')