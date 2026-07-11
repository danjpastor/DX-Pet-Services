## 0.5.4 — Pet Tracker Map Visibility Options

- Added **Hide Captured Pet Locations**, enabled by default. Once at least one pet of a species is owned, all Pet Tracker world-map portraits for that species are hidden.
- Added **Only Show Pet Icons While Tracker Is Open**, disabled by default. When enabled, wild-pet portraits are drawn only while the Pet Tracker side tab is the active world-map panel.
- Both settings redraw the world map immediately without requiring `/reload`.
- Collection changes now continue to refresh the map filter through the existing Pet Journal event cache.

## 0.5.3-packed2 — Studio Auto-Publish Workflow Compatibility

- Added the separate DX Pet Services Studio Packed Workflow package for automatic save-to-runtime publishing.
- Studio continues editing a readable master outside the addon; each save can now trigger packing, full round-trip validation, and atomic installation into `Data/DXDenseLocations.lua`.
- The release packager blocks readable dense-location sources, `.bak` files, and developer tools from entering public addon ZIPs.
- Aligned the runtime-reported addon version with the TOC version.
- No Pet Tracker data, coordinate counts, map behavior, or in-game UI behavior changed from `0.5.3-packed1`.

## 0.5.3-packed1 — Packed Dense Location Runtime

- Replaced the readable per-species dense-coordinate table with per-map packed payloads.
- Added delta encoding, variable-length integers, printable encoding, map-specific scrambling, and Adler-32 integrity validation.
- Dense locations now decode only when a map is requested and remain cached for the current game session.
- Preserved all 141 maps, 982 species/map records, and 22,504 coordinate points from the 2026-07-11 source dataset.
- Reduced the shipped dense-location runtime asset from 119,686 bytes to approximately 95,222 bytes.
- Removed the duplicate `DXDenseLocations.lua.bak` file from the public addon package.
- Kept the decoder readable and documented; the packing is copy deterrence rather than cryptographic secrecy.

## 0.5.2-dxclean1

- Removed bundled desktop/developer tooling from the runtime addon package.
- Removed the in-addon developer metadata exporter and associated slash commands.
- Preserved the first-party dense-location database and ATT wild-pet roster used by the runtime addon.
- Preserved all Pet Tracker functionality, map pins, tooltip fixes, Collector Mode, favorites, and Auto Summon.

## 0.5.2-dxdata1 — DX-Owned Dense Location Database
- Rebuilt directly from the confirmed 0.5.2 stable codebase.
- Replaced the previous third-party-derived dense coordinate file with the DX Pet Services-owned `Data/DXDenseLocations.lua` database.
- Renamed the runtime database namespace to `ns.DXDenseLocationDB` and removed external-addon attribution, compatibility labels, notices, and license files.
- Preserved the DX Pet Services Pet Tracker feature, including its map tab, collection panel, objective tracker integration, settings, slash commands, and dense circular wild-pet pins.
- Dense database metadata: 137 maps, 970 species/map records, and 22,342 coordinate points.

## 0.5.2 — Minimap Shape Compatibility Fix
- Restored a narrow availability check for `GetMinimapShape()` after live testing showed that the global is not present on every supported Retail client state.
- Minimap paw positioning now falls back to round-map behavior when the shape API is unavailable.
- Keeps the broader 0.5.1 defensive-API cleanup intact; this guard remains because it now protects a reproduced runtime failure.

## 0.5.1 — Retail API Cleanup + Settings Panel Simplification

- Reduced unnecessary defensive API boilerplate across the core, Pet Journal modules, Pet Tracker, source map pins, and Collector Mode while preserving guards around secret values, protected/restricted UI, optional templates, dynamic native-frame inspection, and reproduced failure boundaries.
- Standard Retail APIs and methods on frames/textures created by DX Pet Services are now called directly instead of being wrapped in repeated function-existence checks.
- Removed compatibility fallbacks that were outside the addon's current Retail support contract.
- Reduced runtime function-existence checks from 301 in 0.5.0 to 143, while leaving the high-risk NPC/nameplate safety module largely untouched for a separate focused pass.
- Merged Minimap Paw Icons into World Map Paw Icons. The single setting now controls static pet-source paws on both the world map and minimap.
- Removed the Zone Pet Tracker Tab option. The Pet Tracker tab is now always available.
- Added a real scroll frame to the addon settings page so controls remain contained at smaller Settings-window heights and future options cannot overflow the panel.
- Removed the retired `minimapIcons` and `petTrackerPanel` SavedVariables keys during the account database migration.
- Updated development notes with the Retail API support contract and rules for when `pcall` or function-existence checks are appropriate.

## 0.5.0 — Stable Pet Tracker + Maintainability Pass
- Promoted the confirmed `0.4.1-exp29` Pet Tracker build to the `0.5.0` release line.
- Preserved all behavior, data, layout, styling, map pins, tracker panel content, Objective Tracker integration, and tab visuals from the confirmed build.
- Removed unused experimental tracker code and stale state that was no longer part of the active runtime path.
- Removed the unloaded `Modules/JournalIDs.lua` file so the package contains only code that is actually shipped.
- Centralized Pet Tracker panel offsets and tab icon color values near the top of `Modules/PetTracker.lua` for easier hand editing.
- Reorganized large modules with concise section headings and removed release-history commentary from active source files.
- Reduced repeated settings refresh code by using named observer and setting lists.
- Moved database validation choices and boolean setting keys into named constants instead of rebuilding temporary tables during initialization.
- Added `DEVELOPING.md` with module ownership, load order, editing notes, layout controls, and a release/test checklist.

## 0.4.1-exp29 — Zone Pet List + Native Ornament + Gold Tab Paw
- Built directly from the user-adjusted exp28 package, preserving its finalized tracker title, content, backdrop position, and height.
- Restored the small centered native decoration on the top edge of the Map Legend-style backdrop while retaining the exp21 filtering that prevents Map Legend content icons from leaking through.
- Added a `Pets in This Area` list directly below the zone progress bar and above `Wild Pet Collection by Expansion`. The list uses the same zone species data as the progress bar, shows pet portraits, quality-colored names, owned counts, collection desaturation, tooltips, and scrolls when a zone has more than four pets.
- Tinted the Pet Tracker side-tab paw icon gold/yellow to match Blizzard's other right-side tab icons.

## 0.4.1-exp28 — Taller Content Area + Lower Box
- Moved the native Pet Tracker content box slightly downward so it sits a few pixels lower under the title.
- Expanded the usable vertical space inside the content area so the tracker layout uses more of the panel height like Blizzard's other right-side tabs.
- Increased the bottom usage of the internal content area while preserving the native textured backdrop, full border, and current title placement.

## 0.4.1-exp27 — Backdrop Moves With Content
- Corrected the previous title/content alignment passes so the native textured backdrop and full border move upward together with the tracker content.
- Shifted the entire native backdrop frame upward by the same accumulated 24 px that the content had been raised in prior builds.
- Restored the content frame's original internal top offset so its current screen position stays unchanged while the native artwork and border catch up to it.
- Preserves exp26's title placement and all exp21+ backdrop filtering fixes.

