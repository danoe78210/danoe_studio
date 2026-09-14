#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
python_launcher.py — Lanceur Python autonome Danoë Studio

Compilé en python.exe via PyInstaller.
Reçoit un chemin de script .py en 1er argument et l'exécute en important
le module depuis le dossier backend/ situé à côté du launcher.

Usage depuis Flutter (PythonEngine):
    python.exe "backend/generer_ebook.py"
    python.exe "backend/generer_kpf.py"
    python.exe "backend/generer_pdf_direct.py"
"""
import os
import sys
import runpy
import io

# Forcer UTF-8 sur stdout/stderr (Windows cmd.exe = cp1252)
if not isinstance(sys.stdout, io.TextIOWrapper) or sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if not isinstance(sys.stderr, io.TextIOWrapper) or sys.stderr.encoding != 'utf-8':
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')


def main():
    # Mode PyInstaller (onefile) : sys.executable = chemin de l'exe réel
    # Mode développement      : __file__ = chemin du script .py
    if getattr(sys, 'frozen', False):
        # PyInstaller : utiliser le dossier de l'exécutable
        launcher_dir = os.path.dirname(os.path.abspath(sys.executable))
    else:
        launcher_dir = os.path.dirname(os.path.abspath(__file__))
    # Dossier parent (Danoestudio_Autonome/)
    app_root = os.path.dirname(launcher_dir)
    # Dossier backend
    backend_dir = os.path.join(app_root, 'backend')

    # Ajouter backend au path
    if backend_dir not in sys.path:
        sys.path.insert(0, backend_dir)

    # Changer le répertoire de travail vers backend
    os.chdir(backend_dir)

    # Premier argument : chemin du script à exécuter
    # Flutter envoie: "backend/generer_xxx.py" ou le chemin complet
    script_arg = sys.argv[1] if len(sys.argv) > 1 else ''

    if not script_arg:
        print('ℹ️  Lanceur Python Danoë Studio')
        print('Usage: python.exe <script.py> [args...]')
        return 0

    # Extraire le nom du module depuis le chemin
    script_name = os.path.basename(script_arg)
    if script_name.endswith('.py'):
        module_name = script_name[:-3]
    else:
        module_name = script_name

    # Arguments restants pour le script
    sys.argv = [script_name] + sys.argv[2:]

    try:
        # Importer et lancer le module
        mod = __import__(module_name)
        if hasattr(mod, 'main'):
            code = mod.main()
            sys.exit(code if code is not None else 0)
        else:
            # Fallback : exécution directe
            runpy.run_module(module_name, run_name='__main__')
        return 0
    except ImportError as e:
        print(f'❌ Module introuvable : {module_name} ({e})')
        print(f'   Dossier backend : {backend_dir}')
        return 1
    except Exception as e:
        print(f'❌ Erreur : {e}')
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())