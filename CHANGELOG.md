# s2k:Enhancements 1.19.0

- Fixed custom castbar spell names disappearing after an enemy's first cast.
- Added configurable frame strata for general and target healthbars; connected castbars, overlays, buffs and debuffs inherit their healthbar's strata, while overlay frame levels remain independently configurable.
- Improved custom nameplate layering so unrelated WeakAuras groups respect the configured nameplate strata.
- Unified general and target healthbar dimensions and added configurable Blizzard nameplate hitbox width, height and healthbar position within the hitbox.
- Added a movable, animated two-nameplate layout preview showing general and target healthbars, hitboxes, borders, castbars, overlays, buffs and debuffs.
- Added font, size, outline and color controls for castbar spell names.
- Consolidated Blizzard nameplate controls into a single General section.
- Added maximum camera-distance and SpellQueueWindow controls, including world-latency detection and a recommended SpellQueueWindow starting value.
- Added optional automatic quest acceptance, automatic completion without automatic reward selection, quest-level labels, quest-objective tooltip progress and automatic handling of shared-quest requests.
- Added optional quest currency reward display for every currency reported by the Legion quest API, including Garrison and Order Resources, with dynamically sized quest reward content.
- Removed the Blizzard Interface Options registration that could taint Compact Raid Frame profile handling; the standalone LDB, minimap and slash-command configuration entry points remain available.

# s2k:Enhancements 1.18.18-healthbar-color-layout

- Moved the reaction-color controls next to and before their corresponding custom healthbar color pickers in both general and target sections.

# s2k:Enhancements 1.18.17-separate-target-healthbar

- Added an optional complete target-only healthbar style with independent size, offset, texture, color, reaction color, backdrop and border settings.
- Reorganized the Healthbar page into General healthbar and Target healthbar sections.
- Migrates the previous separate-target-border configuration into the complete target style while copying existing general bar values for compatibility.

# s2k:Enhancements 1.18.16-bar-backdrop-colors

- Added independent color and opacity pickers for the healthbar and castbar backdrop textures.
- Backdrop colors are always custom and do not use unit reaction colors.

# s2k:Enhancements 1.18.15-bar-backdrop-textures

- Added previewed LibSharedMedia texture selectors for the healthbar and castbar backdrops.
- Existing profiles retain their flat, solid backdrop through compatible defaults.

# s2k:Enhancements 1.18.14-nameplate-border-recycle-fix

- Fixed malformed target borders after a nameplate left the screen and later returned.
- Rebuilds backdrop edge geometry after recycled nameplates become visible and after Blizzard's delayed nameplate scale transition settles.

# s2k:Enhancements 1.18.13-hp-ratio-accuracy

- Fixed the nameplate HP ratio overlay rounding every result upward to the next whole number.
- HP ratios now use normal rounding with one decimal of precision, while redundant trailing .0 values remain hidden.

# s2k:Enhancements 1.18.12-media-previews-borders

- Added in-list texture previews with overlaid names to the healthbar, castbar and spark texture selectors.
- Added a previewed border-media selector containing compatible Blizzard borders and every border registered through LibSharedMedia.
- Replaced fixed 1/2/3 px border styles with per-border Size, Inset and Offset controls for normal, target and castbar borders.
- Preserved the legacy solid border renderer and automatically migrated existing None/Thin/Thick/Heavy profile settings.
- Refreshes media lists when late-loading SharedMedia provider addons become available.

# s2k:Enhancements 1.18.11-options-layout-slider-inputs

- Added a checkbox-width inner margin between section borders and their content on both sides.
- Combined Language with Minimap under General and combined spell activation overlays with quest reputation rewards under Blizzard Tweaks.
- Consolidated the Profiles page into one more compact section and fixed its left-overflowing status labels.
- Left-aligned long slider titles, including Player cast overlay frame level, so they no longer overflow the section border.
- Added a validated numeric input beside every slider, including type, min/max and step validation with invalid input rollback.

# s2k:Enhancements 1.18.10-compact-section-groups

- Restyled configuration section groups to match the compact framed layout used by classic Legion addons.
- Moved smaller cyan section titles above the borders, increased background opacity and reduced excess vertical and horizontal spacing.

