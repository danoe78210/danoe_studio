#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generer_kpf.py — Pipeline d'export KPF (Kindle Package Format) pour Danoë Studio

Pipeline en 4 étapes, conforme au cahier des charges Chef de Projet :

  1. Mammoth  → conversion DOCX → HTML sémantique (styles structurants seuls)
  2. Jinja2   → templating HTML5/CSS3 optimisé liseuses
  3. zipfile  → packaging EPUB 3 intermédiaire (norme IDPF stricte)
  4. subprocess → compilation .kpf via Kindle Previewer 3 CLI

Le fichier .kpf est le livrable natif d'Amazon Kindle Create / Kindle
Previewer : il est accepté tel quel par KDP et préserve la typographie,
les styles et les images sans recompilation côté serveur.

Dépendances : pip install mammoth jinja2
Exécutable requis : KindlePreviewer3.exe (Kindle Previewer 3 d'Amazon)

Usage :
    python generer_kpf.py              → génère l'EPUB puis le .kpf
    python generer_kpf.py --epub-only  → génère l'EPUB intermédiaire seul
"""
import os
import re
import sys
import glob
import io
import uuid
import zipfile
import shutil
import tempfile
import subprocess
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from html import escape as html_escape

# ── Réutilisation des utilitaires éprouvés du générateur EPUB ──
from generer_ebook import (
    lire_infos,
    lire_annexes,
    trouver_docx,
    trouver_couverture,
    couverture_octets,
    page_xhtml,
    valider_xml,
    TITRE, SOUS_TITRE, AUTEUR, ISBN, ANNEE, EDITEUR, COPYRIGHT,
    SITE, DEDICACE, EPIGRAPHE,
    BASE, DOSSIER_IMAGES, DOSSIER_CHAPITRES,
    CONTAINER_XML,
)

try:
    import mammoth
except ImportError:
    mammoth = None
    print('   ⚠️  mammoth requis : pip install mammoth')

try:
    from jinja2 import Template
except ImportError:
    Template = None
    print('   ⚠️  Jinja2 requis : pip install jinja2')

try:
    from structure_commune import plan_livre
except ImportError:
    plan_livre = None

# v1.0 : code de retour exposé au module appelant (interface ou CLI)
KPF_CODE = 0

# ─────────────────────────────────────────────────────────────
# 1. CONSTANTES
# ─────────────────────────────────────────────────────────────

# Mapping des styles Word Danoë Studio → HTML sémantique Kindle.
# Mammoth ignore les surcharges locales (polices, couleurs) et ne conserve
# que la structure hiérarchique utile aux liseuses.
MAMMOTH_STYLE_MAP = """
p[style-name='TitreActe'] => section.acte > h1:fresh
p[style-name='TitreChapitre'] => h1:fresh
p[style-name='TitreSousChap'] => h2:fresh
p[style-name='SeparateurScene'] => p.sep:fresh
p[style-name='CorpsTexte'] => p:fresh
p[style-name='Normal'] => p:fresh
p[style-name='Title'] => h1.title:fresh
r[style-name='strong'] => strong
r[style-name='Strong'] => strong
"""

# Template Jinja2 pour une page XHTML EPUB 3.
TEMPLATE_XHTML = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="fr" lang="fr">
<head>
<meta charset="utf-8" />
<title>{{ titre }}</title>
<link rel="stylesheet" type="text/css" href="style/default.css"/>
</head>
<body>
{{ contenu | safe }}
</body>
</html>
"""

# CSS stricte, sans décorations, optimisée pour le reflow Kindle (KF8).
CSS_KPF = b"""@charset "UTF-8";
body {
  font-family: "Times New Roman", Georgia, serif;
  font-size: 1em;
  text-align: justify;
  line-height: 1.6;
  margin: 1em 1.1em;
}
h1 { text-align: center; page-break-before: always; margin: 2em 0 1em; font-size: 1.8em; }
h2 { text-align: center; page-break-before: always; margin: 1.5em 0 0.8em; font-size: 1.4em; }
p {
  text-align: justify;
  text-indent: 1.2em;
  margin: 0 0 0.7em 0;
}
p.first { text-indent: 0; }
p.sep { text-align: center; margin: 1em 0; text-indent: 0; letter-spacing: 0.3em; }
section.acte { page-break-before: always; text-align: center; padding-top: 35%; margin-bottom: 1em; }
section.acte h1 { page-break-before: never; }
.title-page { text-align: center; margin: 3em 1em; page-break-after: always; }
.title-page h1 { font-size: 2.2em; page-break-before: never; letter-spacing: 0.05em; }
.title-page .subtitle { font-size: 1.3em; font-style: italic; }
.title-page .author { margin-top: 3em; font-size: 1.3em; }
img { max-width: 90%; display: block; margin: 1em auto; }
strong { font-weight: bold; }
em { font-style: italic; }
"""

# Dossiers probables de Kindle Previewer 3 (Windows).
KINDLE_PREVIEWER_EXES = [
    'kindlepreviewer4.exe',   # Kindle Previewer 4 (Windows Store)
    'KindlePreviewer3.exe',   # Kindle Previewer 3 (legacy)
    'kindlepreviewer.exe',    # nom générique
    'KindlePreviewer.exe',
]

# Dossiers probables de Kindle Previewer 3 (Windows).
KINDLE_PREVIEWER_DIRS = [
    os.path.expandvars(r'%LOCALAPPDATA%\Amazon\Kindle Previewer 3'),
    os.path.expandvars(r'%LOCALAPPDATA%\Amazon\Kindle Previewer 3\application'),
    r'C:\Program Files\Amazon\Kindle Previewer 3',
    r'C:\Program Files (x86)\Amazon\Kindle Previewer 3',
    # Dossier portable prévu pour la version autonome Danoë Studio.
    os.path.join(BASE, 'bin', 'kindle_tools'),
]

# ─────────────────────────────────────────────────────────────
# 2. CONVERSION DOCX → HTML (Mammoth)
# ─────────────────────────────────────────────────────────────

def conversion_mammoth(docx_path):
    """Convertit un DOCX en HTML sémantique via Mammoth.

    Retourne (html_brut, images_dict) où images_dict est un
    {nom_fichier: bytes} des images extraites.
    """
    if mammoth is None:
        raise RuntimeError('mammoth non installé : pip install mammoth')

    images = {}

    def _convertir_image(image):
        """Handler Mammoth : enregistre les images extraites."""
        with image.open() as img_bytes:
            data = img_bytes.read()
        ext = image.content_type.split('/')[-1]
        if ext == 'jpeg':
            ext = 'jpg'
        nom = f'image_{len(images) + 1:03d}.{ext}'
        images[nom] = data
        return {'src': f'images/{nom}'}

    print('   🔄 Conversion DOCX → HTML (Mammoth)…')
    with open(docx_path, 'rb') as f:
        resultat = mammoth.convert_to_html(
            f,
            style_map=MAMMOTH_STYLE_MAP,
            convert_image=mammoth.images.img_element(_convertir_image),
        )

    if resultat.messages:
        for msg in resultat.messages:
            niveau = '⚠️' if msg.level == 'warning' else 'ℹ️'
            print(f'      {niveau} Mammoth: {msg.message}')

    html = resultat.value

    # Nettoyages post-Mammoth
    html = _nettoyer_html_mammoth(html)

    print(f'   ✅ HTML sémantique produit : {len(html)} caractères, '
          f'{len(images)} image(s) extraite(s)')
    return html, images


def _nettoyer_html_mammoth(html):
    """Post-traitement du HTML produit par Mammoth.

    - Supprime les paragraphes vides résiduels (<p></p>).
    - Marque le premier <p> de chaque section comme class="first"
      (pas de retrait, convention typographique française).
    - Enveloppe les <h1> isolés suivis de <p> dans une structure cohérente.
    """
    # Supprimer les paragraphes vides
    html = re.sub(r'<p>\s*</p>', '', html)

    # Marquer le premier paragraphe après chaque h1/h2 comme .first
    html = re.sub(
        r'(</h[12]>\s*)(<p>)',
        r'\1<p class="first">',
        html,
    )

    return html


# ─────────────────────────────────────────────────────────────
# 3. TEMPLATING HTML5/CSS3 (Jinja2)
# ─────────────────────────────────────────────────────────────

def appliquer_template_xhtml(titre, contenu_html):
    """Applique le template Jinja2 XHTML à un contenu HTML."""
    if Template is None:
        raise RuntimeError('Jinja2 non installé : pip install jinja2')
    template = Template(TEMPLATE_XHTML)
    return template.render(titre=html_escape(titre), contenu=contenu_html)


def decouper_en_chapitres(html, infos):
    """Découpe le HTML Mammoth en chapitres structurés.

    Retourne une liste de dicts : {'id', 'titre', 'html', 'type'}
    où type ∈ {'acte', 'chapitre', 'titre', 'final'}.
    """
    chapitres = []

    # Split sur les balises <h1>...</h1>
    parties = re.split(r'(<h1[^>]*>.*?</h1>)', html, flags=re.DOTALL)

    # Préambule (avant le 1er h1) → page de titre
    if parties[0].strip():
        titre_livre = infos.get(TITRE, 'Roman')
        chapitres.append({
            'id': 'titre',
            'titre': titre_livre,
            'html': ('<div class="title-page">' +
                     f'<h1>{html_escape(titre_livre)}</h1>' +
                     (f'<p class="subtitle">{html_escape(infos.get(SOUS_TITRE, ""))}</p>'
                      if infos.get(SOUS_TITRE) else '') +
                     f'<p class="author">{html_escape(infos.get(AUTEUR, "Auteur"))}</p>' +
                     '</div>'),
            'type': 'titre',
        })

    # Paires (h1, contenu)
    i = 1
    seq = 0
    while i < len(parties):
        h1_tag = parties[i]
        contenu = parties[i + 1] if i + 1 < len(parties) else ''

        # Extraire le texte du h1
        titre_match = re.search(r'<h1[^>]*>(.*?)</h1>', h1_tag, re.DOTALL)
        titre = titre_match.group(1).strip() if titre_match else 'Section'
        # Nettoyer les balises internes (ex: <strong>)
        titre = re.sub(r'<[^>]+>', '', titre)

        # Déterminer le type
        if 'class="title"' in h1_tag or titre.lower().startswith('table des mati'):
            i += 2
            continue  # Ignorer la table des matières Mammoth

        seq += 1
        if titre.lower().startswith('acte'):
            type_chap = 'acte'
        elif titre.lower() in ('glossaire', 'du même auteur'):
            type_chap = 'final'
        else:
            type_chap = 'chapitre'

        chap_id = f'chap{seq:03d}'
        html_chap = h1_tag + contenu.strip()

        chapitres.append({
            'id': chap_id,
            'titre': titre,
            'html': html_chap,
            'type': type_chap,
        })
        i += 2

    print(f'   📊 {len(chapitres)} sections : '
          f'{sum(1 for c in chapitres if c["type"] == "acte")} acte(s), '
          f'{sum(1 for c in chapitres if c["type"] == "chapitre")} chapitre(s), '
          f'{sum(1 for c in chapitres if c["type"] == "final")} page(s) finale(s)')
    return chapitres

# ─────────────────────────────────────────────────────────────
# 4. PACKAGING EPUB 3 INTERMÉDIAIRE
# ─────────────────────────────────────────────────────────────

def construire_epub_kpf(html_global, images_mammoth, infos, couverture_data, sortie_epub):
    """Package l'EPUB 3 intermédiaire conforme IDPF."""
    titre = infos[TITRE] or 'Roman'
    sous_titre = infos[SOUS_TITRE] or ''
    auteur = infos[AUTEUR] or 'Auteur'
    annee = infos[ANNEE] or str(datetime.now().year)
    ident = infos[ISBN] or str(uuid.uuid4())
    titre_complet = f'{titre} – {sous_titre}' if sous_titre else titre
    editeur_nom = infos[EDITEUR] or auteur
    copyright_txt = infos[COPYRIGHT] or f'© {annee} {auteur}. Tous droits réservés.'

    print('   📦 Découpage en chapitres…')
    chapitres = decouper_en_chapitres(html_global, infos)

    items = []
    spine = []
    toc_ncx = []

    def add(iid, href, media, data, props=None):
        items.append({'id': iid, 'href': href, 'media': media,
                      'data': data, 'props': props})

    def add_page(iid, href, titre_page, corps_html, entree_toc=None):
        xhtml = appliquer_template_xhtml(titre_page, corps_html)
        add(iid, href, 'application/xhtml+xml', xhtml.encode('utf-8'))
        spine.append(iid)
        if entree_toc:
            toc_ncx.append((iid, entree_toc))

    # Ressources fixes
    add('css', 'style/default.css', 'text/css', CSS_KPF)
    if couverture_data:
        add('cover-image', 'cover.jpg', 'image/jpeg', couverture_data)

# Page de couverture
    if couverture_data:
        corps_cover = ('<div style="text-align:center;margin:0;padding:0;">'
                       '<img src="cover.jpg" alt="Couverture" '
                       'style="width:100%;height:100vh;object-fit:contain;"/>'
                       '</div>')
        add_page('cover-page', 'cover.xhtml', 'Couverture', corps_cover)

    # Faux-titre
    add_page('faux-titre', 'faux-titre.xhtml', 'Faux-titre',
             f'<div class="faux-titre"><h1>{html_escape(titre)}</h1></div>')

    # Copyright
    lignes_cr = [titre_complet, '', copyright_txt]
    if infos[ISBN]:
        lignes_cr.append('ISBN : ' + infos[ISBN])
    lignes_cr.append(f'Dépôt légal : {annee}')
    if infos[SITE]:
        lignes_cr += ['', infos[SITE]]
    lignes_cr += ['', "Toute reproduction interdite sans autorisation."]
    corps_cr = '<div class="copyright">' + ''.join(
        f'<p style="text-indent:0">{html_escape(l) if l else "&#160;"}</p>'
        for l in lignes_cr) + '</div>'
    add_page('copyright', 'copyright.xhtml', 'Mentions légales', corps_cr)

    # Dédicace, épigraphe
    if infos[DEDICACE]:
        corps_ded = '<div class="dedication">' + ''.join(
            f'<p>{html_escape(l)}</p>' for l in infos[DEDICACE].splitlines() if l.strip()) + '</div>'
        add_page('dedicace', 'dedicace.xhtml', 'Dédicace', corps_ded)

    if infos[EPIGRAPHE]:
        corps_epi = '<div class="epigraph">' + ''.join(
            f'<p>{html_escape(l)}</p>' for l in infos[EPIGRAPHE].splitlines() if l.strip()) + '</div>'
        add_page('epigraphe', 'epigraphe.xhtml', 'Épigraphe', corps_epi)

    # Images extraites par Mammoth
    for nom, data in images_mammoth.items():
        ext = nom.rsplit('.', 1)[-1]
        mime = 'image/jpeg' if ext in ('jpg', 'jpeg') else 'image/png'
        img_id = 'img_' + nom.rsplit('.', 1)[0].replace('image_', '')
        add(img_id, f'images/{nom}', mime, data)
# Chapitres
    idx_xhtml = 0
    for chap in chapitres:
        idx_xhtml += 1
        cid = f'chap{idx_xhtml:03d}'
        href = f'{cid}.xhtml'
        add_page(cid, href, chap['titre'], chap['html'], chap['titre'])

    # nav.xhtml
    nav_html = ('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
                '<html xmlns="http://www.w3.org/1999/xhtml" '
                'xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="fr" lang="fr">\n'
                '<head>\n<meta charset="utf-8" />\n<title>Table des matières</title>\n</head>\n'
                '<body>\n<nav epub:type="toc" id="toc"><h1>Table des matières</h1><ol>')
    for iid, lib in toc_ncx:
        href = next(i['href'] for i in items if i['id'] == iid)
        nav_html += f'<li><a href="{href}">{html_escape(lib)}</a></li>'
    nav_html += '</ol></nav>\n</body></html>'
    add('nav', 'nav.xhtml', 'application/xhtml+xml', nav_html.encode('utf-8'), 'nav')

    # toc.ncx
    ncx_xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
               '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">\n'
               '<head>'
               f'<meta name="dtb:uid" content="{html_escape(ident)}"/>'
               '<meta name="dtb:depth" content="1"/>'
               '<meta name="dtb:totalPageCount" content="0"/>'
               '<meta name="dtb:maxPageNumber" content="0"/>'
               '</head>'
               f'<docTitle><text>{html_escape(titre_complet)}</text></docTitle>\n'
               '<navMap>')
    for n, (iid, lib) in enumerate(toc_ncx, 1):
        href = next(i['href'] for i in items if i['id'] == iid)
        ncx_xml += (f'<navPoint id="np{n}" playOrder="{n}"><navLabel>'
                    f'<text>{html_escape(lib)}</text></navLabel>'
                    f'<content src="{href}"/></navPoint>')
    ncx_xml += '</navMap></ncx>'
    add('ncx', 'toc.ncx', 'application/x-dtbncx+xml', ncx_xml.encode('utf-8'))
