# Changelog

## v0.1.0

First public alpha for WoW: Forever. PetStable is a hunter pet field guide in one window (`/petstable`).

- **Pet Guide:** browse the 19 hunter pet families, each family's appearances, and the creatures
  recorded for them, with search and model previews. Every claim says whether it was measured on the
  Forever client or comes from a website reference.
- **Ability Upgrades:** pet ability ranks and the creatures reported to teach them.
- **My Pets:** your active pet and stable, as last observed.
- **Level filter:** the guide and Ability Upgrades show only what your hunter's level can use
  (Settings, or `/petstable levelfilter on|off`).
- **Family diet** is read from the client's own family table.
- **Nearby teacher alert** (off by default): a notice when a creature in view is listed as teaching
  your active pet's next rank of an ability (`/petstable teachers on|off`).
- **Local sightings** (off by default): records the exact appearance of beasts you target or mouse
  over, kept on your computer only (`/petstable sightings on|off`).
- Resizable window with scale and reset (`/petstable scale`, `/petstable reset`); Mouse Button 4 and
  5 go back and forward through what you viewed.

Alpha: the catalog is bounded and some in-game checks are still pending, so expect gaps. Ability
rank tracking and recommendations are not implemented yet.
