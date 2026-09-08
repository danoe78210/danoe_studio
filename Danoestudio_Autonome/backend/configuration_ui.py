#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
configuration_ui.py – Éditeur de configuration du livre (v1.5)

v1.5 : onglet « Style » :
- « Police corps », « Police titres » et « Police lettrine » deviennent des
  LISTES DÉROULANTES limitées aux polices acceptées par Amazon KDP
  (liste POLICES_KDP de configuration_store) ;
- la valeur actuelle, si personnalisée, reste proposée en tête de liste.

v1.4 : formats KDP en liste déroulante + type/usage affichés.
v1.3 : correction relecture Informations / Style.
v1.2 : optimisation complète de l'espace.
"""
import customtkinter as ctk
from tkinter import messagebox
import configuration_store as cs


class FenetreConfiguration(ctk.CTkToplevel):
    def __init__(self, master):
        super().__init__(master)
        self.title("⚙ Configuration du livre")
        self.geometry("1280x860")
        self.minsize(960, 640)
        try:
            self.state('zoomed')
        except Exception:
            pass

        self.master = master
        self.data = cs.charger_configuration()
        self.modified = False

        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=0)

        self.tabview = ctk.CTkTabview(self)
        self.tabview.grid(row=0, column=0, padx=14, pady=(14, 6), sticky="nsew")

        for t in ["Informations", "Chapitres", "Style", "IA", "Bible"]:
            self.tabview.add(t)

        self._build_informations()
        self._build_chapitres()
        self._build_style()
        self._build_ia()
        self._build_bible()

        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.grid(row=1, column=0, padx=14, pady=(6, 14), sticky="ew")
        ctk.CTkButton(btn_frame, text="Annuler", fg_color="gray40",
                      hover_color="gray30",
                      command=self.on_close).pack(side="right", padx=(8, 0))
        ctk.CTkButton(btn_frame, text="Enregistrer",
                      command=self.sauvegarder).pack(side="right")

        self.protocol("WM_DELETE_WINDOW", self.on_close)

    # ── Cycle de vie ──
    def on_close(self):
        if self.modified:
            if messagebox.askyesno("Modifications", "Quitter sans enregistrer ?"):
                self.destroy()
        else:
            self.destroy()

    def _marquer_modifie(self, *args):
        self.modified = True

    # ── Aides de construction ──
    def _champ(self, tab, row, cle, lbl, section, multiligne=False):
        """Champ label + saisie extensible, relié à self.data[section][cle]."""
        ctk.CTkLabel(tab, text=lbl, anchor="w").grid(
            row=row, column=0, sticky="w", padx=(10, 6), pady=4)
        valeur = self.data.get(section, {}).get(cle, "")
        if multiligne:
            w = ctk.CTkTextbox(tab, height=90)
            w.grid(row=row, column=1, sticky="nsew", padx=(0, 10), pady=4)
            w.insert("1.0", str(valeur))
        else:
            w = ctk.CTkEntry(tab)
            w.grid(row=row, column=1, sticky="ew", padx=(0, 10), pady=4)
            w.insert(0, str(valeur))
        w.bind("<KeyRelease>", self._marquer_modifie)
        return w

    def _champ_liste(self, tab, row, cle, lbl, valeurs, section):
        """v1.5 : label + LISTE DÉROULANTE (lecture seule) reliée au JSON."""
        ctk.CTkLabel(tab, text=lbl, anchor="w").grid(
            row=row, column=0, sticky="w", padx=(10, 6), pady=4)
        actuel = str(self.data.get(section, {}).get(cle, "") or "")
        vals = list(valeurs)
        if actuel and actuel not in vals:
            vals.insert(0, actuel)   # police personnalisée conservée en tête
        w = ctk.CTkComboBox(tab, values=vals, state="readonly",
                            command=lambda v: self._marquer_modifie())
        w.grid(row=row, column=1, sticky="ew", padx=(0, 10), pady=4)
        if actuel:
            w.set(actuel)
        elif vals:
            w.set(vals[0])
        return w

    # ── Informations ──
    def _build_informations(self):
        tab = self.tabview.tab("Informations")
        tab.grid_columnconfigure(1, weight=1)
        self.infos_entries = {}
        champs = [("titre_complet", "Titre complet"), ("sous_titre", "Sous-titre"),
                  ("auteur", "Auteur"), ("isbn", "ISBN"), ("depot_legal", "Dépôt légal"),
                  ("annee_publication", "Année"), ("maison_edition", "Éditeur"),
                  ("site_web", "Site web")]
        for i, (cle, lbl) in enumerate(champs):
            self.infos_entries[cle] = self._champ(tab, i, cle, lbl, "informations")
        tab.grid_rowconfigure(8, weight=1)
        tab.grid_rowconfigure(9, weight=1)
        self.infos_entries["dedicace"] = self._champ(
            tab, 8, "dedicace", "Dédicace", "informations", multiligne=True)
        self.infos_entries["epigraphe"] = self._champ(
            tab, 9, "epigraphe", "Épigraphe", "informations", multiligne=True)

    # ── Chapitres ──
    def _build_chapitres(self):
        tab = self.tabview.tab("Chapitres")
        tab.grid_columnconfigure(0, weight=1)
        tab.grid_rowconfigure(1, weight=1)

        btn_f = ctk.CTkFrame(tab, fg_color="transparent")
        btn_f.grid(row=0, column=0, sticky="ew", pady=(8, 6), padx=4)
        for t in ["chapitre", "acte", "image"]:
            ctk.CTkButton(btn_f, text=f"+ {t.capitalize()}", width=110,
                          command=lambda x=t: self._ajouter_ligne(x)).pack(
                side="left", padx=(0, 6))

        self.scroll = ctk.CTkScrollableFrame(tab, fg_color="transparent")
        self.scroll.grid(row=1, column=0, sticky="nsew")
        self.scroll.grid_columnconfigure(0, weight=1)

        self.lignes = []
        for chap in self.data.get("chapitres", []):
            self._ajouter_ligne(chap.get("type", "chapitre"), chap)

    def _ajouter_ligne(self, type_ligne, data=None):
        f = ctk.CTkFrame(self.scroll, corner_radius=8,
                         border_width=1, border_color="#262c49")
        f.grid(row=len(self.lignes), column=0, sticky="ew", pady=3, padx=4)
        ligne = {"frame": f, "type_var": ctk.StringVar(value=type_ligne), "widgets": {}}
        self.lignes.append(ligne)
        self._maj_ligne(f)
        if data:
            self._remplir_ligne(ligne, data)

    def _maj_ligne(self, frame):
        ligne = next(l for l in self.lignes if l["frame"] == frame)
        for w in frame.winfo_children():
            w.destroy()
        ligne["widgets"] = {}
        for c in range(8):
            frame.grid_columnconfigure(c, weight=0)

        ctk.CTkComboBox(frame, values=["chapitre", "acte", "image"],
                        variable=ligne["type_var"], width=110,
                        command=lambda v: self._maj_ligne(frame)).grid(
            row=0, column=0, padx=(6, 4), pady=6, sticky="w")

        t = ligne["type_var"].get()
        if t == "chapitre":
            champs = [("fichier_source", "Fichier source (.md)", 2),
                      ("chapitre_ligne1", "Titre ligne 1", 2),
                      ("chapitre_ligne2", "Titre ligne 2", 1)]
        elif t == "acte":
            champs = [("acte", "Titre de l'acte", 5)]
        else:
            champs = [("image", "Image (.png)", 2), ("legende", "Légende", 3)]

        col = 1
        for cle, placeholder, poids in champs:
            frame.grid_columnconfigure(col, weight=poids)
            e = ctk.CTkEntry(frame, placeholder_text=placeholder)
            e.grid(row=0, column=col, padx=4, pady=6, sticky="ew")
            e.bind("<KeyRelease>", self._marquer_modifie)
            ligne["widgets"][cle] = e
            col += 1

        bf = ctk.CTkFrame(frame, fg_color="transparent")
        bf.grid(row=0, column=col, padx=(4, 6), pady=6, sticky="e")
        ctk.CTkButton(bf, text="▲", width=28,
                      command=lambda: self._monter(frame)).pack(side="left", padx=2)
        ctk.CTkButton(bf, text="▼", width=28,
                      command=lambda: self._descendre(frame)).pack(side="left", padx=2)
        ctk.CTkButton(bf, text="🗑", width=28, fg_color="#a11212", hover_color="#7a0d0d",
                      command=lambda: self._supprimer_ligne(frame)).pack(side="left", padx=2)

    def _remplir_ligne(self, ligne, data):
        for k, w in ligne["widgets"].items():
            if k in data:
                w.delete(0, "end")
                w.insert(0, data[k])

    def _monter(self, frame):
        i = next(i for i, l in enumerate(self.lignes) if l["frame"] == frame)
        if i == 0:
            return
        self.lignes[i], self.lignes[i - 1] = self.lignes[i - 1], self.lignes[i]
        self._regrid()
        self._marquer_modifie()

    def _descendre(self, frame):
        i = next(i for i, l in enumerate(self.lignes) if l["frame"] == frame)
        if i >= len(self.lignes) - 1:
            return
        self.lignes[i], self.lignes[i + 1] = self.lignes[i + 1], self.lignes[i]
        self._regrid()
        self._marquer_modifie()

    def _supprimer_ligne(self, frame):
        frame.destroy()
        self.lignes = [l for l in self.lignes if l["frame"] != frame]
        self._regrid()
        self._marquer_modifie()

    def _regrid(self):
        for i, l in enumerate(self.lignes):
            l["frame"].grid(row=i, column=0, sticky="ew")

    # ── Style (v1.5 : polices en listes déroulantes KDP) ──
    def _build_style(self):
        tab = self.tabview.tab("Style")
        tab.grid_columnconfigure(1, weight=1)
        self.style_entries = {}
        self.style_combos = {}

        # Ligne 0 : format KDP (liste déroulante existante)
        ctk.CTkLabel(tab, text="Format", anchor="w").grid(
            row=0, column=0, sticky="w", padx=(10, 6), pady=4)
        actuel = str(self.data.get("style", {}).get("format_livre", ""))
        self._formats_affiches = [f"{f['label']} ({f['cm']})" for f in cs.FORMATS_KDP]
        val_aff = self._format_affiche_pour(actuel) or actuel
        if val_aff and val_aff not in self._formats_affiches:
            self._formats_affiches.insert(0, val_aff)
        self.combo_format = ctk.CTkComboBox(
            tab, values=self._formats_affiches, state="readonly",
            command=self._sur_changement_format)
        self.combo_format.grid(row=0, column=1, sticky="ew", padx=(0, 10), pady=4)
        if val_aff:
            self.combo_format.set(val_aff)

        # Ligne 1 : type d'ouvrage + utilisation recommandée
        self.info_format = ctk.CTkLabel(
            tab, text="", justify="left", anchor="w", text_color="#9aa3c7",
            font=("Segoe UI", 11))
        self.info_format.grid(row=1, column=1, sticky="w", padx=(0, 10), pady=(0, 8))
        self._afficher_infos_format(self.combo_format.get())

        # v1.5 : lignes 2-4 → polices en LISTES DÉROULANTES (polices KDP)
        self.style_combos["police_corps"] = self._champ_liste(
            tab, 2, "police_corps", "Police corps", cs.POLICES_KDP, "style")
        self.style_combos["police_titres"] = self._champ_liste(
            tab, 3, "police_titres", "Police titres", cs.POLICES_KDP, "style")
        self.style_combos["police_lettrine"] = self._champ_liste(
            tab, 4, "police_lettrine", "Police lettrine", cs.POLICES_KDP, "style")

        # Lignes 5+ : tailles et interligne (saisie numérique)
        champs = [("taille_corps_pt", "Taille corps (pt)"),
                  ("taille_titres_acte_pt", "Taille titres d'acte"),
                  ("taille_chapitre_ligne1_pt", "Taille ligne 1"),
                  ("taille_chapitre_ligne2_pt", "Taille ligne 2"),
                  ("taille_sous_chapitre_pt", "Taille sous-chapitre"),
                  ("interligne_corps", "Interligne")]
        for i, (cle, lbl) in enumerate(champs):
            self.style_entries[cle] = self._champ(tab, i + 5, cle, lbl, "style")

    def _format_affiche_pour(self, valeur):
        if not valeur:
            return None
        w, h = cs.dimensions_format_po(valeur)
        for f in cs.FORMATS_KDP:
            fw, fh = cs.dimensions_format_po(f["label"])
            if abs(fw - w) < 0.05 and abs(fh - h) < 0.05:
                return f"{f['label']} ({f['cm']})"
        return None

    def _afficher_infos_format(self, valeur):
        infos = cs.infos_format_kdp(valeur)
        self.info_format.configure(
            text=f"Type d'ouvrage : {infos['type']}\n"
                 f"Utilisation recommandée : {infos['usage']}")

    def _sur_changement_format(self, valeur):
        self._afficher_infos_format(valeur)
        self._marquer_modifie()

    # ── IA ──
    def _build_ia(self):
        tab = self.tabview.tab("IA")
        tab.grid_columnconfigure(1, weight=1)
        self.ia_entries = {}
        champs = [("mode", "Mode IA"), ("url_ollama", "URL Ollama"),
                  ("modele_ollama", "Modèle Ollama"), ("cle_api_ollama", "Clé API Ollama"),
                  ("cle_api_openai", "Clé API OpenAI"), ("modele_openai", "Modèle OpenAI"),
                  ("url_api_openai", "URL API OpenAI")]
        for i, (cle, lbl) in enumerate(champs):
            ctk.CTkLabel(tab, text=lbl, anchor="w").grid(
                row=i, column=0, sticky="w", padx=(10, 6), pady=4)
            e = ctk.CTkEntry(tab, show="•" if "cle" in cle else "")
            e.grid(row=i, column=1, sticky="ew", padx=(0, 10), pady=4)
            e.insert(0, str(self.data.get("ia", {}).get(cle, "")))
            e.bind("<KeyRelease>", self._marquer_modifie)
            self.ia_entries[cle] = e

    # ── Bible ──
    def _build_bible(self):
        tab = self.tabview.tab("Bible")
        tab.grid_columnconfigure(0, weight=1)
        tab.grid_rowconfigure((1, 3, 5, 7), weight=1)
        self.bible_txts = {}
        sections = [("personnages", "Personnages (Nom | Traits | Relations | Statut | Chapitres)"),
                    ("lieux", "Lieux (Lieu | Chapitres)"),
                    ("objets", "Objets (Objet | Chapitres)"),
                    ("chronologie", "Chronologie (Chapitre | Événement | Repère)")]
        for i, (cle, lbl) in enumerate(sections):
            ctk.CTkLabel(tab, text=lbl, font=ctk.CTkFont(weight="bold")).grid(
                row=i * 2, column=0, sticky="w", padx=10, pady=(8, 0))
            t = ctk.CTkTextbox(tab)
            t.grid(row=i * 2 + 1, column=0, sticky="nsew", padx=10, pady=4)
            lignes = [" | ".join(str(v) for v in item.values())
                      for item in self.data.get("bible", {}).get(cle, [])]
            t.insert("1.0", "\n".join(lignes))
            t.bind("<KeyRelease>", self._marquer_modifie)
            self.bible_txts[cle] = t

    # ── Sauvegarde ──
    def sauvegarder(self):
        for cle, w in self.infos_entries.items():
            self.data["informations"][cle] = (
                w.get("1.0", "end-1c") if isinstance(w, ctk.CTkTextbox) else w.get())

        # Style : format + polices (listes déroulantes) + tailles
        self.data["style"]["format_livre"] = self.combo_format.get()
        for cle, w in self.style_combos.items():
            self.data["style"][cle] = w.get()
        for cle, w in self.style_entries.items():
            val = w.get()
            if "taille" in cle or "interligne" in cle:
                try:
                    val = float(val.replace(',', '.'))
                    if val == int(val):
                        val = int(val)
                except Exception:
                    pass
            self.data["style"][cle] = val

        for cle, w in self.ia_entries.items():
            self.data["ia"][cle] = w.get()

        self.data["chapitres"] = []
        for ligne in self.lignes:
            chap = {"type": ligne["type_var"].get()}
            for k, w in ligne["widgets"].items():
                chap[k] = w.get()
            self.data["chapitres"].append(chap)

        cols_map = {"personnages": ["nom", "traits", "relations", "statut", "chapitres"],
                    "lieux": ["lieu", "chapitres"],
                    "objets": ["objet", "chapitres"],
                    "chronologie": ["chapitre", "evenement", "repere_temporel"]}
        for cle, t in self.bible_txts.items():
            self.data["bible"][cle] = []
            for line in t.get("1.0", "end-1c").splitlines():
                if not line.strip():
                    continue
                parts = [p.strip() for p in line.split("|")]
                self.data["bible"][cle].append(
                    {cols_map[cle][i]: (parts[i] if i < len(parts) else "")
                     for i in range(len(cols_map[cle]))})

        if cs.sauvegarder_configuration(self.data):
            messagebox.showinfo("Succès", "Configuration enregistrée.")
            self.modified = False
            try:
                if hasattr(self.master, 'rafraichir_cibles_traduction'):
                    self.master.rafraichir_cibles_traduction(silencieux=True)
                if hasattr(self.master, '_maj_cartes'):
                    self.master._maj_cartes(
                        {'ouvrage': self.data['informations'].get('titre_complet', '')})
            except Exception:
                pass
        else:
            messagebox.showerror("Erreur", "Impossible de sauvegarder le fichier JSON.")