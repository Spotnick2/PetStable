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
- The active pet's abilities were read and it knows at least one, so a temporary quest pet is left
  alone, and an unreadable spellbook is treated as unknown, never as empty.
- The ability is not a trainer ability, fits the active pet's family, is not ignored, and the listed
  rank is exactly the next one after the pet's current rank, at or below the pet's level.

The text says what the creature is *listed* as teaching and what the pet has now, and notes that
this is reference data. It never says the hunter has or lacks a rank: that is not tracked.

## Controls

- **Target** is a secure macro button the player clicks (`/targetexact`); nothing is targeted
  automatically. It is left out during combat.
- **Snooze 15 min** holds all alerts for fifteen minutes.
- **Snooze while I keep this pet** holds alerts for as long as the same pet stays active, for when
  the hunter needs to stable it before taming another. Summoning a different pet ends the hold; time
  does not.
- **Ignore <ability>** adds it to the ignore list. Cower is ignored by default.
- A creature that alerted stays quiet for fifteen minutes.

## What it does not know

The hunter's learned ranks, stabled pets' abilities, and whether a free stable slot exists. It does
not detect that a creature was just tamed (a tamed creature is controlled, so it stops qualifying).

## Validation

`tests/test_teacheralert.lua` covers each condition above, the cooldown, both snoozes, the ignore
list, the toast buttons, the combat case and class gating. Not yet run in the live client
(unavailable before November 4). To check there: the three unit signals, `UnitCreatureID` for
wild units, the secure Target button in and out of combat, and how the toast looks.
