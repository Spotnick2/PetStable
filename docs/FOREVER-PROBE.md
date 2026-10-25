# PetStable runtime measurements

## Status

Issue #2 provides the module scaffold. The first live smoke check is recorded below;
its measurement steps are saved, but the procedure was stopped at its final instruction.
Offline stub results are not evidence of live client behavior.
Training, appearance, and creature experiments belong to issues #3, #4, and #5.

## Issue #5: creature discovery and taming evidence

Implemented in `Tools/PetStableProbe/Discovery.lua`; first live results are below.
The inspected local API dump is `../References/forever-api-1.60.1.70425.md`.
It exposes family IDs/metadata through C_CreatureInfo, unit creature identity
and family/type tuples, C_TooltipInfo.GetUnit, unit casting/channel information,
indexed auras, C_Spell queries, UnitPosition, and C_Map context. PlayerModel
SetUnit/GetDisplayInfo/GetModelFileID provides an appearance experiment.
No global enumeration of tameable creatures or their spawn locations was found
in these inspected paths. Family enumeration is client metadata, not a roster.

### First live check

After deployment, `/reload`, then `/fp steps ps discover`. Target a convenient
wild beast; a Forever-specific specimen is preferred when naturally available.
The panel records families, the target before/after optional Beast Lore, raw
tooltip data, and a screenshot of visible tooltip evidence. Beast Lore is not
required: record its absence and finish. Hover the creature during the visual
question so its tooltip appears in the screenshot. Click Finish measurements,
then `/reload`. No tame or pet abandonment is needed for this first check.

If no Forever-specific specimen or ability is available, record that coverage
as pending. A regular creature observation remains useful.

### Optional planned tame

`/fp steps ps tame` is only for a tame the owner already intends to perform,
with room for a new pet and existing pets safely stabled. It captures the wild
target first, then the resulting pet GUID, stable lists, and pet spellbook after
the manual attempt. The procedure saves the owner's Yes/No/Not sure answer and
screenshot. A failed or skipped attempt does not prove the species untameable.
No cast, purchase, stable change, or abandonment is performed by the probe.

Before/after IDs link observations as a candidate association. Confirmation
requires inspecting the procedure answer and resulting stable identity, not
matching a generic Pet GUID creature field or accepting any newly summoned pet.
Successful taming does not establish hunter ability acquisition; use the separate
issue #3 `learn` procedure when an appropriate learning opportunity occurs.

### Evidence and limits

- `PetStableProbeDB.discovery` retains the latest 24 captures, each with build,
  locale, host run, timestamp, full API tuples, and explicit missing/error/
  unreadable states. Family and pet-spell enumeration are capped at 200 rows;
  auras are capped at 40 per filter and marked potentially truncated at the cap.
- Only a present target with a Creature GUID enters the creature observation
  path. Player/Pet/Vehicle GUIDs do not supply wild NPC identity. A changed GUID
  during capture invalidates the identity/appearance association.
- `observerPosition` is UnitPosition(player); `creaturePosition` is
  UnitPosition(target). Both retain raw x/y/z/map tuples. Observer UI map ID and
  zone text are context only. Neither position is promoted to a spawn point,
  and world coordinates are not presented as normalized map coordinates.
- Appearance queries clear the prior model before SetUnit. Immediate missing
  or zero results remain inconclusive: asynchronous loading is not retried here.
  The world screenshot and issue #4 display experiments provide complementary
  visual evidence; modelFileID is not a skin/displayID.
- Tooltips remain localized raw data. Casts and auras are visible observations,
  not proof of teachable pet abilities. A spell query returning data establishes
  only client presence. Stable petAbilities lists likewise are not learned spells.
- Captures separate client data, world observation, tameability, and hunter
  ability acquisition. The last two stay unknown until the saved evidence is
  reviewed; no catalog facts are automatically published.

Manual commands: `/fp ps families`, `/fp ps discover [label]`, and
`/fp ps discoveryspell <spellID>`. The last queries one supplied ID; there is no
brute-force spell or creature scan.

