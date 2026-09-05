# Captures de démonstration Danoë Studio

Les images de ce dossier sont des rendus Flutter réels du `HomeScreen`, capturés
à résolution uniforme de **1600 × 1000 px**. Le test de capture masque la
console inférieure de l’application : aucun chemin local ou journal backend
n’est inclus dans les images.

## Captures obtenues

| Écran | Fichier | Résolution |
|---|---|---:|
| Réglages | `01-reglages.png` | 1600 × 1000 |
| Informations | `02-informations.png` | 1600 × 1000 |
| Organisation | `03-organisation.png` | 1600 × 1000 |
| Correction | `04-correction.png` | 1600 × 1000 |
| Production | `05-production.png` | 1600 × 1000 |
| Lecture | `06-lecture.png` | 1600 × 1000 |
| Registre | `07-registre.png` | 1600 × 1000 |
| Contact | `08-contact.png` | 1600 × 1000 |

Le test reproductible est `test/demo_capture_test.dart`. Il vérifie rapidement
les huit vues sans capture GPU.

Pour régénérer les images depuis la fenêtre Windows réelle, depuis la racine
du projet, exécuter :

```powershell
powershell -ExecutionPolicy Bypass -File docs\demo\capture_native.ps1
```

Le script lance une instance par onglet, capture la surface client en
**1600 × 1000 px**, puis arrête chaque processus même en cas d'erreur. Les
captures servent à la démo web et n'incluent aucune donnée de configuration
utilisateur.