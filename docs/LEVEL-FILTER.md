# Filtering the guide to the hunter's level

By default the Pet Guide and Ability Upgrades show only what a hunter of their current level could
use. Settings has "Filter to your level" (on by default), and `/petstable levelfilter on|off` does
the same. It follows the hunter's level, including a level-up while the window is open.

## What is hidden

- **Creatures** whose lowest listed level is above the hunter's: in All Creatures, in each look's
  creature table and in the gallery (a look with no creature left disappears). A creature with no
  known level is never hidden, since a missing level is not evidence.
- **Ability ranks** whose pet level is above the hunter's, and the teaching creatures above it.
  A pet cannot be above its hunter, so these cannot be used yet.
- The family index is unchanged: all 19 families stay listed.

Levels from a website listing and observed levels are used the same way, only to hide and to order.
Nothing is turned into a verified range.

## What you are told

- The appearance page says how many creatures are above your level and hidden, and
  "Show all associated creatures" brings them back, marked "Above your level".
- All Creatures counts them in its footer; an empty list says every match is above your level.
- The creature table on an appearance page is sorted by level, unknown levels last.

## When it does not apply

Other classes are never filtered, and neither is anything while the client gives no level.

## Validation

`tests/test_levelfilter.lua` covers the helpers, All Creatures, galleries, Ability Upgrades, the
Settings button, the slash command and other classes. Not yet looked at in the live client
(unavailable before November 4).