Curated catalog fields still include full creature coverage, spawn ranges and
coordinates, availability conditions, tame restrictions, skin variants, ability
rank source beasts, and acquisition requirements. Beastmaster Forever and
Petopia are candidate references; retain source URL, observation date, client
build where known, and confidence separately from runtime evidence. No website
dataset is imported by this milestone.

### Live discovery: 2026-10-16, build 1.60.1.70425

The revision 1 `discover` run completed in host run 91, ending 14:49:27:
five done, one skipped (optional Beast Lore), and one No (visible ability or
tameability information). Captures 1–3 and screenshot
`WoWScrnShot_101626_144925.jpg` were inspected. The screenshot shows the target
in the world but no expanded creature tooltip.

- Ornery Galestrider: creatureID 251707 from both UnitCreatureID and
  C_CreatureInfo.GetCreatureID; level 9; Tallstrider family ID 12; Beast type
  ID 1; normal classification, alive, not player-controlled. The target GUID
  stayed consistent across both captures. This supplies a Forever creature
  world observation, not proof of tameability or an ability source.
- Observer context: Zephras Isle (UI map 2521), Gustberry Lowlands. Player
  UnitPosition returned approximately 2343.90, 968.40, 0 on world map 2991.
  Target UnitPosition returned nil x/y/z and map 2991. No creature coordinate
  or spawn location was established; the observer's coordinates are not a substitute.
- Family enumeration returned 27 IDs, including Fox (319) and Core Hound (312),
  but also demon families and Remote Control (28). It cannot directly populate
  a hunter-tameable family list.
- Both tooltip responses failed whole-table copying with reason `a function`.
  This is a probe serialization limitation, not evidence that the tooltip API
  is absent. A follow-up fix retains selected readable line fields while keeping
  the raw-copy failure explicit; live validation passed in the follow-up below.
- Hidden PlayerModel SetUnit(target) returned false, GetDisplayInfo returned 0,
  and GetModelFileID returned nil in both captures. This exact appearance query
  path did not establish an appearance ID. It does not invalidate issue #4's
  successful rendering from known stable display IDs.
- No active cast, channel, or aura was returned at either capture. Beast Lore
  was skipped, so these are not before/after measurements of that spell's effect.
  Taming and hunter ability acquisition remain pending.

The tooltip fix copies at most 100 lines and only type, leftText, rightText, id,
and spellID, with field-level errors and truncation recorded. It also copies
query arguments before saving so model widget references are never retained.

Tooltip follow-up on the same build: capture 6 (`tooltip-check`, host run 94)
targeted Ornery Galestrider 251707, level 9. Whole-table copying still correctly
reported `a function`, while the selected-field fallback saved three lines:
`Ornery Galestrider`, `Level 9`, and `Beast`. No field errors or truncation were
reported. This validates ordinary tooltip text capture. These lines contain no
tameability or ability information; Beast Lore output and successful taming
evidence remain separate, unverified experiments. No repeat of this text check
is needed. An earlier follow-up (capture 4) had no qualifying creature target.

## Issue #4: portraits, exact appearances, and stable identity

Implemented: three-view comparison (live pet, saved 2D portrait, saved fitted 3D
model), build-stamped stable captures, bounded model-load observations, and guided
screenshots. Live Cat and Bear runs passed on build 70425 (results below).
Other skins and body shapes still need live coverage; stub tests alone do not
establish texture correctness or stable availability on a client build.

### Live result: 2026-10-16, build 1.60.1.70425

The `models` revision 1 procedure completed all 11 steps in host runs 85–86,
14:23:53–14:24:58 local time: four Yes answers and seven completed actions.
SavedVariables and all four recorded screenshots were inspected.

- Cat: creatureID 3035, displayID 1059, petNumber 3870381. The saved portrait
  and custom ModelScene showed the same orange/white appearance as the live pet;
  the 3D view included the whole body in the observed poses.
