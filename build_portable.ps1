# =============================================================
#  Danoe Studio - Assemblage automatique de la version portable
#  Usage : powershell -ExecutionPolicy Bypass -File .\build_portable.ps1
# =============================================================

param(
    [switch]$SkipIcons,
    [switch]$SkipPython,
    [switch]$NoZip
)

$ErrorActionPreference = "Stop"

# --- Configuration ---
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReleaseSrc  = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$DistRoot    = Join-Path $ProjectRoot "dist"
$DistName    = "Danoestudio_Portable"
$DistDir     = Join-Path $DistRoot $DistName
$BackendSrc  = Join-Path $ProjectRoot "backend"
$PythonSrc   = Join-Path $ProjectRoot "tools\python-embed"

function Step([string]$msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

# --- 0. Verifie Flutter ---
Step "Verification de l'environnement Flutter"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERREUR : 'flutter' n'est pas dans le PATH." -ForegroundColor Red
    exit 1
}

# --- 1. Stoppe l'app si elle tourne ---
Step "Arret de Danoe Studio si en cours"
Get-Process | Where-Object { $_.ProcessName -like "*danoestudio*" } |
    Stop-Process -Force -ErrorAction SilentlyContinue

# --- 2. Nettoyage ---
Step "flutter clean"
flutter clean

# --- 3. Dependances ---
Step "flutter pub get"
flutter pub get

# --- 4. Icone (optionnel) ---
if (-not $SkipIcons) {
    Step "Generation de l'icone (flutter_launcher_icons)"
    dart run flutter_launcher_icons
}

# --- 5. Build release ---
Step "flutter build windows --release"
flutter build windows --release

if (-not (Test-Path $ReleaseSrc)) {
    Write-Host "ERREUR : dossier Release introuvable : $ReleaseSrc" -ForegroundColor Red
    exit 1
}

# --- 6. Prepare le dossier dist ---
Step "Preparation du dossier de distribution"
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

# --- 7. Copie le build Release ---
Step "Copie du build Release"
Copy-Item -Path "$ReleaseSrc\*" -Destination $DistDir -Recurse -Force

# --- 8. Copie le backend Python ---
if (Test-Path $BackendSrc) {
    Step "Copie du backend Python"
    Copy-Item -Path $BackendSrc -Destination (Join-Path $DistDir "backend") -Recurse -Force
} else {
    Write-Host "ATTENTION : dossier backend introuvable ($BackendSrc) - ignore." -ForegroundColor Yellow
}

# --- 9. Copie le Python embarque (optionnel) ---
if (-not $SkipPython -and (Test-Path $PythonSrc)) {
    Step "Copie du Python embarque"
    Copy-Item -Path $PythonSrc -Destination (Join-Path $DistDir "python") -Recurse -Force
} else {
    Write-Host "INFO : Python embarque non inclus." -ForegroundColor Yellow
}

# --- 10. ZIP ---
if (-not $NoZip) {
    Step "Creation de l'archive ZIP"
    $zipPath = Join-Path $DistRoot "$DistName.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$DistDir\*" -DestinationPath $zipPath -CompressionLevel Optimal
}

# --- Resume ---
Step "Termine !"
Write-Host "Dossier distribuable : $DistDir" -ForegroundColor Green
if (-not $NoZip) { Write-Host "Archive ZIP          : $DistRoot\$DistName.zip" -ForegroundColor Green }
Write-Host ""