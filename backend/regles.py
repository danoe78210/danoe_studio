"""regles.py – règles partagées (source : regles_mise_en_page.json)."""
import os, re, json
BASE = os.path.dirname(os.path.abspath(__file__))
try:
    with open(os.path.join(BASE, 'regles_mise_en_page.json'), encoding='utf-8') as f:
        REGLES = json.load(f)
except Exception:
    REGLES = {}
FORMATS_LIVRE = [(n, float(w), float(h)) for n, w, h in REGLES.get('formats_livre', [['6 x 9 po', 15.24, 22.86]])]
def dimensions_pour_format(label):
    s = str(label).lower().strip().replace(',', '.')
    for nom, w, h in FORMATS_LIVRE:
        if nom.lower() in s or s == nom.lower().replace(' po', ''):
            return w, h
    if 'a4' in s:
        return 21.0, 29.7
    m = re.search(r'(\d+(?:\.\d+)?)\s*x\s*(\d+(?:\.\d+)?)', s)
    if m:
        w, h = float(m.group(1)), float(m.group(2))
        if 'mm' in s: return w / 10.0, h / 10.0
        if 'cm' in s: return w, h
        return w * 2.54, h * 2.54
    return 17.78, 25.4
_M = REGLES.get('marges_kdp', {})
BAREME_KDP = [(int(m), float(g)) for m, g in _M.get('bareme_po', [(828, 0.875)])]
GARDE = float(_M.get('garde_po', 0.125))
MARGES_SYMETRIQUES = bool(_M.get('symetriques', True))
def gouttiere_kdp_pour(p):
    for maxi, g in BAREME_KDP:
        if p <= maxi: return g
    return BAREME_KDP[-1][1]
def marge_kdp_pour(p):
    return gouttiere_kdp_pour(p) + GARDE
CORRECTIONS_COMMUNES = [(a, b) for a, b in REGLES.get('corrections_communes', [])]
CORR_PAR_PREFIXE = {k: [(a, b) for a, b in v] for k, v in REGLES.get('corrections_par_chapitre', {}).items()}
REGEX_PENSEES = [(re.compile(p), r) for p, r in REGLES.get('regex_pensees', [])]
def corrections_pour(f):
    for pref, corr in CORR_PAR_PREFIXE.items():
        if str(f).startswith(pref): return corr
    return []
TYPO = REGLES.get('typographie_defaut', {})
MISE_EN_PAGE = REGLES.get('mise_en_page', {})
def __getattr__(name):
    _defauts = {'MARGES_SYMETRIQUES': True, 'GARDE': 0.125, 'TYPO': {}, 'MISE_EN_PAGE': {},
                'BAREME_KDP': [(828, 0.875)], 'CORRECTIONS_COMMUNES': [], 'CORR_PAR_PREFIXE': {},
                'REGEX_PENSEES': [], 'FORMATS_LIVRE': [('6 x 9 po', 15.24, 22.86)]}
    if name in _defauts:
        return _defauts[name]
    raise AttributeError("module 'regles' has no attribute " + repr(name))
