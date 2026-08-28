#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Script de compilation du backend"""
import os
import sys
import subprocess
import shutil
from pathlib import Path

def nettoyer():
    """Nettoie les anciens builds"""
    print("🧹 Nettoyage des anciens builds...")
    for dossier in ['build', 'dist', '__pycache__']:
        if os.path.exists(dossier):
            shutil.rmtree(dossier)
            print(f"   ✓ {dossier} supprimé")

def verifier_dependances():
    """Vérifie que PyInstaller est installé"""
    try:
        import PyInstaller
        print(f"✅ PyInstaller {PyInstaller.__version__} détecté")
    except ImportError:
        print("❌ PyInstaller non trouvé. Installation...")
        subprocess.run([sys.executable, "-m", "pip", "install", "pyinstaller"])

def compiler():
    """Lance la compilation"""
    print("\n🔨 Compilation en cours...")
    print("   Cela peut prendre 2-5 minutes...\n")
    
    # Commande PyInstaller
    cmd = [
        "pyinstaller",
        "--clean",           # Nettoyage avant build
        "--noconfirm",       # Pas de confirmation
        "--onefile",         # Un seul exécutable
        "--name", "DanaeStudio-Backend",
        "generer_pdf_direct.py"
    ]
    
    # Ajout des options supplémentaires
    cmd.extend([
        "--hidden-import", "reportlab",
        "--hidden-import", "reportlab.lib.styles",
        "--hidden-import", "reportlab.platypus",
        "--hidden-import", "reportlab.pdfbase",
        "--hidden-import", "reportlab.pdfbase.ttfonts",
        "--hidden-import", "openpyxl",
        "--hidden-import", "PIL",
        "--hidden-import", "pypdf",
        "--hidden-import", "xml.sax.saxutils",
    ])
    
    # Ajout des fichiers de données
    if os.path.exists('Configuration_roman.xlsx'):
        cmd.extend(["--add-data", "Configuration_roman.xlsx;."])
    if os.path.exists('Configuration_roman.json'):
        cmd.extend(["--add-data", "Configuration_roman.json;."])
    
    result = subprocess.run(cmd, capture_output=False)
    
    if result.returncode == 0:
        print("\n✅ Compilation réussie !")
        print(f"📦 Exécutable : dist/DanaeStudio-Backend.exe")
        return True
    else:
        print("\n❌ Échec de la compilation")
        return False

def verifier_resultat():
    """Vérifie le résultat"""
    exe_path = Path("dist/DanaeStudio-Backend.exe")
    if exe_path.exists():
        taille_mb = exe_path.stat().st_size / (1024 * 1024)
        print(f"   Taille : {taille_mb:.1f} MB")
        print("\n📋 Instructions d'utilisation :")
        print(f"   1. Copiez l'exécutable où vous voulez")
        print(f"   2. Placez 'Configuration_roman.xlsx' à côté")
        print(f"   3. Créez les dossiers 'Chapitres' et 'Images' à côté")
        print(f"   4. Lancez : ./DanaeStudio-Backend.exe")

def main():
    print("=" * 60)
    print("  COMPILATION BACKEND DANOË STUDIO")
    print("=" * 60)
    
    nettoyer()
    verifier_dependances()
    
    if compiler():
        verifier_resultat()

if __name__ == "__main__":
    main()