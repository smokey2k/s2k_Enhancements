# s2k:Enhancements – Project Context

## Current state

Current stable version: 1.18.2
Last verified commit: <commit SHA>
Target client: World of Warcraft 7.3.5
Interface version: 70300

## Purpose

s2k:Enhancements is a modular enhancement addon containing:

- custom nameplates
- healthbar and castbar replacement
- aura frames
- overlays
- quest reputation reward display
- WeakAuras integration
- Dominos integration
- LibDataBroker launcher
- minimap launcher
- standalone configuration window

## Important architecture

- The Blizzard Interface Options entry contains only one button that opens the standalone configuration window.
- Configuration opens through:
  - `/s2ke`
  - LibDataBroker launcher
  - minimap icon
- SavedVariables:
  - `s2k_EnhancementsDB`
- Profiles must remain backward compatible.
- Embedded libraries are stored under `Libs/`.

## Nameplates

Custom Nameplates is the master switch.

Submodules:

- General
- Healthbar
- Castbar
- Overlays
- Buffs
- Debuffs

Disabling Custom Nameplates requires UI reload and restores Blizzard visuals.

## Dominos integration

Supported Dominos version: <exact version>

Modes:

### Dominos

Restores normal Dominos positions, docking and Show States.

### Editable

- temporarily saves Dominos positions and Show States
- clears Show States
- arranges selected action bars horizontally or vertically
- wraps bars into additional rows or columns if they do not fit on screen

Right-clicking the minimap or LDB launcher toggles Dominos/Editable mode.

## WeakAuras integration

Describe the supported WeakAuras version and integration behavior here.

## Known issues

- List known bugs here.
- Mention features that were not verified in a real client.
- Mention performance-sensitive code paths.

## Next planned work

1. ...
2. ...
3. ...

## Testing

Tested client:
- WoW 7.3.5 build: ...

Required test addons:
- Dominos version: ...
- WeakAuras version: ...
- StatBlockCore version: ...

Manual test procedure:

1. Delete or back up SavedVariables.
2. Start the game.
3. Test `/s2ke`.
4. Test LDB and minimap launchers.
5. Test nameplate creation and removal.
6. Test entering and leaving combat.
7. Test Dominos mode switching.
8. Test profile switching.

## Packaging

The release ZIP must contain:

s2k_Enhancements/
    s2k_Enhancements.toc
    Core.lua
    Modules/
    Libs/

## Constraints

- Do not break WoW 7.3.5 compatibility.
- Do not use APIs introduced after Legion.
- Do not change SavedVariables without a migration.
- Protected frames must not be modified during combat.