- Dismissal blanked the live pane while preserving the portrait and 3D view.
  Both saved views also restored after reload with no summoned pet.
- All three renders returned modelFileID 126171 and six numeric bounding-box
  values, fitting at scale approximately 1.37170 on the first poll (~0.20 s).
  This confirms the warm-load path, not delayed or failed loading in the client.
- All three captures reported IsAtStableMaster=false. The active and stabled
  lists each returned one entry, and both Cat and Bear records were available
  after dismissal and reload. Bear identity: creatureID 251115, displayID 136606,
  petNumber 3360409; its rendering was not exercised in this run.
- Selection used Call Pet. The Cat GUID tail was `1B0E792B4A`; its low six hex
  digits do not equal petNumber 3870381. The older AltStable suffix observation
  therefore is not a universal identity rule on this build. Never use the
  generic GUID creature field 165189 as the wild creature identity.

Screenshot evidence in the client's Screenshots directory:
`WoWScrnShot_101626_142414.jpg` (live comparison),
`WoWScrnShot_101626_142419.jpg` (whole-body framing),
`WoWScrnShot_101626_142441.jpg` (dismissed), and
`WoWScrnShot_101626_142456.jpg` (after reload).

Remaining live coverage after the Cat run: Bear/other body shapes, multiple skins of one creature,
the explicit stable-open/closed comparison, and missing/delayed model behavior.
The Cat run need not be repeated.

### Live Bear result: 2026-10-16, build 1.60.1.70425

The second `models` revision 1 run completed all 11 steps in host runs 87–88,
14:30:00–14:30:53 local time: four Yes answers and seven completed actions.
SavedVariables and all four screenshots were inspected.

- Tarthosuk (Bear family): creatureID 251115, displayID 136606, petNumber 3360409.
  The purple feathered appearance matched across the live view, saved portrait,
  and saved 3D model. The whole body fit within the 3D pane in the observed poses.
- Dismissal cleared the live pane. The portrait and 3D model remained textured
  after dismissal and restored after reload with no summoned pet.
- All three renders returned modelFileID 7581790 and six numeric bounding-box
  values. Scale was approximately 1.11143, with the first poll succeeding in
  0.201–0.205 s. This adds a different body shape, not a cold-load timing test.
- Call Pet selected the Bear correctly. Compared with the Cat run, the Bear
  moved from slot 2 to slot 1 and the Cat from slot 1 to slot 2; their saved
  petNumber/displayID identities remained distinct across this slot change.
- All three captures reported IsAtStableMaster=false. Screenshots show the
  player near a stable master with its window closed, so this establishes
  closed-window behavior, not physical distance from the NPC for this run.

Screenshot evidence: `WoWScrnShot_101626_143016.jpg` (live comparison),
`WoWScrnShot_101626_143019.jpg` (whole-body framing),
`WoWScrnShot_101626_143036.jpg` (dismissed), and
`WoWScrnShot_101626_143051.jpg` (after reload).

Cat and Bear need no repeat. The stable-open/closed procedure also passed below.
Remaining live coverage includes multiple skins of one creature, flying or other
unusual shapes, and missing/delayed model behavior.

### Live stable comparison: 2026-10-16, build 1.60.1.70425

The `modelstable` revision 1 procedure completed all five steps in host run 89,
14:31:47–14:32:19 local time. Captures 7 and 8 record the open stable window
and the subsequent closed-window/away action respectively.

- IsAtStableMaster changed from true to false. Both captures returned one
  active pet and one stabled pet, with Bear active and Cat stabled.
- GetActivePetList, GetStabledPetList, and GetStablePetInfo for slots 1 and 2
  retained both pets' creatureID, displayID, petNumber, and other recorded
  details. Slots 3–5 returned nil in both states.
- Call Pet selected the same Bear in both captures. Its away render again
  returned modelFileID 7581790, scale approximately 1.11143, on the first poll.
