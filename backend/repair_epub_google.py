#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
repair_epub_google.py — Répare un EPUB pour compatibilité Google Play Books

Corrige les problèmes critiques :
  1. Ajoute <guide> dans content.opf
  2. Ajoute landmarks nav dans nav.xhtml
  3. Ajoute <dc:rights> et <dc:publisher> dans les métadonnées OPF
  4. Reconstruit le ZIP avec mimetype STORED en première position
"""
import os, sys, io, zipfile, shutil, tempfile, xml.etree.ElementTree as ET
from datetime import datetime, timezone


def repair_epub(input_path, output_path=None):
    """Répare un EPUB existant pour Google Play Books."""
    if output_path is None:
        base, ext = os.path.splitext(input_path)
        output_path = base + '_google_ready' + ext

    tmpdir = tempfile.mkdtemp(prefix='epub_repair_')
    try:
        # 1. Extraire
        with zipfile.ZipFile(input_path, 'r') as zf:
            zf.extractall(tmpdir)

        opf_path = os.path.join(tmpdir, 'OEBPS', 'content.opf')
        nav_path = os.path.join(tmpdir, 'OEBPS', 'nav.xhtml')

        if not os.path.exists(opf_path):
            print('❌ content.opf introuvable')
            return False

        # 2. Lire et parser l'OPF
        with open(opf_path, 'r', encoding='utf-8') as f:
            opf_content = f.read()

        ns = {
            'opf': 'http://www.idpf.org/2007/opf',
            'dc': 'http://purl.org/dc/elements/1.1/',
        }

        root = ET.fromstring(opf_content)
        metadata = root.find('opf:metadata', ns)
        manifest = root.find('opf:manifest', ns)
        spine = root.find('opf:spine', ns)

        # Récupérer les infos existantes
        auteur = ''
        titre = ''
        annee = ''
        has_cover = False
        for elem in metadata:
            tag = elem.tag.split('}')[-1] if '}' in elem.tag else elem.tag
            if tag == 'creator' and not auteur:
                auteur = elem.text or ''
            elif tag == 'title' and not titre:
                titre = elem.text or ''
            elif tag == 'date' and not annee:
                annee = elem.text or ''
            elif tag == 'meta' and elem.get('name') == 'cover':
                has_cover = True

        existing_tags = set()
        for elem in metadata:
            tag = elem.tag.split('}')[-1] if '}' in elem.tag else elem.tag
            existing_tags.add(tag)

        # 3. Ajouter <dc:publisher> si absent
        if 'publisher' not in existing_tags:
            pub_elem = ET.SubElement(metadata, '{http://purl.org/dc/elements/1.1/}publisher')
            pub_elem.text = auteur or 'Auto-édition'

        # 4. Ajouter <dc:rights> si absent
        if 'rights' not in existing_tags:
            rights_elem = ET.SubElement(metadata, '{http://purl.org/dc/elements/1.1/}rights')
            year = annee or str(datetime.now().year)
            author = auteur or 'Auteur'
            rights_elem.text = f'© {year} {author}. Tous droits réservés.'

        # 5. Ajouter <guide> si absent
        existing_guide = root.find('opf:guide', ns)
        premier_texte = None
        href_texte = None
        if existing_guide is None:
            guide = ET.SubElement(root, '{http://www.idpf.org/2007/opf}guide')

            if has_cover:
                cover_ref = ET.SubElement(guide, '{http://www.idpf.org/2007/opf}reference')
                cover_ref.set('type', 'cover')
                cover_ref.set('title', 'Couverture')
                cover_ref.set('href', 'title.xhtml')

            tdm_item = manifest.find("opf:item[@href='tdm.xhtml']", ns)
            if tdm_item is not None:
                toc_ref = ET.SubElement(guide, '{http://www.idpf.org/2007/opf}reference')
                toc_ref.set('type', 'toc')
                toc_ref.set('title', 'Table des matières')
                toc_ref.set('href', 'tdm.xhtml')

            # Début du texte
            liminaires = {'faux-titre', 'title', 'copyright', 'dedicace',
                         'epigraphe', 'tdm', 'preface', 'frontispice'}
            spine_items = spine.findall('opf:itemref', ns)
            for si in spine_items:
                idref = si.get('idref')
                if idref and idref not in liminaires:
                    premier_texte = idref
                    break
            if premier_texte:
                href_item = manifest.find(f"opf:item[@id='{premier_texte}']", ns)
                if href_item is not None:
                    href_texte = href_item.get('href')
                    text_ref = ET.SubElement(guide, '{http://www.idpf.org/2007/opf}reference')
                    text_ref.set('type', 'text')
                    text_ref.set('title', 'Début du texte')
                    text_ref.set('href', href_texte)
# Sérialiser l'OPF modifié
        ET.register_namespace('', 'http://www.idpf.org/2007/opf')
        ET.register_namespace('dc', 'http://purl.org/dc/elements/1.1/')
        new_opf = ET.tostring(root, encoding='unicode', xml_declaration=True)
        new_opf = new_opf.replace(' xmlns:ns0="http://www.idpf.org/2007/opf"', '')
        new_opf = new_opf.replace(' xmlns:ns1="http://purl.org/dc/elements/1.1/"', '')
        new_opf = new_opf.replace('ns0:', '').replace('ns1:', '')
        new_opf = '<?xml version="1.0" encoding="utf-8"?>\n' + new_opf.split('?>', 1)[-1].lstrip()

        with open(opf_path, 'w', encoding='utf-8') as f:
            f.write(new_opf)
        print('✅ content.opf corrigé : +<dc:publisher>, +<dc:rights>, +<guide>')

        # 6. Corriger nav.xhtml : ajouter landmarks
        if os.path.exists(nav_path):
            with open(nav_path, 'r', encoding='utf-8') as f:
                nav_content = f.read()

            if 'epub:type="landmarks"' not in nav_content:
                landmarks = '<nav epub:type="landmarks" hidden="">\n<ol>\n'
                if has_cover:
                    landmarks += '<li><a epub:type="cover" href="title.xhtml">Couverture</a></li>\n'
                if 'tdm.xhtml' in nav_content:
                    landmarks += '<li><a epub:type="toc" href="tdm.xhtml">Table des matières</a></li>\n'
                debut_href = href_texte or 'acte001.xhtml'
                landmarks += f'<li><a epub:type="bodymatter" href="{debut_href}">Début du texte</a></li>\n'
                landmarks += '</ol>\n</nav>\n'
                nav_content = nav_content.replace('</body>', landmarks + '</body>')
                with open(nav_path, 'w', encoding='utf-8') as f:
                    f.write(nav_content)
                print('✅ nav.xhtml corrigé : +landmarks nav')
# 7. Reconstruire le ZIP (mimetype en premier, STORED)
        with zipfile.ZipFile(output_path, 'w') as zf_out:
            mimetype_path = os.path.join(tmpdir, 'mimetype')
            zi = zipfile.ZipInfo('mimetype')
            zi.compress_type = zipfile.ZIP_STORED
            with open(mimetype_path, 'rb') as f:
                zf_out.writestr(zi, f.read())

            for root_dir, dirs, files in os.walk(tmpdir):
                for file in files:
                    if file == 'mimetype':
                        continue
                    full_path = os.path.join(root_dir, file)
                    arcname = os.path.relpath(full_path, tmpdir).replace('\\', '/')
                    zf_out.write(full_path, arcname, zipfile.ZIP_DEFLATED)

        print(f'✅ EPUB réparé → {output_path}')
        return True

    except Exception as e:
        print(f'❌ Erreur : {e}')
        import traceback
        traceback.print_exc()
        return False
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
def validate_epub(path):
    """Valide la structure d'un EPUB pour Google Books."""
    print(f'\n📋 Validation : {os.path.basename(path)}')
    ok = True
    try:
        with zipfile.ZipFile(path, 'r') as z:
            noms = z.namelist()
            if noms and noms[0] == 'mimetype':
                zinfo = z.getinfo('mimetype')
                if zinfo.compress_type == zipfile.ZIP_STORED and z.read('mimetype') == b'application/epub+zip':
                    print('   ✅ mimetype conforme (1er, non compressé)')
                else:
                    print('   ⚠️  mimetype non conforme')
                    ok = False
            else:
                print('   ❌ mimetype absent ou mal positionné')
                ok = False

            if 'META-INF/container.xml' in noms:
                print('   ✅ container.xml présent')

            opf_bytes = b''
            if 'OEBPS/content.opf' in noms:
                opf_bytes = z.read('OEBPS/content.opf')
                try:
                    ET.fromstring(opf_bytes)
                    print('   ✅ content.opf XML valide')
                    if b'<guide>' in opf_bytes:
                        print('   ✅ <guide> présent')
                    else:
                        print('   ⚠️  <guide> absent')
                        ok = False
                    if b'dc:rights' in opf_bytes or b'<rights>' in opf_bytes:
                        print('   ✅ <dc:rights> présent')
                    if b'dc:publisher' in opf_bytes or b'<publisher>' in opf_bytes:
                        print('   ✅ <dc:publisher> présent')
                except Exception as e:
                    print(f'   ❌ content.opf XML invalide : {e}')
                    ok = False

            if 'OEBPS/nav.xhtml' in noms:
                nav_bytes = z.read('OEBPS/nav.xhtml')
                if b'epub:type="landmarks"' in nav_bytes:
                    print('   ✅ landmarks nav présent')
                else:
                    print('   ⚠️  landmarks nav absent')
                    ok = False

            if 'OEBPS/toc.ncx' in noms:
                print('   ✅ toc.ncx présent')
            if 'OEBPS/cover.jpg' in noms:
                print('   ✅ Couverture présente')

            if opf_bytes:
                root = ET.fromstring(opf_bytes)
                ns_opf = {'opf': 'http://www.idpf.org/2007/opf'}
                m_ids = {i.get('id') for i in root.findall('opf:manifest/opf:item', ns_opf)}
                s_ids = {i.get('idref') for i in root.findall('opf:spine/opf:itemref', ns_opf)}
                if s_ids - m_ids:
                    print('   ❌ Spine référence IDs absents du manifest')
                    ok = False
                else:
                    print('   ✅ Cohérence manifest/spine')
    except Exception as e:
        print(f'   ❌ Validation impossible : {e}')
        ok = False

    print(f'   → {"✅ VALIDE" if ok else "❌ PROBLÈMES"}')
    return ok


if __name__ == '__main__':
    default_input = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 'export', 'Les_Schattenjagers_KDP.epub')
    input_path = sys.argv[1] if len(sys.argv) > 1 else default_input

    if not os.path.exists(input_path):
        print(f'❌ Fichier introuvable : {input_path}')
        sys.exit(1)

    print('=' * 58)
    print('🔧 RÉPARATION EPUB POUR GOOGLE PLAY BOOKS')
    print('=' * 58)
    print(f'📄 Source : {os.path.basename(input_path)}')

    if repair_epub(input_path):
        repaired = input_path.replace('.epub', '_google_ready.epub')
        validate_epub(repaired)
    else:
        print('❌ Échec de la réparation')
        sys.exit(1)