# content.opf
    modifie = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    opf = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
           'unique-identifier="book-id" xml:lang="fr">\n<metadata '
           'xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
           f'<dc:identifier id="book-id">{html_escape(ident)}</dc:identifier>\n'
           f'<dc:title>{html_escape(titre_complet)}</dc:title>\n'
           '<dc:language>fr</dc:language>\n'
           f'<dc:creator>{html_escape(auteur)}</dc:creator>\n'
           f'<dc:publisher>{html_escape(editeur_nom)}</dc:publisher>\n'
           f'<dc:rights>{html_escape(copyright_txt)}</dc:rights>\n'
           f'<dc:date>{annee}</dc:date>\n'
           f'<dc:description>Ebook de {html_escape(auteur)}.</dc:description>\n'
           f'<meta property="dcterms:modified">{modifie}</meta>\n')
    if couverture_data:
        opf += '<meta name="cover" content="cover-image"/>\n'
    opf += '</metadata>\n<manifest>\n'
    for i in items:
        props = f' properties="{i["props"]}"' if i.get('props') else ''
        opf += f'<item id="{i["id"]}" href="{i["href"]}" media-type="{i["media"]}"{props}/>\n'
    opf += '</manifest>\n<spine toc="ncx">\n'
    for idref in spine:
        opf += f'<itemref idref="{idref}"/>\n'
    opf += '</spine>\n</package>'

    # Validation XML (non bloquante pour le KPF — Kindle Previewer corrige)
    nb_erreurs_xml = 0
    for i in items:
        if i['media'] in ('application/xhtml+xml', 'application/x-dtbncx+xml'):
            err = valider_xml(i['href'], i['data'])
            if err:
                nb_erreurs_xml += 1
                if nb_erreurs_xml <= 3:
                    print(f'   ⚠️  XML mineur → {err}')
    if nb_erreurs_xml:
        print(f'   ℹ️  {nb_erreurs_xml} avertissement(s) XML (Kindle Previewer les corrige)')
