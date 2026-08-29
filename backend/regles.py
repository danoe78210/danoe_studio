"""regles.py – règles partagées (source : regles_mise_en_page.json)."""
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
    m = re.search(r'(\d+(?:\.\d+)?)\s*x\s*(\d+(?:\.\d+)?)', s)
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