## 0.4.1-exp26 — Title Divider Final Position
- Moved the centered `Pet Tracker` title back down 9 px from exp25 so it sits on the native divider/title line without clipping into the Map & Quest Log top bar.
- Kept the tracker content at exp25's raised position.
- Preserves the native textured backdrop, full border, and clean filtered Map Legend artwork.

## 0.4.1-exp25 — Divider-Line Title Alignment
- Moved the centered `Pet Tracker` title substantially farther upward so it reaches the native top divider-line position instead of sitting inside the side-panel body.
- Shifted the tracker content upward slightly with it so the page remains visually tight beneath the raised header.
- Preserves exp24's native textured backdrop, full border, and clean filtered Map Legend artwork.

## 0.4.1-exp24 — Further Title Raise
- Moved the centered `Pet Tracker` title farther upward so it reaches the same top divider-line position as the native side-panel titles.
- Shifted the tracker content slightly upward as well so the panel layout follows the header adjustment cleanly.
- Preserves exp23's native textured backdrop, full border, and filtered removal of stray Map Legend content.

## 0.4.1-exp23 — Title Line Alignment
- Moved the `Pet Tracker` header further upward so it aligns with the native title line position used by Blizzard's side panels.
- Shifted the tracker content upward with it so the page sits tighter under the header while remaining inside the bordered content area.
- Preserves exp22's native textured backdrop, full border, and filtered removal of stray Map Legend content.

## 0.4.1-exp22 — Header Position Polish
- Moved the centered `Pet Tracker` header upward to better match the native right-panel title placement used by Blizzard tabs like Map Legend.
- Shifted the tracker content upward with it so the zone title, summary, checkbox, progress bar, and expansion section sit closer to the native title/header spacing.
- Preserves exp21's corrected native textured backdrop, full border, and filtered removal of stray Map Legend content icons.

## 0.4.1-exp21 — Native Backdrop Filter Correction
- Restored the exp19 native backdrop structure, which had the correct textured background, full border, and `Pet Tracker` header above the backdrop.
- Fixed the content leak without stripping the backdrop: small textures are no longer preserved merely because they sit near a panel edge.
- Small native artwork is now kept only when it is a true corner ornament; large background, border, vignette, and edge textures remain intact.
- This removes the stray Map Legend icons while preserving the full native backdrop styling.

## 0.4.1-exp19 — Exact Native Backdrop Restore
- Restored a native-styled Pet Tracker content frame without altering Blizzard's Quests, Events, or Map Legend tabs.
- The Pet Tracker now prefers a dedicated backdrop-only `MapLegendFrameTemplate` instance as its content chrome, with the header text placed above that backdrop like the native Map Legend tab.
- The backdrop frame is inset downward to leave space for the centered `Pet Tracker` heading and to restore the full textured border/background instead of a flat dark panel.
- If the exact native backdrop cannot be created, the addon falls back to cloned native legend artwork, and then to the plain copied background texture.
- Adjusted content anchoring so the zone title, summary, checkbox, progress bar, and expansion list sit inside the bordered content area instead of overlapping the header area.

## 0.4.1-exp18 — Backdrop-Only Clone + Native Header
- Removed the `MapLegendFrameTemplate` backdrop instance entirely; it was creating live legend content underneath the Pet Tracker and causing the stray native icons/labels seen in exp17.
- The Pet Tracker now uses only cloned native backdrop artwork from Blizzard's real Map Legend frame, leaving Quests, Events, and Map Legend content frames untouched.
- Disabled clipping on the Pet Tracker panel so native border and corner artwork can extend to their full size instead of being cut off.
- Added a centered white `Pet Tracker` page title above the bordered content area, matching the `Map Legend` tab structure.
- Moved the zone title and tracker content down into the bordered content area.
- Preserves bundled dense wild-pet locations, left-to-right collection bars, larger pinned tracker names, and objective-tracker integration.

## 0.4.1-exp17 — Exact Native Map Legend Template Backdrop
- Fixed the root cause of the tracker backdrop mismatch: the live quest-log content key is `MapLegend`, not `MapLegendFrame`.
- The Pet Tracker remains a completely separate display-mode panel; Blizzard's Quests, Events, and Map Legend tabs are not repurposed or modified.
- Added a dedicated backdrop-only child created from Blizzard's exact `MapLegendFrameTemplate`, then suppresses only the template's legend-specific text/icons while preserving its native background texture, border slices, corner ornaments, vignette, and chrome.
- The tracker panel is anchored to the exact footprint of Blizzard's native `MapLegend` content frame.
- Falls back to cloning the live native `MapLegend` artwork, then to the prior texture fallback only if the template cannot be created.

## 0.4.1-exp16 — Native Border + Texture Match Pass
- Kept the Pet Tracker as its own separate right-side tab panel while improving the native styling match.
- The Pet Tracker panel now anchors to the same native panel footprint as Blizzard's Map Legend frame when available, so the content area matches the size and border placement of the other right-side panels.
- Improved the native-backdrop clone filter so it preserves both the large background textures and the smaller edge/corner border regions from the native Map Legend panel.
- This specifically targets the missing native border/chrome so the Pet Tracker content area carries the same border and texture treatment as the other windows.

## 0.4.1-exp15 — Native Backdrop Clone, Tabs Left Untouched
- Restored the Pet Tracker page to its own separate right-side panel so Blizzard's Quests, Events, and Map Legend tabs remain completely untouched.
- Replaced the prior host-frame/backdrop hijack with a native-backdrop clone approach: the Pet Tracker panel now clones the large native Map Legend backdrop textures into its own panel so the styling matches the other tabs more closely without altering them.
- The cloned backdrop refreshes when the Pet Tracker panel opens and when the map panel refreshes.
- Falls back to the copied native background texture only if the live backdrop clone cannot be built.

## 0.4.1-exp13 — Exact Native Map-Legend Backdrop
- Replaced the copied/fallback tracker-page background with the actual live Blizzard Map Legend content frame shown behind the Pet Tracker page.
- Suppresses only Map Legend labels and small content icons while preserving the native textured backdrop, vignette, borders, ornamental chrome, and panel shading exactly as Blizzard renders them.
- Restores all native Map Legend regions when leaving the Pet Tracker tab so the normal Map Legend remains unchanged.
- Preserves exp12/exp11 tracker data, progress-bar direction, Objective Tracker text sizing, dense bundled spawn locations, and map-pin behavior.

## 0.4.1-exp12 — Native Tracker Panel Background Fix
- Improved the Pet Tracker world-map side panel background so it now copies the same textured background used by Blizzard's native Map & Quest Log tabs instead of falling back to a flat grey fill.
- The background search now checks multiple native right-panel content frames and refreshes whenever the Pet Tracker page is shown or refreshed.

# Changelog

## 0.4.1-exp11 — Bundled-Only Locations + Tracker UI Polish

- Changed zone and expansion progress ordering so collected quality slices begin on the left and missing slices remain on the right.
- Increased pet-name size slightly in the pinned Objective Tracker list.
- Added the native `QuestLog-main-background` texture behind the Pet Tracker world-map page by copying Blizzard's live quest-content background when available.

## 0.4.1-exp10 — Standalone Dense Wild-Pet Spawn Locations

- Revendreth map 1525 now has 109 bundled spawn coordinates across 5 wild species instead of the 2 sparse ATT fallback icons.
- Preserved the exp9 protected-distance fix: the NPC badge fade updater still makes no active `CheckInteractDistance()` calls.