# s2k:Enhancements 1.18.9-section-groups-chat-localization

- Added bordered, subtly shaded group panels around every configuration section so settings inside modules remain visually distinct.
- Added automatic English and Hungarian localization support with a language selector under General.
- Added a configurable Chat module with Alt-click invites, chat-copy support, edit-box layout and appearance controls, font settings, side-button controls and optional Quick Join / Chat Menu LDB launchers.
- Localized the standalone configuration navigation, common controls, descriptions and addon metadata.
- Kept the addon-window header version display numeric-only.

# s2k:Enhancements 1.18.8-dominos-frame-strata

- Moved the Dominos Anchored column before the action-bar names.
- Added a persistent Frame Strata dropdown for every detected Dominos action bar.
- Reapplies configured action-bar strata if Dominos overwrites them and defers those changes during combat.

# s2k:Enhancements 1.18.7-interface-open-button

- Changed the LDB and minimap launcher icon to Ability_Racial_BearForm.
- Added a minimal Blizzard Interface > AddOns entry containing only one button that opens the standalone settings window.

# s2k:Enhancements 1.18.6-ldb-dominos-click

- Fixed Dominos/Editable right-click toggling from LDB display addons that pass the mouse button as the first OnClick argument.
- The launcher now reports why Dominos layout switching is unavailable instead of silently doing nothing.

# s2k:Enhancements 1.18.5-wa-bridge-anchor

- Promoted the WeakAuras bridge anchor path to the only target nameplate anchor implementation.
- Removed the legacy absolute WeakAuras anchor engine, the anchor-engine selector and the per-frame Smooth WeakAuras follow option.
- Kept the movable WeakAuras anchor stats panel for bridge anchor timing and relink/fallback diagnostics.
# s2k:Enhancements 1.18.4-wa-anchor-bridge

- Added an experimental WeakAuras bridge anchor engine that attaches addon-owned UIParent anchors to the custom s2k target health/cast frames using SetPoint-only anchoring.
- Kept the existing safe absolute WeakAuras anchor engine as the default and added an Addons > WeakAuras selector for switching between engines.
- Added a Debug option and `/s2ke wastats` commands for a movable WeakAuras anchor stats panel showing update cadence, CPU timing, relinks and fallback counts.
# s2k:Enhancements 1.18.3-weakauras-group-settings

- Fixed s2k_NP_BT and s2k_NP_BB WeakAuras progress groups being repaired after changing their Group tab layout/style settings.
- Preserved existing progress-group Space, Grow, Align, Sort, animation, stagger, background and anchor-point settings across reloads.
- The WeakAuras scaffold repair still keeps the fixed s2k_NP group structure compatible with WeakAuras 2.5.12 on Interface 70300.

# s2k:Enhancements 1.18.2-spell-overlay-fix

- Fixed Show spell activation overlays not staying unchecked on affected 7.3.5 clients.
- The selected value is now saved globally in s2k_EnhancementsDB instead of relying only on the client CVar to persist it.
- Reapplies displaySpellActivationOverlays during addon load, login and world entry, with two short delayed retries after a manual change.
- Added robust boolean CVar parsing and SetCVar, C_CVar and console fallbacks for private-server client variants.
- Disabling the option immediately hides any spell activation overlay that is already visible.
- Synchronizes the Blizzard combat-options checkbox when that panel is loaded, preventing it from restoring a stale value later.

# s2k:Enhancements 1.18.1-launcher-hotfix

- Restored the shared LDB/minimap launcher click handler accidentally omitted during the 1.18.0 refactor.
- Restored the launcher tooltip handler, including Dominos/Editable right-click status.
- Left-click once again opens or closes the standalone configuration window; right-click toggles the Dominos layout when available.
- Broker initialization is retried during ADDON_LOADED and PLAYER_LOGIN and is only marked complete after the LDB object was created successfully.

# s2k:Enhancements 1.18.0-code-optimization

