# 19-family index (#17)

Pet Guide opens to five columns and four rows of family cards at the default
1040×700 window size, independently of creature coverage. Cards use 64-pixel
native portraits, wrapped names and subtle hover fades; no empty twentieth card
or repeated creature-count subtitle is drawn. Smaller windows use fewer columns
and scrolling. The footer counts displayed families. The three existing creature
records and all non-family facts remain unchanged. Sixteen families have no creature
records; they remain selectable and say "No creatures recorded in PetStable yet."

Search families by singular/plural English labels, including Birds of Prey,
Foxes, and Wolves. Selecting a card opens its appearance gallery, restoring
session search/filter/scroll state when revisited. Clear preserves that family.
Back to families restores the family search;
All Creatures shows the original three-creature browser. Family sources
opens a scrollable source summary. All navigation/search state remains session-only.

## Reference roster reviewed 2026-10-16

- [Petopia Forever](https://www.wow-petopia.com/forever/) lists 19 families and
  identifies its site as under construction.
- [Beastmaster Forever](https://beastmaster.io/forever), rendered v1.39.425,
  lists 18 family cards and describes its roster as preliminary. Core Hound is
  absent from that overview; omission is not a negative availability claim.
- [Petopia Core Hounds](https://www.wow-petopia.com/forever/family.php?id=corehound)
  supplies the nineteenth family reference; displayed appearance groups have
  unconfirmed status. No appearance or creature claim is imported.
- Roles are deliberately deferred: Petopia calls Foxes General while Beastmaster
  calls Fox Offense. No role filtering/color coding, diet, stats, abilities,
  tameability, or acquisition guidance is inferred from family inclusion.

Each roster supplies family-name facts with `reference` status. Source labels
are normalized to the observed singular client names; display plurals are UI
aliases, not competing facts or new family records. Existing Cat, Bear, and
Tallstrider keys and observations are retained. Core Hound has no Beastmaster
name claim. The older unused Beastmaster research evidence entry is preserved.

The sites can change before November 4. Recheck each at implementation/review
time and manually reconcile later updates in small PRs. Keep the review date and
source locator with each reference. There is no scheduled job, crawler, runtime
network access, or automatic promotion to confirmed status.

## Measured metadata

The existing saved PetStableProbe discovery capture was inspected for this
milestone: revision 1, run 91, capture 1, label `client family enumeration`,
build 1.60.1.70425, locale enUS. These are the `id`, `name`, and `iconFile`
values returned by `C_CreatureInfo.GetCreatureFamilyInfo`. Only this metadata
is transcribed; no account/character data or raw SavedVariables are shipped.
The prior finding is documented in [FOREVER-PROBE.md](FOREVER-PROBE.md#live-discovery-2026-10-16-build-160170425).

| Client name | Family ID | Icon file ID |
| --- | ---: | ---: |
| Bat | 24 | 132182 |
| Bear | 4 | 132183 |
| Bird of Prey | 26 | 132192 |
| Boar | 5 | 132184 |
| Carrion Bird | 7 | 132200 |
| Cat | 2 | 132185 |
| Core Hound | 312 | 236191 |
| Crab | 8 | 132186 |
| Crocolisk | 6 | 132187 |
| Fox | 319 | 458223 |
| Gorilla | 9 | 132189 |
| Hyena | 25 | 132190 |
| Raptor | 11 | 132193 |
| Scorpid | 20 | 132195 |
| Spider | 3 | 132196 |
| Tallstrider | 12 | 132198 |
| Turtle | 21 | 132199 |
| Wind Serpent | 27 | 132202 |
| Wolf | 1 | 132203 |

Enumeration also contains non-hunter families: it is not used as the roster.
The addon renders native icons by their recorded file IDs, without requiring
the enumeration API at runtime or fetching website artwork. Missing/conflicting
icons or failed texture calls use a neutral `?` placeholder. A successful texture
call still needs visual verification in the client.

## Validation

Run `pwsh -NoProfile -File tests/run.ps1`. Coverage includes roster/reference
counts, stable identity, exact metadata, literal singular/plural search, empty
family navigation, Clear/Back isolation, source scrolling, icon failure fallback,
widget reuse, and existing browser/focus/portrait regressions. The UI harness runs
with fallback styling and the pinned LibGlass r9. Test fixtures add no creatures
to the shipped catalog. Temporary deployment verifies the shipped files.

Live validation is pending:

1. With probes off, record build/locale; reload and open Pet Guide. Check 19 cards,
   native icons, five-column layout, readable names at preferred/minimum scale.
   Resize with the grip; confirm bottom rows remain reachable with no empty card.
2. Open Cat and Bear: one verified appearance each. Tallstrider has one unresolved
   appearance. Open the other 16: an explicit empty state, no stale models or
   unavailability claim. Follow the drill-down checks in [PET-GUIDE.md](PET-GUIDE.md).
3. Search `FOXES`, `Birds of Prey`, `wolves`, and `%`. Back must restore family
   search. Within a populated family, search a different creature and Clear;
   the selected family must remain. All Creatures must show exactly three creatures.
4. Open Family sources, drag/scroll to both references and the metadata note;
   return to a family and confirm normal detail layout/scroll reset.
5. Check typing does not trigger gameplay bindings, Enter releases focus, Escape
   closes cleanly, page switching/reopening works, and reload returns to the index.

The subsequent UI redesign adds model previews and dedicated appearance pages
using existing evidence, without new creature/appearance/ability facts or
dependencies. Role filters remain deferred. Saved window width/height are
additive version-1 settings; existing position, scale and page remain valid.