# DX Pet Services Changelog

## 0.4.1-exp9 — Dense Wild-Pet Spawn Locations + Protected Distance Fix

- ATT coordinates remain the standalone fallback when the external dense location table is unavailable.
- `/dxpets trackerdebug` now reports the renderer, active location data source, and dense-coordinate count.
- Removed all `CheckInteractDistance` calls from NPC badge distance fading. Current clients can block that protected API even through `pcall`; the fade system now relies on the existing map-coordinate and readable unit-distance paths instead.

## 0.4.1-exp8 — Pet Tracker MapCanvas Locations + Pin Style

- Replaced the wild-pet `AcquirePin` data-provider experiment with a fresh direct-canvas renderer that uses DX Pet Services' direct-canvas map architecture: hook `MapCanvasMixin:OnMapChanged`, validate Blizzard pet-map canvases, attach normal buttons to `frame:GetCanvas()`, calculate raw canvas positions from normalized map coordinates, and reapply `GetGlobalPinScale() / GetCanvasScale()` whenever the canvas scale changes.
- Wild-pet locations are now redrawn from the exact same current-map rows used by the right-side tracker list. Eversong Woods map 2395 therefore feeds all 3 listed species and all 7 recorded spawn points into the direct renderer.
- Removed fake roster-strip markers from the world map. Species without precise coordinates remain visible in the tracker list but no longer receive invented map positions.
- Rebuilt wild-pet map markers to use the DX circular species-pin appearance: 16px button, 14px circular portrait, and the 22px `Neutraltrait-border-selected` border atlas.
- Preserved hover collection details and click-to-waypoint behavior.
- Updated `/dxpets trackerdebug` to report `provider=dx-pet-canvas`.

## 0.4.1-exp7 — Native Wild Pet Map Pins

- Replaced the experimental direct-canvas wild-pet renderer with Blizzard's native MapCanvas data-provider pipeline.
- Wild pet spawn markers now use the same proven `AcquirePin` path as DX Pet Services source-location map pins.
- Eversong Woods tracker rows are acquired directly from map 2395, including all 3 species and 7 recorded spawn coordinates.
- Preserved 50%-size circular markers, collection desaturation, quality rings, tooltips, and click-to-waypoint behavior.
- Added internal per-refresh pin statistics for targeted diagnostics without changing the normal UI.

# Changelog

## 0.4.1-exp6 - Direct Map Pet Pins + Correct Panel Background

- Replaced the wild-pet MapCanvas data-provider pin path with direct canvas-attached pet pins implemented with DX Pet Services' direct map rendering approach. The pins are now explicitly redrawn on map changes and repositioned on canvas scale/size changes.
- Uses the exact same active-map species rows as the Pet Tracker panel, eliminating the state where pets can appear in the zone list but no spawn icons are drawn.
- Preserves ATT spawn coordinates, alternate-map coordinate conversion, collection desaturation, quality rings, tooltips, and click-to-waypoint support.
- Keeps the 50%-size pet circles from exp5.
- Restored Blizzard's native black background on the paw side tab.
- Removed the custom black backdrop and dark background texture from the Pet Tracker page itself, leaving the right-side content area transparent to the native Map & Quest Log presentation.
- Preserves the rounded segmented progress bars from exp5.

## 0.4.1-exp5 - Tracker Visual Polish + Eversong Pin Refresh

- Removed the black background plate from the custom paw side tab while preserving Blizzard's hover and selected glows.
- Rebuilt the zone, expansion, and Objective Tracker progress bars with rounded capsule ends; the per-pet and per-quality color slices remain unchanged.
- Reduced wild-pet map circles to roughly 50% of their previous size, including the roster-only badge treatment.
- Fixed map-pin refresh timing on map changes by explicitly refreshing after the map canvas settles and again after a short delay.
- Added an Eversong Woods runtime map-name fallback to the tracker data map and coordinate conversion support for alternate/phased UiMapIDs.
- Waypoints continue to use the original source-map coordinates even when a pin's display position is converted to the active map.

## 0.4.1-exp4 - Native Tracker Panel + Expansion Progress

- Reworked the paw tab into a true Quest Map content mode: selecting it now hides the Quests / Events / Map Legend content and replaces the right-side panel instead of drawing a high-level overlay over it.
- Replaced the per-pet row progress bars with one zone-wide segmented bar. Every wild species in the current area receives one equal slice; missing pets are dark, Poor/Common are grey, Uncommon green, Rare blue, Epic purple, and Legendary orange.
- Added a scrollable **Wild Pet Collection by Expansion** section with collected/total counts and quality-distribution bars. Species are assigned once to the earliest expansion area represented in the tracker database so cross-expansion spawns are not double-counted.
- Added **Show in Objective Tracker** directly to the Pet Tracker map panel and a matching settings option.
- Added current-zone refreshes for map changes, zone changes, pet collection changes, and Objective Tracker layout changes.

## 0.4.1-exp3 — Pet Tracker Side Tab Interaction Fix

- Fixed the paw icon being blank immediately after `/reload` by explicitly initializing the side tab to its inactive state.
- Fixed the tab appearing selected on reload by hiding the selected glow until the tracker is actually open.
- Fixed the paw tab doing nothing when clicked. Blizzard's side tabs are `Frame` objects driven by `OnMouseUp`, not normal `Button` objects driven by `OnClick`; the tracker now uses the native `SetCustomOnMouseUpHandler` path.
- Changed the tracker tab to inherit directly from `LargeSideTabButtonTemplate` so Blizzard's three-tab display-mode array does not unexpectedly manage the custom tab.
- Fixed Quests, Events, and Map Legend clicks so they close the tracker through their actual `OnMouseUp` interaction path.
- Reapplies the correct icon/glow state whenever the side tab is shown.

# DX Pet Services Changelog

## 0.4.1-exp2 — Pet Tracker Side Tab Fix

- Rebuilt the Pet Tracker control as a real fourth `QuestLogTabButtonTemplate` side tab.
- Anchors the paw tab directly below Blizzard's Map Legend tab, so it follows Blizzard's current Map & Quest Log layout.
- Moved the Pet Tracker collection panel into the native QuestMapFrame side panel instead of floating over WorldMapFrame.
- Decoupled tab creation from map-pin data-provider registration, preventing the tab from disappearing when map provider setup is delayed.
- Clicking Blizzard's Quests, Events, or Map Legend tabs now closes the Pet Tracker overlay cleanly.
- `/dxpets tracker` now opens the quest side panel when needed before showing the tracker.

# 0.4.1-exp1 - Pet Tracker Foundation

- Added the first Pet Tracker implementation on top of the confirmed 0.4.0 stable baseline.
- Added a generated ATT 5.2.8 wild-pet zone index covering 144 maps, 634 unique species, and 1,048 species-to-map relationships.
- Added circular species portrait pins to the world map. ATT-confirmed coordinates use real map positions; species without precise ATT coordinates are placed in a compact, explicitly identified zone-roster strip instead of being assigned fake spawn locations.
- Added rarity/collection-aware pin rings, missing-pet desaturation, pet collection tooltips, and click-to-waypoint support for coordinate-backed wild-pet pins.
- Added a paw-print Map & Quest Log side tab and an initial zone collection panel.
- Added per-zone collection progress, uncollected-first sorting, circular pet portraits, collected-copy counts, best-quality coloring, and rarity-colored progress bars.
- Added account-wide settings for Pet Tracker map icons and the Zone Pet Tracker tab/panel.
- Added `/dxpets tracker` as a direct test/toggle command.

