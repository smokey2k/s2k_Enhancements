# s2k:Enhancements - Project Context

## Current state

- Current stable version: 1.32.0
- Target client: World of Warcraft 7.3.5
- Interface version: 70300
- Lua compatibility target: Lua 5.1

## Purpose

s2k:Enhancements provides custom nameplates, configurable healthbar and hitbox geometry, castbars, aura and overlay frames, a live layout preview, chat tools, quest workflow and reward enhancements, authoritative Blizzard CVar management, WeakAuras and Dominos integrations, launchers, profiles, diagnostics, and a standalone configuration window.

## Core architecture

- The addon deliberately does not register a Blizzard Interface Options panel, avoiding Compact Raid Frame profile taint on Legion.
- Configuration opens through `/s2ke`, LibDataBroker, or the minimap launcher.
- `s2k_EnhancementsDB` is the authoritative SavedVariables database. Legacy `s2k_NameplatesDB` data remains supported through migration.
- Existing profiles and saved configuration keys must remain backward compatible.
- AceDB is not used; the backward-compatible custom profile database remains authoritative.
- Embedded libraries live under `Libs` and remain compatible with the WoW 7.3.5-era API surface.
- Runtime modules prefer event-driven updates, targeted refreshes, cached Blizzard visual discovery, and combat-safe deferred work.

## Configuration UI

- The standalone UI is built from reusable S2K AceGUI widget types rather than feature-specific frame construction.
- Shared types cover the main frame lifecycle, inline tab groups, checkboxes, color pickers, sliders, text/statusbar/border dropdowns, text-viewer windows, and diagnostic stats panels.
- S2K widget types register against whichever `AceGUI-3.0` library is active, including when another addon such as Mapster loaded AceGUI first.
- `S2KFrame` owns persistent header Close/collapse controls, resizing, movement, collapse state, and pooled lifecycle cleanup.
- Natural-height inline tabs use `S2KInlineTabGroup`, one outer page scrollbar, and the shared AceConfig renderer. Option modules define ordered child groups and do not build tab frames manually.
- Section headings are derived from visible sibling structure: multi-section pages retain headings, while a selected tab or single section does not repeat its own title.
- Ordinary slider, dropdown, checkbox, and color changes update their targeted runtime consumer without rebuilding the complete options panel.

## Nameplates

- Custom Nameplates is the master switch. The configuration pages are General, Healthbar, Castbar, Overlays, Buffs, and Debuffs.
- Design priority is Target, then Focus, then Friendly or Enemy reaction group.
- Target, Focus, Friendly, and Enemy have independent design settings. Player Cast Overlay is available only for Target.
- Friendly and Enemy have independent healthbar size, hitbox size, healthbar offset inside the hitbox, and frame strata. Target and Focus inherit dimensions from the unit's Friendly or Enemy classification.
- Runtime and preview plates share one visual-tree constructor for health, backdrop, border, cast, text, marker, icon, and aura objects.
- Blizzard castbar, UnitFrame, and nameplate visual objects are discovered once per owner and cached instead of repeatedly walking visual trees.
- Managed nameplate CVars are authoritative. Saved values are applied at initialization and profile changes, and later external `CVAR_UPDATE` changes are restored without importing them into the profile.
- Protected Blizzard frames are never modified during combat; required work is deferred until combat ends.

## Nameplate layout preview

- The preview displays Target, Focus, Friendly, and Enemy using the same underlying visual hierarchy as runtime plates.
- It responds immediately to healthbar dimensions, hitbox dimensions, offsets, overlap CVars, design settings, and motion mode without a full AceConfig rebuild.
- Overlapping/default places the synthetic unit anchors together to demonstrate overlap.
- Stacking creates a vertical collision stack using neighboring hitbox heights and `nameplateOverlapV`.
- Spread creates a 2x2 Target/Focus/Friendly/Enemy collision matrix using hitbox sizes, `nameplateOverlapH`, and `nameplateOverlapV`.
- The complete preview layout scales to the available canvas in both dimensions.

## CVar management

- Addon-managed CVars include nameplate visibility/layout settings, camera distance, Spell Queue Window, and spell-activation overlays.
- Saved addon values remain authoritative after initialization. Blizzard or third-party changes are detected through `CVAR_UPDATE` and corrected through targeted enforcement.
- CVar enforcement avoids polling and defers combat-sensitive work.

## Chat tools

- `/clear` and `/cls` clear the selected chat window and are documented by `/s2ke help`.
- Shift-clicking a chat tab opens Chat Copy through the reusable `S2KTextViewerWindow`, including resizing, saved geometry, scrolling, and selection auto-scroll.

## Dominos integration

- Dominos mode restores normal positions, docking, and Show States through the verified `GetShowStates` and `SetShowStates` API.
- Editable mode temporarily stores those values and arranges selected bars horizontally or vertically with screen-aware wrapping.
- Right-clicking the minimap or LDB launcher toggles the mode when requirements are met.

## WeakAuras integration

- Required client: World of Warcraft 7.3.5.
- Minimum supported WeakAuras version: 2.5.12.
- UIParent-based bridge anchors connect supported target-nameplate WeakAuras groups without forcing user layout or style fields.

## Quest tweaks

Optional features include automatic quest acceptance, automatic turn-in without automatic reward selection, quest levels, tooltip objective progress, shared-quest acceptance, reputation rewards, and all currency rewards exposed by the Legion quest API.

## Testing priorities

1. Open, close, collapse, and resize configuration through `/s2ke`, LDB, and minimap launchers.
2. Test every inline-tab page at large and small window sizes with one outer scrollbar.
3. Test empty, single-item, and multi-item variants of every dropdown type and watch for pooled visual leakage.
4. Test Target, Focus, Friendly, and Enemy nameplate creation, recycling, priority changes, casts, auras, borders, strata, and hitbox clicks.
5. Test all three preview motion modes while changing Friendly/Enemy hitboxes and horizontal/vertical overlap values.
6. Test entering and leaving combat with pending CVar, nameplate, media, WeakAuras, and Dominos work.
7. Test profile switching, copying, deletion, and legacy SavedVariables migration.
8. Test Chat Copy resizing, geometry persistence, text selection, and auto-scroll.
9. Test compatible WeakAuras, Dominos, Mapster, and other addons that may provide AceGUI first.

## Packaging

The release archive must contain `s2k_Enhancements` as its top-level directory and include the TOC, Lua modules, locales, documentation, and embedded libraries.

## Release validation

- Parse every Lua file successfully with a Lua 5.1-compatible parser.
- Run `git diff --check`.
- Verify that every file listed by the TOC exists.
- Confirm the TOC, runtime API, changelog, and this document report the same numeric release version.
- Do not include build or release suffixes beside the numeric version in the addon window header.
