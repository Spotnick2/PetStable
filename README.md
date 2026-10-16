# PetStable

Hunter pet field guide and ability upgrade advisor for WoW Forever. The player
addon currently provides a LibGlass window with Pet Guide, Ability Upgrades, and
My Pets navigation. A small provenance-aware catalog is now loaded, with measured
Forever observations and a separate Classic reference sample; see
[catalog coverage and validation](docs/CATALOG.md). Pet Guide now browses the
three recorded creatures with search, family filtering, exact 2D portraits where
known, and evidence-aware details. Ability Upgrades and My Pets retain their
empty states; recommendations and pet tracking are not yet implemented.

## Player addon

Open or close with `/petstable`. Drag the title bar to move; Escape or the close
button closes the window. `/petstable scale 0.9` adjusts scale (0.65–1.3), and
`/petstable reset` restores the default scale and centered position. The window
also fits the available screen size. Position, preferred scale, and selected page
are saved in account-wide `PetStableDB`. Non-hunters can open every page.

In Pet Guide, search recorded names or families and click the Family button to
cycle through All, Bear, Cat, and Tallstrider. Clear resets both filters. Select
a result for details; Show evidence exposes the sources, review dates, and
measured builds. Use the mouse wheel or arrow buttons to scroll results and
details. Enter releases search focus; Escape closes the window, including while
typing. Search, filters, and selection last for the session and reset on reload.

The Cat and Bear have measured appearances but no recorded wild names. Ornery
Galestrider has no measured display ID and uses a portrait placeholder. Observer
context is not a spawn location, and no entry claims an acquisition source.
See [browser scope and live checks](docs/PET-GUIDE.md).

For a development checkout:

```powershell
pwsh Tools/embed-libglass.ps1
pwsh Tools/deploy-addon.ps1
```

Then `/reload` and `/petstable`. The embed script reads pinned LibGlass r8
(`7b1b1e6c08f040d3fa495aa5f4308f160d5495d9`) from `../LibGlass` without modifying
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

Catalog references include [Beastmaster's Forever section](https://beastmaster.io/forever),
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

Local tests cover initialization, missing-library fallback, non-hunter navigation
without pet APIs, settings restoration, invalid settings, screen fitting, isolated
glass styling, and deployed Lua/media files. Live feedback and the successful
Escape retest are recorded below.

In game, open `/petstable` and visit all three pages. Check readable text over
bright scenery, drag the title bar, change scale, and close with both Escape and
the close button. Reopen after `/reload` to check position, scale, and selected
page. A full exit/relaunch is needed to verify disk persistence independently
of reload. Repeat opening on a non-hunter when convenient. Pet Guide shows the
bounded catalog; Ability Upgrades and My Pets still have explicit empty states.
The browser's own live validation remains pending as documented in its guide.

Live validation feedback on 2026-10-16 reported that Escape opened the game menu
instead of closing PetStable; the other checks performed seemed fine. The window
now handles Escape directly and consumes that key while passing other keys
through. Local regression checks cover closing and reopening with and without
LibGlass. The owner confirmed the deployed Escape fix works on 2026-10-16.

The reflective shell follows the shared
[window styling recipe](../References/LIBGLASS-WINDOW-STYLING.md): smoked outer
tint/backing, sliced directional silver rim, fine top highlight, and a masked
header reflection fading within 70 UI units. A single masked reading region
starts at y=82 and protects navigation, page content, help, and footer without
moving them. Green accents and text opacity are preserved.

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
