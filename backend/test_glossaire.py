import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from glossaire_shared import (extraire_definitions_glossaire,
                              format_glossaire_html,
                              GlossaireLivre,
                              remplacer_references_glossaire,
                              remplacer_references_texte)
import generer_ebook
from generer_ebook import runs_to_html
from generer_pdf_direct import _retirer_front_matter_yaml


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


def test_front_matter_yaml_initial_n_est_pas_rendu_dans_le_pdf():
    texte = '---\ntitle: Chapitre test\ntome: 2\n---\n\n# Titre\n\nCorps du chapitre.'

    corps = _retirer_front_matter_yaml(texte)

    assert 'title: Chapitre test' not in corps
    assert '# Titre' in corps
    assert 'Corps du chapitre.' in corps


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


def test_glossaire_livre_numere_et_collecte_les_metadonnees():
    glossaire = GlossaireLivre()
    glossaire.enregistrer(
        {'rune': 'Signe ancien', 'cristal': 'Pierre rare'},
        acte='Acte I', chapitre='Chapitre 1', page='12'
    )

    assert glossaire.remplacer('Une [^rune], puis [^cristal].') == 'Une [1], puis [2].'
    assert glossaire.entrees[0].acte == 'Acte I'
    assert glossaire.entrees[0].chapitre == 'Chapitre 1'
    assert glossaire.entrees[0].page == '12'


def test_glossaire_livre_conserve_le_numero_d_un_identifiant_reutilise():
    glossaire = GlossaireLivre()
    glossaire.enregistrer({'rune': 'Signe ancien'}, chapitre='Chapitre 1')
    glossaire.enregistrer({'rune': 'Autre définition'}, chapitre='Chapitre 2')

    assert glossaire.remplacer('[^rune]') == '[1]'
    assert len(glossaire.entrees) == 1
    assert glossaire.entrees[0].definition == 'Signe ancien'


def test_format_html_collecteur_est_numerote():
    glossaire = GlossaireLivre()
    glossaire.enregistrer({'rune': 'Signe ancien'})

    html = format_glossaire_html(glossaire)

    assert 'id="note-1"' in html
    assert '<strong class="glossary-term">[1] rune</strong>' in html


def test_page_par_defaut_est_vide():
    glossaire = GlossaireLivre()
    glossaire.enregistrer({'rune': 'Signe ancien'})

    assert glossaire.entrees[0].page == ''


def test_entree_word_est_une_cible_epub_numerotee():
    class Run:
        text = '[1] — Acte : Acte I; chapitre : Chapitre 1; page : 8; nom : rune; définition : Signe ancien'
        bold = False
        italic = False

    class Paragraph:
        text = Run.text
        runs = [Run()]

    html = runs_to_html(Paragraph())

    assert 'id="note-1"' in html
    assert '[1]' in html
    assert 'définition : Signe ancien' in html


def test_epub_ne_transforme_pas_les_indices_si_glossaire_desactive():
    generer_ebook.GLOSSAIRE_ACTIF = False

    assert generer_ebook._convertir_numeros_glossaire_html('Voir [1].') == 'Voir [1].'


def test_epub_transformer_les_indices_si_glossaire_actif():
    generer_ebook.GLOSSAIRE_ACTIF = True

    html = generer_ebook._convertir_numeros_glossaire_html('Voir [1].')

    assert 'href="#note-1"' in html
    assert '[1]' in html


def test_epub_ne_genere_pas_de_glossaire_si_desactive():
    generer_ebook.GLOSSAIRE_ACTIF = False

    html = generer_ebook._notes_html('Voir [^rune].\n\n[^rune]: Signe ancien')

    assert 'Glossaire' not in html
    assert html == 'Voir [^rune].\n'
