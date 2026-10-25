# Family and creature facts: what has a source

Issue #29 asked which facts hunters use to choose a family can be recorded with a real source. Each
was decided on its own.

| Fact | Source plan | Status |
|---|---|---|
| **Diet** | The client's `CreatureFamily` table (`PetFoodMask`), datamined from wago.tools through the shared tool. | **Shipped** for the 19 hunter pet families (`CatalogFamilies.lua`, `Tools/import-families.py`). |
| Family scale range | Same table (`MinScale`, `MaxScale`). | Stored with the diet; not shown yet. |
| **Attack speed** | Not in any client table: it is per creature, on the server. The client reports it for a unit (`UnitAttackSpeed`). | Measure in game with `/fp steps ps facts` (queued for November 4). Not shipped. |
| **Stat modifiers** (health, armor, damage) | Not in any client table. The only source is a website listing, which would be one reference claim at most. | Not shipped: no verifiable source. Revisit if a measurement path appears. |
| **Role** | Sites disagree (Petopia calls Fox General, Beastmaster calls it Offense), and the client has no role. | Still deferred, as in FAMILY-INDEX.md. |

## Diet

`PetFoodMask` is a bit field. Bit 1 is Meat, then Fish, Cheese, Bread, Fungus, Fruit, Raw Meat, Raw
Fish, in that order (`Guide.Diet` in `GuideData.lua`). That reading is ours: it matched an independent
diet listing for all 19 families without exception, including unusual masks such as the Turtle's
178 (Fish, Fungus, Fruit, Raw Fish) and the Wind Serpent's 14 (Fish, Cheese, Bread), and
`tests/test_families.lua` pins that agreement. It is still not confirmed in game:
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
whether speed varies inside a family. Until that is read, attack speed is not recorded anywhere.