# Écriture ZIP (mimetype en premier, non compressé)
    with zipfile.ZipFile(sortie_epub, 'w') as zf:
        zi = zipfile.ZipInfo('mimetype')
        zi.compress_type = zipfile.ZIP_STORED
        zf.writestr(zi, 'application/epub+zip')
        zf.writestr('META-INF/container.xml', CONTAINER_XML, zipfile.ZIP_DEFLATED)
        zf.writestr('OEBPS/content.opf', opf, zipfile.ZIP_DEFLATED)
        for i in items:
            zf.writestr('OEBPS/' + i['href'], i['data'], zipfile.ZIP_DEFLATED)

    print(f'   ✅ EPUB 3 : {os.path.basename(sortie_epub)}')
    print(f'   📊 {len(chapitres)} sections, {len(spine)} pages, '
          f'{len(images_mammoth)} images')
    return True


# ─────────────────────────────────────────────────────────────
# 5. COMPILATION KPF (Kindle Previewer 3 CLI)
# ─────────────────────────────────────────────────────────────

def trouver_kindle_previewer():
    """Cherche KindlePreviewer*.exe dans PATH, dossiers standards et portable."""
    # Chercher dans le PATH avec tous les noms possibles
    for chemin in os.environ.get('PATH', '').split(os.pathsep):
        for nom in KINDLE_PREVIEWER_EXES:
            exe = os.path.join(chemin, nom)
            if os.path.isfile(exe):
                return exe
    # Chercher dans les dossiers connus
    for dossier in KINDLE_PREVIEWER_DIRS:
        if os.path.isdir(dossier):
            for nom in KINDLE_PREVIEWER_EXES:
                exe = os.path.join(dossier, nom)
                if os.path.isfile(exe):
                    return exe
            try:
                for entree in os.listdir(dossier):
                    chemin = os.path.join(dossier, entree)
                    if os.path.isdir(chemin):
                        for nom in KINDLE_PREVIEWER_EXES:
                            exe = os.path.join(chemin, nom)
                            if os.path.isfile(exe):
                                return exe
            except OSError:
                pass
    return None

