@echo off
chcp 65001 >nul
setlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
title Danoë Studio - Construction autonome

echo ============================================================
echo   DANOË STUDIO - CONSTRUCTION DE LA VERSION AUTONOME
echo ============================================================
echo.

REM -------------------------------------------------------
REM 1. Vérifier que Flutter est disponible
REM -------------------------------------------------------
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Flutter n'est pas dans le PATH.
    echo Installez Flutter ou ajoutez-le au PATH puis relancez ce script.
    pause
    exit /b 1
)

REM -------------------------------------------------------
REM 2. Nettoyer et construire le build Windows de production
REM -------------------------------------------------------
echo [1/4] Nettoyage des anciens builds...
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] flutter clean a échoué.
    pause
    exit /b 1
)

echo.
echo [2/4] Récupération des dépendances...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] flutter pub get a échoué.
    pause
    exit /b 1
)

echo.
echo [3/4] Construction du build Windows de production (cela peut prendre plusieurs minutes)...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] La construction a échoué.
    pause
    exit /b 1
)

REM -------------------------------------------------------
REM 3. Rassembler la version autonome dans un dossier unique
REM -------------------------------------------------------
echo.
echo [4/4] Assemblage du dossier autonome...

set "SRC=build\windows\x64\runner\Release"
set "DEST=Danoestudio_Autonome"

if exist "%DEST%" (
    echo Suppression de l'ancien dossier autonome...
    rmdir /s /q "%DEST%"
)
mkdir "%DEST%"

REM Copier le build Flutter (exécutable + DLL)
xcopy /E /I /Y /Q "%SRC%\*" "%DEST%\" >nul

REM Copier le backend Python à côté de l'exécutable
if exist "backend" (
    echo Copie du backend Python...
    xcopy /E /I /Y /Q "backend" "%DEST%\backend" >nul
) else (
    echo [ATTENTION] Dossier backend introuvable. L'application devra le détecter ailleurs.
)

REM Copier les ressources éventuelles (chapitres, images, config)
if exist "Chapitres" xcopy /E /I /Y /Q "Chapitres" "%DEST%\Chapitres" >nul
if exist "Images"    xcopy /E /I /Y /Q "Images" "%DEST%\Images" >nul

echo.
echo ============================================================
echo   CONSTRUCTION TERMINÉE AVEC SUCCÈS !
echo ============================================================
echo Le dossier autonome se trouve ici :
echo   %CD%\%DEST%
echo.
echo Lancez "%DEST%\danoestudio.exe" pour démarrer l'application.
echo.
pause
endlocal