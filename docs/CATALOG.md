# Catalog v1: bounded issue #7 seed

The original seed below is now supplemented by the generated
[Forever reference catalog](REFERENCE-CATALOG.md). Its website claims remain
reference evidence; the original observations and their build stamps are intact.

This is a static, provenance-aware foundation for Pet Guide, delivered as partial
work on issue #7. The [browser](PET-GUIDE.md) now includes a [19-family index](FAMILY-INDEX.md)
without expanding creature coverage. Ability Upgrades and My Pets retain their empty states. The catalog
does not provide recommendations, collection capture, data import, network access,
or SavedVariables changes.

## Contract

`CatalogData.lua` exposes `NS.CatalogData`: version 1 and dense arrays of records,
evidence, and facts. `Catalog.lua` exposes pure Lua helpers; it requires no game
APIs, library, or developer probe. The TOC loads both after Core and before UI.

- Records contain a stable catalog `key`, entity `kind`, and `game` (`forever`
  or `classic`). Keys are internal identifiers, not localized names or game IDs.
  Kinds are creature, appearance, family, ability, rank, and source.
- Facts contain `subject`, `field`, `value`, `evidence`, and `status`. Numeric
  creature/display/family/spell IDs are distinct, evidence-backed fields. Rank
  keys can exist without spell IDs. An absent fact means unknown; a literal
  `false` is an observed negative. Zero is not a placeholder for a missing ID.
- Evidence contains its key, game, kind (`observation` or `reference`), URL,
  locator, and review date (`date`). Observations also require the measured
  build and locale. The date is the source-review date, not an invented capture
  timestamp. Locators retain procedure/run/capture context where documented.
- Status is `observed`, `confirmed`, or `reference`. Confirmation applies only
  to the individual fact. Here it is used for visually checked appearances.
  Website evidence must have reference status even when the site covers Forever.
- `GetRecord(data, key)` returns the record or nil. `GetFacts(data, key, field)`
  returns all claims (empty list means unknown), without choosing a winner.
  Returned objects belong to the static catalog and should be treated as read-only.
  Consumers must inspect evidence game/build/status; none of these calls implies
  current-build compatibility, completeness, or personal training knowledge.
- Creature `appearance` facts are many-to-many links, each with evidence. No
  reverse relationship is duplicated. The browser can derive it later.
- Classic ranks and their trainer source are separate from Forever spell
  observations. No name-based cross-game join or automatic override is applied.
  A future verified Forever override must carry its own evidence.

Field definitions live in `Catalog.lua`. Level ranges, family eligibility,
conditions, tame/trainer source links and normalized spawn positions can be
represented, but this seed does not populate unsupported fields. `observedLevel`
is one specimen's level. `observerArea` and `observerMapID` are observer context.
`spawn` requires `{kind="spawn", space="ui-map", mapID=..., x=..., y=...}` with
normalized coordinates in [0,1]. World positions or observer positions cannot
be placed in that field. No coordinate conversion is supplied.

`Validate(data)` returns `errors, conflicts`. Structural errors include invalid
IDs, duplicate keys/identities, missing evidence/references, invalid relations,
rank cycles/order errors, and invalid coordinate representations. Conflicts
contain both original claims for a single-valued field within the same
record/build/locale. Multi-valued links permit several distinct targets.
Neither claims nor conflicts are discarded. Tests fail if the shipped seed has
errors or unresolved conflicts. Semantic checks use agreeing claims within the
same game/build/locale: a second supporting claim does not disable trainer-source,
rank or level checks, and evidence from another scope does not supply their values.
Validation does not establish source truth;
cross-build and cross-game interpretation remains a research task.

## Exact seed coverage