# 0.4.0

- Promoted the confirmed 0.3.0-exp26 feature set to the first non-experimental 0.4.x baseline.
- Preserves the working full dungeon/raid pet tooltip index across the bundled ATT-derived instance data.
- Preserves MapNotes and HandyNotes dungeon-icon tooltip augmentation and reinjection.
- Preserves the ATT-derived NPC source database, live vendor/quest learning, world-map and minimap pet-source pins, click-to-waypoint support, boss pet-source paws, dynamic collection counts, and confirmed smooth component-level NPC badge fading.
- Preserves Collector Mode, character-based native favorites, Auto Summon, BreedID-style tooltips, selected-pet quality/breed information, and all existing legacy battle-pet functionality.
- Removes experimental naming from the active release metadata and documentation; historical experimental changelog entries remain for development history.

# 0.3.0-exp26

- Expanded dungeon/raid tooltip name resolution across the full bundled ATT pet-instance index.
- Corrected the core data-key interpretation: `ATTPetWorldDB.instances` is keyed by Encounter Journal instance ID, not UiMapID.
- Removed the incorrect `instance ID -> map conversion -> instance ID` path that caused most dungeon names to fail matching.
- Resolves every bundled instance directly with `EJ_GetInstanceInfo(instanceID)` / `C_EncounterJournal.GetInstanceInfo(instanceID)`, so the alias layer uses localized Blizzard names automatically.
- Keeps explicit `instanceNames` entries only as deterministic fallbacks; Cinderbrew Meadery remains the positive regression test.
- Added debug summary for resolved instance counts and any unresolved instance IDs.
- Preserved the working MapNotes/HandyNotes tooltip reinjection and rebuild-repair logic from exp24-exp25.

# 0.3.0-exp25

- Uses Cinderbrew Meadery as the canonical dungeon-tooltip test case.
- Fixed instance-name indexing for the existing ATT relationship: Cinderbrew Meadery (instance map 1272) -> Goldie Baronbottom (encounter 2589) -> Bop (species 4469).
- Added a tiny explicit instance-name fallback table so known instance-map IDs can match tooltip titles even when C_Map / Encounter Journal conversion is unavailable or delayed.
- Preserves exp24 MapNotes/HandyNotes tooltip reinjection and all existing collector/battle-pet functionality.

# 0.3.0-exp24

- Fixes dungeon pet sections being recognized in debug but erased from the visible tooltip by MapNotes/HandyNotes tooltip rebuilds.
- Stops trusting the old per-tooltip dungeon key unless the actual DX Pet Services header is still present in the tooltip.
- Hooks tooltip content mutations (`ClearLines`, `SetText`, `AddLine`, and `AddDoubleLine`) and reinjects the pet section after the source addon finishes rebuilding the tooltip.
- Adds post-build verification passes so a section removed immediately after injection is restored while the dungeon tooltip remains hovered.
- Adds direct HandyNotes world-map pin support by hooking the official `HandyNotesWorldMapPinMixin:OnMouseEnter` path after the plugin's own `OnEnter` tooltip builder runs.
- Discovers owner-bound custom GameTooltip frames created by HandyNotes plugins and supports anonymous tooltip font-string regions.
- Keeps Blizzard, MapNotes, reused GameTooltip, WorldMapTooltip, and existing battle-pet functionality intact.

# 0.3.0-exp23

- Fixes dungeon/raid world-map tooltip augmentation by treating the ATT instance table keys as UiMapIDs instead of Encounter Journal instance IDs.
- Resolves each pet-instance map through its localized C_Map name and its mapped Encounter Journal instance name before matching tooltip text.
- Adds a lightweight world-map tooltip watcher so MapNotes/HandyNotes-style tooltips are detected even when they reuse an already-visible GameTooltip without firing OnShow again.
- Adds delayed rechecks at 0, 0.05, and 0.15 seconds for map providers that populate tooltip lines after showing the tooltip.
- Adds optional debug output for unmatched tooltip text and successful dungeon pet-section appends.
- Keeps all existing battle-pet functionality intact.

# 0.3.0-exp22

- Cleaned up the now-confirmed working NPC badge fade implementation without changing its behavior.
- Removed the unused legacy `fadeTicker` state left behind by the pre-frame-update fade driver.
- Removed repeated `Frame:SetAlpha(1)` calls from every fade update; the badge container is now fixed at full alpha once when created, while only the visible components are faded.
- Removed the obsolete scenario-map corner/world-position scale reconstruction from the fade path. Maps without a reliable yard scale now go directly to the working continuous normalized ATT-coordinate fallback.
- Kept the useful distance fallbacks for live-learned NPCs that do not have ATT coordinates.
- Preserves exp21 component-level fading, map-first source priority, diagnostics, and all world/map/minimap functionality.

# 0.3.0-exp21

- Reworked NPC badge fading to fade the actual visual components directly (background, border, paw icon, and text) instead of relying on the child frame's alpha, which could behave like an on/off switch under Blizzard nameplate alpha handling.
- Keeps the badge container at full alpha while applying the calculated opacity to each visible region every frame.
- Changes fade-source priority so authoritative ATT/map source distance wins before nameplate unit distance.
- Rejects implausible zero-like direct nameplate distance values unless the NPC is genuinely within close interaction range.
- Adds optional fade diagnostics to the badge tooltip while `/dxpets debug` is enabled, showing the active source, target opacity, displayed opacity, and source metric.

# 0.3.0-exp20

- Replaced the remaining binary fade fallback for ATT-backed NPCs with continuously changing normalized map-coordinate deltas.
- Calibrates map-scale-independent fade range from the farthest source delta observed while the nameplate is active.
- Keeps exact unit distance and true map-yard distance as preferred sources when available.
- Moves opacity animation to a per-frame driver instead of a 0.05-second ticker.
- Interaction-distance checks are now only a last resort for live-learned sources with no static coordinates.

# DX Pet Services 0.3.0-exp20

## Continuous NPC display distance fading

- Replaced the binary interaction-range fallback for known ATT sources with continuous player-to-source map-coordinate distance.
- Searches the current player map and parent map hierarchy for the matching NPC coordinate.
- Uses validated map world spans, including a scenario-map corner-transform fallback.
- Keeps direct readable unit distance as the highest-priority source.
- Uses a linear 0% to 100% opacity relationship from the outer fade range to the NPC, with frame-rate-independent smoothing.
- Retains discrete interaction-distance animation only for learned sources that have no static ATT coordinates.

# DX Pet Services 0.3.0-exp18

- Reworked NPC pet-display fading into one continuous monotonic curve across the useful nameplate range: near sources approach 100% opacity and far sources approach 0% without a broad full-opacity plateau.
- Switched fade interpolation to frame-rate-independent exponential smoothing for softer movement when Blizzard distance data updates unevenly.
- World-map and minimap paw pins now hide automatically when every pet associated with that source NPC is collected.
- Collection events refresh both map surfaces immediately, so completing the final pet removes the source marker without a reload.
- Preserves exp17 HandyNotes-style continuous minimap tracking and exp16 MapCanvas safety.

