# Family and creature facts: what has a source

Issue #29 asked which facts hunters use to choose a family can be recorded with a real source. Each
was decided on its own.

| Fact | Source plan | Status |
|---|---|---|
| **Diet** | The client's `CreatureFamily` table (`PetFoodMask`), datamined from wago.tools through the shared tool. | **Shipped** for the 19 hunter pet families (`CatalogFamilies.lua`, `Tools/import-families.py`). |
| Family scale range | Same table (`MinScale`, `MaxScale`). | Stored with the diet; not shown yet. |
| **Attack speed** | Not in any client table: it is per creature, on the server. The client reports it for a unit (`UnitAttackSpeed`). An owned pet's spellbook also names it: Faster Attack I-VII and Slower Attack I-III are attack speed auras (see below). | Measured once in game (2026-11-14, below); it matches the spell reading. Not shipped. |
| **Stat modifiers** (health, armor, damage) | Not in any client table. The only source is a website listing, which would be one reference claim at most. | Not shipped: no verifiable source. Revisit if a measurement path appears. |
| **Role** | Sites disagree (Petopia calls Fox General, Beastmaster calls it Offense), and the client has no role. | Still deferred, as in FAMILY-INDEX.md. |

## Diet

`PetFoodMask` is a bit field. Bit 1 is Meat, then Fish, Cheese, Bread, Fungus, Fruit, Raw Meat, Raw
Fish, in that order (`Guide.Diet` in `GuideData.lua`). That reading is ours: it matched an independent
diet listing for all 19 families without exception, including unusual masks such as the Turtle's
178 (Fish, Fungus, Fruit, Raw Fish) and the Wind Serpent's 14 (Fish, Cheese, Bread), and
`tests/test_families.lua` pins that agreement. In game it is confirmed for the Cat only (see the
attack speed probe below):
`/fp steps ps facts` records `C_PetInfo.GetPetFoodTypes` and `C_StableInfo.GetStablePetFoodTypes`
beside the family so the decoded names can be compared on the client. If they ever differ, correct
the one list in `GuideData.lua`.

The table is client data, not an in-game observation and not a statement about tameability. The
appearance page shows it as "Diet: Meat, Fish (client family table, build 1.60.1.70532)" in the
Family abilities & diet row. The fact comes from the client's own family list, so it applies to the
family, not to a creature: some creatures of a family could in principle differ.

## Updating

Fetch the table for a new build with `python References/Tools/Wago/wago.py get CreatureFamily`, then
`python Tools/import-families.py ../References/Forever/db/forever-creaturefamily-<build>.csv`.
`--check` compares without writing. Any change in a mask is worth a look: it means Blizzard changed
a diet.

## Attack speed probe

`/fp steps ps facts` records `UnitAttackSpeed` for the target (a wild beast) and the pet, and the
food lists, in `PetStableProbeDB.facts`. Read two beasts of one family and a fast rare to see
whether speed varies inside a family. Attack speed is still not shipped anywhere.

Run #290 (2026-11-14, 70938) read two wild beasts, an Elder Mottled Boar (level 8) and a Bloodtalon
Scythemaw (level 10): both 2.0 s. The same run listed the Cat's foods as Meat and Fish, both for the
active pet and from the stable, which matches the decoded `PetFoodMask` (3). That is the first
family whose diet is confirmed in game; the other 18 are still the client table only.

## Attack speed spells (#43)

A pet that is not at the 2.0 s base carries one passive spell for its speed. The client's
`SpellEffect` table (1.60.1.70862) gives each a single `MOD_ATTACKSPEED` aura:

| Spell | IDs | Aura | Speed on a 2.0 s base |
|---|---|---|---|
| Faster Attack I-VII | 1263099, 1263100, 1263102, 1263104, 1263107, 1263109, 1263110 | +17, +25, +33, +43, +54, +67, +100% | 1.7, 1.6, 1.5, 1.4, 1.3, 1.2, 1.0 s |
| Slower Attack I-III | 1263111, 1263113, 1263114 | -17, -20, -26% | 2.4, 2.5, 2.7 s |

A Bear captured on 70425 carried Slower Attack II (2.5 s), so an owned pet's speed seems readable from
its spellbook. A wild beast still needs `UnitAttackSpeed`.

First check in game (2026-11-14, build 1.60.1.70938, `/fp steps ps facts` run #290): a level-14 Cat
with Faster Attack IV (+43%) read **1.371 s** from `UnitAttackSpeed`, twice. The hunter is Skyborne,
whose racial Wind Blessed (1259710, skill line 2980 "Skyborne Racial") gives +2% melee and ranged
attack speed (aura 342). With it, 2.0 / (1.43 x 1.02) = 1.3712 s, the measured value to the
millisecond; without it the table alone gives 1.399 s. So the pet's reading includes its owner's
haste, and the table holds for this one rank. Before showing a speed computed from the spell, read
a Slower rank and a pet with neither spell, ideally with a hunter of a race without haste, and
decide whether to show the pet's own speed (the table) or what `UnitAttackSpeed` reports.
