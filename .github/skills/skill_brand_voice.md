# Skill — Brand Voice

## Description
Référentiel de la voix de marque Rhapsodi. Chaque agent consulte ce skill avant toute rédaction ou génération de visuel pour garantir la cohérence éditoriale et graphique.

---

## Identité de marque

```yaml
marque: Rhapsodi
secteur: [à compléter — ex. tech, culture, services...]
valeurs:
  - [valeur 1]
  - [valeur 2]
  - [valeur 3]
positionnement: [phrase de positionnement courte]
cible_principale: [description de l'audience cible]
```

---

## Ton éditorial

### Principes généraux

- **Clarté avant tout** : une idée par phrase, des mots précis.
- **Verbes d'action** : préférer les verbes forts aux adverbes (ex. *bondir* plutôt que *avancer rapidement*).
- **Pas de jargon creux** : bannir *synergies*, *disruptif*, *paradigme*, *valeur ajoutée* utilisés à vide.
- **Présence humaine** : écrire comme on parlerait, pas comme un communiqué de presse.
- **Concision** : couper tout mot qui n'ajoute pas de sens.

### Registre

```yaml
registre:
  linkedin: professionnel, inspirant, pédagogique
  instagram: chaleureux, visuel, direct
  ton_général: confiant sans arrogance, expert sans distance
```

### Ce qu'on dit / Ce qu'on ne dit pas

| ✅ On dit | ❌ On ne dit pas |
|---|---|
| "Nous construisons..." | "Nous avons la mission de construire..." |
| "Voici comment..." | "Il convient de noter que..." |
| "Résultats concrets" | "Valeur ajoutée significative" |
| "Vous" ou "Tu" (selon audience) | "Les utilisateurs" (impersonnel) |

---

## Charte graphique

```yaml
couleurs_principales:
  - nom: [Couleur 1]
    hex: "#XXXXXX"
  - nom: [Couleur 2]
    hex: "#XXXXXX"
  - nom: [Couleur 3]
    hex: "#XXXXXX"

couleurs_interdites:
  - "#XXXXXX"  # [raison]

typographies:
  titre: [Police titre]
  corps: [Police corps de texte]
  accent: [Police d'accentuation — optionnel]

style_visuel: [ex. flat design, photographie lifestyle, illustration vectorielle...]
ambiance: [ex. épuré, dynamique, chaleureux...]
```

---

## Exemples de voix de marque

### Post LinkedIn — Ton attendu

```
Nous avons passé 6 mois à résoudre ce problème.
Voici les 3 leçons que personne ne nous a dites au départ.

[...]

Et vous, quelle leçon vous a le plus surpris dans votre parcours ?
```

### Légende Instagram — Ton attendu

```
Ce moment où tout s'aligne. ✨

Derrière chaque projet, des dizaines de décisions silencieuses.
Rhapsodi, c'est aussi ça.

→ L'histoire complète en lien dans la bio.

#rhapsodi #[secteur] #[hashtag3]
```

---

## Instructions d'utilisation pour les agents

```
1. Lire la section "Ton éditorial" avant toute rédaction.
2. Appliquer le registre correspondant à la plateforme cible.
3. Vérifier chaque livrable contre le tableau "On dit / On ne dit pas".
4. Appliquer la charte graphique pour tout visuel.
5. En cas de doute sur le ton, soumettre une variante et laisser la validation humaine choisir.
```

---

## Compatibilité

- **Gemini Code** : structure YAML-friendly, tableaux Markdown.
- **VS Code** : prévisualisation Markdown native.
