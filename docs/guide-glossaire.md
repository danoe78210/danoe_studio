# Utiliser le glossaire

Le mode glossaire permet d'associer une définition à un mot ou à une expression dans un chapitre. Les définitions sont ensuite regroupées dans une section dédiée à la fin du chapitre.

## 1. Activer le mode glossaire

Dans Danoe Studio :

1. Ouvrir le menu **Organisation**.
2. Activer l'option **Glossaire**.
3. Enregistrer la configuration.

L'option doit être activée avant de générer les documents.

## 2. Ajouter une référence dans le texte

Dans le fichier Markdown du chapitre, placer une référence immédiatement après le mot concerné :

```markdown
Le scriptorium[^scriptorium] abritait plusieurs manuscrits.
```

La forme générale est :

```text
[^identifiant]
```

L'identifiant doit être court et stable. Il peut contenir :

- des lettres ;
- des chiffres ;
- le tiret `-` ;
- le caractère `_`.

Les espaces et les accents ne doivent pas être utilisés dans l'identifiant. Par exemple, utiliser `[^ancienne_rune]` plutôt que `[^ancienne rune]`.

## 3. Écrire la définition

Ajouter la définition à la fin du même chapitre :

```markdown
[^scriptorium]: Salle destinée à la copie et à l'etude des manuscrits.
```

Exemple complet :

```markdown
Le scriptorium[^scriptorium] etait silencieux. Une ancienne rune[^rune]
ornait la couverture du manuscrit.

[^scriptorium]: Salle destinée à la copie et à l'etude des manuscrits.
[^rune]: Signe ancien utilisé pour représenter un pouvoir ou une connaissance.
```

Les lignes de définition sont retirées du corps du chapitre lorsque le mode glossaire est actif.

## 4. Définitions sur plusieurs lignes

Une définition peut continuer sur les lignes suivantes. Ces lignes doivent être indentées :

```markdown
[^cristal]: Pierre extrêmement rare, capable de conserver une grande
  quantité d'energie magique pendant plusieurs siècles.
```

Sans indentation, la ligne suivante est considérée comme un nouveau paragraphe.

## 5. Résultat selon le format

### EPUB

La référence devient cliquable. Un clic ouvre la définition dans la section **Glossaire** et le lien de retour permet de revenir au mot dans le chapitre.

### Word

Une section **Glossaire** est ajoutée à la fin du chapitre. Les références sont affichées sous la forme `[scriptorium]`.

### PDF

Une page dédiée **Glossaire** est ajoutée à la fin du chapitre. Les termes y sont mis en évidence, suivis de leur définition.

## 6. Points à vérifier

- Chaque référence utilisée dans le texte doit avoir une définition correspondante.
- Un même identifiant doit toujours désigner le même terme.
- Les définitions doivent être placées dans le fichier Markdown du chapitre concerné.
- Après toute modification, régénérer le format à contrôler depuis le menu **Production**.

## 7. Faut-il installer `pypdf` ?

`pypdf` n'est pas nécessaire pour extraire les définitions, remplacer les références ou construire le glossaire partagé. Ces opérations sont réalisées par le module interne `backend/glossaire_shared.py`.

En revanche, `pypdf` est une dépendance du générateur PDF `backend/generer_pdf_direct.py`. Il doit donc être installé pour utiliser la génération PDF depuis une installation de développement Python :

```powershell
pip install pypdf
```

Résumé :

| Fonction | `pypdf` requis ? |
|---|---:|
| Glossaire dans Word | Non |
| Glossaire dans EPUB | Non |
| Extraction et formatage des définitions | Non |
| Génération PDF KDP avec le backend actuel | Oui |
| Version autonome Windows | Non, la dépendance est déjà incluse |

Les dépendances complètes du backend peuvent être installées avec :

```powershell
pip install python-docx openpyxl Pillow reportlab pypdf pywin32
```