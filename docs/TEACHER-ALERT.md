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
  finishes, and no cooldown is spent meanwhile. Every unit seen while a scan is pending is kept, so a burst
  of nameplates loses none; one notice shows at a time, and the rest wait and are looked at again, one by one, when that notice is dismissed or expires.
- The client is English. Catalog ability names are English, so on other locales the alert stays
  quiet rather than misreport a rank.
- The ability is not a trainer ability, fits the active pet's family, is not ignored, and the listed
  rank is exactly the next one after the pet's current rank, at or below the pet's level.

The text says what the creature is *listed* as teaching and what the pet has now, and notes that
this is reference data. It never says the hunter has or lacks a rank: that is not tracked.

## Controls

- **Target <name>** (#39) targets the beast in one click: `/cleartarget`, `/targetexact <name>`,
  `/cleartarget [dead]`, the macro Stakeout ships on Forever. It is offered only with the name read from
  the unit itself, checked as Stakeout does (plain, at most 100 bytes, no control character). The
  player clicks; nothing targets automatically. With several beasts of the same name it targets one of
  them, and with only corpses it clears the target.
  - **A separate secure frame** (`TargetButton.lua`), parented and anchored to `UIParent` only. It sits
    over a fixed band under the notice's title. The notice never parents or anchors it, so the notice
    itself stays unprotected: it shows, is replaced and hides at any time, including in combat.
  - **The notice is no longer clamped to the screen.** Its top and width never move and its height is
    capped at 300, so the band and the button always line up.
  - **Only out of combat:** PetStable arms, moves or hides the button only out of combat. At combat end
    it applies the notice that is up then, unconditionally.
  - **A one-way combat latch:** a secure state driver clears the button's action and hides it when
    combat starts, on the secure manager's next update, and does nothing when combat ends. So there is
    no targeting from the notice during combat, and a button whose notice has gone never comes back by
    itself. In the brief window before that update, the button still targets the beast it was armed for.
  - **A notice that appears in combat** says "Target button after combat", and the button comes at
    combat end if the notice is still up.
  - The design was reviewed with Codex to consensus. It is on issue #39.
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
list, the toast buttons, showing and hiding in combat, a nameplate burst and class gating.
`tests/test_targetbutton.lua` models the secure rules: insecure combat calls are errors, and the
state driver runs the button's real latch snippet on a separate update. It covers the structure,
the latch, the combat-end re-arm in either order, A→B through the queue, expiry, unsafe names,
long text under the height cap, a client without the state driver, and initialising under
lockdown. Eleven deliberate mutations (latch removed, notice clamped, the button anchored to the
notice, one click edge, a cached re-arm, and others) each turn it red.
In game: `/fp steps ps target` (PetStableProbe) walks through the combat transitions and records the
button and the notice at each step. Not yet run in the live client
(unavailable before November 4). To check there: the three unit signals, `UnitCreatureID` for
wild units, and how the toast looks.
