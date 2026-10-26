# PetStable

A hunter pet field guide for **WoW: Forever**, in one window. Browse the pet families, see the looks
each one has and the creatures recorded for them, check which pet ability ranks you could train next
and who is listed as teaching them, and see your active pet and stable.

> **Alpha.** The catalog is bounded, some in-game checks are still pending, and ability-rank tracking
> and recommendations are not implemented. Every fact says where it came from; a website listing is
> never presented as something measured in the client.

- [PetStable on CurseForge](https://www.curseforge.com/wow/addons/petstable) (CurseForge project 1749062)
- [Releases on GitHub](https://github.com/Spotnick2/PetStable/releases)
- [PetStable on Wago Addons](https://addons.wago.io/addons/vNAW1pKo)

## Install

Install from CurseForge or Wago with your addon manager, or unzip a release from GitHub into
`World of Warcraft\_forever_\Interface\AddOns\`. PetStable has no required dependencies; its one
library (LibGlass, for the window material) is included.

## Use

Open or close the window with `/petstable`. Escape or the close button closes it.

- **Pet Guide:** a searchable grid of the 19 referenced families. A family opens its gallery of looks,
  and a look opens the creatures recorded for it and their details. "All Creatures" is the flat list.
  Sources and observations are collapsed on each page, with the source links you can select and copy.
  See [the guide](docs/PET-GUIDE.md) and the [family index](docs/FAMILY-INDEX.md).
- **Ability Upgrades:** pet ability ranks, and the creatures reported to teach them
  ([details](docs/UPGRADES.md)).
- **My Pets:** your active pet and your stable as last observed ([details](docs/MY-PETS.md)).
  Family diet comes from the client's own family table ([details](docs/FAMILY-FACTS.md)).
- **Level filter:** on by default, the guide and Ability Upgrades hide what your hunter's level can't
  use yet, and say how much is hidden ([details](docs/LEVEL-FILTER.md)).
- **Navigation:** with the pointer over the window, Mouse Button 4 goes back and Mouse Button 5 goes
  forward through the views you visited, each with its search, filters, selection and scroll. History
  lasts for the session (50 visits) and doesn't change your mouse bindings.
- Drag the title bar to move the window and the lower-right grip to resize it. Position, size, scale
  and the selected page are saved. Non-hunters can open every page.

### Commands

| Command | What it does |
| --- | --- |
| `/petstable` | Open or close the window |
| `/petstable scale 0.9` | Scale the window (0.65 to 1.3); also in Settings |
| `/petstable reset` | Back to the default size, scale and position |
| `/petstable levelfilter on\|off` | Filter the guide and Ability Upgrades to your level (on by default) |
| `/petstable teachers on\|off` | Nearby teacher alert (off by default) |
| `/petstable sightings on\|off\|clear` | Local sighting journal (off by default) |
| `/petstable material reflective\|flat` | Window material, for this session |

### Optional features, both off by default

- **Nearby teacher alert:** a notice when a creature you target, mouse over or see on a nameplate is
  *listed* as teaching the next rank of an ability your active pet lacks. It never says you have or
  lack a rank, since that isn't tracked. English client only
  ([when it shows](docs/TEACHER-ALERT.md)).
- **Local sightings:** records the exact appearance of world beasts you target or mouse over, when the
  client gives its IDs. It stays in your saved variables; nothing is uploaded. Capture is off until its
  model binding is measured on the live client ([reference guide](docs/REFERENCE-CATALOG.md)).

## Good to know

- The catalog is a reference seed, not a full bestiary: 808 creatures and 499 distinct display IDs
  across 18 of the 19 families. Core Hounds have only unconfirmed website looks and no recorded
  creatures. See [catalog coverage](docs/REFERENCE-CATALOG.md).
- Website model previews are labelled as references and don't establish that a creature is tameable.
  No entry claims an acquisition source, and an observer's position is not a spawn location.
- Some entries have no measured appearance and show an unresolved card (Ornery Galestrider has no
  display ID); an appearance with no recorded wild name says so.
- Recommendations and learned-rank tracking are not implemented.

## Bug reports

Please open an [issue on GitHub](https://github.com/Spotnick2/PetStable/issues) with what you did,
what you expected, and any Lua error text.

## Credits

Catalog references: [Petopia Forever](https://www.wow-petopia.com/forever/),
[Beastmaster's Forever section](https://beastmaster.io/forever),
[WarcraftDB Forever pet families](https://forever.warcraftdb.com/list/pet-families),
[Petopia Classic](https://www.wow-petopia.com/classic/) and
[Petopia mainline](https://www.wow-petopia.com/index.php). Website claims and build-stamped in-game
observations keep separate provenance.

Window material by [LibGlass](https://github.com/Spotnick2/LibGlass) (MIT), which bundles LibStub
(public domain).

## Development

```powershell
pwsh Tools/embed-libglass.ps1   # copy the pinned LibGlass r9 into Libs/
pwsh Tools/deploy-addon.ps1     # copy the addon to the game's AddOns folder
```

Then `/reload` and `/petstable`. The embed script reads pinned LibGlass r9
(`fcfd472b30756a51b265969e71deb36cd3524802`) from `../LibGlass` without modifying that checkout, and
uses the release's own deployment script. Override the source with `-LibGlass <path>`. `.pkgmeta` pins
the same release for packaging; the embedded copy is gitignored. A source checkout without the
library uses a flat readable frame, and deployment requires the embedded library. PetStable has no
AltStable or ForeverProbe dependency, and its glass instance doesn't change another addon's material
settings.

Run the syntax and integration checks with `pwsh tests/run.ps1` after embedding. Lua 5.1,
`../LibGlass` (or `LIBGLASS`, for its widget mocks) and the sibling `../ForeverProbe` checkout (or
`FOREVERPROBE`) are needed for the full suite. CI tests the addon against the pinned LibGlass commit
and skips probe integration when the private host is unavailable. The host and probe module are
excluded from the package.

The developer-only PetStableProbe module measures what the client does (training, models, creature
discovery, planned tames; `/fp steps ps ...`). See [the probe guide](docs/FOREVER-PROBE.md). Its
captures are evidence only: they don't automatically confirm tameability or hunter ability
acquisition.

The window follows the shared
[window styling recipe](../References/Docs/LIBGLASS-WINDOW-STYLING.md) using LibGlass r9's `Reflect`
and `SetSurfaceAlpha`. `/petstable material flat|reflective` compares the two for the session without
changing saved settings.

### Releasing

A tag `vX.Y.Z` (or `vX.Y.Z-alpha1`, `-beta1`) is built by CurseForge's webhook, and the tag's CI run
publishes the checked zip as a GitHub Release (pre-release for alpha and beta) and uploads it to
Wago. The tag's section of `CHANGELOG.md` is the release notes. The TOC version is written by the
packager; never edit it by hand.

## Licence

MIT, see [LICENSE](LICENSE), which also lists the bundled third-party code.
