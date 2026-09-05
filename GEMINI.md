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

\- `docs/` contient le site et la documentation KDP.



L'ecran principal est `lib/ui/home\_screen.dart`.

Il contient actuellement une grande partie de l'etat, de la navigation,

de la persistance, de l'acces aux fichiers et de l'orchestration Python.

Toute modification de ce fichier doit rester ciblee.



\## Etat et services



L'application n'utilise actuellement ni Provider, ni Riverpod, ni Bloc.

L'etat est principalement local a `\_HomeScreenState` avec `setState`.



Avant d'introduire une solution de gestion d'etat :

1\. extraire d'abord la logique metier ou la persistance dans un service dedie ;

2\. conserver les APIs existantes ;

3\. justifier le gain de complexite ;

4\. ajouter des tests sur le comportement extrait.



`PythonEngine` lance les scripts Python et transmet stdout/stderr ligne par ligne.

`SpellcheckerService` utilise l'API LanguageTool et decoupe les textes longs.



Les contrats de progression entre Python et Flutter reposent actuellement sur

des prefixes textuels. Toute modification de ces messages doit etre coordonnee

entre `backend/` et `lib/ui/home\_screen.dart`.



\## Persistance et fichiers



\- Les configurations utilisateur sont stockees dans `danoestudio\_config.json`.

\- La configuration de production est `Configuration\_roman.json`.

\- Les exports sont places dans `backend/export/`.

\- Les chapitres sont lus depuis `backend/Chapitres/`.

\- Les images sont lues depuis `backend/Images/`.



Preferer `package:path/path.dart` pour les nouveaux chemins.

Ne pas ajouter de nouveaux chemins Windows en dur sauf contrainte specifique

de l'integration Windows.



Les erreurs de fichier, JSON, processus ou reseau ne doivent pas etre

silencieusement ignorees. Les erreurs doivent etre journalisees et, lorsque

possible, signalees a l'utilisateur.



\## Flutter et Dart



\- Preferer `withValues(alpha: ...)` a `withOpacity(...)`.

\- Preferer `KeyEvent`, `KeyDownEvent` et `onKeyEvent` aux anciennes API clavier.

\- Verifier `mounted` avant tout `setState` apres une operation asynchrone.

\- Liberer tous les `TextEditingController`, `AnimationController`,

&#x20; `ScrollController`, `Timer` et abonnements dans `dispose`.

\- Utiliser `const` lorsque cela ameliore clairement le code.

\- Eviter les operations synchrones de fichiers dans le thread UI pour les

&#x20; traitements potentiellement longs.

\- Preferer des modeles types aux `Map<String, dynamic>` pour les nouvelles

&#x20; donnees metier.



\## Interface



Preserver l'identite visuelle existante et les tokens de `AntiqueTheme`.

Ne pas introduire une nouvelle palette ou un nouveau systeme typographique

sans demande explicite.



Verifier les tailles desktop et les contraintes de mise en page.

Eviter les debordements, les textes tronques sans raison et les controles

inaccessibles au clavier.



Le theme global doit rester coherent avec `AntiqueTheme.theme`.

Ne pas creer une seconde source de verite pour les couleurs, les polices ou

les surfaces.



\## Tests et validation



Apres toute modification :



1\. lancer le test le plus proche du code modifie ;

2\. lancer `flutter analyze` ;

3\. lancer `flutter test` si le changement touche l'interface ou un comportement ;

4\. signaler explicitement toute validation impossible.



Le projet peut echouer avant l'analyse Flutter si le depot et le SDK Flutter

sont situes sur des lecteurs Windows differents et qu'un plugin exige un lien

symbolique. Dans ce cas, deplacer le projet ou le SDK sur le meme lecteur,

puis relancer les commandes.



Le test de demarrage doit utiliser exactement le nom de classe declare dans

`lib/main.dart`.



\## Format des reponses techniques



Pour une demande de correction :

\- identifier la cause racine ;

\- citer les fichiers concernes ;

\- proposer le changement minimal ;

\- appliquer la modification si elle est demandee ;

\- indiquer la validation executee et ses resultats.



Pour une revue :

\- lister d'abord les bugs, risques et regressions potentiels par severite ;

\- mentionner ensuite les tests manquants ;

\- terminer par un bref resume.



Ne pas presenter comme valide un resultat qui n'a pas ete verifie.

