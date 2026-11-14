# Ability Upgrades: reference listing

The Ability Upgrades page browses the 31 pet abilities in the catalog (see
[REFERENCE-CATALOG.md](REFERENCE-CATALOG.md#pet-ability-teachers)): every rank with its pet level and
training points, and the creatures a listing reports as teaching it. It is built by
`UpgradesData.lua` (a projection of the catalog) and `UpgradesUI.lua`.

- Left: all abilities, sorted by name, each with its spell icon and its rank count (or "Trainer").
  The icons come from the client's own spell tables (`CatalogSpells.lua`, see
  [REFERENCE-CATALOG.md](REFERENCE-CATALOG.md#ability-icons-and-rank-spell-ids)).
- Right: the selected ability's icon and name, its families and, per rank, "Rank n · pet level · training points"
  and its listed teachers as `name · level · zone`. Website levels and zones carry the same
  "(reference)" qualifier as the Pet Guide. Trainer abilities say they are learned from a Pet Trainer.
- The family button cycles through the 19 families. It keeps only abilities some rank of which
  the family can learn, and only that family's teachers.
- A teacher opens its family in the Pet Guide.

## Markers for the active pet

When this session has read the active pet's spellbook (`PetState`), ranks are marked for that pet
(#10, the measurable part):

- **Learned:** the pet has this rank or a higher one. Ranks are matched by the client spell IDs in
  `CatalogSpells.lua`, so this works in any client language. An English client falls back to the
  ability name and "Rank n" text for a rank the client tables don't cover.
- **Can learn now:** not learned, the pet's family can use it, and the pet's level reaches the rank.
- **Needs pet level N:** not learned, and the pet is still below the rank's level.

The list shows the same per ability ("2/8 · Can learn", "Learned 8/8", "Can learn"). The note at
the top names the pet. Abilities for another family get no marker.

Nothing is marked when the pet's knowledge is unknown: no pet out, a spellbook that couldn't be
read, or only an earlier session's record. Unknown never shows as "not learned". The page repaints
when the pet is summoned, dismissed or swapped.

## What it does not do

It does not know what your hunter can teach: Forever has no Beast Training list in the API (the
legacy craft functions are absent), so markers are about the active pet only. "Can learn now" means
the pet's level allows the rank. Training points and where to learn it are still for the player to
check. It recommends no route (#10). It shows no coordinates, spawn timers or tameability (#11).
Every teacher is a reference claim, not confirmed in game, and an empty teacher list means none is
listed, not that none exists.

## Validation

`tests/test_upgrades.lua` covers the projection, rank order, family filtering and teacher
resolution. `tests/upgrades_cases.lua` (run from `tests/test_reference_ui.lua`) drives the page
with the full shipped catalog. The layout has not been looked at in the live client, which is
unavailable before November 4; check it there, including narrow window sizes.
