# Pet Guide: family index and appearance browsing

Pet Guide uses the [19-family index](FAMILY-INDEX.md) and the same three creature
records shipped in PR #16. The redesigned shell has horizontal tabs, saved grip
resizing, Settings, embedded search clearing and restrained hover feedback.
Ability Upgrades and My Pets retain their existing empty states.

## Navigation and presentation

Families opens a five-column index at the default size. Selecting a family opens
an appearance gallery with three columns and two visible rows at the default
size for ordinary labels. Long labels increase card height; smaller windows use
two columns and scrolling. Nine reusable slots load only intersecting cards;
leaving the gallery clears their models and pending work.

An appearance opens a dedicated page with a model at left and a scrollable
creature/location table at right. Selecting a row reveals that creature's own
facts. Back to appearances restores family, query, level/location filters and
scroll. Family information is secondary, and Family sources remains accessible.
All Creatures preserves the original searchable list, portraits and evidence pane.
That view also retains its selection, query, evidence mode and scroll in-session.

Mouse Button 4/5 provides Back/Forward while the pointer is over PetStable,
including child cards, search fields, scrollbars and the model viewer. History
includes view and top-level tab changes; inline filtering/disclosure edits are
saved with the visit rather than creating a visit per click/keystroke. Returning
restores that visit's selection, evidence/disclosure state and scroll as well as
its filters. New destinations discard the forward branch. Repeated visits to the
same destination and window reopening do not add duplicates. History is bounded
to 50 session visits and does not replace global mouse bindings. Native mouse
delivery over each control still needs a client smoke check.

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

`GuideData.lua` groups by family and an unambiguous verified display ID. Matching
model-file IDs, names or families alone never merge records. Unknown or competing
appearance links remain separate unresolved creature cards. Every grouped record
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

The camera uses a centered square viewport inside the available preview area,
matching the measured probe's near-square projection rather than stretching it
across a shallow gallery card. Usable unit-scale bounds are cached and fit with
margin against height and horizontal diagonal. Resize and Reset reuse those
measurements. Gallery poses are still; callbacks stop after fitting.
Detail previews support drag/button rotation, wheel/button zoom and reset.
Controls appear after successful fitting. Hiding a view cancels fitting/dragging
and clears actors. Missing/rejected models and bounds timeouts show a verified
portrait where available, otherwise an explicit unavailable-preview message.

API success and offline fitting calculations do not establish correct texture,
animation extents or whole-body framing in game. Existing Cat/Bear probe results
support the mechanism; the new gallery/detail composition still needs live
verification. Other shapes and skins require their own visual evidence.

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

The owner accepted the original browser in PR #16 and confirmed its evidence
wheel, arrows and draggable thumb. That does not validate the new screens.

Live smoke checklist (pending):

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
