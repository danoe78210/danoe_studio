# ============================================================
#  Danoë Studio — Installateur Portable Complet (v1.0)
#  - Télécharge Flutter SDK (portable, dans le dossier)
#  - Installe les dépendances Python (venv local)
#  - Installe les dépendances Flutter (pub get)
#  - Compile l'application Windows
#  - Crée un lanceur autonome
#  Tout est contenu dans CE dossier → 100% portable
# ============================================================

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference   = "SilentlyContinue"   # accélère les téléchargements

$ROOT            = Split-Path -Parent $MyInvocation.MyCommand.Path
$FLUTTER_DIR     = Join-Path $ROOT "flutter_sdk"
$PYTHON_VENV     = Join-Path $ROOT "python_venv"
$BACKEND_DIR     = Join-Path $ROOT "backend"
$FLUTTER_PROJECT = Join-Path $ROOT "danoestudio"
$BUILD_DIR       = Join-Path $ROOT "build_release"
$LAUNCHER        = Join-Path $ROOT "Lancer_Danoestudio.bat"

# Dépendances Python nécessaires au backend
$PY_DEPS = @(
    "reportlab", "pypdf", "Pillow", "openpyxl",
    "python-docx", "ebooklib", "beautifulsoup4"
)

function Write-Step { param([string]$msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "   ✔ $msg" -ForegroundColor Green }
function Write-Err  { param([string]$msg) Write-Host "   ✘ $msg" -ForegroundColor Red }

# ------------------------------------------------------------
# ÉTAPE 0 — Vérifications préalables
# ------------------------------------------------------------
Write-Step "Vérifications préalables"

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Err "PowerShell 5+ requis. Ouvrez PowerShell en tant qu'administrateur."
    exit 1
}
Write-Ok "PowerShell $($PSVersionTable.PSVersion)"

# Vérifier la connexion Internet
try {
    Invoke-WebRequest -Uri "https://www.google.com" -Method Head -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Ok "Connexion Internet OK"
} catch {
    Write-Err "Pas de connexion Internet. Impossible de continuer."
    exit 1
}

# Vérifier que le projet existe
if (-not (Test-Path (Join-Path $ROOT "danoestudio\pubspec.yaml"))) {
    Write-Err "Le dossier 'danoestudio' (projet Flutter) est introuvable à côté de l'installateur."
    exit 1
}
if (-not (Test-Path $BACKEND_DIR)) {
    Write-Err "Le dossier 'backend' est introuvable à côté de l'installateur."
    exit 1
}
Write-Ok "Structure du projet détectée"

# ------------------------------------------------------------
# ÉTAPE 1 — Télécharger et installer Flutter SDK (portable)
# ------------------------------------------------------------
Write-Step "Installation de Flutter SDK (portable)"

if (Test-Path (Join-Path $FLUTTER_DIR "bin\flutter.bat")) {
    Write-Ok "Flutter SDK déjà présent dans '$FLUTTER_DIR'"
} else {
    # Récupérer la dernière version stable depuis l'API Flutter
    $releasesUrl = "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
    $releases = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
    $stable  = $releases.releases | Where-Object { $_.channel -eq 'stable' } | Select-Object -First 1
    $version = $stable.version
    $archive = $stable.archive

    $url     = "https://storage.googleapis.com/flutter_infra_release/releases/$($stable.hash)/windows/$archive"
    $zipPath = Join-Path $ROOT "flutter_sdk.zip"

    Write-Host "   Téléchargement Flutter $version ($([math]::Round((Invoke-WebRequest $url -Method Head).Headers['Content-Length']/1MB,1)) Mo)…"
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    Write-Ok "Téléchargement terminé"

    Write-Host "   Extraction…"
    Expand-Archive -Path $zipPath -DestinationPath $ROOT -Force
    # Le zip extrait dans un dossier 'flutter', on le renomme
    if (Test-Path (Join-Path $ROOT "flutter")) {
        if (Test-Path $FLUTTER_DIR) { Remove-Item $FLUTTER_DIR -Recurse -Force }
        Rename-Item (Join-Path $ROOT "flutter") $FLUTTER_DIR
    }
    Remove-Item $zipPath -Force
    Write-Ok "Flutter SDK installé dans '$FLUTTER_DIR'"
}

$flutterBin = Join-Path $FLUTTER_DIR "bin\flutter.bat"

# Ajouter Flutter au PATH pour cette session uniquement (portable)
$env:PATH = "$FLUTTER_DIR\bin;$env:PATH"

# Désactiver les analytics (portable / confidentialité)
& $flutterBin config --no-analytics 2>$null
Write-Ok "Flutter configuré (analytics désactivé)"

