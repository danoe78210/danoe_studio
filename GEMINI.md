\# Instructions projet - Danoe Studio



\## Identite du projet



Danoe Studio est une application Flutter desktop principalement ciblee Windows.

Elle transforme des chapitres Markdown en livres Word, PDF KDP et EPUB.

Le moteur de production principal se trouve dans `backend/` et est implemente en Python.



L'interface utilise une direction artistique de bibliotheque gothique :

parchemin, cuir, laiton, or patine, lettrines, rubans et typographies editoriales.



\## Regles generales



\- Repondre en francais par defaut.

\- Preserver les APIs publiques et les conventions existantes.

\- Ne pas effectuer de refactorisation large sans necessite fonctionnelle.

\- Modifier uniquement les fichiers utiles a la demande.

\- Ne pas supprimer ni annuler des modifications locales existantes.

\- Utiliser Dart et Flutter modernes compatibles avec Dart 3.

\- Privilegier la lisibilite, la robustesse et les changements incrementaux.

\- Ne pas inventer de service, de route, de fichier ou de contrat backend non present dans le depot.

\- Ajouter des tests lorsqu'une logique metier ou un contrat entre Flutter et Python est modifie.



\## Architecture actuelle



\- `lib/main.dart` est le point d'entree Flutter.

\- `lib/ui/` contient les ecrans et composants d'interface.

\- `lib/services/` contient les integrations externes.

\- `lib/theme/` contient les tokens visuels et le theme.

\- `lib/widgets/` contient les composants visuels reutilisables.

\- `backend/` contient les scripts Python de generation.

\- `assets/` contient les ressources graphiques.
# Danoe Studio - contexte court

Danoe Studio est une application Flutter desktop, principalement Windows, qui
transforme des chapitres Markdown en Word, PDF KDP et EPUB via `backend/` Python.

## Regles universelles

- Repondre en francais. Modifier uniquement le perimetre utile.
- Preserver les APIs et contrats existants ; ne pas inventer d'architecture.
- Ne pas annuler les changements locaux. Corriger la cause racine.
- Signaler les erreurs de fichier, JSON, processus et reseau ; ne rien ignorer.
- Ajouter ou mettre a jour les tests si une logique metier ou un contrat change.

## Points sensibles

- `lib/ui/home_screen.dart` orchestre encore une grande partie de l'etat et de Python.
- `PythonEngine` lit les sorties ligne par ligne ; les prefixes `PROGRESS:`,
  `STATUS:`, `WARNING:`, `ERROR:` et `DONE:` sont un contrat Flutter/Python.
- Configurations : `danoestudio_config.json`, `backend/Configuration_roman.json`.
- Sources : `backend/Chapitres/`, `backend/Images/`. Sorties : `backend/export/`.
- Utiliser `pathlib.Path` en Python et `package:path/path.dart` en Dart.
- Preserver `AntiqueTheme`; ne pas creer une seconde source de tokens visuels.

## Validation

Lancer le test le plus proche, puis `flutter analyze`. Lancer `flutter test` pour
un changement UI ou comportemental. Pour Python, utiliser la commande pytest
pertinente. Indiquer les commandes impossibles ou echouees.

Les details specialises sont dans `docs/agents-reference/` et ne doivent etre
ouverts que si la tache le justifie.
