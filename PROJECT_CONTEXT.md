# s2k:Enhancements – Project Context

## Current state

Current stable version: 1.19.0
Target client: World of Warcraft 7.3.5
Interface version: 70300

## Purpose

s2k:Enhancements contains custom nameplates, configurable hitboxes and strata, aura and overlay frames, an animated layout preview, quest workflow and reward enhancements, Blizzard camera and SpellQueueWindow tweaks, WeakAuras and Dominos integrations, launchers and a standalone configuration window.

## Important architecture

- No panel is registered with Blizzard Interface Options, avoiding Compact Raid Frame profile taint on Legion.
- Configuration opens through /s2ke, LibDataBroker or the minimap icon.
- SavedVariables are s2k_EnhancementsDB with legacy s2k_NameplatesDB migration support.
- Existing profiles and configuration keys must remain backward compatible.
- Embedded libraries are stored under Libs.
- AceConfig, AceGUI and AceDB are not currently used.

## Nameplates

Custom Nameplates is the master switch. Subpages are General, Healthbar, Castbar, Overlays, Buffs and Debuffs. General and target healthbars share dimensions and hitbox placement. Target appearance can still be overridden. Child visuals inherit healthbar frame strata while overlay frame levels remain independently configurable.

Disabling Custom Nameplates requires UI reload and restores Blizzard visuals. Protected Blizzard frames must never be modified during combat.

## Quest tweaks

Optional features include automatic accept, automatic turn-in without automatic reward choice, quest levels, tooltip objective progress, shared-quest acceptance, reputation rewards and all currency rewards reported by the Legion quest API.

## Dominos integration

Dominos mode restores normal positions, docking and Show States. Editable mode temporarily saves these values and arranges selected bars horizontally or vertically with screen-aware wrapping. Right-clicking the minimap or LDB launcher toggles the mode when requirements are met.

## WeakAuras integration

Required client: WoW 7.3.5. Minimum supported WeakAuras version: 2.5.12. Bridge anchors connect supported target-nameplate WeakAuras groups without forcing user layout and style fields.

## Testing priorities

1. Open and resize configuration with /s2ke, LDB and minimap launchers.
2. Test nameplate creation, recycling, target switching, casting, auras, strata and hitbox clicks.
3. Test general and target layout previews.
4. Test quest detail, log and completion panels with reputation and currency rewards.
5. Test entering and leaving combat, especially Dominos and protected frames.
6. Test profile switching and legacy SavedVariables migration.
7. Test compatible WeakAuras and Dominos installations.

## Packaging

The release ZIP must contain s2k_Enhancements as its top-level directory and include the TOC, Lua modules, locales and embedded libraries.

## Constraints

- Remain compatible with Lua 5.1 and Interface 70300.
- Do not assume Retail APIs.
- Do not change SavedVariables without migration.
- Prefer events over per-frame polling.
- Do not modify protected frames during combat.
