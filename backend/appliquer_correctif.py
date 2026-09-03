#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Correctif FABLE : normalise les clés JSON (espaces finaux) dans generer_roman.py."""
import os, shutil, datetime
BASE = os.path.dirname(os.path.abspath(__file__))
ROMAN = os.path.join(BASE, 'generer_roman.py')

NORMALISEUR = '''
def _normaliser_cles(d):
    if isinstance(d, dict):
        return {str(k).strip(): _normaliser_cles(v) for k, v in d.items()}
    if isinstance(d, list):
        return [_normaliser_cles(x) for x in d]
    if isinstance(d, str):
        return d.strip()
    return d
'''

LIRE_ANNEXES = '''
def lire_annexes():
    ax = {'sommaire': True}
    j = (_normaliser_cles(_lire_json_brut() or {})).get('informations', {}) or {}
    def g(*cles):
        for c in cles:
            v = j.get(c)
            if v: return str(v).strip()
        return ''
    ax['editeur'] = g('editeur', 'Éditeur', 'Editeur', 'maison_edition')
    ax['autres_livres'] = g('autres_livres', 'Autres livres du même auteur')
    ax['remerciements'] = g('remerciements', 'Remerciements')
    ax['frontispice'] = g('frontispice', 'Frontispice')
    ax['preface'] = g('preface', 'Préface')
    ax['postface'] = g('postface', 'Postface')
    sv = j.get('sommaire')
    ax['sommaire'] = sv if isinstance(sv, bool) else (str(sv).strip().lower() != 'false' if sv is not None else True)
    return ax
'''

def bak(p):
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    shutil.copyfile(p, p + f".bak_{ts}")

def main():
    s = open(ROMAN, encoding='utf-8').read(); s0 = s
    # 1) helper de normalisation
    if 'def _normaliser_cles' not in s:
        s = s.replace('def _lire_json_brut():', NORMALISEUR + '\ndef _lire_json_brut():', 1)
    # 2) _lire_json_brut renvoie le JSON normalisé (les 2 définitions)
    s = s.replace('return json.load(f)', 'return _normaliser_cles(json.load(f))')
    # 3) reordonner_structure_word_file : lecture normalisée
    s = s.replace("inf = (_json.load(open(p, encoding='utf-8')) or {}).get('informations', {}) or {}",
                  "inf = (_normaliser_cles(_json.load(open(p, encoding='utf-8'))) or {}).get('informations', {}) or {}")
    # 4) branche JSON_OK de lire_infos : normaliser data
    s = s.replace("jj = (data or {}).get('informations', {}) or {}",
                  "jj = (_normaliser_cles(data or {})).get('informations', {}) or {}")
    # 5) lire_annexes manquant (appelé par le bloc annexes de main)
    if 'def lire_annexes' not in s:
        s = s.replace('def lire_infos():', LIRE_ANNEXES + '\ndef lire_infos():', 1)
    if s != s0:
        bak(ROMAN); open(ROMAN, 'w', encoding='utf-8').write(s)
        print('✅ generer_roman.py patché (clés JSON normalisées + lire_annexes).')
    else:
        print('ℹ️  Aucun changement nécessaire.')

if __name__ == '__main__':
    main()