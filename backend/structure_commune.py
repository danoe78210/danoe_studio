"""structure_commune.py – plan éditorial partagé Word/PDF/EPUB."""
import os, json
BASE = os.path.dirname(os.path.abspath(__file__))
CHEMIN = os.path.join(BASE, 'structure_livre.json')

def charger_structure():
    try:
        with open(CHEMIN, encoding='utf-8') as f:
            return json.load(f).get('structure', [])
    except Exception:
        return []

def plan_livre(infos, annexes):
    plan = []
    for el in charger_structure():
        typ, eid = el.get('type'), el.get('id')
        src = el.get('source', '')
        contenu = None
        if typ == 'vide': contenu = ''
        elif typ == 'faux_titre': contenu = infos.get('titre')
        elif typ == 'image': contenu = annexes.get('frontispice') or None
        elif typ in ('titre', 'copyright'): contenu = infos
        elif typ == 'dedicace': contenu = infos.get('dedicace') or None
        elif typ == 'epigraphe': contenu = infos.get('epigraphe') or None
        elif typ == 'sommaire': contenu = True if annexes.get('sommaire', True) else None
        elif typ in ('chapitre_md', 'texte'):
            contenu = annexes.get(src.replace('champ:', '')) or None
        elif typ == 'manuscrit': contenu = True
        if contenu is None and el.get('optionnel'):
            continue
        plan.append({'id': eid, 'type': typ, 'saut': el.get('saut', 'next'),
                     'contenu': contenu, 'meta': el})
    return plan