# DX Pet Services 0.3.0-exp17

- Replaced the 0.20-second minimap coordinate polling loop with continuous world-space pin tracking modeled after the positioning strategy used by HandyNotes / HereBeDragons.
- Static pet-source coordinates are converted to world positions once per map; the player position is then read from `UnitPosition("player")` every frame so pins glide continuously with the minimap instead of riding with the player arrow and snapping back.
- Added a one-time live calibration fallback for phased/scenario maps when Blizzard map-space instance data does not line up with the player's world instance.
- Kept a lightweight one-second full refresh only for sources entering/leaving range, map changes, minimap rotation state, and nearest-pin selection.
- Added rotating-minimap support and non-round minimap edge handling to the continuous world-space projector.
- Disabled texture pixel-grid snapping on the minimap paw/glow textures to reduce frame-to-frame shimmer, following the same smoothing advice used around HereBeDragons minimap pins.
- Preserves exp16's MapCanvas assertion fix and all prior world-map, waypoint, ATT, nameplate, boss, dungeon-tooltip, settings, and live collection-count work.

# DX Pet Services 0.3.0-exp16

- Fixed a Blizzard MapCanvas `AcquirePin()` assertion when world-map pet paws are created.
- Removed `OnEnter` / `OnLeave` scripts from the custom map-pin XML template.
- Moved paw tooltip hover handling to the MapCanvas-native `OnMouseEnter` / `OnMouseLeave` mixin callbacks.
- Preserved world-map paw clicking, user waypoints, super-tracking, and the selected waypoint overlay.

# 0.3.0-exp15 - Minimap Anchoring, Monotonic Fading, Live Counts, and Dungeon Tooltips

- Reworked minimap pet-source projection to use normalized map deltas with a validated map span, avoiding per-point world-position conversion that could collapse source coordinates onto the player arrow in scenario-style maps.
- Added a guard that refuses to render a distinct source coordinate directly on the player indicator when a projection collapses.
- Fixed NPC badge fading jumping back to 100% opacity after the unit moved beyond readable distance data; unreadable far-range data now continues toward fully faded out.
- Added a lightweight 0.5-second refresh of visible NPC badge collection counts so learning a purchased pet updates the display even when collection events are delayed or absent.
- Dungeon/raid pet tooltip indexing now loads Blizzard Encounter Journal data on demand instead of silently building an empty index before that UI data exists.
- Dungeon tooltip matching now checks every populated tooltip line, no longer depends on a specific map-pin owner ancestry, and retries after Blizzard finishes populating the tooltip.
- Preserves exp14 waypoint behavior, localized map labels, ATT source data, restricted-region nameplate safety, boss paws, and all feature toggles.

# 0.3.0-exp14 - Minimap Projection, Live Counts, Map Names, and Waypoints

- Reworked minimap pet-source pins to project source and player coordinates through world-space positions instead of relying primarily on map world-size scaling. This prevents pins from collapsing onto the player marker on modern/scenario map layers.
- Kept the older map-size projection only as a compatibility fallback when world-position conversion is unavailable.
- World-map and minimap source tooltips no longer expose raw numeric NPC IDs. Localized names are resolved from the client when available and names learned from visible nameplates/merchant sessions are cached account-wide.
- Added account-wide NPC-name caching so map pins become more informative as sources are encountered without shipping a separate full creature-name database.
- Improved NPC badge distance fading for modern nameplate units whose exact distance/position is unavailable or secret. The addon now falls back to readable interaction-distance bands and still blends alpha smoothly.
- Preserved badge alpha across same-NPC refreshes so collection updates do not make the display flash off and restart its fade.
- Added multi-pass collection refreshes after Pet Journal changes, companion updates, merchant updates, merchant close, and pet-related bag changes while a merchant is open.
- Pet-source counts now update dynamically after buying/learning a pet instead of requiring the vendor or nameplate to be reopened.
- Clicking a world-map paw now sets that source location as the active user waypoint and super-tracks it.
- Added a waypoint marker overlay to the selected paw pin and refreshes it when the user waypoint changes.
- Added a click hint to world-map pet-source tooltips.
- Added persistent NPC-name storage migration (account schema 7).
- Preserves exp13's restricted-region nameplate safety fix and all exp12/exp11 world-integration and ATT source data.

# 0.3.0-exp13 - Restricted Nameplate Measurement Fix

- Removed all absolute geometry reads (`GetLeft`, `GetRight`, `GetTop`, and `GetBottom`) from cooperative nameplate decoration stacking.
- Fixed `Action[FrameMeasurement] failed because[Can't measure restricted regions]` errors caused by measuring restricted Blizzard/nameplate regions.
- Decoration overlap detection now uses safe anchor relationships and offsets instead of screen-space rectangle measurements.
- Added guarded reads for candidate size, object type, parent, points, children, regions, visibility, protection, and forbidden state.
- Raw texture regions and protected frames are never re-anchored; DX moves its own pet badge upward to reserve space for them.
- Safe non-protected icon frames can still be shifted above the pet badge and restored when the badge fades or disappears.
- Preserves exp12 distance fading, boss paws, dungeon tooltip data, map/minimap pins, ATT static source data, and settings.

# 0.3.0-exp12 - World Integration, Boss Pets, Map Pins, and Settings

- Added smooth distance-based fading for normal NPC pet-source badges. Badges remain fully visible nearby, ease out through the mid range, and smoothly return as the NPC comes back into range.
- Added cooperative nameplate decoration stacking. When another addon or Blizzard places small icon decorations in the pet badge's reserved space, DX temporarily moves safe non-protected decorations upward and restores their original anchors when the badge disappears. Protected Blizzard frames are never moved; the DX badge stacks above them instead.
- Added out-of-combat blue paw markers beside dungeon and world boss nameplates when the ATT-derived encounter data lists possible pet drops. Boss paws hide immediately when combat begins and also hide when that boss is engaged.
- Added boss-paw hover tooltips listing possible pet drops and Collected/Missing status.
- Added dungeon/raid map-tooltip augmentation with a `DX Pet Services — Battle Pets` section listing available pet drops and the boss that drops each pet. Duplicate encounter rows are collapsed.
- Added blue paw markers to the world map for known static pet-source NPC coordinates. Hovering a marker shows source name, collection progress, and the available pets.
- Added nearby blue paw markers to the minimap using the same ATT-derived static coordinates. Pins update as the player moves and support rotating minimaps.
- Added a dedicated AddOns settings panel and `/dxpets settings` / `/dxpets options` commands.
- Added account-wide toggles for NPC Pet Displays, Boss Paw Icons, World Map Paw Icons, Minimap Paw Icons, and Dungeon Tooltip Pet Info.
- Added an account-wide Default View setting for Battle Pet Mode or Collector Mode. The previous character view is migrated as the initial default where possible.
- Expanded the reduced ATT-derived world index with 532 source-location rows across 124 maps, 152 boss NPC mappings with 173 boss-to-pet links, and 43 instance groups for dungeon tooltip data.
- Kept exp11's authoritative ATT NPC source mappings and exp10's live merchant/quest learning fallback.

