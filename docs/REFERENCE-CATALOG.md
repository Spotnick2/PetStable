# Forever reference catalog and local sightings

The 2026-10-16 research inventory expands the original observed seed without
changing its verification evidence. `CatalogReference.lua` contains generated
reference facts for 810 creatures (806 numeric NPC identities and four unresolved
source identities) and 499 distinct display IDs. All 19 family metadata records
remain available. Eighteen families have creature records; Core Hounds have only
unconfirmed website looks with no supplied exact NPC/display mapping.

## Reproduction and provenance

The raw research stays outside this repository and addon package:

- `../References/Forever/petstable/petstable-forever-research.md`
- `../References/Forever/petstable/petstable-forever-inventory.json`

Run `python Tools/import-reference.py ../References/Forever/petstable/petstable-forever-inventory.json`
to regenerate, or add `--check` to compare without writing. The generated file
includes the input SHA-256 as `referenceRevision`. Python uses only its standard
library; neither Python nor the raw JSON is needed by the player addon.

Each imported fact retains its inspected source URL, locator, review date, and
reference status. Sources are Petopia Forever, Beastmaster Forever, and Wowhead
Forever. WarcraftDB remains an additional research lead, not an input to this
inventory. English website names are fallbacks, not localized client observations.
The target build 70450 is deliberately not attached as verification of website data.

The importer includes explicit NPC and display identities, creature-family and
exact creature-display relationships, names, reported levels, zone names, creature
classification, tameability statements, and acquisition/location notes. It keeps
disagreeing claims rather than choosing a source winner. The catalog validator
reports these disagreements separately from structural errors; the guide leaves
disputed single-valued fields unresolved. Multiple zone names and display links
are legitimate multi-valued relationships.

Named Petopia/Beastmaster looks without exact display IDs, candidate color mappings,
the 7,774 reference coordinates, and inferred model file IDs are not imported.
They remain in the raw research. No zone ID is treated as a UI map ID. The runtime
subset is not an exhaustive inventory of obtainable pets or unique visual skins.
Identical display IDs group within a family, never across family boundaries.
Multiple displays for one NPC retain that NPC under every explicit variant.

Reference models use the exact-display preview API with the existing bounded
visible-card pool. Successful loading changes no verification or sighting flags.
Missing models show the existing unavailable-preview fallback. Website levels
and zones are usable filters, labeled as references; no spawn pins are generated.

## Localization

Stable numeric identities remain language-independent. Family labels use
`C_CreatureInfo.GetCreatureFamilyInfo` where available. Creature labels can use
local target names captured for the current locale; English source names remain
fallbacks. Conflicting local names are not arbitrarily selected. Existing windows
retain their current projection; `/reload` rebuilds labels from newly stored names.
Full UI/appearance-label translation and localized spell/map presentation remain
separate work. No global NPC-name-by-ID API is assumed.

## Local encounter journal

`Sightings.lua` listens for target and mouseover changes and entering the world.
It queries a cleared hidden PlayerModel for an addressable, non-player-controlled
world beast and waits up to two seconds for its display/model IDs. Every delayed
read rechecks the captured GUID. Changing the target, disabling capture, missing
APIs, or inconclusive IDs cancels the pending observation. It does not enumerate
every nearby creature, and cannot guarantee capture of a unit that disappears
before its model loads.

The account-wide `PetStableDB.sightings.records` journal stores NPC, display, model
file, family, localized name, observed level/classification, locale, build, and
first/last-seen timestamps. It does not store GUIDs, player names, inferred spawn
coordinates, or tameability conclusions. A new NPC/display/family/build/locale
combination is a new record, including displays absent from the shipped catalog.
Repeated observations update last-seen time without adding duplicates.

Capture defaults on and can be disabled in Settings or with
`/petstable sightings off`; `on` re-enables it. `/petstable sightings` reports the
count. The journal retains at most 10,000 combinations; reaching that limit warns
once per session and preserves existing records. Save a copy before using
`/petstable sightings clear`, which clears the local journal only.

For manual contribution, log out or reload to flush SavedVariables, then copy the
`PetStableDB.sightings` section from `WTF/Account/<account>/SavedVariables/PetStable.lua`.
Do not edit that file while the client is running. There is no background upload
or automatic mutation of the shipped catalog. A later reviewed import can combine
datamined IDs with these build-stamped observations. Neither source alone proves
that a creature is tameable. Appearance details can show “Seen by you in game”
for an observed family/display; previewing a model never sets this marker.

This is the capture foundation for issue #23. An in-addon export dialog, observation
review/acceptance tooling, and a richer gallery badge remain follow-up work.

## Validation and live checklist

Automated checks cover deterministic import, invalid input references, exact ID
namespaces, retained source-only creatures and conflicts, reference/observed proof
separation, multiple skins, filters, family localization, full shipped TOC loading,
bounded preview pooling, model fallback, navigation, and journal deduplication,
delayed loads, target changes, player control, persistence initialization and limits.

Still requires in-game testing on the current Forever build:

1. Browse every populated family; exercise tall/winged models, long names, filters,
   scrolling, detail/back navigation, unavailable displays and supported scales.
2. Target and mouse over world beasts, switch targets quickly during loading,
   then target player pets and summoned/controlled creatures. Confirm only eligible
   observations are recorded with the expected NPC/display/model IDs.
3. Verify capture toggling, a new uncatalogued display, two skins sharing geometry,
   and seen markers after reopening the family. Rendering alone must not mark seen.
4. Check a non-English client, reload, then fully exit/relaunch to verify disk
   persistence. Review exported rows before promoting any catalog fact.

Automated mocks do not establish live PlayerModel timing or availability of the
499 researched displays on any client build.
