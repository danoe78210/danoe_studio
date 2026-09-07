import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from glossaire_shared import (extraire_definitions_glossaire,
                              format_glossaire_html,
                              remplacer_references_glossaire,
                              remplacer_references_texte)


def test_extraire_definitions_glossaire():
    texte = '''# Le Dernier Soir

Le diamant garde un secret.

[^scriptorium]: salle de copie et de travail intellectuel.
[^rune]: signe de pouvoir ou de connaissance.
'''

    corps, defs = extraire_definitions_glossaire(texte)

    assert 'Le diamant garde un secret.' in corps
    assert defs['scriptorium'] == 'salle de copie et de travail intellectuel.'
    assert defs['rune'] == 'signe de pouvoir ou de connaissance.'


def test_definitions_multilignes_et_identifiants_invalides_ignores():
    texte = 'Corps.\n\n[^cristal]: première ligne\n  suite de la définition\n[^bad id]: ignorée'

    corps, defs = extraire_definitions_glossaire(texte)

    assert 'Corps.' in corps
    assert defs['cristal'] == 'première ligne suite de la définition'
    assert 'bad id' not in defs


def test_format_html_echappe_et_retourne_vers_la_reference():
    html = format_glossaire_html({'rune': 'pierre <br> & fragile'})

    assert '<strong class="glossary-term">rune</strong>' in html
    assert 'pierre &lt;br&gt; &amp; fragile' in html
    assert 'href="#ref-rune"' in html
    assert 'id="note-rune"' in html


def test_references_respectent_le_mode_desactive():
    texte = 'Voir [^rune].'

    assert remplacer_references_texte(texte) == texte
    assert remplacer_references_texte(texte, active=True) == 'Voir [rune].'
    assert '[^rune]' in remplacer_references_glossaire(texte)
    assert 'href="#note-rune"' in remplacer_references_glossaire(texte, True)
