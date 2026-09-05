"""Plan éditorial partagé par les générateurs Word, PDF et EPUB."""
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
CHEMIN = BASE / 'structure_livre.json'

def charger_structure():
    try:
        with CHEMIN.open(encoding='utf-8') as f:
            return json.load(f).get('structure', [])
    except (OSError, json.JSONDecodeError):
        return []


def plan_livre(infos, annexes, organisation=None):
    """Retourne les modules actifs dans l'ordre éditorial canonique.

    ``saut`` décrit uniquement la pagination imprimée: ``impair`` signifie
    recto, ``pair`` verso et ``next`` la page suivante. Les exporteurs EPUB
    peuvent ignorer cette information tout en conservant l'ordre du plan.
    """
    infos = infos or {}
    annexes = annexes or {}
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
        plan.append({
            'id': eid,
            'type': typ,
            'saut': el.get('saut', 'next'),
            'force_start': el.get('saut', 'next') in ('impair', 'pair'),
            'pairs_with_next': bool(el.get('pairs_with_next', False)),
            'contenu': contenu,
            'meta': el,
        })

    # Les chapitres et actes restent pilotés par Organisation, mais sont
    # insérés à l'emplacement unique du manuscrit dans tous les exporteurs.
    if organisation is not None:
        manuscrit = next((m for m in plan if m['id'] == 'manuscrit'), None)
        if manuscrit is not None:
            index = plan.index(manuscrit)
            plan[index:index + 1] = [
                {
                    'id': f"{bloc.get('type', 'module')}_{index}",
                    'type': bloc.get('type', 'module'),
                    'saut': 'impair' if bloc.get('type') in ('acte', 'chapitre') else 'next',
                    'force_start': bloc.get('type') in ('acte', 'chapitre'),
                    'pairs_with_next': False,
                    'contenu': bloc,
                    'meta': bloc,
                }
                for index, bloc in enumerate(organisation)
            ]
    return plan