def convertir_kpf(epub_path, exe_kindle=None, timeout=300):
    """Convertit un EPUB en KPF via Kindle Previewer 3 CLI."""
    if exe_kindle is None:
        exe_kindle = trouver_kindle_previewer()

    if exe_kindle is None or not os.path.isfile(exe_kindle):
        print('   ⚠️  KindlePreviewer3.exe introuvable.')
        print('   ℹ️  Téléchargez Kindle Previewer 3 sur kdp.amazon.com')
        print('   ℹ️  Placez l\'exécutable dans le PATH ou bin/kindle_tools/')
        return False, None, 'Kindle Previewer 3 non installé'

    epub_abs = os.path.abspath(epub_path)
    sortie_dossier = os.path.dirname(epub_abs)
    sortie_kpf = epub_abs.replace('.epub', '.kpf')
    dossier_kpf = os.path.join(sortie_dossier, 'KPF')
    cmd = [exe_kindle, epub_abs, '--convert', '--locale', 'fr',
           '--output', sortie_dossier]
    print(f'   🔄 Conversion KPF…')

    try:
        resultat = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
            cwd=os.path.dirname(epub_abs),
        )
        logs = (resultat.stdout or '') + '\n' + (resultat.stderr or '')
        if resultat.returncode == 0:
            # Kindle Previewer 4 place .kpf dans sous-dossier KPF/
            kpf_trouve = None
            if os.path.isfile(sortie_kpf):
                kpf_trouve = sortie_kpf
            elif os.path.isdir(dossier_kpf):
                candidates = [f for f in os.listdir(dossier_kpf) if f.endswith('.kpf')]
                if candidates:
                    kpf_trouve = os.path.join(dossier_kpf, candidates[0])
            if kpf_trouve:
                print(f'   ✅ KPF généré : {os.path.basename(kpf_trouve)}')
                return True, kpf_trouve, logs
            else:
                print(f'   ⚠️  KPF introuvable après conversion (code {resultat.returncode})')
                return False, None, logs
        else:
            print(f'   ❌ Échec (code {resultat.returncode})')
            if resultat.stderr:
                for ligne in resultat.stderr.strip().split('\n')[-5:]:
                    print(f'      {ligne}')
            return False, sortie_kpf if os.path.isfile(sortie_kpf) else None, logs
    except subprocess.TimeoutExpired:
        print(f'   ⚠️  Timeout ({timeout}s)')
        return False, None, 'Timeout'
    except Exception as e:
        print(f'   ❌ Erreur : {e}')
        return False, None, str(e)