# 0.3.0-exp11 - ATT Static Pet Source Database

- Integrated a compact static NPC-to-pet source index derived from AllTheThings 5.2.8.
- Ships 376 NPC source mappings with 739 NPC-to-species links covering fixed ATT vendor and quest-giver relationships across zones, expansion features, events, instances, delves, character/crafting data, and aliases used by the world indicator.
- Added ATT `common_vendor` alias resolution during generation, so phased/scenario variants inherit the canonical vendor's pet list.
- Kifaan now has static mappings for both Naigtal NPC ID 265559 and Val NPC ID 266234, each containing species 4898, 5073, and 5074.
- Static ATT mappings display immediately and no longer require opening the merchant or quest reward screen first.
- Live merchant and quest scanning remains enabled as an additive account-wide fallback for new or incomplete source data.
- Pet Journal source-text matching now runs only when an NPC has neither a static ATT mapping nor a learned exact mapping, reducing heuristic false positives.
- The full ATT database is not bundled; DX Pet Services includes only the generated pet-source index required by the indicator feature.
- Added ATT attribution and MIT license notice.
- Preserves exp10's corrected merchant item-to-species resolver, scenario vendor context binding, hover tooltip, player filtering, and lightweight scan schedule.

# 0.3.0-exp10 - Correct Pet Species Return Resolution

- Fixed the numeric merchant item resolver introduced in exp9.
- `C_PetJournal.GetPetInfoByItemID(itemID)` can return full pet information with the species ID later in the return list; exp9 captured only the first value and therefore tried to convert the pet name to a number.
- The resolver now supports all observed shapes without extra item-data loading: structured table, direct numeric species ID, or full multi-return pet information with `speciesID` in the final field.
- Preserves the scenario-vendor context binding, exact matching safeguards, nameplate filtering, hover tooltip, and lightweight scan schedule from exp8/exp9.

# 0.3.0-exp9 - Numeric Merchant Item Resolution

- Added a direct `GetMerchantItemID(index)` merchant-row resolver before all name-based fallbacks.
- Scenario-style merchant rows can now resolve companion pets even when Blizzard exposes no readable item name or hyperlink.
- Numeric item IDs are passed directly to `C_PetJournal.GetPetInfoByItemID`, avoiding broad source-name heuristics and avoiding item-data loading.
- Added compatibility support for a structured `C_MerchantFrame.GetItemInfo(index).itemID` field if a client build exposes one.
- Expanded merchant debug lines to include the numeric item ID whenever a row remains unresolved.
- Preserves exp8 merchant-session NPC binding, exp7 battlepet-link support, exp6 strict source matching, and the lightweight vendor scan rollback.

# 0.3.0-exp8 - Scenario Vendor Context Binding

- Added persistent merchant-context binding for scenario-style zones such as Val and Naigtal, where the normal `npc` unit token can be unavailable or short-lived.
- Vendor identity now resolves through direct interaction units first, then exact merchant-title to active-nameplate matching, recent exact-name NPC history, and a very short recent-interaction fallback.
- Delayed merchant rescans reuse the captured vendor NPC ID instead of trying to rediscover the vendor after the interaction unit has disappeared.
- Added safe legacy/current merchant API fallbacks for item count, links, and item names without adding heavy item-data requests or global rescan events.
- `/dxpets debug` now reports merchant context resolution, item counts, successful pet resolution paths, and unresolved merchant rows.
- Preserved exp7 strict pet matching, player exclusions, recycled-nameplate cleanup, hover tooltip, and lightweight scan schedule.

# 0.3.0-exp7 - Companion Merchant Links + Voidlight Marl Icon

- Added direct support for `battlepet:` merchant hyperlinks, allowing companion-pet vendor rows to resolve straight to Pet Journal species IDs.
- Kept normal `item:` link resolution and added a strict exact merchant-item-name fallback against the lightweight Pet Journal species index.
- Updated quest reward link handling to accept native `battlepet:` links as well.
- Fixed raw `INV_112_RaidTrinkets_VoidPrism.BLP` source placeholders by rendering the native Voidlight Marl icon through FileDataID 7137586.
- Preserved exp6 exact source matching, clean NPC-only nameplate filtering, recycled-frame cleanup, hover tooltips, and the exp3 lightweight scan schedule.

# 0.3.0-exp6 - Exact Source Name Matching

- Fixed unrelated NPCs such as Thor in Silvermoon receiving pet-source indicators from raw substring matches.
- NPC names must now match complete words or phrases inside Pet Journal vendor/quest source text.
- Heuristic source-text matches are now runtime-only and are never persisted to an NPC ID.
- Persistent NPC-to-pet mappings are learned only from actual merchant inventories or quest reward screens.
- Added a one-time reset of the experimental NPC source cache to remove false mappings saved by exp4/exp5.
- Preserved exp5 NPC GUID parsing, player filtering, recycled-nameplate cleanup, delayed rebinds, hover tooltips, and the exp3 lightweight scan rollback.

# 0.3.0-exp5 - Correct NPC GUID Parsing

- Fixed the exp4 GUID parser reading the shared zone ID instead of the actual NPC ID.
- This prevented one learned pet-source record from being reused by every NPC in the same area.
- Preserved exp4 player/player-controlled exclusions, recycled-nameplate cleanup, lightweight delayed rebinds, and hover tooltip support.
- Preserved the exp3 lightweight merchant scanning rollback.

# 0.3.0-exp4 - Nameplate Binding + Hover Tooltip Fix

- Fixed NPC pet badges appearing above players by rejecting player, player-controlled, pet, and other non-Creature/Vehicle GUID types before source-name matching.
- Fully clears cached unit, GUID, NPC, species, count, and tooltip state whenever a recycled nameplate is rebound or removed.
- Added two lightweight unit-data rebind attempts for nameplates whose GUID/name is temporarily unavailable in crowded areas.
- Restored badge hover interaction without stealing nameplate clicks.
- Hover tooltip now lists the NPC's pet species and marks each as Collected or Missing.
- Preserved the exp3 stability rollback: no ITEM_DATA_LOAD_RESULT rescans, forced item-data requests, or heavy merchant scanning were reintroduced.

# 0.3.0-exp3 - Vendor Scan Rollback

- Rolled back the heavy exp2 merchant scanning changes that could cause severe lag or client crashes.
- Removed ITEM_DATA_LOAD_RESULT rescans and forced item-data requests.
- Restored the lightweight exp1 merchant scan schedule: immediate, 0.25s, and 1.0s only.
- Kept the native battle-pet paw indicator and all Collector Mode functionality.
- This is a stability rollback before the ATT-backed NPC pet source database is integrated.

# DX Pet Services Changelog

## 0.3.0-exp2 - NPC Pet Source Counting Fix

- Fixed merchant pet detection reading the wrong return value from `C_PetJournal.GetPetInfoByItemID`. This prevented the exact vendor scan from learning most or all pets sold by an NPC.
- Vendor scans now aggregate every distinct pet species resolved across the full merchant inventory and persist them account-wide for that NPC.
- Added additional short merchant rescans and item-data requests for inventory entries that are still loading when the vendor first opens.
- Replaced the hunter whistle icon with Blizzard's native `WildBattlePetCapturable` paw atlas.
- Added optional debug output for exact merchant scans when `/dxpets debug` is enabled.