- The retained petAbilities arrays contain many ranks (24 entries for Bear,
  22 for Cat), including ranks beyond these pets' observed learned spellbooks.
  They must not be interpreted as the individual pet's known abilities.

This establishes stable-data availability after closing the window in this
session. It does not establish cache freshness, availability before the first
stable visit on a fresh login, or behavior with a larger roster. The procedure
records API results and manual actions; it does not measure distance from the NPC.
No screenshots are requested by this data-comparison procedure.

Prior evidence is preserved from `../AltStable/docs/forever-api-notes.md` (Pets,
measured build 70124) and `Tools/AltStableProbe/Pets.lua`:

- Stable `displayID` preserves the exact skin; `SetCreature` can choose a different
  skin and is deliberately not used by this viewer.
- A generic hunter pet GUID creature field is not its original wild NPC identity.
  The probe retains the stable's `creatureID` separately.
- The low six hex digits of the GUID tail can match `petNumber`; parsing the full
  tail can overflow on Forever. Call Pet spells provide independent slot evidence.
  Duplicate names are never a fallback. Ambiguous/conflicting matches stay unknown.
- A custom ModelScene actor works around missing preset 718 actors. Forever's
  measured bounding box is six numbers; table vectors are also supported here.

### First in-game check

After deployment, `/reload`, then **`/fp steps ps models`**. Summon an existing
Bear or Cat and stand away from the stable master with its window closed. The
panel guides you through capture, visual comparison, normal dismissal, saved-only
rendering, and reload restoration. It asks specifically about the right-hand 3D
view's whole-body framing; the middle portrait intentionally shows a head view.
The live pane may use a different camera and goes blank after dismissal.

Screenshots are recorded automatically on the visual-answer steps. Wait until
the right-hand preview appears before answering. If uncertain, choose Not sure
and describe the picture in Notes; the saved screenshots allow inspection later.
No pet needs to be abandoned, trained, or purchased. At the last step, click
**Finish measurements** (not Stop), then type `/reload` to save the completed run.

### Stable and appearance coverage

`/fp steps ps modelstable` captures the stable window while open, then after you
close it and walk away with the same pet. The saved results retain the actual
IsAtStableMaster response, list APIs and indexed active slots 1–5; this experiment
does not assume full stable availability away from the NPC.

For a second existing pet, summon it and repeat `models`; saved identity/render
captures accumulate even though the host keeps only the latest run of a named
procedure. To inspect saved pets together, `/fp ps models` opens the viewer;
Previous pet/Next pet select records, and Screenshot uses host screenshot tracking.
Different displays sharing one creature ID remain separate records. When multiple
skins of one creature, flying pets, or unusual shapes become available naturally,
run the same check and note that context. Bear/Cat checks alone do not validate
those shapes. Do not obtain extra pets solely to make these checks pass.

Other controls: `/fp ps modelcapture` captures and selects the summoned pet;
`/fp ps modelslot <slotID>` explicitly selects a captured stable slot if automatic
matching is unknown. `/fp ps display <displayID>` previews a supplied positive ID
without claiming tameability or adding it to the owned-pet list. `/fp ps modelclear`
tests the missing-ID state and must blank the previous portrait and saved model.
The next render clears old content before attempting a new ID; rejected requests
and bounds timeouts are recorded. Unknown positive IDs are not guaranteed to exist.

Model fitting retries every 0.2 seconds for at most four seconds; a selection
change or viewer close cancels the pending work. Successful bounds produce a
scale to fit the model's height and width. Successful API calls do not imply
correct textures, animation extents or framing: those remain visual observations.

Evidence is in `PetStableProbeDB.models`: the last 24 `captures`, exact stable
`records` keyed by petNumber/displayID, persistent selection/comparison keys, and
the last 24 `renders`. Render records retain full client build, request status,
API results, load attempts/time, fitted bounds/scale, and model file ID when read.
The comparison key holds the same saved appearance across dismissal and reload,
even if the active pet changes. No player names or owner GUIDs are collected.
Screenshot filenames and procedure answers are in the host's normal records.

