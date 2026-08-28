# 🖋️ Danoë Studio

**Machine à romans pour écrivains indépendants.**

Danoë Studio est une application de bureau (Windows) conçue pour accompagner les auteurs de la première page à la publication KDP.

![Danoë Studio](https://raw.githubusercontent.com/danoe78210/danoe_studio/main/assets/icon/app_icon.png)

## ✨ Fonctionnalités

- 📚 **Organisation du manuscrit** : actes, chapitres, images — tout se réordonne d'un glisser-déposer
- ✍️ **Correcteur orthographique** : LanguageTool intégré, variantes de français (FR/CA/CH/BE)
- 📖 **Export KDP complet** : Word, PDF (marges gouttière auto), EPUB
- 🕯️ **Interface immersive** : parchemin, lettrines enluminées, pages qui se tournent avec curl réaliste
- 📊 **Registre** : statistiques en temps réel (mots, pages, chapitres)
- 🤖 **Résumés IA** : génération de synopsis et quatrièmes de couverture

## 📥 Téléchargement

👉 **[Télécharger Danoë Studio v1.0.0](https://github.com/danoe78210/danoe_studio/releases/latest)**

Décompressez et lancez `danoestudio.exe`. Aucune installation requise.

## 🛠️ Installation depuis les sources

### Prérequis

- [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) (stable)
- [Python 3.10+](https://www.python.org/downloads/) avec `reportlab`, `pypdf`, `Pillow`, `openpyxl`
- Visual Studio 2022 (charge de travail "Développement Desktop en C++")

### Compilation

```powershell
git clone https://github.com/danoe78210/danoe_studio.git
cd danoe_studio
flutter pub get
flutter build windows --release