# Changelog

## 0.2.0-exp6 - Collector Model Control Hover Fix

- Fixed Collector Mode model manipulation controls not appearing on hover.
- Exposed the control frame as `ModelScene.ControlFrame`, matching Blizzard's Mount Journal parentKey wiring.
- Forwarded hover events to the inherited model-scene mixin using the same self/button pattern as Blizzard.
- Added a direct show fallback so the controls remain available if the inherited hover path does not reveal them.

## 0.2.0-exp5 - Collector Model Hover Controls

- Added the same hover-driven 3D model manipulation control behavior used by Blizzard's Mount Journal.
- Hovering the Collector Mode model area now reveals the native `ModelSceneControlFrameTemplate` turn/zoom controls.
- Leaving the model area hides the native manipulation controls again through the shared model-scene mixin.
- Added the native model-scene reset callback so the reset control reloads the selected pet preview and camera state.
- Kept the existing large pet model, Collector footer layout, Battle Mode restoration, and mode switch unchanged.

## 0.2.0-exp4 - Window-Centered Collector Footer

- Recentered the Collector Mode `Summon` and `Auto Summon` button group against the full Pet Journal window instead of the right-side Collector preview pane.
- Preserved the native footer baseline and existing spacing between the two controls.
- Battle Mode control restoration and Collector Mode visibility enforcement remain unchanged from exp3.

## 0.2.0-exp3 - Collector Controls and Battle Restoration

- Fixed switching back to Battle Pet Mode so the native selected-pet card, pet-card inset/background, right-side inset, battle pet slots, Revive Battle Pets, Find Battle, Summon, and Summon Random Favorite Pet controls are explicitly restored before and after Blizzard refreshes.
- Restores native button/frame anchors when leaving Collector Mode so Collector layout changes do not leak back into Battle Pet Mode.
- In Collector Mode, moves Blizzard's native Summon Random Favorite Pet control into the former Revive Battle Pets location.
- In Collector Mode, centers the native Summon button and DX Auto Summon button together beneath the large collector preview.
- Keeps Find Battle, Battle Pet Slots/loadout, the battle pet card, the right battle inset, and Revive Battle Pets hidden after pet selections and delayed Blizzard refreshes.

## 0.2.0-exp2 - Collector Mode Visibility and Preview Fixes

- Moved the Battle/Collector title-bar switch onto the Collections Journal title frame beside the native close button so it remains visible above the journal content.
- The switch now only appears while the Pet Journal tab is active.
- Collector Mode now hard-hides every live Find Battle, Battle Pet Slots/loadout, right inset, pet card, and Revive Battle Pets frame variant.
- Added immediate and short deferred visibility enforcement after pet selection and Blizzard Pet Journal refresh paths so clicking a pet cannot bring battle UI back.
- Battle Mode restoration now delegates visibility back to Blizzard's native Pet Journal refresh functions instead of force-showing battle frames.
- Fixed large 3D previews by using the Pet Journal card model scene and the native `unwrapped` actor tag used by Blizzard's selected-pet card.
- Added short actor-availability retries for model scenes that finish creating asynchronously.

## 0.2.0-exp1 - Experimental Collector Mode

- Branched from the confirmed stable 0.1.15 checkpoint.
- Added a Battle / Collector mode switch in the Pet Journal title bar beside the close button.
- Battle Pet Mode preserves Blizzard's normal Pet Journal, roster, and battle controls.
- Collector Mode keeps the pet list but replaces the battle-focused right side with a Mount Journal-inspired collection display.
- Collector display includes the selected pet icon, name, source, description, large 3D model scene, and native model-scene turn/zoom controls.
- Collector Mode hides Revive Battle Pets, Find Battle, the selected battle-pet card, and battle-pet loadout roster.
- Summon, Summon Random Favorite Pet, Auto Summon, search, filters, and the pet list remain available.
- View mode is saved per character.


## 0.1.15 - ASCII Tooltip Cycle Hint

- Replaced the Unicode arrow in the Auto Summon tooltip cycle hint with plain ASCII `->`.
- The tooltip now displays `OFF -> ON -> RANDOM` to avoid unsupported or invalid glyphs in WoW fonts.

## 0.1.14 - Three-State Auto Summon Button

- Replaced the ON/OFF toggle plus right-click source menu with one three-state cycle: `OFF -> ON -> RANDOM -> OFF`.
- `ON` summons only from the active character's native favorite pets.
- `RANDOM` summons randomly from the full owned-pet collection.
- Removed the Auto Summon right-click menu entirely.
- Updated the hover tooltip so ON explicitly says it is summoning from favorites and RANDOM explicitly says it is summoning randomly.
- The button now measures the longest label, `Auto Summon: RANDOM`, and adds 32 pixels of padding, making it only as wide as needed while keeping RANDOM comfortable.
- Existing 0.1.13 settings migrate naturally: disabled remains OFF, enabled Favorites becomes ON, and enabled Any Random Pet becomes RANDOM.
- Added explicit `/dxpets autosummon on|off|random` commands while keeping older favorites/all aliases compatible.

## 0.1.13 - Auto Summon Source Choice

- Added a per-character Auto Summon source setting.
- Auto Summon can now use either `Character Favorites` or `Any Random Pet`.
- Left-clicking the compact footer button still toggles Auto Summon on or off.
- Right-clicking the footer button opens an `Auto Summon From` chooser without adding another journal control.
- `Character Favorites` calls Blizzard's random-pet summon with the favorite-only mode.
- `Any Random Pet` calls the same native random-pet summon with favorite filtering disabled, even when the character has favorites.
- Updated the Auto Summon tooltip to show the active source and mouse controls.
- Added `/dxpets autosummon favorites` and `/dxpets autosummon random` source commands.
- The selected summon source is saved per character.

## 0.1.12 - Character Favorite Persistence Fix

- Fixed character favorites being erased during login or character switching when the Pet Journal temporarily returned an empty owned-pet list.
- Removed login-time pruning of saved favorites; real pet removals continue to be handled by `PET_JOURNAL_PET_DELETED`.
- Added a collection-readiness gate so character favorites are not applied until owned pet data is available.
- Added a startup sync state so early `PET_JOURNAL_LIST_UPDATE` events cannot overwrite the incoming character's saved set with the previous character's native favorites.
- Native Favorite / Unfavorite changes now read back the actual `C_PetJournal.PetIsFavorite` state immediately after Blizzard updates it.
- Added authoritative favorite snapshots after native Pet Journal updates and again on `PLAYER_LOGOUT` before SavedVariables are serialized.
- Added debug messages for favorite sync and snapshots when `/dxpets debug` is enabled.
- Auto Summon now waits for the incoming character's favorite sync to finish, preventing a pet from the previous character's native favorite set from being summoned during login.

## 0.1.11 - Compact Auto Summon Button

- Kept the Auto Summon control on the exact native footer-button baseline.
- Removed the stretch-to-fill behavior introduced in 0.1.10.
- Restored the compact 140-pixel button width from the original Auto Summon design.
- Added an invisible gap anchor so the compact button remains perfectly centered between Summon and Find Battle at any journal layout width.

## 0.1.10 - Shared Minimum Tooltip Width + Button Alignment

