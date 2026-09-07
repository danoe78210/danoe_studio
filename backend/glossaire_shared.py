import re
from collections import OrderedDict
from dataclasses import dataclass
from html import escape

GLOSSAIRE_RE = re.compile(r'^\[\^([A-Za-z0-9_-]+)\]:\s*(.*)$')
REF_RE = re.compile(r'\[\^([A-Za-z0-9_-]+)\]')
NUM_REF_RE = re.compile(r'\[(\d+)\]')


@dataclass
class EntreeGlossaire:
    numero: int
    identifiant: str
    definition: str
    acte: str
    chapitre: str
    page: str


class GlossaireLivre:
    """Collecte un glossaire unique et numérote ses références dans l'ordre."""

    def __init__(self):
        self.entrees = []
        self._par_identifiant = {}

    def reinitialiser(self):
        self.entrees.clear()
        self._par_identifiant.clear()

    def enregistrer(self, defs, acte='', chapitre='', page='à calculer après pagination'):
        for ident, definition in defs.items():
            if ident not in self._par_identifiant:
                entree = EntreeGlossaire(
                    len(self.entrees) + 1, str(ident), str(definition),
                    str(acte), str(chapitre), str(page)
                )
                self._par_identifiant[ident] = entree
                self.entrees.append(entree)

    def remplacer(self, texte):
        def remplacement(match):
            entree = self._par_identifiant.get(match.group(1))
            return f'[{entree.numero}]' if entree else match.group(0)

        return REF_RE.sub(remplacement, str(texte))

    def par_numero(self):
        return {entree.numero: entree for entree in self.entrees}


def extraire_definitions_glossaire(texte):
    """Sépare le corps du chapitre des définitions du glossaire.

    Format attendu :
        [^mots]: définition
    """
    lignes = []
    defs = OrderedDict()
    ident_courant = None
    for ligne in str(texte).splitlines():
        m = GLOSSAIRE_RE.match(ligne.strip())
        if m:
            ident = m.group(1).strip()
            if ident:
                defs[ident] = m.group(2).strip()
                ident_courant = ident
        elif ident_courant and ligne[:1].isspace() and ligne.strip():
            defs[ident_courant] += ' ' + ligne.strip()
        else:
            ident_courant = None
            lignes.append(ligne)
    return '\n'.join(lignes), defs


def remplacer_references_glossaire(texte, active=False):
    if not active:
        return texte
    return REF_RE.sub(r'<sup class="note-ref"><a href="#note-\1" id="ref-\1">[\1]</a></sup>', texte)


def remplacer_references_texte(texte, active=False):
    """Rend les références lisibles dans les formats qui ne sont pas HTML."""
    if not active:
        return texte
    return REF_RE.sub(r'[\1]', str(texte))


def format_glossaire_html(defs, titre='Glossaire'):
    if not defs:
        return ''
    items = []
    if isinstance(defs, GlossaireLivre):
        sources = [
            (entry.numero, entry.identifiant, entry.definition)
            for entry in defs.entrees
        ]
    else:
        sources = [(None, ident, desc) for ident, desc in defs.items()]
    for numero, ident, desc in sources:
        ident_html = escape(str(ident), quote=True)
        clean = escape(str(desc).replace('\n', ' ').strip())
        cible = str(numero) if numero is not None else ident_html
        etiquette = f'[{numero}] ' if numero is not None else ''
        items.append(
            f'<li epub:type="footnote" id="note-{escape(cible, quote=True)}">'
            f'<a href="#ref-{escape(cible, quote=True)}" aria-label="Retour à la référence '
            f'{escape(cible, quote=True)}">↩</a> '
            f'<strong class="glossary-term">{etiquette}{ident_html}</strong> — {clean}</li>'
        )
    return (
        '<section class="notes" aria-labelledby="glossaire-title">'
        '<h3 id="glossaire-title">' + escape(str(titre)) + '</h3><ol>'
        + ''.join(items) + '</ol></section>'
    )


def glossaire_texte(defs):
    if not defs:
        return []
    return [f"{ident} — {desc}" for ident, desc in defs.items()]