- Audited all addon-owned Lua modules and removed obsolete compatibility stubs, dead helpers and stale generated-file headers.
- Split generic frame/CVar/media helpers out of feature modules and moved configuration widget helpers into the options module.
- Added cached runtime feature flags so event and OnUpdate paths no longer repeatedly resolve module state.
- Reworked cast updates to track only currently casting nameplates instead of scanning every visible nameplate; target casts are no longer updated by two independent runtime loops.
- Added numeric state caches for castbar colors/text/icons, player-cast overlays, sparks and HP-threshold marker layout/color to avoid repeated string allocations and identical frame writes.
- Coalesced nameplate-scale stabilization timers during bursty nameplate/target events.
- Rebuilt font and status-bar media registries once per refresh cycle instead of once per delayed retry, and centralized configured media-path handling.
- Cached Dominos action-bar counts, made legacy field cleanup one-time, removed obsolete Dominos UI APIs and reduced repeated settings normalization.
- Consolidated duplicated launcher click/tooltip code shared by the LDB object and minimap icon.
- Consolidated nameplate context cleanup for frame recycling and removal, including active-cast cache cleanup.
- Reduced duplicate startup work by separating PLAYER_LOGIN initialization from PLAYER_ENTERING_WORLD world refreshes.
- Preserved the existing SavedVariables/profile format and all public compatibility aliases.

# s2k:Enhancements 1.17.4-compact-options

- Removed the redundant Custom Nameplates heading and master-switch explanation from Nameplates > General.
- Removed the repeated Addon integrations heading and introduction from integration pages.
- Replaced the addon-detection paragraph with a compact four-row status list; the block gains its own scrollbar only when more than four integrations are listed.
- Moved Quest reputation rewards into General > General below Spell activation overlays and removed the standalone Quests navigation button.
- Made the left main-navigation area independently scrollable when future categories exceed the available window height.
- Preserved responsive tab wrapping and the existing resizable configuration window.

# s2k:Enhancements 1.17.3-dominos-screen-wrap

- Added screen-aware wrapping for selected Dominos action bars in Editable mode.
- Side by side alignment creates additional rows when the complete sequence would cross the screen edge.
- One below another alignment creates additional columns when the complete sequence would cross the screen edge.
- Wrapped horizontal layouts start at the left screen edge; wrapped vertical layouts start at the top screen edge.
- Row and column breaks preserve numeric action-bar order and account for each bar's actual scaled dimensions.
- The layout keeps the first selected bar at its original Dominos position whenever the complete unwrapped sequence fits on screen.
- Added a best-effort warning for physically impossible layouts where an individual bar or the complete wrapped group is larger than the available screen area.

# s2k:Enhancements 1.17.2-dominos-launcher-toggle

- Renamed the user-facing Locked layout state to Dominos.
- Added right-click Dominos/Editable switching to both the LibDataBroker launcher and the minimap icon.
- The launcher tooltip now shows the active Dominos layout and the right-click target when Dominos is compatible, the integration is enabled and at least one action bar is Anchored.
- Added `/s2ke dominos` as a no-argument layout toggle command.
- Removed the long action-bar-count information paragraph from the Dominos panel.

# s2k:Enhancements 1.17.1-dominos-workflow-fix

- Corrected the Dominos state semantics: Editable now creates the temporary editing layout, while Locked restores the normal Dominos layout and Show States.
- Removed the per-bar Show States input fields and the Anchor Parent column.
- Show States are now captured directly from Dominos when Editable mode starts and restored when Locked mode is selected.
- The lowest-numbered checked bar keeps its Dominos position; the remaining checked bars are arranged after it side by side or one below another.
- The action-bar list now uses the bar count reported by Dominos instead of a fixed ten-row list.
- Added persistent edit-session recovery so `/reload`, addon disable and profile changes can safely restore the captured Dominos state.
- Migrates and restores the original 1.17.0 base snapshots to undo layouts created by the inverted implementation.

# s2k:Enhancements 1.17.0-dominos-integration

- Added a native WoW 7.3.5 Dominos integration under Addons > Dominos.
- Added per-action-bar Anchored, Show States and exclusive Anchor Parent controls for Action Bars 1-10.
- Added Locked mode: selected bars are stacked exactly on the anchor-parent bar and stored macro-style Show States are injected into Dominos.
- Added Editable mode: selected bars are arranged side by side or one below another and their Dominos Show States are temporarily cleared without deleting the saved s2k values.
- Switching back to Locked mode restores the saved Show States.
- Dominos changes are deferred during combat and applied automatically after combat ends.
- Added original-layout snapshots so disabling the integration restores the Dominos base layout and original Show States.
- Added a responsive action-bar editor suitable for the resizable standalone configuration window.