- Aligned the Auto Summon button to the exact bottom baseline of Blizzard's native Summon and Find Battle buttons.
- Anchored the Auto Summon button between the two native buttons so it automatically fills the available center gap.
- Reworked tooltip sizing to measure both Blizzard's native pet tooltip and the Battle Pet BreedID-style panel.
- Both tooltips now use the larger of their two true content-width requirements, producing the smallest shared width that contains every visible line without clipping, wrapping, or overflow.
- Added a next-frame re-measure of both panels to catch Blizzard tooltip content or sizing that finishes after the original hover hook.

## 0.1.9 - Auto Summon Favorites

- Added the first Auto Summon module.
- Added a native-style `Auto Summon: ON/OFF` toggle centered between Blizzard's Summon and Find Battle buttons.
- Auto Summon is stored per character.
- Uses Blizzard's native favorite pool via `C_PetJournal.SummonRandomPet(true)`, so it automatically follows the active character's synchronized favorite set.
- Checks after login, loading screens, zone changes, pet battles, combat, and companion updates.
- Does nothing while a companion pet is already active.
- Avoids summon attempts during pet battles and combat lockdown.
- Added delayed, debounced checks and limited retries for transient loading/context transitions.
- Added `/dxpets autosummon` as a slash-command toggle.

## 0.1.8 - Native Character Favorites

- Reworked character favorites to use Blizzard's actual native pet-favorite state while the character is active.
- The built-in `Summon Favorite Pet` action now sees the active character's DX favorites because the native favorite set is synchronized from the per-character database.
- Removed the custom exact/species favorite actions from the DX right-click menu; Blizzard's own native `Favorite` / `Unfavorite` action is now the source of truth.
- Hooked native favorite changes so using Blizzard's normal right-click menu immediately saves the change to the current character's DX favorite list.
- Removed all custom favorite portrait overlays.
- Favorite pets now use Blizzard's own `PetJournal-FavoritesIcon` texture at Blizzard's exact atlas size and native top-left placement.
- Native favorite stars now appear consistently anywhere Blizzard displays them, including pet-list portraits, the selected pet card, and battle-pet loadout slots.
- Simplified the DX character favorite filter to `All Pets` and `Character Favorites`.
- Preserves existing account-wide native favorites by importing them once into the first character loaded after upgrading, then switches native favorites per character on future logins.
- Retains old species-favorite saved data for compatibility, but species favorites no longer affect the active native-style favorite system.

## 0.1.7 - Matched Native/Breed Tooltip Widths

- Removed the fixed 420-pixel minimum width from the Battle Pet BreedID-style panel.
- The breed panel now measures its longest visible text line and sizes itself only wide enough to fit that content comfortably.
- Blizzard's main pet tooltip is resized to exactly the same width while the pet tooltip is shown, producing a flush two-panel stack.
- Added a next-frame width reapply to survive Blizzard tooltip paths that perform a final native size pass after addon hooks run.
- Restores the native tooltip's minimum-width constraint when the pet tooltip closes so unrelated tooltips are not forced to the pet-tooltip width.
- Made the Breed heading use the same larger font as the Quality heading in the selected-pet Quality/Breed help tooltip.
- Made Breed body lines use the same body font scale as the Quality explanation.


- Increased the selected-pet quality/breed text by 2 font points.
- Moved the quality/breed text 3 pixels lower in Blizzard's existing `QualityFrame`.
- Widened the reused quality row to 180 pixels for the larger text.
- Added the same selected-card hover information pattern used by the DX Pet Tracker:
  - Quality header and Blizzard rarity explanation.
  - Breed header and breed-distribution explanation.
  - Current readable breed profile name.
  - Percentage bonuses for every stat boosted by the current breed.
- Anchored the hover tooltip to the right of the quality/breed row using a right-side anchored offset.


- Removed the separate DX Pet Information tooltip entirely.
- Kept a single Battle Pet BreedID-style secondary tooltip.
- Increased the breed tooltip minimum width to 420 pixels for collected-pet lists and possible-breed information.
- Added selected-pet quality and breed profile directly to Blizzard's existing Pet Journal `QualityFrame`.
- Uses the DX selected-card placement strategy: the existing quality row is widened, its native background region is hidden, and the text becomes an inline breed icon + quality + breed profile.
- Uses native WoW stat textures for breed icons with no external addon dependency.

## 0.1.4 - Dedicated Breed + ID Tooltip Stack

- Removed the appended-line tooltip approach.
- Added a dedicated `GameTooltipTemplate` breed panel anchored directly beneath Blizzard pet tooltips.
- Added the Battle Pet BreedID default tooltip information set:
  - Current Breed
  - Collected copies with level and breed
  - Possible Breed(s)
  - Current breed stats at level 25
  - All possible breed stats at level 25
- Added Battle Pet BreedID breed calculations and current pet breed/base-stat data as an attributed vendored data module.
- Added a dedicated DX Pet Information tooltip beneath the breed panel.
- Added a generic `GameTooltip:SetCompanionPet` hook so any Blizzard UI surface using the native companion-pet tooltip path can display the stack.
- Kept Pet Journal drag-button, loadout-button, selected pet-card, caged-pet, Auction House, and floating battle-pet tooltip fallbacks.
- Added conflict handling for the official Battle Pet BreedID addon to avoid duplicate breed panels.

## 0.1.3

- Fixed Pet Journal portrait tooltips by hooking the actual `PetJournalDragButtonMixin:OnEnter` path used by Blizzard.
- Appended DX pet IDs to the native `GameTooltip` shown for Pet Journal list portraits.
- Added Pet Journal pet-card tooltip integration.
- Kept generic battle-pet tooltip hooks.

## 0.1.2 - Generic Battle Pet Tooltips

- Added generic standard and floating battle-pet tooltip hooks.

## 0.1.1 - Native Journal Integration

- Removed the separate side panel.
- Moved character favorite actions into the native pet right-click context menu.
- Added exact-pet and species-favorite overlays directly on pet portraits.
- Moved character favorite filters into Blizzard's existing Filter menu.

## 0.1.0 - Phase 1 Foundation

- Added core module, database, and event architecture.
- Added character-based exact-pet and species favorites.

## 0.3.0-exp1 - NPC Pet Source Indicators (Experimental)

- Added compact pet collection indicators above visible NPC nameplates.
- Indicator shows a pet-themed icon and collected species / available species, for example `1/3`.
- Completed NPC sources turn green; incomplete sources remain gold.
- Automatically discovers many vendor and quest pet sources from Pet Journal source text.
- Learns exact NPC-to-pet mappings when visiting pet vendors or viewing pet quest rewards, and saves those mappings account-wide.
- Updates indicators when the pet collection changes.
- Uses secret-value guards before reading nameplate unit names or GUIDs on WoW 12.x.

## 0.5.2-dxdata2

- Added the standalone DX Dense Location Editor under `Tools/DenseLocationEditor`.
- Added visual decode/edit/re-encode support for `Data/DXDenseLocations.lua`.
- Added map/species record creation, point dragging, deletion, deduplication, validation, and automatic backups.
- Integrated the single-page NPC location grabber directly into the editor.
- Added import support for existing `pet_locations.json` extractor output with explicit source-map to Blizzard UiMapID mapping.
- No in-game Pet Tracker runtime or UI behavior changed.

