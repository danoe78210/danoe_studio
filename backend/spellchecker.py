#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
spellchecker.py – Module de vérification orthographique et grammaticale
Utilise l'API publique de LanguageTool avec gestion du découpage (chunking)
et validation stricte des paramètres pour éviter les erreurs 400.

Correction v1.26.5 : Format correct de 'preferredVariants' avec tiret (fr-FR, fr-CA, etc.).
"""

import requests
import time

def decouper_texte(texte: str, taille_max: int = 5000) -> list:
    """
    Découpe un texte long en morceaux plus petits, en respectant 
    les fins de paragraphes ou les fins de mots.
    """
    chunks = []
    debut = 0
    longueur_totale = len(texte)
    
    while debut < longueur_totale:
        fin = min(debut + taille_max, longueur_totale)
        
        if fin < longueur_totale:
            idx = texte.rfind('\n\n', debut, fin)
            if idx != -1 and idx > debut + (taille_max // 2): 
                fin = idx + 2
            else:
                idx_space = texte.rfind(' ', debut, fin)
                if idx_space != -1:
                    fin = idx_space + 1
        
        chunk = texte[debut:fin]
        chunks.append((debut, chunk))
        debut = fin
        
    return chunks

def verifier_texte(texte: str, langue: str = "fr", config: dict = None) -> list:
    """
    Envoie le texte à l'API LanguageTool.
    :param langue: Langue de vérification (ex: 'fr'). Ignorée si preferredVariants est actif.
    :param config: Dictionnaire contenant 'level', 'preferredVariants', 'motherTongue'
    """
    url = "https://api.languagetool.org/v2/check"
    tous_les_matches = []
    
    if config is None:
        config = {}
        
    # Validation stricte des valeurs
    level = config.get('level', 'default')
    if level not in ['default', 'picky']:
        level = 'default'
        
    variants = config.get('preferredVariants', '')
    # Format correct : fr-FR, fr-CA, fr-CH, fr-BE, fr-1990
    valid_variants = ['fr-FR', 'fr-1990', 'fr-CA', 'fr-CH', 'fr-BE']
    if variants not in valid_variants:
        variants = ''
        
    mother_tongue = config.get('motherTongue', 'Aucune')
    valid_mothers = ['en-US', 'es-ES', 'de-DE', 'it-IT', 'pt-PT', 'nl-NL', 'pl-PL', 'ru-RU']

    chunks = decouper_texte(texte, taille_max=5000)
    
    for i, (offset_debut, chunk) in enumerate(chunks):
        if not chunk.strip():
            continue
            
        # ── CONSTRUCTION SÉCURISÉE DU PAYLOAD ──
        payload = {
            'text': chunk,
            'level': level,
            'enabledOnly': 'false'
        }
        
        # RÈGLE CRITIQUE DE L'API : 
        # Si on utilise 'preferredVariants', 'language' DOIT être 'auto'
        if variants:
            payload['language'] = 'auto'
            # Format correct : fr-FR, fr-CA, etc.
            payload['preferredVariants'] = variants
        else:
            # Sinon, on utilise la langue spécifique
            payload['language'] = langue
        
        # N'ajouter motherTongue que si c'est une valeur valide
        if mother_tongue in valid_mothers:
            payload['motherTongue'] = mother_tongue
        # ────────────────────────────────────────
        
        try:
            if i > 0:
                time.sleep(0.3)  # Délai de politesse pour l'API
                
            response = requests.post(url, data=payload, timeout=15)
            
            if response.status_code == 413:
                print(f"⚠️ Le chunk {i+1} est trop grand. Réduction...")
                chunks[i] = (offset_debut, chunk[:len(chunk)//2])
                chunks.insert(i+1, (offset_debut + len(chunk)//2, chunk[len(chunk)//2:]))
                continue
                
            if response.status_code == 400:
                print(f"⚠️ Erreur 400 API (Payload invalide) : {response.text}")
                continue
                
            response.raise_for_status()
            result = response.json()
            matches = result.get('matches', [])
            
            # Correction des offsets pour qu'ils soient absolus
            for match in matches:
                match['offset'] += offset_debut
                match['context']['offset'] += offset_debut
                tous_les_matches.append(match)
                
        except requests.exceptions.RequestException as e:
            print(f"Erreur API (chunk {i+1}) : {e}")
        except Exception as e:
            print(f"Erreur inattendue (chunk {i+1}) : {e}")
            
    return tous_les_matches

def appliquer_corrections(texte: str, corrections_a_appliquer: list) -> str:
    """
    Applique les corrections au texte.
    Les corrections DOIVENT être triées par offset DÉCROISSANT.
    """
    if not corrections_a_appliquer:
        return texte
        
    corrections_a_appliquer.sort(key=lambda x: x['offset'], reverse=True)
    
    texte_corrigé = texte
    for corr in corrections_a_appliquer:
        offset = corr['offset']
        length = corr['length']
        nouvelle_valeur = corr['nouvelle_valeur']
        texte_corrigé = texte_corrigé[:offset] + nouvelle_valeur + texte_corrigé[offset + length:]
        
    return texte_corrigé