# s2k:Enhancements 1.16.5-spell-activation-overlay

- Added General > General > Show spell activation overlays.
- The checkbox reads and updates the WoW `displaySpellActivationOverlays` CVar directly.
- The change is applied immediately and is independent from addon profiles.

# s2k:Enhancements 1.16.4-minimap-general

- Added a draggable minimap launcher for the existing LibDataBroker object.
- The minimap icon opens/closes the standalone configuration window.
- Minimap visibility and position are saved globally, independently from profiles.
- Renamed the left-side Profiles category to General.
- General now contains General and Profiles subpages.
- Added General > General > Show minimap icon.
- Moved the existing profile manager unchanged to General > Profiles.

## 1.16.3-resize-performance

- Reworked live configuration-window resizing to avoid full option-tree layout on every pixel change.
- Responsive reflow is now coalesced and capped at approximately 25 updates per second while dragging.
- Only the currently visible main panel and subpage are laid out during live resizing.
- Hidden panels are refreshed lazily when opened instead of being recalculated continuously.
- Added width/signature caches so unchanged controls, tab rows and scroll children are not rewritten.
- Font-string/child discovery and anchor capture are cached after the options tree has finished building.
- The final layout is applied immediately when the resize grip is released, and the saved window size behavior is unchanged.

## 1.16.2-responsive-config

- Made the standalone configuration window resizable from a bottom-right resize grip.
- Added persistent window width and height in the account-wide SavedVariables root.
- Kept the left navigation at a fixed width while the right-hand settings area resizes.
- Made all scroll viewports and scroll-child widths follow the available content area.
- Added dynamic wrapping for Nameplates and Addons internal tab buttons.
- Repositions subpages automatically when a tab row wraps or unwraps.
- Added responsive widths and wrapped-text reflow for long descriptions and notes.
- Made the WeakAuras progress-group editor switch between wide and compact row layouts.
- Added minimum and screen-clamped maximum window dimensions for WoW 7.3.5.

## 1.16.1-close-button-fix

- Fixed the standalone configuration window's top-right close button on WoW 7.3.5.
- The draggable title bar no longer overlaps the close button's mouse hit area.
- The close button now has an explicit size, elevated frame level and left-button click registration.

## 1.16.0-ldb-standalone-config

- Added an embedded LibDataBroker-1.1 launcher named `s2k:Enhancements`.
- LDB display addons such as StatBlockCore can open or close the addon's configuration window.
- Added an independent movable configuration window with Profiles, Nameplates, Addons, Quests and Debug navigation.
- Removed all registrations from the Blizzard Interface Options tree.
- `/s2ke` now toggles the configuration window; `/s2ke config`, `/s2ke options` and `/s2ke settings` open it directly.
- Embedded LibStub, CallbackHandler-1.0 and LibDataBroker-1.1, so no external library addon is required.
- Preserved the existing saved-variable schema and profile implementation; no AceDB migration is performed.

## 1.15.5-quest-reputation

- Added a native quest reputation reward display; no external reputation addon is required.
- Shows reputation rewards in quest-giver details, quest-log details and quest-completion panels.
- Displays faction names, base reward and supported known bonuses.
- Added `Quests > Show quest reputation rewards` to the Interface Options panel.
- Handles the load-on-demand `Blizzard_QuestUI` module and avoids duplicate template registration.

# s2k:Enhancements 1.15.4-addon-availability-scale-fix

- A **WeakAuras** és **Dominos** integrációs gomb mindig látható az Addons panelen.
- A nem telepített vagy nem kompatibilis addon gombja elsötétül és nem kattintható.
- Az Addons panel állandó státuszterülete külön kiírja, melyik támogatott addon nem található, és hogy emiatt az integráció ki van kapcsolva.
- Az integrációs panelek előre felépülnek, így egy később betöltött kompatibilis addon gombja ugyanabban a játékmenetben aktiválható.
- Javítva a ritka hiba, amelynél célpontváltáskor a custom target nameplate extrém nagyra skálázódhatott.
- A skálázás most elutasítja a Blizzard target-scale animáció közben jelentkező irreális átmeneti értékeket, megtartja az utolsó stabil skálát, majd rövid késleltetéssel újraellenőrzi azt.

