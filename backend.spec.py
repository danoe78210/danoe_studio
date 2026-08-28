# -*- mode: python ; coding: utf-8 -*-
import os
import sys
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

# Chemins
BASE_DIR = os.path.dirname(os.path.abspath('generer_pdf_direct.py'))
block_cipher = None

a = Analysis(
    ['generer_pdf_direct.py'],  # Point d'entrée principal
    pathex=[BASE_DIR],
    binaries=[],
    datas=[
        # Fichiers de configuration
        ('Configuration_roman.xlsx', '.'),
        ('Configuration_roman.json', '.'),
        
        # Dossiers de données
        ('Chapitres', 'Chapitres'),
        ('Images', 'Images'),
        ('_cache_HD', '_cache_HD'),
    ],
    hiddenimports=[
        # ReportLab
        'reportlab',
        'reportlab.lib',
        'reportlab.lib.units',
        'reportlab.lib.enums',
        'reportlab.lib.styles',
        'reportlab.lib.colors',
        'reportlab.platypus',
        'reportlab.pdfbase',
        'reportlab.pdfbase.ttfonts',
        
        # PIL/Pillow
        'PIL',
        'PIL.Image',
        'PIL._imaging',
        
        # OpenPyXL
        'openpyxl',
        'openpyxl.cell',
        'openpyxl.workbook',
        
        # pypdf
        'pypdf',
        'pypdf._reader',
        'pypdf._writer',
        
        # XML et autres
        'xml.sax',
        'xml.sax.saxutils',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['matplotlib', 'numpy', 'scipy', 'pandas', 'IPython'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='DanaeStudio-Backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,  # Mettre False pour cacher la console
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,  # Ajouter un .ico si souhaité
)