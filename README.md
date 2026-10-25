# PetStable

Hunter pet field guide and ability upgrade advisor for WoW Forever. The player
addon currently provides a LibGlass window with Pet Guide, Ability Upgrades, and
My Pets navigation. A small provenance-aware catalog is now loaded, with measured
Forever observations and a separate Classic reference sample; see
[catalog coverage and validation](docs/CATALOG.md). Pet Guide now browses the
19 referenced families and the same three recorded creatures, with search,
appearance galleries, verified saved model previews, and evidence-aware details. The guide and Ability Upgrades are filtered to your hunter's level unless you turn that off
(see [docs/LEVEL-FILTER.md](docs/LEVEL-FILTER.md)). Family diet comes from the client's own family table ([docs/FAMILY-FACTS.md](docs/FAMILY-FACTS.md)). An optional [nearby teacher alert](docs/TEACHER-ALERT.md) is off by default. Ability Upgrades lists pet ability ranks and the creatures reported to teach them
(see [docs/UPGRADES.md](docs/UPGRADES.md)); My Pets shows your active pet and stable as last observed
(see [docs/MY-PETS.md](docs/MY-PETS.md)); recommendations and learned-rank tracking are not yet implemented.

CurseForge project ID: **1749062**. The planned public page is
[PetStable on CurseForge](https://www.curseforge.com/wow/addons/petstable);
publication is pending.

## Player addon

Open or close with `/petstable`. Drag the title bar to move; Escape or the close
button closes the window. Drag the lower-right grip to resize. Settings includes
scale and reset controls; `/petstable scale 0.9` also adjusts scale (0.65–1.3).
`/petstable reset` restores the 1040×700 size, default scale and centered position.
The window also fits the available screen size. Position, dimensions, preferred scale, and selected page
are saved in account-wide `PetStableDB`. Non-hunters can open every page.

With the pointer over PetStable, Mouse Button 4 goes back and Mouse Button 5
goes forward through visited views and tabs. Visits retain their search,
filters, selection and scroll. A new destination after going back replaces the
forward branch. History is session-only, capped at 50 visits, and does not change
global mouse bindings; closing/reopening preserves it, while reload clears it.

Pet Guide opens to a searchable five-column family grid with larger portraits,
independently enlarged family labels and subtle shading/hover feedback. The
slim scrollbar appears only when needed. The footer counts displayed families; cards do not imply
creature coverage or collection progress. A family opens its appearance gallery;
an appearance opens its associated creatures and their individual details.
Back restores the family search, level/location filters and gallery scroll.
Sixteen families still have no creature records. All Creatures retains the
original browser. Family sources explains the dated reference roster and
measured native icons; see [family index](docs/FAMILY-INDEX.md).
Appearance details keep Sources & observations collapsed, with further technical
evidence and selectable source URLs. Scroll galleries and details using the
wheel or draggable thumb. The All Creatures view also retains its arrow controls.
Enter releases search focus; Escape closes the window, including while typing.
Search, family selection, and view last for the session and reset on reload.

The Cat and Bear have measured appearances but no recorded wild names. Ornery
Galestrider has no measured display ID and uses an unresolved appearance card. Observer
context is not a spawn location, and no entry claims an acquisition source.
See [browser scope and live checks](docs/PET-GUIDE.md).

For a development checkout:

```powershell
pwsh Tools/embed-libglass.ps1
pwsh Tools/deploy-addon.ps1
```

Then `/reload` and `/petstable`. The embed script reads pinned LibGlass r9
(`fcfd472b30756a51b265969e71deb36cd3524802`) from `../LibGlass` without modifying
that checkout, and uses the release's own deployment script to copy its runtime
files, license, and media. Override the source with `-LibGlass <path>`.
`.pkgmeta` pins the same release for packaging. The embedded copy is gitignored.
A source checkout without the library uses a flat readable frame; deployment
requires the embedded library. PetStable has no AltStable or ForeverProbe
dependency. Its glass instance does not change another addon's material settings.

## Developer probes

The developer-only PetStableProbe module includes the issue #2 smoke check and
issue #3 guided training captures (`/fp steps ps switch|trainer|teach|learn`), and
issue #4 portrait/model comparisons (`/fp steps ps models`). See
[the probe guide](docs/FOREVER-PROBE.md) for deployment and guided checks.

Issue #5 adds creature observations (`/fp steps ps discover`) and an optional
planned-tame comparison (`/fp steps ps tame`). These collect evidence; they do
not automatically confirm tameability or hunter ability acquisition.

Catalog references include [Petopia Forever](https://www.wow-petopia.com/forever/),
[Beastmaster's Forever section](https://beastmaster.io/forever),
[WarcraftDB Forever pet families](https://forever.warcraftdb.com/list/pet-families),
[Petopia Classic](https://www.wow-petopia.com/classic/), and
[Petopia mainline](https://www.wow-petopia.com/index.php). Website claims and
build-stamped in-game observations will retain separate provenance.

Run local syntax and integration checks with `pwsh tests/run.ps1` after embedding.
Lua 5.1, `../LibGlass` (or `LIBGLASS`, for its widget mocks), and the sibling
`../ForeverProbe` checkout (or `FOREVERPROBE`) are required for the full suite.
CI tests the player addon against the pinned LibGlass commit and skips probe
integration when the private host is unavailable. The host and probe module
are excluded from player packaging.

## Scaffold validation

The browser now includes an attributed [Forever reference expansion](docs/REFERENCE-CATALOG.md):
808 creatures and 499 distinct numeric display IDs across 18 families, alongside
the 19-family index. Core Hound availability remains unconfirmed. Website model
previews are labeled as references and do not establish tameability.

When turned on, targeting or mousing over a world beast records its exact appearance
locally if the client supplies its IDs. Capture is off by default until its model
binding is measured on the live client. Toggle this in Settings or with `/petstable sightings on|off`;
`/petstable sightings` reports the journal size. Nothing is uploaded automatically.
See the reference guide for export, limits, and required in-game checks.

Local tests cover initialization, missing-library fallback, non-hunter navigation
without pet APIs, settings restoration, invalid settings, screen fitting, isolated
glass styling, and deployed Lua/media files. Live feedback and the successful
Escape retest are recorded below.

In game, open `/petstable` and visit all three pages. Check readable text over
bright scenery, drag the title bar, change scale, and close with both Escape and
the close button. Reopen after `/reload` to check position, scale, and selected
page. A full exit/relaunch is needed to verify disk persistence independently
of reload. Repeat opening on a non-hunter when convenient. Pet Guide shows the
bounded catalog; My Pets shows observed pets and Ability Upgrades is a reference listing.
The browser's own live validation remains pending as documented in its guide.

Live validation feedback on 2026-10-16 reported that Escape opened the game menu
instead of closing PetStable; the other checks performed seemed fine. The window
now handles Escape directly and consumes that key while passing other keys
through. Local regression checks cover closing and reopening with and without
LibGlass. The owner confirmed the deployed Escape fix works on 2026-10-16.

The reflective shell follows the shared
[window styling recipe](../References/Docs/LIBGLASS-WINDOW-STYLING.md): smoked outer
tint/backing, sliced directional silver rim, fine top highlight, and a masked
header reflection fading within 70 UI units. A single masked reading region
starts at y=52 and protects the horizontal navigation, content, and footer.
Sage accents mark active controls and hover states. The shell uses r9's
`Reflect` and `SetSurfaceAlpha` APIs with the same material settings.

For live comparison at the same position and scale:

```text
/petstable material flat
/petstable material reflective
```

`flat` restores the prior nearly opaque window; `reflective` is the default.
This development comparison is session-only and repaints existing layers,
without rebuilding widgets or changing saved settings. Both work before opening
the window too. Compare side by side with GRF over bright outdoors and dark
interiors, then moving scenery. The reflective adaptation has passed local
checks, and initial live feedback reported no visual issue. No sibling or library
files changed.
