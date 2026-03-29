# QuestHUD — Claude Code Master Prompt
## Phase 1: HUD Overlay (FarmHUD Fork + Rename)

Paste this entire document into a new Claude Code session.

---

## Your Role

You are building a World of Warcraft addon called **QuestHUD** for Retail (Midnight / Patch 12.x, Interface 120001). You are working from a fork of the open-source **FarmHUD** addon. Your job for this phase is to:

1. Fork FarmHUD into a clean QuestHUD directory structure
2. Rename every FarmHUD reference to QuestHUD throughout
3. Strip all farming-specific code (node tracking, GatherMate2 hooks, Range Circles)
4. Stub in the new QuestHUD-specific files as empty modules
5. Confirm the addon loads in WoW with no Lua errors

Do not implement quest routing, the directional arrow, or node gathering yet. This phase is foundation only.

---

## Source Material

The FarmHUD source is in: `FarmHud-master/`

Key files you will work with:

| File | Action |
|---|---|
| `FarmHud-master/FarmHud.toc` | Rename → `QuestHUD/QuestHUD.toc`, update all metadata |
| `FarmHud-master/FarmHud.xml` | Rename → `QuestHUD/QuestHUD.xml`, update script references |
| `FarmHud-master/FarmHud.lua` | Rename → `QuestHUD/QuestHUD.lua`, strip farming code, rename globals |
| `FarmHud-master/FarmHud_Options.lua` | Rename → `QuestHUD/QuestHUD_Options.lua`, keep structure, clear content |
| `FarmHud-master/FarmHud_DataBroker.lua` | Rename → `QuestHUD/QuestHUD_DataBroker.lua`, update references |
| `FarmHud-master/Localization.lua` | Copy → `QuestHUD/Localization.lua`, keep structure |
| `FarmHud-master/Bindings.xml` | Rename → `QuestHUD/Bindings.xml`, update binding names |
| `FarmHud-master/modules/CardinalPoints.lua` | Copy as-is → `QuestHUD/modules/CardinalPoints.lua` |
| `FarmHud-master/media/` | Copy all `.tga` files except `gathercircle.tga` |
| `FarmHud-master/.pkgmeta` | Rewrite for QuestHUD, remove HizurosSharedTools |
| `FarmHud-master/.github/workflows/packager.yml` | Copy and update addon name |

