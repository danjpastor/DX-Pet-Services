# DX Pet Services development notes

This file is the quickest map of the addon for anyone editing it by hand.

## Load order

The `.toc` file is the source of truth. The important order is:

1. Core services and SavedVariables.
2. Static/generated data.
3. Pet Journal modules.
4. World/nameplate/map modules.
5. Pet Tracker.
6. Map pin XML templates.
7. Dungeon tooltip integration.
8. UI integration and settings.

Modules register themselves with `ns:RegisterModule(name, module)`. `Core/Core.lua` calls `OnInitialize` and `OnEnable` in registration order.

## Main files

### Core

- `Core/Core.lua` — module registry, addon lifecycle, slash commands.
- `Core/Database.lua` — account and character defaults, migrations, validation.
- `Core/Events.lua` — small owner-based event dispatcher.

### Pet Journal

- `Modules/Favorites.lua` — per-character favorites synchronized into Blizzard's native favorite state.
- `Modules/AutoSummon.lua` — OFF / ON / RANDOM summon state and retry logic.
- `Modules/BreedInfo.lua` — breed calculation and breed tooltip data.
- `Modules/PetTooltips.lua` — general battle-pet tooltip hooks.
- `Modules/PetCardBreed.lua` — selected-pet quality/breed presentation.
- `UI/Journal.lua` — Pet Journal controls, menu integration, filters.
- `UI/CollectorMode.lua` — Battle / Collector mode layout and model scene.

### World and map integration

- `Modules/NPCPetIndicators.lua` — NPC collection badges, boss paws, distance fading, source learning.
- `Modules/MapPetPins.lua` — static source paws on the world map and minimap.
- `Modules/DungeonPetTooltips.lua` — Battle Pets sections on dungeon/raid tooltips.
- `Modules/PetTracker.lua` — wild-pet map pins, zone tracker panel, expansion progress, Objective Tracker block.
- `UI/WorldMapPins.xml` — virtual pin and side-tab templates.

### Data

The files under `Data/` are data assets, not normal hand-edited module code.

- `ATTPetSources.lua` — reduced NPC-to-pet source relationships.
- `ATTPetWorld.lua` — reduced source locations, boss relationships, instance groups.
- `ATTPetTracker.lua` — zone/species tracker index.
- `DXDenseLocations.lua` — packed runtime-only dense wild-pet spawn coordinates. It decodes one map at a time through `ns.DXDenseLocationDB:GetMap(mapID)` and must not be hand-edited.
- `BreedData.lua` — breed/stat lookup data.

Keep data regeneration separate from UI or runtime cleanup work. The readable dense-location master and its packing utility belong in the separate developer source archive; never place the readable source or `.bak` copies in the distributable addon folder.

For normal dense-location editing, use the separate `DX_PetServices_StudioPackedWorkflow_2026-07-11` workspace. Configure it to watch the readable Studio export and this development addon folder. Each successful Studio save is packed, round-trip validated, and atomically installed into `Data/DXDenseLocations.lua`. Its release command refuses to package readable sources, backups, or developer tools.

## Pet Tracker layout controls

The most commonly edited tracker layout values are grouped near the top of `Modules/PetTracker.lua` in `PANEL_LAYOUT`:

```lua
local PANEL_LAYOUT = {
    backdropTop = 0,
    backdropBottom = 0,
    contentLeft = 16,
    contentTop = -16,
    contentRight = -18,
    contentBottom = 8,
    titleY = 25,
}
```

What they control:

- `backdropTop` / `backdropBottom` — position and height of the native textured content box.
- `contentLeft` / `contentRight` — horizontal padding inside the box.
- `contentTop` / `contentBottom` — vertical padding and usable content height.
- `titleY` — vertical position of the `Pet Tracker` heading above the backdrop.

The side-tab paw tint is `TAB_ICON_COLOR` in the same file.

For the zone pet list:

- `ZONE_PET_ROW_HEIGHT` controls row height.
- `ZONE_PET_MAX_VISIBLE_ROWS` controls how many rows are visible before scrolling.

For the expansion list:

- `EXPANSION_ROW_HEIGHT` controls spacing between expansion rows.

## Settings

Account-wide defaults live in `Core/Database.lua`.

When adding a boolean setting:

1. Add the default under `ACCOUNT_DEFAULTS.settings`.
2. Add the key to `BOOLEAN_SETTINGS`.
3. Add the checkbox in `UI/Settings.lua`.
4. Add the module to `SETTINGS_OBSERVERS` only when it needs a live refresh after the setting changes.

## Code style

The codebase follows a few simple rules:

- Keep module state at the top of the file.
- Keep tunable values in named constants rather than burying numbers inside frame setup.
- Comments should explain a constraint or reason, not narrate the next line.
- Avoid release-history notes in runtime code; those belong in `CHANGELOG.md`.
- Prefer small local helpers for repeated frame/API work.
- Keep protected-frame, secret-value, and combat-lockdown guards intact unless testing proves they are no longer needed.
- Do not mix generated data cleanup with runtime refactors.

## Supported client and API policy

DX Pet Services targets the current Retail client declared by `## Interface` in the TOC. Code should trust APIs and frame methods that are guaranteed by that client.

Do not add a function-existence check or `pcall` by default. Use them only for:

- optional or load-order-dependent Blizzard templates and mixins;
- dynamically discovered frames, regions, or third-party objects;
- secret, protected, forbidden, or otherwise restricted values;
- APIs with a reproduced runtime failure mode.

Standard Retail APIs, standard methods on frames/textures created by this addon, and methods guaranteed by a template the addon already requires should be called directly. Every remaining `pcall` should protect a specific known boundary rather than hide ordinary programmer errors.

## Safe test checklist

After code-only changes:

1. `/reload` with no Lua errors.
2. Open the Pet Journal in Battle and Collector modes.
3. Cycle Auto Summon through OFF, ON, and RANDOM.
4. Check character favorites and the native favorite star.
5. Open the world map and switch among Quests, Events, Map Legend, and Pet Tracker.
6. Confirm wild-pet icons render at dense spawn locations.
7. Check the zone progress bar, zone pet list, expansion list, and Objective Tracker attachment.
8. Check an NPC pet-source badge and its distance fade.
9. Check a boss paw outside combat.
10. Check a dungeon/raid map tooltip with pet data.

## Release checklist

Before packaging:

1. Update `ns.version` in `Core/Core.lua`.
2. Update `## Version` in `DX_PetServices.toc`.
3. Add the release to the top of `CHANGELOG.md`.
4. Parse every Lua file.
5. Parse the XML file.
6. Verify every `.toc` file reference exists.
7. Test ZIP integrity.
