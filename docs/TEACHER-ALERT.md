# Nearby teacher alert

An optional notice when a creature in view is listed as teaching the next rank of a pet ability
that the **active pet** lacks. It is off by default; Settings has "Nearby teacher alerts" and
`/petstable teachers on|off` does the same. `TeacherAlert.lua` holds the logic and `Toast.lua`
the notice.

## When it shows

It looks at the target, the mouseover and new nameplates, and only for creatures the catalog lists
as teachers (an index of creature ID to ability ranks, built once). It shows when all of these hold:

- The hunter is level 10 or more, the creature is not above the hunter's level, and it is a wild
  creature (not a player, pet or other controlled unit, and not dead).
- The active pet's abilities were read by this session's scan and it knows at least one, so a
  temporary quest pet is left alone, and an unreadable spellbook is treated as unknown, never as
  empty. While a scan is pending, or before the first one, the unit is looked at again once it
  finishes, and no cooldown is spent meanwhile.
- The client is English. Catalog ability names are English, so on other locales the alert stays
  quiet rather than misreport a rank.
- The ability is not a trainer ability, fits the active pet's family, is not ignored, and the listed
  rank is exactly the next one after the pet's current rank, at or below the pet's level.

The text says what the creature is *listed* as teaching and what the pet has now, and notes that
this is reference data. It never says the hunter has or lacks a rank: that is not tracked.

## Controls

- **Target** is a secure macro button the player clicks (`/targetexact`); nothing is targeted
  automatically. It is a separate frame, not a child of the notice, so the notice can show and hide
  in combat. The secure button is only moved, shown, hidden or re-aimed out of combat: in combat it
  is made transparent, a plain "Target (after combat)" placeholder holds its slot, and it is hidden
  when combat ends.
- **Snooze 15 min** holds all alerts for fifteen minutes.
- **Snooze while I keep this pet** holds alerts for as long as the same pet stays active, for when
  the hunter needs to stable it before taming another. The pet is identified by its live GUID, never
  saved, so a different pet with the same name and family still ends the hold; time does not. If the
  client gives no GUID there is nothing to hold on and no hold is set.
- **Ignore <ability>** adds it to the ignore list. Cower is ignored by default.
- A creature that alerted stays quiet for fifteen minutes. The cooldown starts only when a notice
  actually appeared.

## What it does not know

The hunter's learned ranks, stabled pets' abilities, and whether a free stable slot exists. It does
not detect that a creature was just tamed (a tamed creature is controlled, so it stops qualifying).

## Validation

`tests/test_teacheralert.lua` covers each condition above, the cooldown, both snoozes, the ignore
list, the toast buttons, the combat case and class gating. Not yet run in the live client
(unavailable before November 4). To check there: the three unit signals, `UnitCreatureID` for
wild units, the secure Target button in and out of combat, and how the toast looks.