Use `pwsh ../ForeverProbe/Tools/screenshots.ps1 -Module PetStableProbe` to locate
shots after flushing, and its `-Remove` only after documenting findings. The host
and module remain developer-only and are excluded from the player package.

## Issue #3: training and acquisition experiments

The training captures are implemented and tested offline. Live switch, trainer,
and a teaching attempt are recorded below. The teaching action was unavailable
and skipped; successful learning/teaching behavior remains unverified.
Reviewed references: `forever-api-1.60.1.70425.md`, the shared host guide,
`PORTING-TBC-TO-FOREVER.md`, and the sibling client UI source
`Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua`. The UI source uses
`C_Trainer.GetTrainerType`, `GetNumTrainerServices`, `GetTrainerServiceInfo` and
`C_PetInfo.GetPetTrainingPoints`; it does not establish hunter training semantics.

| Capability | Declared/reference shape | Live status for issue #3 |
| --- | --- | --- |
| Pet spell enumeration | `HasPetSpells`: count/token; item info: spellID, actionID, name, subName | Observed on 70425 across two pets; commands without spellID cause the current conservative partial label |
| Rank text | Item name/subName and `C_Spell.GetSpellSubtext` | Spellbook subName and trainer rank text observed in enUS; other locales untested |
| Training points | `C_PetInfo.GetPetTrainingPoints`: total, used | Observed 70/20 on Bear and 0/8 on Cat; retain literal tuple |
| Hunter learned ranks | Player-bank, Pet-bank and legacy `IsSpellKnown` checks | Unknown; a Player-bank boolean alone does not prove teachable knowledge |
| Base/override relationship | `FindBaseSpellByID`, `FindSpellOverrideByID` | Pending; neither defines rank progression |
| Trainer/training list | Trainer type, visible service tuples/links, requirements/costs and filters | 41 services observed with window open on 70425, also after reload; service links all nil |
| Legacy training UI | `GetNumCrafts`, `GetCraftInfo`, `GetCraftTrainingPoints` | Absent from 70425 dump and live captures |
| Change events | UNIT_PET, PET_BAR_UPDATE, SPELLS_CHANGED, LEARNED_SPELL_IN_SKILL_LINE, UNIT_PET_TRAINING_POINTS, TRAINER_SHOW/UPDATE/CLOSED | UNIT_PET, SPELLS_CHANGED, TRAINER_SHOW/UPDATE/CLOSED observed; acquisition events pending |

Deploy the updated module with `pwsh Tools/deploy.ps1 -Probe`, then `/reload`.
Use a hunter and keep the same character throughout each experiment. Start with
`/fp steps ps switch` if two pets are available; no new pet or rank is required.
The other independent procedures are:

- `/fp steps ps trainer`: start with the trainer window closed, then open it and
  capture the list. Buying a skill is optional and is done manually.
- `/fp steps ps teach`: open the pet training UI, capture it, then manually teach
  one eligible rank and capture again.
- `/fp steps ps learn`: capture before and after the game reports learning a new
  pet ability rank. Prepare the pet/ability beforehand; this may need a separate
  gameplay session. Do not abandon an existing pet for the experiment.

Use each panel's Notes for the pet family, selected ability/rank, visible UI and
filters, or why an action was unavailable. Skip unavailable actions and answer No
to the change-confirmation question. A skipped acquisition is not evidence of an
API failure. Each procedure captures again after reload and finishes through its
**Finish measurements** Run button; type `/reload` afterwards to flush results.
The record includes capture IDs, so there are no counts to remember or compare
by eye. Starting another procedure stops the current one; run them individually.

Additional commands:

- `/fp ps capture <label>` saves a snapshot and starts the event watch.
- `/fp ps track <spellID>` includes a known ID in later knowledge checks, even
  when it is no longer on the active pet or trainer list. IDs persist across reload.