| Records | Evidence and limits |
| --- | --- |
| Creature 3035, display 1059 | Cat family; measured portrait/model match and model file 126171. Wild name, spawn and acquisition remain unknown. |
| Creature 251115, display 136606 | Bear family; measured portrait/model match and model file 7581790. The recorded pet name is not promoted to a wild NPC name. |
| Creature 251707 | Ornery Galestrider, Tallstrider family ID 12, observed level 9; observer context Zephras Isle/Gustberry Lowlands, UI map 2521. Appearance, tameability, range and spawn remain unknown. |
| Seven Forever spell observations | 17255, 16827, 4188, 14916, 24549, 1263113, 1742. Active-pet spellbook observations only; no source-creature links. Slower Attack II retains its label without interpreting II as rank progression. |
| Two trainer row observations | Great Stamina Rank 3: required level 18, raw cost 400, Rank 2 prerequisite flag true. Rank 4: required level 24, Rank 3 prerequisite flag false, cost unknown. Both unavailable in the recorded context. No spell IDs, cost-unit interpretation, or links to identified ranks. |
| Classic reference sample | Great Stamina ranks 2-4, minimum pet levels 12/18/24, training costs 10/15/25 TP, all-family eligibility, trainer source and ordered rank links. No spell IDs or Forever equivalence inferred. |

The seed has 45 records and ten evidence entries, including 19 families and
the original three creatures. Family `iconFileID` is a positive native file ID,
separate from family identity and creature display IDs. It contains no petNumber,
character GUID, pet GUID, or stable slot. Stable `petAbilities` arrays are not
used as spellbooks. Hunter learned ranks remain unknown. Synthetic shared looks,
alternate skins, spawn points, and contradictory facts exist only in tests.

## Sources reviewed on 2026-10-16

- [Committed live findings](FOREVER-PROBE.md): primary basis for Forever facts,
  measured on 1.60.1.70425. Runtime evidence points to the immutable PR #14 merge
  version of this document. The original SavedVariables and screenshots were
  inspected when those findings were written; this seed transcribes the findings
  and does not claim a new independent inspection of those artifacts.
- [Petopia Classic abilities](https://www.wow-petopia.com/classic/abilities.php):
  the Great Stamina section supplies the small Classic reference sample.
  Only selected facts are transcribed; no prose or artwork is copied.
- [Beastmaster Forever](https://beastmaster.io/forever): the rendered page was
  reviewed (site v1.39.425). It describes its roster as preliminary beta research.
  The page links to [Forever abilities](https://beastmaster.io/forever/abilities)
  and family browsing, useful leads for later source research. Its evidence entry
  is deliberately unused by seed facts: this pass did not establish stable
  ID/source mappings or confirm its gameplay claims in Forever. The earlier
  text-only fetch could not read the page; the rendered page is accessible.
- [Petopia Forever](https://www.wow-petopia.com/forever/) and a new dated
  [Beastmaster roster](https://beastmaster.io/forever) evidence entry supply
  family-name references only. Their reviewed counts are 19 and 18; Core Hound
  appears only in the former overview. All 19 native family IDs/icons come from
  run 91 capture 1. See [family evidence and limits](FAMILY-INDEX.md).
- [Petopia mainline](https://www.wow-petopia.com/index.php): retained as a future
  appearance research reference, not evidence of Forever tameability.

No website dataset is bulk-imported and no export API is assumed. More detailed
claims require the original captures or new build-stamped observations. The
local Forever API dump describes declarations, not catalog truth.

## Validation and remaining work

Run `lua5.1 tests/test_catalog.lua` (or the installed Lua 5.1 executable), then
`pwsh -NoProfile -File tests/run.ps1`. Catalog tests need no host or client. The
full runner includes addon/probe regressions and a temporary deployment that
loads the catalog from its deployed TOC and checks exact copies. CI runs catalog
validation unconditionally and retains the optional private-host probe skip.

After deployment, smoke-test `/petstable` on build 70425 or record the newer
build: enable only the player addon, open each page, close with Escape, reopen,
and reload. Include a non-hunter/no-pet check. The catalog-only change did not
introduce rendering; the browser now has its own [live checks](PET-GUIDE.md).

Issue #7 remains open for real shared-look/multiple-appearance seed coverage,
identified acquisition sources, and more representative requirements/location
data. Issues #3-#5 retain their documented research gaps. Issue #8 closed with
PR #16; #17 tracks the family-index follow-up. PR #18 adds saved-display 3D
previews, appearance grouping, and record-level level/location filters; owner
UI verification is recorded on build 1.60.1.70450 in [PET-GUIDE.md](PET-GUIDE.md).
Collection tracking and recommendations (#9-#11), and broad catalog expansion
(#12) remain outside this milestone.
