# -*- mode: python ; coding: utf-8 -*-
# DanaeStudio Backend – Spécification PyInstaller
# Build : pyinstaller backend.spec

block_cipher = None

a = Analysis(
    ['generer_pdf_direct.py'],
    pathex=[],
    binaries=[],
    # Ne PAS inclure les données ici : elles restent à côté de l'exe
    datas=[],
    hiddenimports=[
        # reportlab
        'reportlab',
        'reportlab.platypus',
        'reportlab.platypus.doctemplate',
        'reportlab.platypus.flowables',
        'reportlab.platypus.paragraph',
        'reportlab.platypus.table',
        'reportlab.lib',
        'reportlab.lib.styles',
        'reportlab.lib.units',
        'reportlab.lib.enums',
        'reportlab.lib.colors',
        'reportlab.lib.fonts',
        'reportlab.lib.utils',
        'reportlab.pdfbase',
        'reportlab.pdfbase.pdfmetrics',
        'reportlab.pdfbase.ttfonts',
        'reportlab.pdfbase.pdfdoc',
        'reportlab.pdfbase._fontdata',
        'reportlab.pdfbase._fontdata_enc_winansi',
        'reportlab.pdfbase._fontdata_widths',
        'reportlab.pdfbase._fontdata_widths_timesroman',
        'reportlab.pdfbase._fontdata_widths_timesbold',
        'reportlab.pdfbase._fontdata_widths_timesitalic',
        'reportlab.pdfbase._fontdata_widths_timesbolditalic',
        'reportlab.rl_config',
        'reportlab.rl_settings',
        # pypdf
        'pypdf',
        'pypdf._reader',
        'pypdf._writer',
        'pypdf._merger',
        'pypdf._page',
        'pypdf._cmap',
        'pypdf._protocols',
        'pypdf._encryption',
        'pypdf._utils',
        # Pillow
        'PIL',
        'PIL.Image',
        'PIL.ImageOps',
        'PIL.PngImagePlugin',
        'PIL.JpegImagePlugin',
        'PIL.GifImagePlugin',
        # openpyxl
        'openpyxl',
        'openpyxl.reader.excel',
        'openpyxl.reader',
        'openpyxl.workbook',
        'openpyxl.worksheet',
        'openpyxl.cell',
        'openpyxl.styles',
        # xml (utilisé par reportlab)
        'xml.sax',
        'xml.sax.saxutils',
        'xml.sax.handler',
        'xml.sax.xmlreader',
        'xml.sax._exceptions',
        # encodings
        'encodings',
        'encodings.utf_8',
        'encodings.latin_1',
        'codecs',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter', 'matplotlib', 'numpy', 'scipy', 'pandas',
        'IPython', 'jupyter', 'pytest', 'unittest',
    ],
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
    a.datas,
    [],
    name='DanaeStudio_Backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)