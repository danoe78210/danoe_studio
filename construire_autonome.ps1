# construire_autonome.ps1 - Construction autonome Danoë Studio
$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  DANOË STUDIO - CONSTRUCTION AUTONOME" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Vérifier Flutter
Write-Host "`n[1/5] Vérification de Flutter..." -ForegroundColor Yellow
try {
    $flutterVer = flutter --version 2>&1
    Write-Host "  Flutter trouvé : $($flutterVer[0])" -ForegroundColor Green
} catch {
    Write-Host "  ERREUR : Flutter n'est pas dans le PATH." -ForegroundColor Red
    pause; exit 1
}

# 2. Nettoyer
Write-Host "`n[2/5] Nettoyage..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) { Write-Host "  ERREUR flutter clean" -ForegroundColor Red; pause; exit 1 }

# 3. Dépendances
Write-Host "`n[3/5] Récupération des dépendances..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "  ERREUR flutter pub get" -ForegroundColor Red; pause; exit 1 }

# 4. Build release
Write-Host "`n[4/5] Build Windows Release (cela peut prendre plusieurs minutes)..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Host "  ERREUR flutter build" -ForegroundColor Red; pause; exit 1 }

# 5. Assembler le dossier autonome
Write-Host "`n[5/5] Assemblage du dossier autonome..." -ForegroundColor Yellow
$src = "build\windows\x64\runner\Release"
$dest = "Danoestudio_Autonome"

if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Path $dest | Out-Null

# Copier le build Flutter
Copy-Item -Path "$src\*" -Destination $dest -Recurse -Force

# Copier le backend Python
if (Test-Path "backend") {
    Copy-Item -Path "backend" -Destination "$dest\backend" -Recurse -Force
    Write-Host "  Backend Python copié." -ForegroundColor Green
} else {
    Write-Host "  ATTENTION : dossier 'backend' introuvable." -ForegroundColor Red
}

# Copier les ressources
if (Test-Path "Chapitres") {
    Copy-Item -Path "Chapitres" -Destination "$dest\Chapitres" -Recurse -Force
}
if (Test-Path "Images") {
    Copy-Item -Path "Images" -Destination "$dest\Images" -Recurse -Force
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  CONSTRUCTION TERMINEE AVEC SUCCES !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Dossier : $(Resolve-Path $dest)" -ForegroundColor White
Write-Host "  Lancez : $dest\danoestudio.exe" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green