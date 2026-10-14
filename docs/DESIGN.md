# AstraOS Aurora — système de design

Aurora est l'identité visuelle du premier bureau d'AstraOS. Elle conserve une base noire et blanche, avec un accent bleu froid utilisé uniquement pour les éléments interactifs et l'état actif.

## Principes

1. **Contraste d'abord** — le texte important reste blanc sur fond sombre ou noir sur surface claire.
2. **Peu de couleurs** — le bleu signale une action, une sélection ou l'identité Astra.
3. **Pixel perfect** — toutes les positions restent entières et adaptées au framebuffer 320x200.
4. **Hiérarchie claire** — fond, surface, carte, bordure, texte et accent ont chacun un rôle stable.
5. **Léger** — aucune image compressée ni bibliothèque graphique ; le kernel dessine rectangles, glyphes et icônes.

## Palette VGA programmée

Les valeurs DAC sont sur 6 bits, de 0 à 63.

| Index | Rôle | RGB DAC |
|---:|---|---:|
| 0 | Fond presque noir | `2, 3, 5` |
| 1 | Surface sombre | `5, 7, 11` |
| 2 | Accent bleu profond | `4, 18, 34` |
| 3 | Accent secondaire | `8, 28, 45` |
| 7 | Carte claire | `46, 49, 54` |
| 8 | Bordure sombre | `13, 16, 22` |
| 9 | Texte secondaire | `25, 30, 39` |
| 11 | Accent Aurora | `18, 43, 63` |
| 12 | Danger / fermeture | `63, 22, 27` |
| 15 | Blanc principal | `61, 62, 63` |

Les autres index sont réservés aux futurs états succès, avertissement et thèmes.

## Bureau

- Fond sombre sans texture lourde.
- Grand symbole `A` géométrique dessiné par le kernel.
- Deux colonnes de cartes d'applications.
- Barre des tâches de 22 pixels.
- Bouton Astra bleu, applications réduites au centre et horloge RTC `HH:MM` à droite.

## Fenêtres

- Ombre de 5 pixels pour les fenêtres flottantes.
- Surface cliente claire pour maximiser la lisibilité de la police 5x7.
- Barre de titre sombre avec soulignement Aurora de 2 pixels.
- Bordure extérieure de 1 pixel.
- Contrôles alignés à droite : réduire, agrandir/restaurer, fermer.
- La fermeture devient rouge uniquement au survol.

## Icônes

Chaque application doit avoir une silhouette reconnaissable sans texte :

- **Files** : dossier avec onglet bleu.
- **About** : fiche avec symbole information.
- **System** : écran avec graphe en barres.
- **Notes** : feuille avec lignes bleues.
- **Terminal** : écran sombre avec invite et curseur Aurora.

Les fichiers utilisent une carte document avec bordure, en-tête Aurora et lignes de contenu.

## Typographie

La police actuelle est une fonte bitmap 5x7 en capitales. Les textes utilisent une grille horizontale de 6 pixels : 5 pixels de glyphe et 1 pixel d'espacement.

Prochaines améliorations :

- minuscules ;
- caractères français accentués ;
- taille 2x pour les titres ;
- mesure et centrage automatique des chaînes ;
- troncature avec points de suspension.

## Interaction

- Bleu : action principale ou sélection.
- Gris : élément secondaire ou inactif.
- Rouge : action destructive.
- Carte éclaircie : survol.
- Curseur blanc avec contour sombre, ombre et pointe Aurora.

## Contraintes techniques

- Résolution : `320x200`, 256 couleurs, VGA mode 13h.
- Backbuffer : adresse physique `0x300000`.
- VRAM : adresse physique `0xA0000`.
- Aucun flottant, aucune allocation dynamique pendant le rendu.
- Le rendu complet est copié vers la VRAM en une passe de 16 000 doubles mots.
- Le backbuffer reste sans curseur afin de servir de fond propre.
- Un mouvement ordinaire restaure seulement une zone sale de `12x13` pixels avant de recomposer le curseur directement en VRAM.
- Un rendu complet n'est demandé que lorsqu'une fenêtre, un survol, un menu ou une donnée visible change.