- `/fp ps compare` compares the last two captures' raw knowledge/point queries
  and pet spell ID sets. Partial, failed or truncated enumeration suppresses set
  differences. A removed ID is not automatically a lost rank or an upgrade.
- `/fp ps watch on` and `/fp ps watch off` control the event watch. It is off at
  login; captures enable it and finishing a guided experiment disables it. Stop
  it manually if you stop/skip a procedure before its final Run button.

Evidence lives in `PetStableProbeDB.training`: the latest 24 `captures` and 200
`events`. Captures retain all GetBuildInfo returns, locale, class/levels, pet
context, raw plain API tuples with arity, availability/error states, and IDs.
Tracked IDs come from captured pet spells, trainer spell links, or explicit
`track` commands; there is no whole-client spell scan. Queries are bounded to
200 rows per enumerated list, with truncation flagged. Event payloads are copied
through the host's plain-value guard; secret/unpersistable returns are marked
unreadable rather than saved. Clearing the console log does not delete captures.

Until live learning/teaching comparisons establish a reliable enumeration of
hunter-learned ranks, the advisor must use **unknown hunter training knowledge**.
Manual observations in procedure Notes can support individual confirmations but
must retain their character/build/procedure context. Trainer availability and
active-pet spells must not be substituted for hunter-wide learning knowledge.
Once collected, add observed return tuples, event ordering and limitations to the
table above with the client build and procedure/run IDs.

### Initial live pet-switch results (build 1.60.1.70425)

The hunter account's saved `switch` procedure, run 63, contains capture 1
(`switch-before`), captures 2 and 3 (`switch-after`; step repeated), and capture 4
(`switch-reload`). Different
pet GUIDs establish that the pet did change. The tester's first note was Bear,
and the switch note was “i talked to the stable master?”; using the stable master
to exchange pets is a valid way to perform this test. The confirmation answer was
Unsure, so conclusions here use the saved API observations directly.

| Observation | Before switch | After switch |
| --- | --- | --- |
| Spellbook entries, including commands/stances | 14 | 9 |
| Ability spell IDs | Bite 2 (17255), Claw 1 (16827), Great Stamina 2 (4188), Growl 2 (14916), Natural Armor 2 (24549), Slower Attack II (1263113) | Cower 1 (1742) |
| Training point tuple (total, used) | 70, 20 | 0, 8 |
| Pet-bank IsSpellKnown for original six IDs | true | false |
| Pet-bank IsSpellKnown for Cower 1 | Not queried before discovery | true |
| Player-bank IsSpellKnown for captured ability IDs | false | false |
| Trainer service count | 0 | 0 |

This confirms working active-pet spell IDs, names/subtext and Pet-bank checks on
this build. It does not establish the hunter's teachable rank knowledge. The
training point tuple is retained literally: total less than used is observed,
and must not be silently normalized in research data. Legacy GetCraft APIs are
absent in the live captures, matching the reference dump.

All captures were marked `partial` by the current probe because the spellbook
also includes ordinary commands/stances with no spellID (Attack, Follow, Stay,
etc.). Their successful enumeration was mistaken for incomplete ability data.
The raw tuples are intact. Future classification must distinguish those action
rows without treating actionID as a spellID or parsing localized command names.

Subsequent inspection after the tester continued shows capture 4 (`switch-reload`)
with the same level-7 Cat, following the level-14 Bear before the switch. The
procedure reached step 9 and was stopped there. Its saved status is `stopped`,
but the before, after, and after-reload measurements are intact. There is no need
to repeat the switch experiment just to obtain a formal completion marker.
Events recorded in the saved training buffer include UNIT_PET and SPELLS_CHANGED;
these are observations, not proof that every relevant change fires those events.

### Live trainer results: 2026-10-16, build 1.60.1.70425

Evidence: trainer procedure revision 1, captures 5 (`trainer-before`), 6
(`trainer-after`) in run 66, and 7 (`trainer-reload`) in run 67. The record is
stopped at step 9, with all three measurement captures saved. No purchase or
learning event was recorded. The tester answered Unsure and noted “what change?”;
the intended change was opening the dialog, not buying anything. Revision 2
clarifies this question and names the final Finish measurements button directly.

