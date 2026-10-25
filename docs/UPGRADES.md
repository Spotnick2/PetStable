# Ability Upgrades: reference listing

The Ability Upgrades page browses the 33 pet abilities in the catalog (see
[REFERENCE-CATALOG.md](REFERENCE-CATALOG.md#pet-ability-teachers)): every rank with its pet level and
training points, and the creatures a listing reports as teaching it. It is built by
`UpgradesData.lua` (a projection of the catalog) and `UpgradesUI.lua`.

- Left: all abilities, sorted by name, with their rank count (or "Trainer").
- Right: the selected ability's families and, per rank, "Rank n · pet level · training points"
  and its listed teachers as `name · level · zone`. Website levels and zones carry the same
  "(reference)" qualifier as the Pet Guide. Trainer abilities say they are learned from a Pet Trainer.
- The family button cycles through the 19 families. It keeps only abilities some rank of which
  the family can learn, and only that family's teachers.
- A teacher opens its family in the Pet Guide.

## What it does not do

It does not know which ranks your hunter or pets have learned (#9), so nothing is marked
learned, missing or ready, and it recommends nothing (#10). It shows no coordinates, spawn
timers or tameability. Every teacher is a reference claim, not confirmed in game, and an
empty teacher list means none is listed, not that none exists.

## Validation

`tests/test_upgrades.lua` covers the projection, rank order, family filtering and teacher
resolution. `tests/upgrades_cases.lua` (run from `tests/test_reference_ui.lua`) drives the page
with the full shipped catalog. The layout has not been looked at in the live client, which is
unavailable before November 4; check it there, including narrow window sizes.
