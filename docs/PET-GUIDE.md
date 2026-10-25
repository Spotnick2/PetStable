# Pet Guide: family index and appearance browsing

Pet Guide uses the [19-family index](FAMILY-INDEX.md) and the same three creature
records shipped in PR #16. The redesigned shell has horizontal tabs, saved grip
resizing, Settings, embedded search clearing and restrained hover feedback.
My Pets retains its existing empty state; Ability Upgrades is described in [UPGRADES.md](UPGRADES.md).

## Navigation and presentation

Families opens a five-column index at the default size. Selecting a family opens
an appearance gallery of looks: two columns and two visible rows (three columns
from a 1300-unit-wide panel), each card a model over a band with the look's name
and one "level · zone" caption. Named looks come first, then unnamed displays.
Creatures without a matched display sit behind a "without a matched look"
disclosure under the grid, shown directly only when nothing else matches. Long
labels increase card height. Nine reusable slots keep each visible result on the
same card; models load only after scrolling rests for 0.15 s, and the wheel eases
instead of jumping. Leaving the gallery clears their models and pending work.

An appearance opens a dedicated page with the model across nearly half the width
and "Where to tame this look" at right (titled "Reported locations for this look"
when no creature has a recorded spawn, with website zones marked "(reference)"): a reference/verified status line, a
creature · level · location table, the selected creature's taming and spawn
summary, and its zone with "Open zone map" when the client resolves the zone
name. Family abilities & diet and Sources & observations are collapsed rows; the
latter holds the creature's facts, the look's Petopia source and the shared-skin
display IDs. Back to appearances restores family, query, level/location filters
and scroll. Family sources remains accessible.
All Creatures preserves the original searchable list, portraits and evidence pane.
That view also retains its selection, query, evidence mode and scroll in-session.

Mouse Button 4/5 provides Back/Forward while the pointer is over PetStable,
including child cards, search fields, scrollbars and the model viewer. History
includes view and top-level tab changes; inline filtering/disclosure edits are
saved with the visit rather than creating a visit per click/keystroke. Returning
restores that visit's selection, evidence/disclosure state and scroll as well as
its filters. New destinations discard the forward branch. Repeated visits to the
same destination and window reopening do not add duplicates. History is bounded
to 50 session visits and does not replace global mouse bindings.

Search uses literal, trimmed, case-insensitive substrings: family singular/plural
names on the index; appearance labels and creature names in a family; creature
and family names under All Creatures. It does not advertise abilities or zones.
Lua 5.1 lowercasing is not Unicode case folding; the current seed is enUS.

The level and zone controls cycle through the available choices. Level choices
match an observed level or overlap a verified range. Unknown levels/locations
remain selectable. All criteria must match the same creature; an appearance is
returned if at least one associated creature matches. Details explicitly label
filtered records and offer Show all associated creatures / Show matching creatures.
Summaries never turn observations into verified ranges. Longer zone summaries
show the first two labels plus the number of additional locations; individual
rows retain the complete known location information.

Sources & observations starts collapsed. Opening it shows fact-specific values,
status, review date and source type for the selected creature. Technical evidence
adds build/locale/capture/URL details. Select source URLs exposes an EditBox for
Ctrl+C; edits are not saved and no network requests occur. Evidence for one field
never certifies another. Enter releases input focus and Escape closes the window.

## Data boundaries

The catalog is unchanged by the visual redesign. Cat and Bear have verified
saved displays 1059 and 136606 on build 1.60.1.70425; neither has a recorded wild
name or an appearance color/name. Generic labels include the display identifier
to distinguish otherwise unnamed appearances. Ornery Galestrider has observed
level 9 but no resolved display. It remains accessible in its own unresolved
appearance card. Sixteen families have no creature coverage yet.

`GuideData.lua` groups by family and skin. Exact displays sharing a datamined
skin key (see [REFERENCE-CATALOG.md](REFERENCE-CATALOG.md)) render identically
apart from scale and share one card; a display without a key keeps its own card.
Matching model-file IDs, names or families alone never merge records. Unknown or
competing appearance links remain separate unresolved creature cards. Every grouped record
retains its original details and field evidence, including its own level,
tameability, conditions and location. Structurally invalid catalogs fail closed.

A confirmed appearance relationship, confirmed true visual proof and a display
claim must share game/build/locale. Model and portrait proof are checked
separately. A name observation, recorded display alone, successful model API call
or website reference cannot promote appearance/tameability verification.

The seed contains no verified spawn positions, family roles, learnable family
abilities or diet. Those fields remain unknown/unverified; no role filters or
signature-ability icons are fabricated. Galestrider's observer map/area is not a
spawn location and is excluded from zone filtering. There are no map buttons,
pins or waypoints. Verified range/spawn projection has synthetic coverage only;
adding real data remains a separate reviewed task. Known active-pet spells and
Classic references are not treated as family eligibility or wild acquisition.

## Preview implementation and limitations

`GuideModels.lua` uses the custom ModelScene actor path measured in
`Tools/PetStableProbe/Models.lua`, documented in [FOREVER-PROBE.md](FOREVER-PROBE.md).
The local `../References/forever-api-1.60.1.70425.md` provides the client API
surface. `SetModelByCreatureDisplayID` uses the saved exact skin and does not
require a nearby/targeted creature. No SetCreature, SetUnit or model-file fallback
is used. Actor bounds are polled every 0.2 seconds for at most four seconds.