# ─────────────────────────────────────────────────────────────
# 6. AUTO-CONTRÔLE
# ─────────────────────────────────────────────────────────────

def verifier_epub_kpf(chemin):
    """Valide la structure de l'EPUB intermédiaire KPF."""
    ok = True
    try:
        with zipfile.ZipFile(chemin, 'r') as z:
            noms = z.namelist()
            if noms and noms[0] == 'mimetype' \
                    and z.getinfo('mimetype').compress_type == zipfile.ZIP_STORED \
                    and z.read('mimetype') == b'application/epub+zip':
                print('   ✅ mimetype conforme')
            else:
                print('   ⚠️  mimetype non conforme')
                ok = False

            if 'META-INF/container.xml' in noms:
                cxml = z.read('META-INF/container.xml')
                try:
                    ET.fromstring(cxml)
                    if not cxml.startswith(b'<?xml'):
                        print('   ⚠️  container.xml ne commence pas par <?xml')
                        ok = False
                except Exception as e:
                    print(f'   ⚠️  container.xml XML invalide : {e}')
                    ok = False

            if 'OEBPS/content.opf' in noms:
                opf_bytes = z.read('OEBPS/content.opf')
                try:
                    ET.fromstring(opf_bytes)
                    print('   ✅ OPF valide')
                except Exception as e:
                    print(f'   ⚠️  OPF invalide : {e}')
                    ok = False

            nb_bad = sum(1 for n in noms
                        if n.endswith(('.xhtml', '.ncx', '.opf'))
                        and valider_xml(n, z.read(n)))
            if nb_bad:
                print(f'   ⚠️  {nb_bad} document(s) XML invalide(s)')
                ok = False
            else:
                print('   ✅ Tous les documents XML valides')
    except Exception as e:
        print(f'   ⚠️  Vérification impossible : {e}')
        ok = False
    return ok


