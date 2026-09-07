import re
from collections import OrderedDict
from html import escape

GLOSSAIRE_RE = re.compile(r'^\[\^([A-Za-z0-9_-]+)\]:\s*(.*)$')
REF_RE = re.compile(r'\[\^([A-Za-z0-9_-]+)\]')


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
    for ident, desc in defs.items():
        ident_html = escape(str(ident), quote=True)
        clean = escape(str(desc).replace('\n', ' ').strip())
        items.append(
            f'<li id="note-{ident_html}">'
            f'<a href="#ref-{ident_html}" aria-label="Retour à la référence '
            f'{ident_html}">↩</a> '
            f'<strong class="glossary-term">{ident_html}</strong> — {clean}</li>'
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