| Observation | Closed window | Open window | Reopened after reload |
| --- | --- | --- | --- |
| Service count | 0 | 41 | 41 |
| Services returned as unavailable | None listed | 41 | 41 |
| Non-nil service links | None listed | 0 | 0 |
| Trainer type returned | 0 | 0 | 0 |
| Available/unavailable/used filters | true/true/false | true/true/false | true/true/false |

The captured context is a level-16 Hunter with a level-7 Cat. The setup note says
“bear”, but both live family/level captures identify the Cat; use the API data
for this context. A trainer type of 0 alone does not establish whether this was
the NPC trainer or the hunter's own teaching UI. The note says pet trainer dialog.

GetTrainerServiceInfo returned six values: name, availability, icon, required
level, localized rank subtext, and category text. For example, Great Stamina
Rank 3 returned required level 18 and cost 400; its prerequisite text was Great
Stamina (Rank 2) with a true satisfaction flag. Rank 4 required level 24 and its
Rank 3 prerequisite was false. Costs are raw API values; currency/point semantics
must be interpreted in the correct trainer context.

This establishes a usable source of trainer requirements for the guide. It does
not enumerate all learned hunter ranks: the used filter was off, service links
did not expose spell IDs, and only this trainer context was measured. Prerequisite
flags may help identify known ranks, but their hunter-versus-pet semantics still
need a controlled teaching/acquisition experiment. Do not convert these observations
into a complete known/unknown rank list or match localized names as stable IDs.

The retained event buffer includes TRAINER_SHOW, TRAINER_UPDATE and TRAINER_CLOSED.
No successful acquisition or teaching change was observed in this trainer run.

### Teaching attempt: 2026-10-16, build 1.60.1.70425

Evidence: captures 8 (`teach-before`) and 9 (`teach-after`) in run 69, and capture
10 (`teach-reload`) in run 70. The procedure reached step 9 and was stopped;
the manual teaching action at step 3 was explicitly skipped. Step 5 was answered
Unsure with the note “what change?”. No teaching operation needs to be inferred
from that answer: it was unavailable and skipped, matching the tester's report.

All three captures show the same level-16 Hunter, level-7 Cat, Cower Rank 1
(1742), training point tuple 0/8, and 41 unavailable trainer services with no
service links. There is no observed ability or point change. The identical
trainer data does not establish that the hunter's own teaching interface was
opened; do not treat this as a controlled test of that interface's semantics.

The saved before/after/reload evidence is sufficient to document an unavailable
experiment. No rerun or new rank acquisition is required merely to finish this
procedure. Leave hunter learned-rank enumeration and successful teaching/learning
pending until an opportunity occurs during normal gameplay; meanwhile represent
hunter training knowledge as unknown. Pet appearance work in issue #4 can proceed
independently using the existing pets.

## Live smoke check: 2026-10-15

- Client: 1.60.1.70425 (build date Oct 14 2026), Interface 16001, project 18,
  locale enUS. This is newer than the 70374 API reference used during planning.
- Module procedure revision 1, identity `1:9:8a9090b4`; deployed host c8a1c48.
- Evidence: PetStableProbeDB.log and the host's `PetStableProbe/check` record,
  runs 20 through 22. State measurements returned module load counts **2, 3, 4**.
- Quiet logging: step 2 answered Yes.
- Reload: procedure resumed, and module loads increased from 2 to 3.
- Exit/relaunch step: procedure resumed, and module loads increased from 3 to 4;
  step 8 answered Yes. The host cannot distinguish a reload from a full process
  restart, so the persistence conclusion depends on following the full-exit step.