# ─────────────────────────────────────────────────────────────
# 7. POINT D'ENTRÉE
# ─────────────────────────────────────────────────────────────

def main(epub_only=False):
    print('=' * 58)
    print('📱  GÉNÉRATION KPF (Kindle Package Format)')
    print('=' * 58)
    t0 = time.time()

    docx = trouver_docx()
    if not docx or not os.path.isfile(docx):
        print('   ℹ️  Aucun fichier *_KDP.docx trouvé.')
        print('   ℹ️  Lancez d\'abord « Générer le livre » dans l\'interface.')
        return 0
    print(f'   📄 Source : {os.path.basename(docx)}')

    infos = lire_infos()
    if not infos.get(TITRE):
        infos[TITRE] = 'Roman'
    print(f'   📚 {infos[TITRE]} — {infos.get(AUTEUR, "Auteur")}')

    couv_bytes, couv_nom = couverture_octets()

    # Étape 1 : Mammoth
    print()
    try:
        html_brut, images = conversion_mammoth(docx)
    except Exception as e:
        print(f'   ⚠️  Échec conversion Mammoth : {e}')
        return 0

    # Étape 2-3 : Jinja2 + EPUB3
    sortie_epub = os.path.join(BASE, 'export',
                               os.path.basename(docx).replace('.docx', '_KPF.epub'))
    print()
    try:
        construire_epub_kpf(html_brut, images, infos, couv_bytes, sortie_epub)
    except Exception as e:
        print(f'   ⚠️  Échec packaging EPUB : {e}')
        import traceback
        traceback.print_exc()
        return 0

    # Auto-contrôle
    print()
    print('   🔎 Auto-contrôle…')
    verifier_epub_kpf(sortie_epub)

    if epub_only:
        print(f'\n✅ EPUB KPF intermédiaire : {sortie_epub}')
        print(f'   ⏱️  Durée : {time.time() - t0:.1f} s')
        return 0

    # Étape 4 : Kindle Previewer
    print()
    exe = trouver_kindle_previewer()
    if exe:
        print(f'   🛠️  Kindle Previewer 3 : {exe}')
    else:
        print('   ℹ️  Kindle Previewer 3 non détecté.')
        print('   ℹ️  Installez-le puis relancez, ou utilisez --epub-only.')
        print(f'\n✅ EPUB KPF intermédiaire : {sortie_epub}')
        print(f'   ⏱️  Durée : {time.time() - t0:.1f} s')
        return 0

    ok, kpf, logs = convertir_kpf(sortie_epub, exe)
    if ok:
        print(f'\n✅ KPF prêt pour KDP : {kpf}')
    else:
        print(f'\n   ⚠️  Conversion KPF échouée.')
        print(f'   ℹ️  EPUB intermédiaire disponible : {sortie_epub}')

    print(f'   ⏱️  Durée : {time.time() - t0:.1f} s')
    return 0


if __name__ == '__main__':
    epub_only = '--epub-only' in sys.argv
    sys.exit(main(epub_only=epub_only) or 0)