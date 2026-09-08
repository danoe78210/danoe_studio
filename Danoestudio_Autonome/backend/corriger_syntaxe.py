import re

with open('interface_livre.py', 'r', encoding='utf-8') as f:
    contenu = f.read()

# Remplacer les chaînes problématiques
remplacements = [
    ("'Aucun .docx généré pour l'instant.\\nLancez d'abord une génération.'",
     '"Aucun .docx généré pour l\'instant.\\nLancez d\'abord une génération."'),
    ("'Aucun .docx généré pour l'instant.'",
     '"Aucun .docx généré pour l\'instant."'),
]

for ancien, nouveau in remplacements:
    contenu = contenu.replace(ancien, nouveau)

with open('interface_livre.py', 'w', encoding='utf-8') as f:
    f.write(contenu)

print("✅ Corrections appliquées avec succès !")