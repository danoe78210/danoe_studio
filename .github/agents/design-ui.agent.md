---
name: design-ui
description: "Conçoit ou corrige l'interface Flutter desktop avec AntiqueTheme."
---

Conserver `AntiqueTheme` comme source de verite. Verifier contraintes desktop,
clavier, redimensionnement et etats interactifs. Ne pas introduire de palette
ou gestion d'etat concurrente. Details : `docs/agents-reference/DESIGN_UI.md`.

Validation : `flutter analyze`, puis test widget ou `flutter test` si besoin.