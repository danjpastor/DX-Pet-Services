# DX Pet Services

DX Pet Services expands the Retail World of Warcraft Pet Journal with companion-pet collection tools while preserving useful legacy battle-pet features.

## Current features

- Compact three-state Auto Summon button centered and aligned between Blizzard's native Summon and Find Battle buttons.
- Auto Summon cycles through `OFF`, `ON` (character favorites), and `RANDOM` (any random owned pet).
- Character-based pet favorites that use Blizzard's native favorite state while the character is active.
- Blizzard's normal right-click `Favorite` / `Unfavorite` action saves directly to the current character.
- Blizzard's built-in `Summon Favorite Pet` action summons from the current character's favorite set.
- Blizzard's own favorite star is used at its exact native size and placement; no custom favorite overlay is drawn.
- Pet Journal filter entries for `All Pets` and `Character Favorites`.
- Battle Pet BreedID-style secondary tooltip information.
- Selected-pet quality + readable breed profile in Blizzard's existing Pet Journal quality row.
- Quality/Breed help tooltip.
- Zone Pet Tracker with circular wild-pet map icons and a Map & Quest Log collection panel.

## Auto Summon modes

Click the compact Auto Summon footer button to cycle through `OFF -> ON -> RANDOM`. `ON` summons from the active character's native favorite set. `RANDOM` summons randomly from the full owned-pet collection. The state is saved per character.

## Favorite synchronization

WoW's native favorite state is shared by the pet collection, while DX Pet Services stores favorite pet GUIDs per character. When a character logs in, DX Pet Services synchronizes that character's saved set into Blizzard's native favorite state. Native UI features then work normally with the active character's favorites.

On the first native-favorites migration, existing native favorites are imported once so the current favorite set is not lost. After that, each character keeps its own saved set. Favorite sets are applied only after the Pet Journal collection is ready, are updated immediately from Blizzard's native Favorite / Unfavorite action, and receive a final snapshot on logout.

## Commands

- `/dxpets` - show version, character favorite count, and Auto Summon state.
- `/dxpets tracker` - toggle the Zone Pet Tracker panel on the world map.
- `/dxpets autosummon` - cycle `OFF -> ON -> RANDOM`.
- `/dxpets autosummon on` - enable favorite-only Auto Summon.
- `/dxpets autosummon random` - enable full-collection random Auto Summon.
- `/dxpets autosummon off` - disable Auto Summon.
- `/dxpets resetfilter` - reset the Pet Journal DX filter to All Pets.
- `/dxpets debug` - toggle debug messages.
- `/dxpets settings` or `/dxpets options` - open the DX Pet Services settings panel.

## Collector Mode

Use the Battle / Collector switch beside the Pet Journal close button.

- **Battle** keeps the standard Blizzard Pet Journal unchanged.
- **Collector** keeps the pet list on the left and replaces the battle-focused right side with a large collection preview containing the pet icon, name, source, description, and interactive 3D model.
- Revive Battle Pets and Find Battle are hidden in Collector Mode. Summon Random Favorite Pet moves into the former Revive Battle Pets location, while Summon and Auto Summon are centered beneath the collector preview.
- Summon, favorites, Auto Summon, search, and filters remain available.

## Zone Pet Tracker

The world map shows catchable pets with small circular portraits at every bundled spawn location for the current zone. The dense location database is owned and bundled by DX Pet Services; no external location addon is required. Clicking a precise location can create a waypoint.

A gold paw tab on the right side of the Map & Quest Log opens the zone collection panel. The panel includes:

- zone collection summary and sliced quality progress bar;
- a scrollable `Pets in This Area` list with portrait, name, quality, and owned count;
- wild-pet collection progress grouped by expansion;
- optional Objective Tracker attachment for the current zone.

The tracker panel uses Blizzard's native Map Legend backdrop style while remaining a separate fourth tab. Quests, Events, and Map Legend keep their normal behavior.

The reduced ATT tracker index contains 144 maps, 634 unique species, and 1,048 species-to-map relationships. The bundled dense location snapshot contains 19,469 spawn points across 122 maps.

## NPC Pet Source Indicators

When WoW has a visible nameplate for an NPC that sells or rewards pets, DX Pet Services can show a compact pet collection badge above that NPC. The badge displays collected pet species versus total pet species available from that NPC, such as `1/3`.

Hovering the badge shows the NPC's known pet species and marks each one as Collected or Missing.

The feature now ships with a compact NPC-to-pet source index derived from the AllTheThings 5.2.8 database. Known ATT vendor and quest-giver relationships can therefore display immediately, without requiring the shop or quest reward screen to be opened first.

Source resolution uses three layers:

1. Shipped ATT-derived NPC ID -> pet species mappings.
2. Account-wide exact learning from live merchant inventories and quest reward screens, used additively for new or incomplete source data.
3. Exact-word Pet Journal source-text matching only when no authoritative static or learned mapping exists.

The full ATT database is not bundled or loaded; DX Pet Services ships only the reduced pet-source relationships used by this feature. Rotating catalogs such as the Trading Post and Black Market are intentionally excluded because a static historical pet list would not represent their current availability. Because the badge is attached to WoW nameplates, an NPC must currently have a nameplate frame for the indicator to be displayed.

## World, boss, map, and dungeon integration

Known pet-source NPC badges now fade smoothly with distance. DX also reserves the badge area above the nameplate: safe icon decorations from other addons can be shifted upward while the badge is visible, then restored to their original anchors when the badge fades away. Protected Blizzard frames are never moved.

Dungeon and world bosses with ATT-derived pet-drop data can show a blue paw to the right of their nameplate while out of combat. The boss paw hides during combat and its tooltip lists the possible pet drops with Collected/Missing status.

Known static pet-source coordinates can appear as blue paw markers on the world map and minimap. Marker tooltips show the source, collection progress, and available pets. Dungeon and raid map icon tooltips can also receive a Battle Pets section listing each available pet and the boss that drops it.

The reduced world index currently contains 532 source-location rows across 124 maps, 152 boss NPC mappings with 173 boss-to-pet links, and 43 instance groups used for dungeon/raid tooltip data. The full ATT database is still not bundled.

## Settings

Open **Options -> AddOns -> DX Pet Services** or use `/dxpets settings`. The panel includes:

- Default View: Battle Pet Mode or Collector Mode.
- NPC Pet Displays.
- Boss Paw Icons.
- World Map Paw Icons (controls both world-map and minimap source paws).
- Pet Tracker Map Icons.
- Objective Tracker Pet List.
- Dungeon Tooltip Pet Info.

These settings are account-wide.

## Development

See `DEVELOPING.md` for module ownership, load order, Pet Tracker layout controls, safe editing notes, and the release checklist.
