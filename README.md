# 🖋️ Danoë Studio — Machine à romans pour écrivains

**Version 3.5.0** · Windows 10/11 · Gratuit · Version autonome disponible

Danoë Studio transforme vos chapitres Markdown en livres brochés professionnels conformes **Amazon KDP** : Word (.docx), PDF KDP et EPUB 3, avec lettrines, en-têtes, table des matières dynamique et images 300 DPI.

> Conçu par un écrivain, pour les écrivains. 📚

---

## 📥 Téléchargement

👉 **[Télécharger la version Windows autonome v3.5.0](https://github.com/danoe78210/danoe_studio/releases/download/v3.5.0/Danoestudio_Autonome_Windows_v3.5.0.zip)**

La version autonome contient l’application Windows, le runtime Flutter, Python 3.12 et les dépendances du backend. **Aucun téléchargement de Flutter ou Python n’est nécessaire.**

Décompressez `Danoestudio_Autonome_Windows_v3.5.0.zip` et lancez `danoestudio.exe`.

Une archive portable plus légère, sans Python embarqué, est également disponible dans la [Release v3.5.0](https://github.com/danoe78210/danoe_studio/releases/tag/v3.5.0).

---

## ✨ Nouveautés v3.5.0

### 🖋️ Progression et fermeture
- Barre de progression animée : une plume de style ancien trace une ligne d’encre au fil de l’avancement.
- Bouton Antique **Fermer le livre** sur la page gauche, avec confirmation avant fermeture.
- Nettoyage du cache temporaire backend lors de la fermeture de l’application.

### 🪟 Version Windows autonome
- Runtime Flutter Windows inclus dans l’exécutable de production.
- Python 3.12 et les dépendances backend inclus dans l’archive autonome.
- Détection automatique du Python embarqué, avec conservation du chemin Python personnalisé en développement.

---

## ✨ Nouveautés v3.3

### 📊 Registre affiché + compilation réparée
- Le ruban **Registre** affiche les statistiques réelles (ouvrage, format, mots, pages, chapitres, illustrations) lues depuis `registre.json`.
- Correction de l'erreur de compilation Flutter (`The setter '_statX' isn't defined`).

### 🛠️ Robustesse
- `appliquer_correctif.py` : syntaxe corrigée, patchs Dart idempotents (REGISTRE v4).

---

## ✨ Nouveautés v3.2

### 📊 Registre fiable
- Statistiques réelles via `registre.json`, normalisation automatique des clés/valeurs.

### 📱 EPUB renforcé
- Word cherché et EPUB écrit dans `backend/export/` ; infos du menu **Informations**.

### 📐 Parité Word ↔ PDF consolidée
- Copyright en bas de page, dédicace/épigraphe centrées, TDM sans négatifs, espacement des titres.

---

## 🚀 Fonctionnalités

| Ruban | Rôle |
|---|---|
| ⚙️ Réglages | Paramètres (format, polices, tailles), dossiers, journal |
| 📜 Informations | Titre, sous-titre, auteur, année, ISBN, dédicace, épigraphe |
| 📖 Organisation | Actes, chapitres et images réordonnables |
| ✍️ Correction | Relecteur LanguageTool (FR) |
| ▶️ Production | Génération Word / PDF KDP / EPUB / Résumés IA |
| 📖 Lecture | Ouvrir le dernier Word / PDF / EPUB / résumé |
| 📊 Registre | Mots, pages réelles, chapitres, illustrations |
| 🌐 Contact | QR code & coordonnées |

---

## 📐 Conformité Amazon KDP

Détail complet sur la page **[Règles KDP implémentées](https://danoe78210.github.io/danoe_studio/regles-kdp.html)**.

- Formats supportés : 5×8 → 8,5×11, A4
- Gouttière selon le barème officiel (0.375 → 0.875 po) + garde 0.125 po, marges symétriques
- Texte justifié, retrait 0,5 cm, images 300 DPI N&B, titres Cinzel centrés
- Table des matières en fin de volume, nombre de pages pair

---

## 🛠️ Utilisation

### Interface graphique (recommandé)
1. Décompressez l’archive autonome Windows.
2. Lancez `danoestudio.exe`.
3. Ouvrez **Production → Générer le livre / PDF KDP / Ebook KDP**.

Les fichiers générés sont placés dans `backend/export/`. Le bouton **Fermer le livre** vide le cache temporaire avant de fermer l’application.

### Ligne de commande
```powershell
cd backend
python generer_roman.py             # Word (mode exact)
python generer_roman.py --rapide    # mode rapide
python generer_pdf_direct.py        # PDF (conversion Word→PDF)
python generer_pdf_direct.py --direct
python generer_ebook.py             # EPUB 3
python appliquer_correctif.py       # correctifs idempotents
```

Les livrables sont dans `backend/export/`.

---

## 📁 Structure

```
danoe_studio/
├── lib/ui/home_screen.dart       # Interface Flutter
├── lib/services/python_engine.dart # Détection et lancement du backend Python
├── backend/
│   ├── generer_roman.py          # Générateur Word
│   ├── generer_pdf_direct.py     # Générateur PDF
│   ├── generer_ebook.py          # Générateur EPUB 3
│   ├── regles.py + regles_mise_en_page.json
│   ├── appliquer_correctif.py    # Fichier unique de correctifs
│   ├── Configuration_roman.json
│   └── export/                   # Livrables (Word, PDF, EPUB)
└── docs/                         # Site + règles KDP
```

Dans l’archive autonome distribuée, le runtime Python est placé dans `python/` à côté de `backend/` et de `danoestudio.exe`.

---

## 🔧 Prérequis (utilisation)

### Windows autonome

- Windows 10 ou 11
- Aucun prérequis logiciel : Python et Flutter sont inclus dans l’archive autonome
- Microsoft Word reste nécessaire pour les fonctions de conversion Word → PDF selon la configuration utilisée

### Développement

- Flutter 3.x, Python 3.10+, Microsoft Word
- `pip install python-docx openpyxl Pillow reportlab pypdf pywin32`

---

## 🗂️ Notes de version

| Version | Apports |
|---|---|
| **v3.5.0** | Version Windows autonome, plume de progression, fermeture avec nettoyage du cache |
| **v3.3** | Registre affiché, compilation Flutter réparée, correctifs idempotents |
| v3.2 | Registre fiable, EPUB export/, parité consolidée, robustesse |
| v3.1 | Conversion Word→PDF, parité complète, règles centralisées, landing page KDP |
| v3.0 | Moteur PDF anti-LayoutError |
| v2.9.5 | Vitesse : instance Word unique, mode `--rapide` |

---

© 2026 Danoë Studio — *Conçu par un écrivain, pour les écrivains.*