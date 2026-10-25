# My Pets and the observed pet state

`PetState.lua` owns what PetStable has observed about a hunter's pets, so pages read one source
instead of each polling the client. `PetsUI.lua` is the My Pets page. `Util.lua` holds the shared
safe client call (`NS.Call`: tolerates a missing API, an error or a secret value) that
`Sightings.lua` and `PetState.lua` both use.

## What is observed

- **Active pet:** name, level, family (client family ID first, English name as fallback), and the
  abilities in the pet spellbook that have a spell ID, with the rank from the sub-text. Commands
  such as Attack and Follow have no spell ID and are skipped. If no pet is summoned that is
  recorded as a check, not as missing data.
- **Stable:** the pets in `C_StableInfo.GetActivePetList` and `GetStabledPetList` (pet number,
  slot, name, level, family, creature and display IDs). Both lists were readable away from the
  stable master in the 70425 measurements. The two lists are separate sections: one that cannot be
  read keeps its last answer and time, and the page says when only part of the stable could be
  read. An empty answer is stored as a real answer. Stabled pets' families also resolve by the
  client's own localized family names, since the stable entries carry a name but no family ID.
- Everything is stored per character in `PetStableDB.pets`, with the time and build. At most 20
  characters are kept. Non-hunters never scan, register events or store anything.

Scans run on `UNIT_PET`, `PET_BAR_UPDATE`, `SPELLS_CHANGED`, `PET_STABLE_SHOW`, `PET_STABLE_UPDATE`
and `PLAYER_ENTERING_WORLD`, collapsed by a 0.25 s delay. All six are declared in the 70532 API
dump. Subscribers (`PetState.Subscribe`) are told after each scan.

## Freshness

`PetState.State()` is `fresh` once a scan has run this session, `stale` when only an earlier
session's data exists, and `unknown` otherwise. The page says which, with the date for stale data.

## What it does not know

- What the hunter has **learned** (the Player bank `IsSpellKnown` check was false for pet
  abilities in the measurements, and the legacy training window is absent). Nothing is marked
  learned. This is why only the active pet's observed ranks are exposed (`PetState.ActiveRank`).
- Abilities of **stabled** pets: they cannot be read, and the active pet's spellbook is never
  copied onto them.
- A stable **identity** beyond the pet number the stable lists give (the GUID tail is not an
  identifier on this build).

## The page

Active pet with its observed abilities, then the stable (name, level, family, slot). Clicking a
stabled pet opens its family in the Pet Guide. A hunter-only message is shown to other classes.

## In the Pet Guide

- Family cards on the index show "Your pet" for the active pet's family (with "· n in stable"
  when stabled pets share it) and "In stable" or "In stable (n)" otherwise. It is text plus a thin
  accent, never colour alone, and updates when the pets are re-read. Only what this session's latest
  scan read is stated in the present tense. Before the first scan, or when the stabled list could not
  be read, saved stable pets are marked "Was in stable (earlier visit)" with a dimmer accent, and a
  saved active pet is not marked at all.
- On the first open of a session the guide may open on the active pet's family. This needs
  data from a scan this session and a pet that is present, applies only when the saved page is
  the guide, and never replaces restored history. Settings has "Open on your pet's family"
  (on by default).

## Validation

`tests/test_markers.lua` covers the card marks, live updates and the opening rule. `tests/test_petstate.lua` covers the scan, the delay, missing APIs, secrets, freshness, class
gating, subscriptions and saved data. `tests/pets_cases.lua` (run from `tests/test_reference_ui.lua`)
drives the page. Nothing here has run in the live client, which is unavailable before November 4.
To check there: the stable lists on a fresh login before visiting the stable master, that the
event names fire, and `UnitCreatureFamily("pet")` returning the family ID on a Forever build.
