# Changelog

## v0.1.0

PetStable is a hunter pet field guide for WoW: Forever, in one window (`/petstable`). v0.1.0-alpha1
was the first public alpha; alpha2 adds the active pet's rank markers, the Target button and the
teacher check, and fixes below.

- **Pet Guide:** browse the 19 hunter pet families, each family's appearances, and the creatures
  recorded for them, with search and model previews. Every claim says whether it was measured on the
  Forever client or comes from a website reference.
- **Ability Upgrades:** pet ability ranks and the creatures reported to teach them, with the client's
  own ability icons.
  - *New in alpha2:* ranks are marked for your active pet: **Learned**, **Can learn now**, or
    **Needs pet level N**, with a summary per ability ("2/8 · Can learn"). Ranks are matched by the
    client's spell IDs, so this works in any client language. Nothing is marked when the pet's
    abilities are unknown.
  - *New in alpha2:* Faster Attack and Slower Attack are no longer listed as taught by trainers.
- **My Pets:** your active pet and stable, as last observed.
- **Level filter:** the guide and Ability Upgrades show only what your hunter's level can use
  (Settings, or `/petstable levelfilter on|off`).
- **Family diet** is read from the client's own family table.
- **Nearby teacher alert** (off by default): a notice when a creature in view is listed as teaching
  your active pet's next rank of an ability (`/petstable teachers on|off`).
  - *New in alpha2:* a **Target** button on the notice targets that beast in one click. It works only
    out of combat: it hides when combat starts, and comes back when combat ends if the notice is still
    up.
  - *New in alpha2:* the pet's level no longer hides a teacher, since taming the beast teaches you,
    not the pet. When the rank is above your pet's level, the notice says the level it can train it at.
  - *New in alpha2:* `/petstable teachers check` checks your current target now, or says why no
    notice shows.
- **Local sightings** (off by default): records the exact appearance of beasts you target or mouse
  over, kept on your computer only (`/petstable sightings on|off`).
- Resizable window with scale and reset (`/petstable scale`, `/petstable reset`); Mouse Button 4 and
  5 go back and forward through what you viewed.
- *New in alpha2:* the appearance preview is animated, and four Fox records gained their NPC IDs.
- *Fixed in alpha2:* PetStable's window no longer takes the global name of Blizzard's stable window
  (`PetStableFrame`), so addons that restyle the stable window find Blizzard's.

Alpha: the catalog is bounded and some in-game checks are still pending, so expect gaps. What your
hunter has learned can't be read on Forever, so ranks are marked for the active pet only, and
recommendations are not implemented yet.
