# Boosted Rest Hide

WoW Forever addon for client interface 16001 (1.60.1).

- Hides Boosted Rest (spell 1229451) from Blizzard's default player debuff bar.
- `/rest` prints the remaining minutes, or seconds when less than a minute remains.
- Prints `Boosted Rest: has fallen off!` once when a previously observed debuff disappears.

Enable **Boosted Rest Hide** in the character selection AddOns list. If the game
was already running when the addon was installed, restart it if the addon is not
listed; otherwise `/reload` loads it.

The timer reads the actual player aura each time. No saved timer or configuration
is needed. Logging in or reloading without the debuff does not produce a false
expiration message. Aura updates during loading screens are ignored; the state is
checked again on entering the world.

Only the default player debuff bar is filtered. Replacement bars supplied by
other addons require their own filters. The debuff itself remains active.

Spell reference: https://www.wowhead.com/forever/spell=1229451/boosted-rest

## Verification

Run `luajit tests/test.lua` from this folder for mocked aura/event/display checks.
In game, verify `/rest` with and without the debuff, confirm other debuff tooltips
still match their icons, and check the chat alert when Boosted Rest expires.