- Subsequent disk inspection: the procedure resumed at step 9 in runs 23 and 24,
  then logged `STOPPED at 9/9: stopped from the panel` in run 24. The saved status
  is `stopped`, not `done`. Steps 1 through 8 and their measurements remain intact.
  Step 9 only instructs the tester to finish and save; no measurement was lost.
  No rerun is needed to recover the measured counts. Formal Finish behavior was
  not exercised in this run; do not describe the procedure itself as completed.

The count to compare is the **`module loads N`** line from `/fp ps state`, also
recorded as the result of each Record state step. It counts PetStableProbe loads.
The `#20`, `#21`, `#22` prefixes are the host's session numbers, and `4/9` is a
procedure step number; neither is the module load count. The saved evidence lets
us compare the counts without requiring the tester to remember them.

## Development workflow

Read `../ForeverProbe/docs/GUIDE.md` and `../References/PROBES.md` before changing
the probe. It lives in `Tools/PetStableProbe`; never modify the sibling host here.
Diagnostics use the shared console and saved log. No character-specific facts
are registered in the account-wide facts cache.

```powershell
pwsh tests/run.ps1
pwsh Tools/deploy.ps1 -Probe
# Optional custom location:
pwsh Tools/deploy.ps1 -Probe -AddOnsPath 'D:\WoW\Interface\AddOns'
```

Deployment validates the module, deploys ForeverProbe first, and copies the
probe only after the host succeeds. `FOREVERPROBE` overrides the sibling checkout.
Deployment without `-Probe` refuses to copy anything. No live deployment is done
by the test runner. Both the host and module are developer-only; neither is a
player addon dependency or release external. `.pkgmeta` excludes `Tools`.

In game, enable the host and probe, `/reload`, then use `/fp steps ps check`.
The guided procedure records state, checks quiet logging, resumes through a
reload, and asks for a full exit/relaunch to check persistence. `/reload` alone
does not prove process-independent persistence. Finish and reload to flush results.

Commands: `/fp ps state` records all GetBuildInfo returns, locale, project, and
module load count. `/fp ps clear` clears only the module log, preserving its
bound table. `/fp mirror off` keeps diagnostics out of chat.

Read `PetStableProbe.lua` and `ForeverProbe.lua` in the client's account
SavedVariables directory after flushing. The structured procedure record is
`ForeverProbeDB.steps.records["PetStableProbe/check"]`; the host baseline carries
the build and run. Use the step Note box for unexpected behavior.

For future visual experiments use the host's Shot button or `Probe:Screenshot`.
Locate images with `pwsh ../ForeverProbe/Tools/screenshots.ps1 -Module PetStableProbe`.
After recording findings, that tool's `-Remove` removes only recorded probe shots.

## Findings template

For each completed experiment record: client version/build, date, module revision,
procedure/run, preconditions, observed return shapes/events, PASS/FAIL observations,
saved evidence/screenshot references, and remaining unknowns. Keep API declarations
and observations from older builds explicitly distinguished from new measurements.

## Tests

The integration test loads the actual sibling host in TOC order using its single
strict WoW stub environment. It checks delayed SavedVariables binding, quiet
dispatch, log clearing, missing APIs, and guided result recording. No second stub
environment is loaded. CI has no access to the private host and explicitly sets
`FOREVERPROBE_OPTIONAL=1`; only host-dependent tests skip when it is absent.
Locally a missing host is an error. Run local tests before every probe PR.

## Model binding variants (pending, issue: sighting capture review)

The first discovery capture saw a hidden `PlayerModel:SetUnit("target")` return
false with no display or model file ID on build 1.60.1.70425. Sighting capture
binds the same way (hidden model, `blend=false`), and neither the argument nor
build 70450 has been measured. `/fp steps ps bind` targets a wild beast and, for
two seconds, tries hidden and shown models with `SetUnit(unit)`,
`SetUnit(unit, false)` and `SetUnit(unit, true)`. It records each call's return,
and the first time display and model file ID both resolve, then repeats on
mouseover. Results are in `PetStableProbeDB.binding.runs` and the module log.
Until it is run, sighting capture is unverified on 70450.