The camera retains a square projection, matching the measured probe's near-square
projection. Gallery scenes cover the full preview area; their parent clips the
surplus above/below or beside the preview. The still pose is fitted using its
rotated bounding-box corners, perspective depth, and the visible area's aspect
ratio, with a 15% margin. Detail scenes remain inscribed squares and retain the
72% height/diagonal fit for rotation. Usable unit-scale bounds are cached;
resize and Reset reuse those measurements. Card labels grow when needed instead of
reserving a second line for every name, leaving more height for previews.
Gallery poses are still; callbacks stop after fitting.
Detail previews support drag/button rotation, wheel/button zoom and reset.
Controls appear after successful fitting. Hiding a view cancels fitting/dragging
and clears actors. Missing/rejected models and bounds timeouts show a verified
portrait where available, otherwise an explicit unavailable-preview message.

API success and offline fitting calculations do not establish correct texture,
animation extents or whole-body framing in game. The owner verified the current
UI in game on build 1.60.1.70450; Cat/Bear screenshots show the final gallery fit,
and the owner accepted the detail framing. Taller and winged shapes and other
skins still require their own visual evidence.

## Validation

Run `pwsh -NoProfile -File tests/run.ps1`. This covers Lua 5.1 syntax, catalog and
projection validation, fallback and embedded LibGlass r9 UI paths, existing probe
regressions and a temporary deployment with exact runtime copies and TOC loading.

`tests/test_guide.lua` checks proof scopes, shared-display grouping, different
skins sharing geometry, independent unresolved records, observed versus verified
levels, record-level combined filters, unknown locations and long zone summaries.
`tests/appearance_cases.lua` checks pooled rendering, model failures/timeouts,
rotation/zoom/reset, detail selection, matching/all disclosure, focus, source URL
selection, navigation state and minimum-size layout. Existing browser and shell
coverage remains in `guide_cases.lua` and `test_addon.lua`. Synthetic fixtures
are test-only. Widget mocks and approximate text heights are not visual testing.
`tests/history_cases.lua` covers Back/Forward across controls and tabs, visit
state, branch truncation, boundary no-ops, reopening, and history limits.

### Owner verification: 2026-10-16, build 1.60.1.70450

The owner explicitly confirmed in-game verification of the current UI on this
build after the interaction and preview fixes. Supplied screenshots cover Cat
and Bear appearance galleries and the Cat detail viewer; the owner accepted the
detail size and confirmed the gallery size, with taller pets deferred. Earlier
feedback confirmed wheel/arrow/thumb scrolling, and the original browser was
accepted in PR #16.

API declarations were checked against the owner-supplied
`../References/forever-api-1.60.1.70450.md` (Interface 16001, WOW_PROJECT_ID 18).
This updates UI compatibility evidence; catalog observations retain their
original build 1.60.1.70425 provenance. Locale was not separately reported for
the 70450 verification.

The final review also replaces the missing resize-arrow font glyph with three
drawn corner lines. Resizing behavior is unchanged; the replacement's appearance
still needs a client glance after deployment. Full exit/relaunch persistence and
taller/winged model framing remain follow-up checks. Shared-appearance and large
gallery scenarios have synthetic coverage; the seed has no such live examples.

Reusable live smoke checklist (owner acceptance above; expanded cases remain
follow-up checks):

1. Disable probes, reload and open `/petstable`; record build/locale. Check the
   family grid, hover fade, horizontal tabs and sources over bright/dark scenery.
2. Open Cat and Bear, then their appearance cards with no pet targeted/nearby.
   Check correct skin and complete body framing. Rotate, zoom and reset. Close
   while loading and reopen; no stale preview or continuing drag should remain.
3. Open Tallstriders. Expect Ornery Galestrider with an unresolved preview,
   Observed level 9, unknown location and explicit observer context in details.
   Empty families must remain accessible without implying unavailability.
4. Search, cycle level/location choices, open a detail and go Back. Confirm
   query/filter/scroll retention. Select sources, technical disclosure and copy
   URLs. Confirm typing does not trigger gameplay bindings. No seeded appearance
   has multiple creatures; that scenario currently has synthetic coverage only.
5. Open All Creatures: exactly three records, existing details/evidence controls.
   Visit Ability Upgrades/My Pets, then return; verify retained navigation state.
6. Drag the header, resize with the grip, change scale through Settings and close
   using Escape/the close button. Check long labels, bottom rows and both thumbs
   at default and minimum size/scale. Reload preserves window settings/page but
   resets browser state. A full exit/relaunch checks disk persistence separately.
7. Visit Families → a family → an appearance. Press Mouse Button 4 twice and
   Button 5 twice over cards, the search field, a scrollbar and the model. Check
   restored search/filter/detail/scroll state and exactly one step per click.
   Go back, choose a different family, and confirm the old forward route is gone.
   Check ordinary selection, model dragging, grip resizing and mouse bindings
   outside PetStable remain unaffected.

No creature expansion, website imports, invented appearance names, ability
recommendations, collection tracking or gameplay actions accompany this change.
