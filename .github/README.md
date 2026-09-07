# Rhapsodi — Agent Communication Sociale

Structure complète des agents et skills pour la gestion des réseaux sociaux Rhapsodi.

---

## Architecture

```
rhapsodi-social-agent/
├── agents/
│   ├── Directeur_Communication.md   # Orchestrateur central
│   ├── agent_linkedin.md            # Publications LinkedIn
│   ├── agent_instagram.md           # Publications Instagram
│   └── agent_illustration.md        # Génération de visuels
│
├── skills/
│   ├── skill_brand_voice.md         # Voix de marque & charte graphique
│   ├── skill_validation_humaine.md  # Circuit d'approbation
│   ├── skill_calendrier_editorial.md# Planification des publications
│   └── skill_conformite.md          # CGU, sécurité & légal
│
└── README.md                        # Ce fichier
```

---

## Flux de travail global

```
Coordinateur humain
    ↓ (rédige les briefs dans le calendrier)
Directeur_Communication
    ↓ (lit le calendrier, délègue)
    ├── agent_linkedin       → post LinkedIn
    ├── agent_instagram      → post Instagram
    └── agent_illustration   → visuel
          ↓ (livrable soumis)
    Validation humaine (skill_validation_humaine)
          ↓ (APPROUVÉ)
    Publication via API officielle
```

---

## Règle fondamentale

> **Aucune publication sans validation humaine explicite.**

---

## Compatibilité

| Environnement | Support |
|---|---|
| Gemini Code | ✅ Structure YAML-friendly, blocs de code délimités |
| VS Code | ✅ Prévisualisation Markdown native |
| Foam / Dendron | ✅ Compatible liens wikilinks |
| Obsidian | ✅ Compatible |

---

## Pour commencer

1. Compléter `skill_brand_voice.md` avec les valeurs, couleurs et typographies Rhapsodi.
2. Créer le premier brief dans `skill_calendrier_editorial.md`.
3. Lancer le `Directeur_Communication` avec le brief en entrée.
4. Valider le livrable produit avant publication.