# s2k:Enhancements 1.15.3-overlay-addon-detection

- A Custom Nameplates főkapcsoló alatt kikapcsolt állapotban külön státuszszöveg jelenik meg.
- Kikapcsolt Custom Nameplates mellett a Healthbar, Castbar, Overlays, Buffs és Debuffs fülek elsötétülnek és nem kattinthatók.
- A Castbar főkapcsoló felirata **Show Castbar**.
- Az Overlays panelen minden overlayhez egyetlen főkapcsoló maradt; a korábbi kettős runtime/megjelentetési kapcsolók megszűntek.
- A WeakAuras fül csak kompatibilis, betöltött és működő WeakAuras esetén jelenik meg.
- Detektált Dominos esetén megjelenik egy **Dominos** integrációs fül; funkciót egyelőre nem tartalmaz.
- Ha egyetlen támogatott integráció sem detektálható, az Addons panel kiírja: **No compatible addons were found.**
- Az opciópanel a PLAYER_LOGIN eseménynél épül fel, hogy az addonintegrációk detektálása a normál addonbetöltés után történjen.

# s2k:Enhancements 1.15.2-profiles-reload-ui

- Az addon látható neve az Interface panelen és az addonlistában **s2k:Enhancements**.
- A külön **Profiles** almenü megszűnt; a profilkezelő közvetlenül az addon gyökérpaneljén nyílik meg.
- A Nameplates fülsor legfeljebb öt gombot tesz egy sorba; a **Debuffs** a második sorban, a General alatt jelenik meg.
- A **Custom Nameplates** főkapcsoló módosításakor Reload UI / Cancel párbeszédablak jelenik meg.
- A Cancel visszaállítja a kapcsoló előző értékét; a Reload UI újratölti a kezelőfelületet és érvényesíti a módosítást.

# s2k:Enhancements 1.15.1-menu-fix

- Megszűnt a különálló **General** és **Modules** Interface Options-menüpont.
- A Custom Nameplates főkapcsoló, a Blizzard-vizuálok, a skálázás és az összes nameplate CVar a **Nameplates / General** belső fülre került.
- A **Nameplates** panel belső füleket használ: General, Healthbar, Castbar, Overlays, Buffs és Debuffs.
- Az **Addons** panel belső WeakAuras fület használ, később további addonintegrációs fülekkel bővíthető.
- A Healthbar, Castbar, Overlays, Buffs, Debuffs és WeakAuras panelek többé nem kerülnek hibás harmadik szintű Interface Options-kategóriaként regisztrálásra.
- A bal oldali s2k:Enhancements fa most kizárólag ezt tartalmazza: Nameplates, Addons, Profiles, Debug.
- A módosítás nem változtatja meg a profilok konfigurációs kulcsait vagy a SavedVariables-formátumot.

# s2k:Enhancements 1.15.0-enhancements

- Az addon új neve: **s2k:Enhancements — s2k Enhancements**.
- Az addon mappaneve és TOC-fájlja: `s2k_Enhancements` / `s2k_Enhancements.toc`.
- A Modules panelen a korábbi Healthbar, Castbar, Buff és Debuff runtime kapcsolók helyett egyetlen **Custom Nameplates** főkapcsoló található.
- A Custom Nameplates kikapcsolása leállítja a custom nameplate runtime útvonalait, elrejti a custom frame-eket és visszaállítja az eredeti Blizzard nameplate-elemeket.
- A Target health runtime tick kapcsoló a Healthbar panelre került.
- A Name text, HP ratio, Level overlay, HP threshold marker és Player Cast overlay modulkapcsolók az Overlays panelre kerültek.
- Új **Addons** kategória, benne a WeakAuras integrációval.
- A korábbi `s2k_NameplatesDB` profiljai automatikusan átkerülnek az új `s2k_EnhancementsDB` adatbázisba.
- Új slash parancsok: `/s2ke`, `/s2kemod`, `/s2keprof`; a régiek kompatibilitási aliasként megmaradtak.