# ------------------------------------------------------------
# ÉTAPE 2 — Détecter / préparer Python
# ------------------------------------------------------------
Write-Step "Préparation de l'environnement Python"

# Chercher python dans le PATH
$pythonExe = $null
foreach ($cand in @("python", "python3", "py")) {
    try {
        $ver = & $cand --version 2>&1
        if ($ver -match "Python 3") { $pythonExe = $cand; break }
    } catch { }
}

if (-not $pythonExe) {
    Write-Err "Python 3 introuvable dans le PATH. Installez Python 3.10+ depuis python.org."
    exit 1
}
Write-Ok "Python détecté : $(& $pythonExe --version)"

# Créer un venv local (portable)
if (-not (Test-Path (Join-Path $PYTHON_VENV "Scripts\python.exe"))) {
    Write-Host "   Création du venv Python…"
    & $pythonExe -m venv $PYTHON_VENV
    Write-Ok "Venv créé dans '$PYTHON_VENV'"
} else {
    Write-Ok "Venv Python déjà présent"
}

$venvPython = Join-Path $PYTHON_VENV "Scripts\python.exe"
$venvPip    = Join-Path $PYTHON_VENV "Scripts\pip.exe"

# ------------------------------------------------------------
# ÉTAPE 3 — Installer les dépendances Python
# ------------------------------------------------------------
Write-Step "Installation des dépendances Python"

# Mettre à jour pip
& $venvPython -m pip install --upgrade pip --quiet

foreach ($dep in $PY_DEPS) {
    Write-Host "   Installation de $dep…"
    & $venvPip install $dep --quiet
    Write-Ok $dep
}
Write-Ok "Toutes les dépendances Python sont installées"

# ------------------------------------------------------------
# ÉTAPE 4 — Dépendances Flutter (pub get)
# ------------------------------------------------------------
Write-Step "Installation des dépendances Flutter (pub get)"

Push-Location $FLUTTER_PROJECT
& $flutterBin pub get
Pop-Location
Write-Ok "Dépendances Flutter installées"

# ------------------------------------------------------------
# ÉTAPE 5 — Compiler l'application Windows
# ------------------------------------------------------------
Write-Step "Compilation de l'application Windows (Release)"

Push-Location $FLUTTER_PROJECT
& $flutterBin build windows --release
Pop-Location

# Copier le build dans un dossier dédié (portable)
$srcBuild = Join-Path $FLUTTER_PROJECT "build\windows\x64\runner\Release"
if (Test-Path $BUILD_DIR) { Remove-Item $BUILD_DIR -Recurse -Force }
Copy-Item -Path $srcBuild -Destination $BUILD_DIR -Recurse
Write-Ok "Application compilée dans '$BUILD_DIR'"

# ------------------------------------------------------------
# ÉTAPE 6 — Créer le lanceur autonome
# ------------------------------------------------------------
Write-Step "Création du lanceur autonome"

$launcherContent = @"
@echo off
chcp 65001 >nul
title Danoë Studio
cd /d "%~dp0"

REM Chemin vers le venv Python local (portable)
set "PYTHON=%~dp0python_venv\Scripts\python.exe"

REM Démarrer l'application Flutter
start "" "%~dp0build_release\danoestudio.exe"

exit
"@

Set-Content -Path $LAUNCHER -Value $launcherContent -Encoding UTF8
Write-Ok "Lanceur créé : $LAUNCHER"

# ------------------------------------------------------------
# ÉTAPE 7 — Créer un raccourci de configuration (facultatif)
# ------------------------------------------------------------
Write-Step "Création d'un raccourci pour ouvrir le dossier du projet"

$shortcutPath = Join-Path $ROOT "Ouvrir_Projet.bat"
$shortcutContent = @"
@echo off
explorer "%~dp0"
exit
"@
Set-Content -Path $shortcutPath -Value $shortcutContent -Encoding UTF8
Write-Ok "Raccourci créé : $shortcutPath"

# ------------------------------------------------------------
# RÉSUMÉ
# ------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "   INSTALLATION TERMINÉE AVEC SUCCÈS !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   Dossier racine      : $ROOT"
Write-Host "   Flutter SDK         : $FLUTTER_DIR"
Write-Host "   Venv Python         : $PYTHON_VENV"
Write-Host "   Application compilée: $BUILD_DIR"
Write-Host "   Lanceur             : $LAUNCHER"
Write-Host ""
Write-Host "   ✔ L'ensemble est 100% PORTABLE."
Write-Host "     Vous pouvez déplacer le dossier '$ROOT'"
Write-Host "     n'importe où, tout fonctionnera."
Write-Host ""
Write-Host "   Double-cliquez sur 'Lancer_Danoestudio.bat' pour démarrer."
Write-Host "============================================================" -ForegroundColor Green