Files to **DELETE** (farming-specific, not needed):
- `FarmHud-master/modules/RangeCircles.lua` — farming gather radius circles
- `FarmHud-master/modules/TrailPath.lua` — farming trail breadcrumbs
- `FarmHud-master/QuestArrow/` — entire sub-addon (replaced by QuestHUD's own arrow)
- `FarmHud-master/media/gathercircle.tga` — farming circle texture

---

## Complete Global Rename Map

Apply these renames **everywhere** — Lua, XML, TOC, and Bindings files:

| Old | New |
|---|---|
| `FarmHud` | `QuestHUD` |
| `FarmHudMixin` | `QuestHUDMixin` |
| `FarmHudMinimapDummyMixin` | `QuestHUDMinimapDummyMixin` |
| `FarmHudDB` | `QuestHUDDB` |
| `FarmHud_Options` | `QuestHUD_Options` |
| `FarmHud_DataBroker` | `QuestHUD_DataBroker` |
| `FarmHudRangeCircles` | *(delete all references)* |
| `FarmHudFont` | `QuestHUDFont` |
| `FarmHudonScreenButtonTemplate` | `QuestHUDOnScreenButtonTemplate` |
| `FarmHudMinimapDummy` | `QuestHUDMinimapDummy` |
| `FarmHudTrailPathPinTemplate` | *(delete — TrailPath removed)* |
| `FarmHudCircleLineTemplate` | *(delete — RangeCircles removed)* |
| `FARMHUD` | `QUESTHUD` (binding header) |
| `TOGGLEFARMHUD` | `TOGGLEQUESTHUD` |
| `TOGGLEFARMHUDMOUSE` | `TOGGLEQUESTHUDMOUSE` |
| `TOGGLEFARMHUDBACKGROUND` | `TOGGLEQUESTHUDBACKGROUND` |
| `SavedVariables: FarmHudDB` | `SavedVariables: QuestHUDDB` |
| `package-as: FarmHud` | `package-as: QuestHUD` |
| `libs/HizurosSharedTools` | *(remove — not needed)* |

---

## Farming Code to Strip from FarmHud.lua

Remove the following blocks from `FarmHud.lua` during the rename. Comment them out first with `--[[STRIPPED]]` markers, then delete in a second pass:

**Lines/sections to strip:**

1. **GatherMate2 references** (lines ~368, ~594–595):
   ```lua
   -- STRIP: GatherMate2 pin reparenting
   or (_G["GatherMate2"] and objName:match("GatherMatePin"))
   -- STRIP: GatherMate2 display module call
   if _G["GatherMate2"] then
       _G["GatherMate2"]:GetModule("Display"):ReparentMinimapPins(Map);
   end
   ```

2. **Tracking types system** (locals at top, ~line 27):
   ```lua
   -- STRIP: farming node tracking
   local trackingTypes,trackingTypesStates,numTrackingTypes,trackingHookLocked = {},{},0,false;
   ```
   And all functions that reference `trackingTypes`, `trackingTypesStates`, `trackingHookLocked`.

3. **RangeCircles references** — any mention of `FarmHudRangeCircles` in the ignore list or module calls.

4. **Module loads in QuestHUD.xml** — remove these script tags:
   ```xml
   <!-- REMOVE -->
   <Script file="modules/RangeCircles.lua" />
   <Script file="modules/TrailPath.lua"/>
   ```
   And remove these frame templates:
   ```xml
   <!-- REMOVE -->
   <Frame name="FarmHudTrailPathPinTemplate" .../>
   <Frame name="FarmHudCircleLineTemplate" .../>
   <Frame name="FarmHudRangeCircles" .../>
   ```

5. **QuestArrow module** — remove from `FarmHud.xml`:
   ```xml
   <!-- The QuestArrow sub-addon is replaced by QuestHUD's own system -->
   ```
   The `move-folders` entry in `.pkgmeta` for `QuestArrow` should also be removed.

---

## New Files to Create (Empty Stubs)

Create these files with the module skeleton shown. They will be implemented in later phases.

### `QuestHUD/QuestHUD_RouteEngine.lua`
```lua
-- QuestHUD_RouteEngine.lua
-- Phase 2: Quest route algorithm — filtering, sorting, hub advancement
-- TODO: Implement in Phase 2

local addon, ns = ...
ns.RouteEngine = {}

function ns.RouteEngine:Init()
    -- TODO
end

function ns.RouteEngine:GetActiveStep()
    return nil  -- TODO
end
```

### `QuestHUD/QuestHUD_RouteData.lua`
```lua
-- QuestHUD_RouteData.lua
-- Phase 3: Pre-built route backbone — all quest IDs, coords, metadata
-- TODO: Populate with Midnight quest IDs from Wowhead before Phase 3

QuestHUD_Route = {
    -- Stub: one example entry to validate table structure loads
    {
        step = 1,
        zone = "Eversong Woods",
        hub = "Isle of Quel'Danas",
        level_range = {80, 81},
        quests = {},  -- TODO: populate
    },
}
```

### `QuestHUD/QuestHUD_InfoPanel.lua`
```lua
-- QuestHUD_InfoPanel.lua
-- Phase 3: SimpleHTML info panel — objective, XP, distance, time
-- TODO: Implement in Phase 3

local addon, ns = ...
ns.InfoPanel = {}

function ns.InfoPanel:Init()
    -- TODO
end

function ns.InfoPanel:Update(step)
    -- TODO
end
```

### `QuestHUD/QuestHUD_Arrow.lua`
```lua
-- QuestHUD_Arrow.lua
-- Phase 2: Directional arrow — bearing, rotation, colour by quest type
-- TODO: Implement in Phase 2

local addon, ns = ...
ns.Arrow = {}

function ns.Arrow:Init()
    -- TODO
end

function ns.Arrow:SetTarget(x, y, mapID, questType)
    -- TODO
end
```

### `QuestHUD/QuestHUD_BonusDetector.lua`
```lua
-- QuestHUD_BonusDetector.lua
-- Phase 4: XP bonus detection + time estimate calculation
-- TODO: Implement in Phase 4

local addon, ns = ...
ns.BonusDetector = {}

function ns.BonusDetector:Detect()
    return {
        warMode       = false,
        restedXP      = false,
        heirlooms     = false,
        darkmoon      = false,
        warbandMentor = false,
    }
end
```

### `QuestHUD/QuestHUD_Gathering.lua`
```lua
-- QuestHUD_Gathering.lua
-- Phase 3: Self-contained node collector + HUD pin renderer
-- Reads from QuestHUD_NodeData.lua (bundled) and SavedVariables (live)
-- TODO: Implement in Phase 3

local addon, ns = ...
ns.Gathering = {}

function ns.Gathering:Init()
    -- TODO
end

function ns.Gathering:UpdatePins()
    -- TODO
end
```

### `QuestHUD/QuestHUD_NodeData.lua`
```lua
-- QuestHUD_NodeData.lua
-- Auto-generated by tools/extract_nodes.py
-- Run: python3 tools/extract_nodes.py --herb HerbalismData.lua --mine MiningData.lua --out QuestHUD_NodeData.lua
-- TODO: Generate this file using the extraction script before Phase 3

QuestHUD_BundledHerbDB = {}
QuestHUD_BundledMineDB = {}
QuestHUD_HerbNodeNames = {}
QuestHUD_MineNodeNames = {}
QuestHUD_ZoneNames = {}
```

### `QuestHUD/QuestHUD_FirstCraft.lua`
```lua
-- QuestHUD_FirstCraft.lua
-- Phase 4: First craft XP reminder — detection, route injection, dismissal
-- TODO: Implement in Phase 4

local addon, ns = ...
ns.FirstCraft = {}

function ns.FirstCraft:Init()
    -- TODO
end
```

---

## Target TOC File

The final `QuestHUD/QuestHUD.toc` should look exactly like this:

```
## Interface: 120001
## Title: QuestHUD
## Notes: Optimised quest routing HUD for 80-90 levelling in Midnight. Directional arrow, node overlay, XP tracking.
## Version: @project-version@

## Category-enUS: Map

## Author: [Your name]
## IconTexture: 134215
## SavedVariables: QuestHUDDB

## X-Curse-Project-ID:
## X-Wago-ID:

libs\LibStub\LibStub.lua
libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
libs\AceGUI-3.0\AceGUI-3.0.xml
libs\AceConfig-3.0\AceConfig-3.0.xml
libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
libs\LibDBIcon-1.0\LibDBIcon-1.0.lua
libs\HereBeDragons\HereBeDragons-2.0.lua
libs\HereBeDragons\HereBeDragons-Pins-2.0.lua
libs\HereBeDragons\HereBeDragons-Migrate.lua
libs\LibColors-1.0\LibColors-1.0.xml

Localization.lua
QuestHUD_NodeData.lua
QuestHUD_RouteData.lua
QuestHUD.xml
QuestHUD_Options.lua
QuestHUD_DataBroker.lua
QuestHUD_RouteEngine.lua
QuestHUD_Arrow.lua
QuestHUD_InfoPanel.lua
QuestHUD_Gathering.lua
QuestHUD_BonusDetector.lua
QuestHUD_FirstCraft.lua
```

---

## Target .pkgmeta File

```yaml
package-as: QuestHUD

externals:
    libs/LibStub:
        url: https://repos.curseforge.com/wow/libstub/trunk
        tag: latest

    libs/CallbackHandler-1.0:
        url: https://repos.curseforge.com/wow/callbackhandler/trunk/CallbackHandler-1.0
        tag: latest

    libs/AceGUI-3.0:
        url: https://repos.curseforge.com/wow/ace3/trunk/AceGUI-3.0
        tag: latest

    libs/AceConfig-3.0:
        url: https://repos.curseforge.com/wow/ace3/trunk/AceConfig-3.0
        tag: latest

    libs/LibDataBroker-1.1:
        url: https://repos.curseforge.com/wow/libdatabroker-1-1
        tag: latest

    libs/LibDBIcon-1.0:
        url: https://repos.curseforge.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0
        tag: latest

    libs/HereBeDragons:
        url: https://repos.curseforge.com/wow/herebedragons
        tag: latest

    libs/LibColors-1.0:
        url: https://github.com/HizurosWoWAddOns/LibColors-1.0.git
        tag: latest

enable-nolib-creation: no
enable-toc-creation: yes

ignore:
    - libs/LibStub/tests
    - libs/HereBeDragons/CallbackHandler-1.0
    - libs/HereBeDragons/LibStub
```

---

## Target Directory Structure After Phase 1

```
QuestHUD/
├── QuestHUD.toc
├── QuestHUD.xml
├── QuestHUD.lua                  ← FarmHud.lua renamed + stripped
├── QuestHUD_Options.lua          ← FarmHud_Options.lua renamed (content stubbed)
├── QuestHUD_DataBroker.lua       ← FarmHud_DataBroker.lua renamed
├── QuestHUD_RouteEngine.lua      ← NEW stub
├── QuestHUD_RouteData.lua        ← NEW stub
├── QuestHUD_InfoPanel.lua        ← NEW stub
├── QuestHUD_Arrow.lua            ← NEW stub
├── QuestHUD_BonusDetector.lua    ← NEW stub
├── QuestHUD_Gathering.lua        ← NEW stub
├── QuestHUD_NodeData.lua         ← NEW stub (generate with extract_nodes.py)
├── QuestHUD_FirstCraft.lua       ← NEW stub
├── Localization.lua              ← copied from FarmHUD
├── Bindings.xml                  ← renamed + bindings updated
├── modules/
│   └── CardinalPoints.lua        ← copied from FarmHUD as-is
├── media/
│   ├── arrows1.tga
│   ├── Mouse-Active.tga
│   ├── Mouse-Highlight.tga
│   ├── Mouse-Normal.tga
│   ├── Mouse-Pushed.tga
│   ├── mouse1.tga / mouse2.tga / mouse3.tga
│   ├── options.tga
│   ├── playerDot-black.tga
│   ├── playerDot-blizz-smaller.tga
│   ├── playerDot-gold.tga
│   ├── playerDot-hide.tga
│   ├── playerDot-white.tga
│   └── trail-arrow-1.tga
│   ← gathercircle.tga NOT copied
├── tools/
│   └── extract_nodes.py          ← node data extraction script
├── libs/                         ← pulled by packager at build time
│   ├── LibStub/
│   ├── CallbackHandler-1.0/
│   ├── AceGUI-3.0/
│   ├── AceConfig-3.0/
│   ├── LibDataBroker-1.1/
│   ├── LibDBIcon-1.0/
│   ├── HereBeDragons/
│   └── LibColors-1.0/
├── .pkgmeta
└── .github/
    └── workflows/
        └── packager.yml
```

---

## Known Issues to Handle

### 1. HizurosSharedTools removal
FarmHud.lua references `LibStub("HizurosSharedTools")` at the very top for debug printing and the invalid installation check. Remove the entire block:
```lua
-- REMOVE THIS ENTIRE BLOCK:
if not LibStub.libs["HizurosSharedTools"] or ... then
    ...
    StaticPopup_Show("FARMHUD_INVALID_INSTALLATION")
end
local addon, ns = ...
ns.debugMode = ...
LibStub("HizurosSharedTools").RegisterPrint(ns, addon, "FH");
```
Replace with a minimal debug stub:
```lua
local addon, ns = ...
ns.debugMode = false
ns.print = function(_, msg) print("|cff00ff00[QuestHUD]|r " .. tostring(msg)) end
```

### 2. ADDON_ACTION_FORBIDDEN (Midnight)
FarmHUD's README documents this issue: `PingLocation` is protected in Midnight. QuestHUD does not use `PingLocation` so this is not a concern. However, any `C_SuperTrack` calls must be wrapped in `pcall()` as a precaution:
```lua
local ok, err = pcall(function()
    C_SuperTrack.SetSuperTrackedQuestID(questID)
end)
if not ok then
    ns:print("SuperTrack error: " .. tostring(err))
end
```

### 3. Minimap variable reference
`FarmHud.lua` caches `Minimap` as a local at the top. Keep this — QuestHUD uses the same minimap hijack:
```lua
local Minimap = _G.Minimap  -- keep this line
```

### 4. QuestArrow sub-addon
The original FarmHUD has a `QuestArrow/` sub-addon with its own `.toc`. This was loaded via the `.pkgmeta` `move-folders` directive. Remove the `move-folders` section entirely from `.pkgmeta` — QuestHUD handles quest tracking internally.

---

## Acceptance Criteria for Phase 1

Before ending the session, verify:

- [ ] `QuestHUD/` directory exists with all files listed in the target structure
- [ ] `QuestHUD.toc` loads only `## Interface: 120001` (Retail Midnight only)
- [ ] No remaining `FarmHud` (case-sensitive) strings anywhere in `.lua`, `.xml`, `.toc`, `.xml` files — run: `grep -r "FarmHud" QuestHUD/`
- [ ] No remaining `FarmHudDB` references — run: `grep -r "FarmHudDB" QuestHUD/`
- [ ] `RangeCircles.lua` and `TrailPath.lua` do not exist in `QuestHUD/`
- [ ] `gathercircle.tga` does not exist in `QuestHUD/media/`
- [ ] `QuestArrow/` directory does not exist in `QuestHUD/`
- [ ] All 8 new stub `.lua` files exist and contain valid Lua (no syntax errors)
- [ ] `tools/extract_nodes.py` exists in the repo
- [ ] `.pkgmeta` references `package-as: QuestHUD` and has no `move-folders` section
- [ ] `Bindings.xml` uses `QUESTHUD` header and `TOGGLEQUESTHUD*` names

---

## Quick Validation Commands

Run these in the terminal after completing Phase 1:

```bash
# 1. Check for any remaining FarmHud references
grep -rn "FarmHud" QuestHUD/ --include="*.lua" --include="*.xml" --include="*.toc"
# Expected: 0 results

# 2. Check all stub files exist
ls QuestHUD/QuestHUD_*.lua
# Expected: 8 files

# 3. Basic Lua syntax check on all files (requires luac)
for f in QuestHUD/*.lua QuestHUD/modules/*.lua; do
    luac -p "$f" && echo "OK: $f" || echo "FAIL: $f"
done

# 4. Verify media files
ls QuestHUD/media/
# gathercircle.tga should NOT appear

# 5. Confirm stub tables load (requires lua 5.1)
lua -e "dofile('QuestHUD/QuestHUD_RouteData.lua'); print('RouteData OK, steps:', #QuestHUD_Route)"
```

---

## Next Phase Preview

Once Phase 1 passes all acceptance criteria, Phase 2 will implement:
- `QuestHUD_Arrow.lua` — HereBeDragons bearing calculation, 24fps rotation ticker
- `QuestHUD_RouteEngine.lua` — `QUEST_LOG_UPDATE` handler, completion filtering, hub sorting
- `C_SuperTrack` integration to auto-set the super-tracked quest
- First working playthrough of Eversong Woods chapters 1–3

---

## Reference: Key WoW APIs Used in Phase 2+

For context — do not implement these in Phase 1, but be aware they exist:

```lua
-- Quest state
C_QuestLog.IsQuestFlaggedCompleted(questID)
C_QuestLog.GetQuestObjectives(questID)
C_QuestLog.GetAllCompletedQuests()

-- Arrow bearing
HereBeDragons:GetDirectionToPlayerFromCoords(mapID, x, y)
GetPlayerFacing()  -- player's current facing in radians

-- Position
C_Map.GetPlayerMapPosition(mapID, "player")  -- returns Vector2D or nil

-- Super tracking
C_SuperTrack.GetSuperTrackedQuestID()
C_SuperTrack.SetSuperTrackedQuestID(questID)  -- wrap in pcall()

-- XP
UnitXP("player")
UnitXPMax("player")
GetXPExhaustion()  -- Rested XP remaining, nil if none

-- Professions (for gathering overlay)
GetProfessions()  -- returns up to 6 slot indices
GetProfessionInfo(slot)  -- returns name, ...
```
