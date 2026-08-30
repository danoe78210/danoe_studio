# 🖋️ Danoë Studio — Machine à romans pour écrivains

**Version 3.1** · Windows 10/11 · Gratuit · Aucune installation requise

Danoë Studio transforme vos chapitres Markdown en **livres brochés professionnels conformes Amazon KDP** : Word (`.docx`), PDF KDP et EPUB, avec lettrines, en-têtes, table des matières dynamique et images 300 DPI.

> Conçu par un écrivain, pour les écrivains. 📚

---

## 📥 Téléchargement

👉 **[Télécharger Danoë Studio v3.2](https://github.com/danoe78210/danoe_studio/releases/tag/v3.2)**

Décompressez `DanoeStudio-Windows-v3.1.zip` et lancez `danoestudio.exe`. **Aucune installation requise.**

---

## ✨ Nouveautés de la v3.1

- 🔄 **Conversion Word → PDF** : le PDF est généré *depuis votre fichier Word*, donc **vos retouches manuelles (texte et images) sont conservées** (garde-fou 180 s, repli automatique ; `--direct` pour forcer le moteur rapide).
- 📐 **Parité Word ↔ PDF** : page copyright complète (ISBN, dépôt légal, éditeur, site web), corrections typographiques par chapitre, images centrées, marges symétriques, table des matières sans numéros négatifs.
- 🎯 **Règles centralisées** : `regles_mise_en_page.json` + `regles.py` = source de vérité unique lue par les deux générateurs.
- 🌐 **Landing page** : [règles Amazon KDP implémentées](https://danoe78210.github.io/danoe_studio/) documentées en ligne.
- 🛠️ **Correctif unique** : `appliquer_correctif.py` (idempotent) applique tous les correctifs en une commande.
- 🖥️ **Interface** : pages défilantes (anti-débordement) et barre de progression fluide.

---

## 🚀 Fonctionnalités

| Ruban | Rôle |
|---|---|
| ⚙️ Réglages | Paramètres (format du livre, polices, tailles, interligne), dossiers, journal des erreurs |
| 📜 Informations | Titre, sous-titre, auteur, année, ISBN, dédicace, épigraphe |
| 📖 Organisation | Actes, chapitres et images réordonnables |
| ✍️ Correction | Relecteur LanguageTool (FR, plusieurs variantes) |
| ▶️ Production | Génération Word / PDF KDP / EPUB / résumés IA (modes Exact & Rapide) |
| 📖 Lecture | Ouvre le dernier Word / PDF / EPUB généré (dossier `export/`) |
| 📊 Registre | Mots, pages réelles, chapitres, illustrations, temps de lecture |
| 🌐 Contact | QR code & coordonnées |

---

## 📐 Conformité Amazon KDP

### Formats de coupe supportés
`5×8` · `5,06×7,81` · `5,25×8` · `5,5×8,5` · **`6×9`** · `6,14×9,21` · `7×10` · `8×10` · `8,5×8,5` · `8,5×11` · `A4`

### Marges intérieures (gouttière) — barème officiel KDP

| Nombre de pages | Gouttière | + garde 0,125 po | Appliqué |
|---|---|---|---|
| 24 – 150 | 0,375 po | 0,500 po | ✅ automatique |
| 151 – 300 | 0,500 po | 0,625 po | ✅ automatique |
| 301 – 500 | 0,625 po | 0,750 po | ✅ automatique |
| 501 – 700 | 0,750 po | 0,875 po | ✅ automatique |
| 701 – 828 | 0,875 po | 1,000 po | ✅ automatique |

Marges **symétriques** (gauche = droite), convergence recalculée sur le **nombre de pages réel** compté par Word. Marges extérieures toujours ≥ 0,25 po.

### Typographie
- Corps : **justifié**, retrait de 1ʳᵉ ligne **0,5 cm**, espacement maîtrisé (Aptos 11 pt par défaut, personnalisable).
- Titres : **Cinzel**, centrés, positionnés au tiers de la page.
- **Lettrine** en début de chaque chapitre.
- Images : **300 DPI, niveaux de gris**, dimensionnées selon le format du livre et centrées.

---

## 🛠️ Utilisation

### Interface graphique (recommandé)
Lancez `danoestudio.exe` puis **Production → Générer le livre** / **PDF KDP**.

### Ligne de commande
```powershell
cd backend

# Livre Word (mode exact)
python generer_roman.py

# Mode rapide (parité estimée, ~1 min pour 600 pages)
python generer_roman.py --rapide

# PDF KDP (converti depuis le Word le plus récent ; --direct = moteur Python)
python generer_pdf_direct.py
python generer_pdf_direct.py --direct

# Outils
python generer_roman.py --init    # crée la configuration (3 onglets)
python generer_roman.py --verif   # auto-contrôle des formats
python generer_roman.py --json    # rafraîchit Configuration_roman.json
```

Les fichiers générés (`*_KDP.docx`, `*_KDP.pdf`, `*.epub`) sont rangés dans `backend\export\`.

---

## 📁 Structure du projet

```
danoe_studio/
├── lib/ui/home_screen.dart      # Interface Flutter (livre + rubans + console)
├── backend/
│   ├── generer_roman.py         # Générateur Word (v2.9.5, instance Word unique)
│   ├── generer_pdf_direct.py    # Générateur PDF (v3.0, anti-LayoutError)
│   ├── generer_ebook.py         # Export EPUB
│   ├── IA_Roman.py              # Résumés / quatrième de couverture
│   ├── regles.py                # Module partagé des règles
│   ├── regles_mise_en_page.json # 🎯 Source de vérité (formats, marges, corrections)
│   ├── appliquer_correctif.py   # Correctif unique idempotent
│   ├── Configuration_roman.json # Infos + style + organisation du roman
│   ├── Chapitres/  Images/  export/
└── docs/index.html              # Landing page (GitHub Pages)
```

---

## 🔧 Prérequis (développement)

- **Flutter** 3.x (interface) · **Python** 3.10+ · **Microsoft Word** (comptage de pages & conversion)
- `pip install python-docx openpyxl Pillow reportlab pypdf pywin32`

---

## 📖 Documentation & contact

- 🌐 Landing page & règles KDP : <https://danoe78210.github.io/danoe_studio/>
- ✒️ Site de l'auteur : <https://danoeecrivain.net>
- 📧 contact@danoeecrivain.net

---

## 🗂️ Notes de version

| Version | Apports |
|---|---|
| **v3.1** | Conversion Word→PDF, parité complète, règles centralisées, landing page KDP |
| v3.0 | Moteur PDF anti-LayoutError (mode sécurisé automatique) |
| v2.9.5 | Vitesse : instance Word unique, mode `--rapide` |
| v2.9.4 | Marges symétriques + convergence sur pages réelles (anti-rejets KDP) |

---

© 2026 Danoë Studio — *Conçu par un écrivain, pour les écrivains.*
