# Pet Guide browser and family index

Pet Guide opens to the [19-family index](FAMILY-INDEX.md), then browses the same
three Forever creature records shipped in PR #16. This follow-up adds family
metadata and references only. Ability Upgrades,
My Pets, the window style, and the SavedVariables schema retain their scope.

## Behavior

- Search is a trimmed, case-insensitive literal substring over known creature
  and family names. It is intended for the current enUS seed; Lua 5.1 lowercasing
  is not Unicode case folding. Lua pattern characters are treated literally.
- Family cards include families with no recorded creatures. Select a family or
  Browse all creatures to enter the creature browser. Family search is separate
  from creature search; Back to families restores it. Clear resets search text
  while keeping the selected family. Family sources reuses the scrollable pane.
- Results use four reusable rows. Mouse wheel moves through the list; arrow
  buttons move by four. Selection is retained if still present after filtering,
  otherwise the first result is selected. No results clears the selected details.
- Cat (3035) and Bear (251115) use family-based name-unknown labels and display
  IDs 1059 and 136606. Galestrider (251707) has its recorded name and a portrait
  placeholder. Stable pet names are not substituted for wild creature names.
- A reused row clears its texture before every display request. Missing IDs,
  missing APIs, and API errors show the placeholder. A successful API call is
  not proof that a texture has loaded: visual verification remains a live check.
- Details expose family, observed level, appearance verification, unknown
  tameability/acquisition/spawn, and any recorded observer context. A recorded
  false tameability value would display No, distinct from Unknown.
- Show evidence switches the same scrollable pane to fact sources, status,
  game/build/locale, review date, capture locator and URL. References are shown
  as text, with no network requests. Scroll with the wheel, up/down buttons,
  or draggable scrollbar thumb.
- Search, family, selection and the evidence toggle are session-only. Enter
  clears search focus; Escape closes the entire window. Page switches, clicks
  on browser controls, and closing the window release search focus.

## Evidence boundaries

`GuideData.lua` builds a pure-Lua display projection from valid catalog data.
It includes only Forever creatures, never Classic rank records, trainer rows,
or active-pet spell observations as creature results. Invalid structural data
produces a catalog-unavailable state. Empty catalogs and empty search results
have separate messages.

Scalar disagreements, including differences across builds/locales, remain
unresolved rather than picking the first or most recent claim. Several distinct
appearance links also remain unresolved in this slice; variant selection is
deferred. Agreeing claims retain their evidence. Sorting uses labels and stable
keys, so input order does not determine the selected factual value.

The appearance-verified text requires a confirmed creature/appearance link,
a confirmed true portrait verification, and the display ID in the same evidence
scope. It names the measured build, not the current client. Mere display presence
or a successful API call cannot grant confirmation. Unknown facts do not become
negative claims or eligibility advice.

The seed's Cat/Bear appearance checks were measured on 1.60.1.70425. The local
`../References/forever-api-1.60.1.70425.md` declares
`SetPortraitTextureFromCreatureDisplayID(textureObject, creatureDisplayID)` and
the EditBox, ScrollFrame, Slider, and FontString methods used here. This establishes the
API surface; it does not independently validate the new UI's live behavior.
Source evidence remains in [the catalog guide](CATALOG.md). The family index adds
dated Petopia/Beastmaster roster references; it imports no website creature claims.

## Validation

`tests/test_guide.lua` covers the seed projection, combined/literal filters,
selection, reordered input, conflicts, explicit false, same-scope visual evidence,
empty catalogs and malformed references. It requires no WoW client or probe host.

`tests/guide_cases.lua` runs through the existing addon harness with both flat
fallback and embedded LibGlass. It covers exact portraits, stale texture removal,
missing/error APIs, search/family changes, focus/Escape/navigation, evidence
scrolling, empty states, and pooled scrolling over 20 synthetic rows. Fixtures
are not shipped in the catalog. `guide_stubs.lua` adds state/event behavior to the
existing LibGlass mocks locally; its text-height estimate is not a visual test.

Run `pwsh -NoProfile -File tests/run.ps1`. This includes Lua 5.1 syntax, catalog
and guide tests, addon/probe regressions, and a temporary deployment that verifies
exact runtime file copies and loads the guide modules in deployed TOC order.
CI runs guide tests unconditionally, alongside the existing optional-host policy.

The owner accepted the first browser slice in PR #16. Screenshots show the Cat and
Bear filtered views, rendered portraits, and the evidence pane. The owner
confirmed that the evidence wheel, arrow buttons, and added draggable thumb work.
The new family index still needs its own live checks in [FAMILY-INDEX.md](FAMILY-INDEX.md).

Browser regression smoke checklist:

1. Deploy the player addon, disable the probes, reload, and open Pet Guide.
   Record the client build and locale. Choose Browse all creatures and confirm
   exactly three entries, correct Cat
   and Bear skins, and Galestrider's placeholder.
2. Search `cat`, `GALESTRIDER`, and `%`; select families through the index and
   combine with creature searches, then Clear. Confirm correct results/selection
   and no stale portraits or details. Clear must retain the selected family.
3. Check Galestrider's level is labeled observed and its area is observer context,
   not a spawn. Open Show evidence and scroll to the source/build information.
   Drag the scrollbar thumb to both ends, then use the wheel/arrows and confirm
   the thumb follows. Switch entries/views and check the scroll position resets.
4. Type movement-key letters in search and confirm no movement/bindings fire.
   Check Enter releases focus, Escape closes without opening the game menu,
   reopening works, and page switches/close button release focus.
5. Check readability, wrapping, and detail scrolling over bright/dark scenery at
   preferred and minimum supported scale; check the flat fallback when convenient.
   Repeat on a non-hunter with no summoned pet. Reload should reset browser filters
   while retaining the existing saved window settings and navigation page.

Issue #8 closed with PR #16; #17 tracks the family index. 3D previews/rotation,
appearance-variant controls, role and other extra filters, tameable-at-my-level,
maps, recommendations, and creature expansion are
not implemented by this slice. Live testing introduces no taming or training action.
