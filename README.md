# Scrapyard Tycoon (ROBLOX)

Scrapyard Tycoon (ROBLOX) is a small Roblox tycoon prototype about building up an old scrapyard one unlock at a time.

The current goal is not to build a giant finished tycoon yet. The goal is to make a tiny playable loop that works, feels readable, and can grow without becoming messy too early.

## Current Gameplay Loop

1. Unlock the Scrapyard.
2. Buy Broken Cars with Parts.
3. Broken Cars generate StoredParts over time.
4. Walk onto the CollectPad to collect StoredParts.
5. Use Parts to unlock more scrapyard objects.
6. Continue expanding the small scrapyard area.

## Current Features

* Physical collision/touch-based build buttons
* Scrapyard unlock flow
* Broken Car unlock progression
* Shared StoredParts collection system
* CollectPad that transfers StoredParts into visible Parts
* World-space StoredParts sign
* World-space build button signs
* Button signs that use clean player-facing display names
* Whole-number Parts display
* Live parts/sec display in the top-left UI
* Workbench unlock with x1.5 Parts income boost
* Scrapyard expansion unlock after Broken Car 3
* ScrapyardSlab_02 reveal when Expand Scrapyard is purchased
* Parts as the only visible leaderstat
* Hidden internal ScrapyardLevel value for progression logic

## Current Objects

* Scrapyard
* Broken Cars
* Workbench
* Parts Collector
* CollectPad
* Build buttons
* Button signs

## Design Direction

This project is being built prototype-first.

The focus is:

* Make the first interaction work
* Make the loop readable
* Make each unlock feel clear
* Keep systems small and expandable
* Avoid adding large mechanics before the core loop is proven

The project currently avoids large systems such as saving, vehicles, shops, claim pads, premium systems, managers, and advanced automation until the basic loop feels good.

## Future Ideas

Possible future additions:

* More scrapyard unlocks
* Better visual progression
* Cleaner button art
* Improved button feedback
* Modular placeable tycoon buttons
* More object reveal stages
* Small upgrade choices
* Better collector visuals
* Vehicle-related progression later
* Save data after the early loop is stable

These ideas are not final commitments. They are possible directions once the prototype loop is stronger.

## Development Notes

Roblox Studio is used for world layout, object placement, tags, attributes, and visual setup.

Code changes are handled through the project repository using Rojo-style structure.

Studio is treated as the source of truth for placed objects, button locations, tags, and object attributes such as BuildCost and DisplayName.

Code should support the Studio setup without silently overriding intentional Studio values.

## Design Acknowledgement

This project is inspired by classic Roblox tycoon structure: visible unlock buttons, simple resource collection, and gradual base expansion.

The current design intentionally starts smaller than a full tycoon. It focuses on a scrapyard loop first so the game can grow from a working foundation instead of becoming too large too early.

## Status

Early prototype.

The game is playable for testing the first scrapyard loop, but many systems are still placeholder or incomplete.
