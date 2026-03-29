# QuestHUD — Product Requirements Document
**Version:** 1.0  
**Date:** 2026-03-29  
**Author:** PRD Creation Assistant  
**Source References:** FarmHud-master (codebase), WoW_Midnight_Leveling_Guide (routing data)

---

## 1. App Overview & Objectives

### What Is QuestHUD?

QuestHUD is a World of Warcraft addon for **Retail (Midnight / Patch 12.x)** that overlays a full-screen HUD — replacing the minimap, in the same manner as FarmHUD — and displays a dynamically ordered quest route optimised for maximum XP-per-minute efficiency across the level 80→90 range.

It combines three concepts into a single cohesive tool:

| Inspiration | Contribution to QuestHUD |
|---|---|
| **FarmHUD** | HUD overlay system, minimap takeover, coordinate rendering via HereBeDragons, cardinal points, modular Lua architecture |
| **TomTom** | Directional arrow pointing to next objective (via shared HereBeDragons library — already compatible) |
| **Zygor / RestedXP** | Pre-authored route backbone with live quest state overlay |

### Primary Goal

> Guide players from **level 80 to 90 in under 2 hours** (alts with full XP bonus stack: War Mode + Rested XP + Warband Mentor + Heirlooms) without entering dungeons, using a HUD-driven, arrow-guided quest route covering all quests — campaign, side quests, and Tier 1 Delve first-time quests — at each zone hub.

### Design Principles

1. **Zero context-switching** — the player should never need to open the map or quest journal to know where to go next.
2. **Route discipline** — the addon enforces the "hub cluster" philosophy: complete everything at your current location before moving, never detour for isolated quests.
3. **Live state awareness** — the route adapts to what's already completed; characters mid-playthrough get placed into the correct position automatically.
4. **Adaptive** — detects active XP bonuses (War Mode, Rested XP, heirlooms, Warband Mentor) and displays an estimated completion time accordingly.

---

## 2. Target Audience

| Segment | Description |
|---|---|
| **Primary — Alts** | Alt players speed-levelling to 90 with the full Warband XP bonus stack (sub-2 hr target) |
| **Primary — First Characters** | Fresh characters progressing through Midnight at an optimised pace (5–7 hr target) |
| **Tertiary** | Completionists who want all quests routed efficiently, not just campaign chapters |

**Adaptive behaviour:** On load, QuestHUD detects which XP bonuses are active (War Mode, Warband Mentor, Rested XP, Heirlooms) and adjusts the displayed time estimate accordingly. A first character with no bonuses sees a ~6 hr estimate; an alt with full stack sees ~1h 45m. The route itself is identical — only the time estimate and pacing commentary changes.

**User skill level:** Intermediate WoW players comfortable with addon installation. No configuration required — the addon works correctly on first install with sensible defaults.

---

## 3. Core Features & Functionality

### 3.1 HUD Overlay (FarmHUD Architecture)

**Description:** Replaces the minimap with a full circular HUD overlay, centred on the player, showing cardinal directions, the quest arrow, and the objective info panel.

**Technical approach:** Fork FarmHUD's minimap hijack system. The HUD uses `FarmHudMixin` pattern, `HereBeDragons-2.0` for world coordinate transforms, and `HereBeDragons-Pins-2.0` for pin rendering. The existing `FarmHud.xml` frame structure is retained and extended with new child frames for the quest info panel.

**Key behaviours:**
- Toggled via minimap button or `/qhud` slash command
- Minimap is hidden while HUD is active (same "only one" constraint as FarmHUD — Blizzard limitation)
- HUD size is user-configurable (small / medium / large presets)
- Supports ElvUI, SexyMap, BasicMinimap (same compatibility list as FarmHUD)

**Acceptance criteria:**
- HUD renders correctly on first `/qhud` toggle with no configuration
- Toggling off restores the minimap to its previous state
- No Lua errors on `ADDON_ACTION_FORBIDDEN` (known Midnight issue — use same workaround as FarmHUD: disable ping function until `/reload`)

---

### 3.2 Directional Arrow

**Description:** A large, animated directional arrow displayed in the centre of the HUD pointing toward the next quest objective.

**Technical approach:** Uses `HereBeDragons-2.0` bearing calculation (`HBD:GetDirectionToPlayerFromCoords()`). Does NOT require TomTom to be installed — QuestHUD provides its own arrow, but is TomTom-compatible (will suppress TomTom's own arrow when QuestHUD is active to avoid duplication).

**Arrow data source:** The active route step's target coordinates. Coordinates are stored per quest objective in the route data table (see Section 6).

**Key behaviours:**
- Arrow rotates smoothly at 24fps (same ticker rate as FarmHUD's cardinal points)
- Arrow pulses when the player is within 10 yards of the objective (arrival indicator)
- Arrow colour changes by quest type: gold (main campaign), teal (side quest), purple (delve)
- When TomTom is installed, QuestHUD registers as a `TomTom` waypoint handler and suppresses the duplicate arrow

**Acceptance criteria:**
- Arrow points correctly in all four cardinal directions verified against known coords
- Colour-coding is visually distinct at a glance
- Arrival pulse triggers within ±2 yards of the 10-yard threshold
- No arrow rendering when no active route step is loaded

---

### 3.3 Quest Route Engine

**Description:** The core logic system that maintains the ordered route, tracks completion state against the live WoW quest API, and surfaces the correct "next objective" at all times.

**Technical approach:** Hybrid model — a pre-authored route backbone (hardcoded Lua table of quest IDs, coordinates, and metadata) overlaid with live state from the WoW C API.

#### Route Backbone Structure (Lua data table)

```lua
QuestHUD_Route = {
  {
    step = 1,
    zone = "Eversong Woods",
    hub = "Isle of Quel'Danas",
    level_range = {80, 81},
    quests = {
      {
        id = XXXXX,          -- numeric quest ID from Wowhead
        name = "Whispers in the Twilight",
        type = "campaign",   -- "campaign" | "side" | "delve"
        coords = {x=52.4, y=31.1, mapID=2248},
        xp = 45000,
        priority = 1,        -- lower = do first
        prereqs = {},        -- quest IDs that must be complete first
        objective_coords = { -- one entry per quest objective
          {x=55.1, y=28.3, mapID=2248, label="Defend the Sunwell"},
        }
      },
      -- ... more quests at this hub
    }
  },
  -- ... more steps
}
```

#### Zone Order (from leveling guide)

| Step | Zone | Chapters | Level Range | Notes |
|---|---|---|---|---|
| 1 | Eversong Woods | 3 | 80–83 | Mandatory first. Set hearth to Silvermoon. |
| 2 | Zul'Aman | 4 | 83–88 | Densest. Do first of the three branches. |
| 3 | Harandar | 3 | 83–88 | Shadow Enclave Delve required (campaign-gated). |
| 4 | Arator's Journey | 4 | 83–88 | Most travel. Do last of the three branches. |
| 5 | Voidstorm | 3 | 88–90 | Enter at 87+. Gear scales with level. |

#### Live API Integration

The route engine queries the following WoW C API functions on every `QUEST_LOG_UPDATE` event:

| API Function | Purpose |
|---|---|
| `C_QuestLog.GetAllCompletedQuests()` | Populate completion bitmask on load |
| `C_QuestLog.IsQuestFlaggedCompleted(questID)` | Per-quest completion check |
| `C_QuestLog.GetQuestObjectives(questID)` | Objective progress text |
| `C_QuestLog.GetQuestInfo(questID)` | Quest name, level, type |
| `C_QuestLog.GetQuestDifficultyLevel(questID)` | Colour difficulty indicator |
| `C_SuperTrack.GetSuperTrackedQuestID()` | What Blizzard is currently tracking |
| `C_SuperTrack.SetSuperTrackedQuestID(questID)` | Override Blizzard tracking |
| `C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)` | Player vs quest level delta |
| `UnitXP("player")` / `UnitXPMax("player")` | Current XP progress |
| `GetPlayerFacing()` | Bearing for arrow calculation |
| `C_Map.GetPlayerMapPosition(mapID, "player")` | Player coords for distance calc |

#### Route Selection Logic (Priority Algorithm)

On each `QUEST_LOG_UPDATE` the engine:

1. Filters the route table to quests in the current hub cluster (zone + hub match)
2. Removes any quest flagged as completed via `IsQuestFlaggedCompleted()`
3. Removes quests whose `prereqs` are not yet complete
4. Sorts remaining quests by: `priority ASC → distance ASC` (closest incomplete quest at highest priority first)
5. Returns the top result as the `activeStep`
6. When all quests in a hub are complete, advances to the next hub in the route

**Acceptance criteria:**
- Completing a quest removes it from the HUD within 2 seconds of turn-in
- A character mid-playthrough (some quests done) is correctly placed into the route on first load
- Quest prereq chains are respected (e.g., chapter 2 quests don't appear until chapter 1 is complete)
- Distance sorting correctly selects the geographically nearest available quest
- Route advances to next hub automatically when all hub quests are complete

---

### 3.4 Objective Info Panel (HTML Renderer)

**Description:** A compact info panel rendered below the HUD arrow using WoW's `HTMLText` frame (the same system used by the quest log) displaying the active quest name, current objective text, XP value, and quest type badge.

**Why HTML rendering:** The WoW API supports a subset of HTML in `SimpleHTML` frame objects. This allows rich text formatting (bold, colour, links) without requiring textures, making it easy to update and style.

**Panel layout (all four confirmed display elements):**

```
┌──────────────────────────────────────────┐
│ [●] CAMPAIGN  •  Zul'Aman Ch.2           │  ← type badge + zone
│ Loa of the Lost                          │  ← quest name (bold)
│ ▶ Investigate Akil'zon Temple: 0/1       │  ← next quest objective name + progress
│ ✦ 52,000 XP  •  📍 340 yds  •  ~1h 42m  │  ← XP value · distance · time remaining
└──────────────────────────────────────────┘
```

**Display element specifications:**

| Element | Source | Update trigger | Format |
|---|---|---|---|
| **Next quest objective name** | `C_QuestLog.GetQuestObjectives(questID)` | `QUEST_LOG_UPDATE` | "Objective text: N/M" |
| **XP value of quest** | `C_QuestLog.GetQuestInfo(questID)` → `xpReward` | On step change | "✦ 52,000 XP" — green text |
| **Distance to objective** | `C_Map.GetPlayerMapPosition()` vs objective coords | Every 1s ticker | "📍 340 yds" — grey text; switches to "📍 Nearby" under 10 yds |
| **Estimated time remaining** | XP bonus detector + `UnitXP()` + `UnitXPMax()` | On level-up + bonus change | "~1h 42m" — gold text on track, orange if behind pace |

**Technical approach:** Uses `CreateFrame("SimpleHTML")` with a custom stylesheet. Content is set via `frame:SetText(htmlString)` rebuilt on each `QUEST_LOG_UPDATE`.

**Acceptance criteria:**
- Panel updates within 1 second of quest objective progress
- HTML renders without Lua errors on all supported WoW client versions (Retail 12.x)
- Panel is draggable and position is saved to `SavedVariables`
- Panel can be hidden independently of the HUD arrow

---

### 3.5 XP Bonus Detector & Time Estimator

**Description:** Automatically detects active XP bonuses and displays a live estimated completion time on the HUD panel.

**Detected bonuses:**

| Bonus | Detection Method |
|---|---|
| War Mode | `C_PvP.IsWarModeDesired()` |
| Rested XP | `GetXPExhaustion()` returns non-nil |
| Heirlooms | `C_Heirloom.GetHeirloomInfo()` for equipped slots |
| Darkmoon WHEE! | `C_UnitAuras.GetPlayerAuraBySpellID(46668)` |
| Warband Mentor | `C_UnitAuras.GetPlayerAuraBySpellID(?)` (confirm spell ID at implementation) |

**Time estimation formula:**

```
remainingXP = totalXPRequired - currentXP
bonusMultiplier = product of all active bonus multipliers
adjustedXPPerHour = baselineXPPerHour * bonusMultiplier
estimatedMinutes = (remainingXP / adjustedXPPerHour) * 60
```

`baselineXPPerHour` is derived from empirical testing of the route (to be calibrated during alpha).

**Acceptance criteria:**
- Bonus state updates within 5 seconds of a buff being gained or lost
- Time estimate displayed as "~1h 45m remaining" format
- Estimate recalculates on each level-up

---

### 3.6 Delve Integration

**Description:** Tier 1 Delves with a first-time completion quest are included in the route at the appropriate hub stop. The addon tracks whether the first-time quest has been picked up and completed.

**In-scope delves (Midnight):**

| Delve | Zone | Trigger | Notes |
|---|---|---|---|
| Shadow Enclave | Harandar | Campaign-required | Mandatory — do not skip |

Additional Tier 1 delves to be added as confirmed at launch.

**Key behaviours:**
- Delve first-time quest appears in the route at the point the guide recommends (Shadow Enclave during Harandar chapter)
- The route step shows a purple arrow and "DELVE" badge
- After the first-time quest is complete, the delve is removed from the route permanently (repeat clears have negligible XP — do not re-queue)
- A warning is shown if the player enters a delve without the first-time quest in their log

**Acceptance criteria:**
- Shadow Enclave appears correctly as a route step during Harandar chapter 2
- Completing the first-time quest removes the delve from the active route
- Warning fires on delve entry without quest in log

---

### 3.7 Gathering Node Overlay (Self-Contained, No Dependencies)

**Description:** QuestHUD includes its own bundled node database and its own live node collector — no GatherMate2 installation required. Mining and Herbalism nodes are displayed on the HUD as small coloured dots while questing. The player gathers *en route*, never detouring.

**Why this matters for levelling:** The leveling guide documents ~2,500–4,000 XP per node across 80→90 — roughly one full level of bonus XP. Every node gathered while moving between quest objectives is free XP at zero travel cost if route-aligned.

---

#### Architecture: Two-Layer Node System

QuestHUD uses a **hybrid approach** — a bundled community database as the starting baseline, continuously enriched by the player's own live collection during play:

```
Layer 1: QuestHUD_NodeData.lua     ← Bundled at install (pre-populated, static)
Layer 2: SavedVariables (live)     ← Player collects new nodes during play (dynamic)
```

On each HUD update, both layers are merged in memory — live data takes priority over bundled data for the same coordinate (player data is fresher).

---

#### Layer 1 — Bundled Node Database

**Source:** Extracted and re-formatted from GatherMate2_Data community database (Wowhead data dump), filtered to Midnight and Arator's Journey zones only. This is a one-time extraction done at build time — the GatherMate2_Data addon is not required at runtime.

**Bundled zones and node counts (confirmed from GatherMate2_Data source):**

| Zone | mapID | Herb nodes | Mine nodes |
|---|---|---|---|
| Eversong Woods (Midnight) | 2393 | 63 | 0 |
| Zul'Aman (Midnight) | 2395 | 2,431 | 1,345 |
| Harandar (Midnight) | 2405 | 1,350 | 571 |
| Arator's Journey hub zones | 2413 | 1,320 | 752 |
| Voidstorm (Midnight) | 2437 | 1,619 | 1,396 |
| Arathi Highlands | 14 | 631 | 573 |
| Blackrock Mountain | 25 | 975 | 438 |
| Eastern Plaguelands | 27 | 417 | 133 |
| **Total bundled** | | **~8,806 nodes** | **~5,208 nodes** |

**Bundled data size:** ~243 KB uncompressed (152 KB herb + 91 KB mine). Compressed inside the addon `.zip` this becomes approximately 80 KB — well within acceptable addon size limits.

**Data format** (directly ported from GatherMate2's encoding — no conversion needed at runtime):

```lua
-- QuestHUD_NodeData.lua
QuestHUD_BundledHerbDB = {
  [2395] = {  -- Zul'Aman mapID
    [3560343000] = 1481,  -- coord (packed) = nodeID (Argentleaf)
    [3560353000] = 1482,  -- Azeroot
    -- ...
  },
  -- ...
}

QuestHUD_BundledMineDB = {
  [2395] = {
    [2520294000] = 1245,  -- Brilliant Silver
    -- ...
  },
}
```

**Coord encoding** (identical to GatherMate2, fully self-contained):
```lua
-- Encode
local function EncodeLoc(x, y)
    return math.floor(x * 10000 + 0.5) * 1000000 + math.floor(y * 10000 + 0.5) * 100
end
-- Decode  
local function DecodeLoc(id)
    return math.floor(id / 1000000) / 10000, math.floor(id % 1000000 / 100) / 10000
end
```

These are zone-relative 0–1 fractions — the same format HereBeDragons uses. Zero conversion needed for HUD pin positioning.

---

#### Layer 2 — Live Node Collection

QuestHUD replicates the node collection logic from GatherMate2's `Collector.lua`, stripped down to Herb and Mining only. The events and spell IDs are confirmed from GatherMate2 source:

**Spell IDs (confirmed):**

| Profession | Spell | spellID |
|---|---|---|
| Herbalism | Herb Gathering | 2366 |
| Mining (classic) | Mining | 2575 |
| Mining (Legion+) | Mining | 195122 |
| Mining (Khaz Algar) | Mining | 423341 |
| Mining (Midnight) | Mining | 471013 |

**Collection event sequence:**
```
UNIT_SPELLCAST_SENT   → player begins casting gather spell → record spell + target name
CURSOR_CHANGED        → hand cursor appears over node → GetWorldTarget() reads tooltip
UNIT_SPELLCAST_STOP   → cast completes → confirm target → save to SavedVariables
UNIT_SPELLCAST_FAILED → cast interrupted → discard
```

**Node storage in SavedVariables:**
```lua
-- Per-character, merged at runtime with bundled DB
QuestHUDDB["CharName-Realm"].collectedNodes = {
  herb = {
    [2395] = { [3560343000] = 1481, ... }
  },
  mine = {
    [2395] = { [2520294000] = 1245, ... }
  }
}
```

**Midnight node types (confirmed from GatherMate2 Constants.lua):**

*Herbalism (IDs 1481–1484):* Argentleaf, Azeroot, Mana Lily, Sanguithorn — each with Lush / Lightfused / Primal / Transplanted / Voidbound / Wild variants.

*Mining (IDs 1245–1250):* Brilliant Silver, Brilliant Silver Seam, Refulgent Copper, Refulgent Copper Seam, Umbral Tin, Umbral Tin Seam — each with Rich / Lightfused / Primal / Voidbound / Wild variants.

---

#### HUD Rendering

Nodes are rendered as small coloured pins on the HUD using `HereBeDragons-Pins-2.0` (already bundled from FarmHUD):

| Node type | Colour | Dot size | Condition |
|---|---|---|---|
| Herbalism | Green `(0, 1, 0)` | 8px | Player has Herbalism profession |
| Mining | Orange-red `(1, 0.35, 0)` | 8px | Player has Mining profession |

**Display radius:** Nodes within 80 yards rendered on HUD. Configurable 20–150 yds in options.

**Priority rule:** Node dots are a passive awareness layer. The quest arrow always points to the next quest objective — nodes never redirect it. The player sees them and chooses to gather while passing.

**Profession detection:**
```lua
-- Called on SKILL_LINES_CHANGED
local function DetectProfessions()
    local p1, p2 = GetProfessions()
    for _, slot in ipairs({p1, p2}) do
        if slot then
            local name = GetProfessionInfo(slot)
            if name == HERBALISM_NAME then hasHerbalism = true end
            if name == MINING_NAME    then hasMining    = true end
        end
    end
end
```

If the player has neither profession, the node overlay is hidden entirely — no performance cost.

**Acceptance criteria:**
- Herb nodes render as green dots within 80 yards when player has Herbalism
- Mine nodes render as orange dots when player has Mining
- Both render simultaneously if player has both professions
- No node dots render outside Midnight and Arator's Journey mapIDs
- Live-collected nodes appear on the HUD immediately after gathering
- Bundled nodes render on first login with no prior play required
- Toggling gathering overlay off in options hides all node dots immediately
- No GatherMate2 installation required at any point

---

### 3.8 First Craft XP Bonus Integration

**Description:** QuestHUD tracks first-craft XP bonus opportunities and surfaces a reminder at the optimal moment in the route — at the Silvermoon City hub after Eversong chapter 2.

#### Profession Recommendation

> **Recommended: Herbalism + Alchemy**

**Reasoning:**

| Factor | Herbalism + Alchemy | Mining + Blacksmithing | Mining + Engineering |
|---|---|---|---|
| Gathering XP/node | ✅ 2,500–4,000 | ✅ 2,500–4,000 | ✅ 2,500–4,000 |
| Midnight node density | ✅ High (4 herb types) | ✅ High (3 ore types) | ✅ Same as Mining |
| First craft recipe density | ✅ High — every new potion | ⚠️ Moderate — fewer recipes early | ✅ Good early density |
| Self-sufficient reagents | ✅ Gather your own herbs | ✅ Smelt your own ore | ⚠️ Needs herbs/cloth too |
| Useful output while levelling | ✅ Healing/mana potions | ⚠️ Gear replaced by 82 | ⚠️ Limited combat value |
| No AH dependency | ✅ Fully self-sufficient | ✅ Fully self-sufficient | ⚠️ Some components needed |
| **Verdict** | ✅ **Winner** | 2nd | 3rd |



#### First Craft XP — How It Works

Each new recipe crafted for the first time grants a "First Craft" XP bonus scaling with recipe level. QuestHUD tracks this via `C_TradeSkillUI` — not spell IDs, which are less stable across patches:

```lua
-- After any craft event fires:
local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
if info and info.numCrafted == 1 then
    -- This was a first craft — record dismissal
    QuestHUDDB[charKey].firstCraftDismissed[profName] = true
end
```

**Route injection:** A special "CRAFT" step type appears in the route at Silvermoon hub (end of Eversong chapter 2):

```
┌──────────────────────────────────────┐
│ [⚗] FIRST CRAFT  •  Silvermoon City │
│ Open Alchemy — craft 3 new potions  │
│ ✦ ~9,000 XP bonus  •  📍 At hub    │
└──────────────────────────────────────┘
```

- Appears only once per character per profession (tracked in `SavedVariables`)
- Does not block route advancement — arrow continues to next quest if skipped
- Auto-dismisses when first-craft events fire for the suggested recipes
- If player has neither Herbalism nor Alchemy, the step is never injected

**Acceptance criteria:**
- Craft reminder appears at Silvermoon hub if player has Alchemy
- Reminder is dismissed permanently after first-craft events detected
- Reminder never re-appears once dismissed (per character, per profession)
- If no applicable profession detected, step is silently absent from route

---

### 3.9 Options Panel

**Description:** AceConfig-3.0 driven options panel (same system as FarmHUD) accessible via `/qhud config` or Game Menu → Interface → AddOns → QuestHUD.

**Options:**

| Setting | Type | Default | Description |
|---|---|---|---|
| HUD Size | Dropdown | Medium | Small / Medium / Large |
| Arrow colour (campaign) | Colour picker | Gold | |
| Arrow colour (side quest) | Colour picker | Teal | |
| Arrow colour (delve) | Colour picker | Purple | |
| Show XP value on panel | Toggle | On | |
| Show time estimate | Toggle | On | |
| Show distance | Toggle | On | |
| Include side quests | Toggle | On | Disable for pure campaign-only speed |
| Show gathering nodes | Toggle | On | Show Herb/Mine nodes on HUD (requires GatherMate2) |
| Gathering node radius | Slider | 80 yds | Range: 20–150 yds |
| Show herb nodes | Toggle | On | Herbalism nodes specifically |
| Show mining nodes | Toggle | On | Mining nodes specifically |
| Show first craft reminder | Toggle | On | Craft XP reminder steps in route |
| Auto-advance hub | Toggle | On | Move to next hub when current is clear |
| Panel position | Reset button | — | Resets to default anchor |

**Acceptance criteria:**
- All settings persist across sessions via `SavedVariables`
- Options panel opens without Lua errors
- Toggling "Include side quests" to Off immediately hides side quest steps from the route

---

## 4. Technical Stack

| Component | Technology | Rationale |
|---|---|---|
| Language | Lua 5.1 (WoW flavour) | Required by the WoW addon API |
| Frame XML | WoW XML (`.xml`) | Declarative frame definition — matches FarmHUD pattern |
| Coordinate library | HereBeDragons-2.0 + Pins | Already bundled in FarmHUD; handles mapID transforms and pin rendering |
| Options framework | AceConfig-3.0 + AceGUI-3.0 | Standard WoW addon options; bundled in FarmHUD |
| Data broker | LibDataBroker-1.1 + LibDBIcon-1.0 | Minimap button; bundled in FarmHUD |
| Quest HTML panel | WoW `SimpleHTML` frame | Built-in WoW API; no external dependency |
| Persistence | `SavedVariables` (WoW native) | Per-character and per-account saved settings |
| Bundled node database | `QuestHUD_NodeData.lua` (self-contained) | ~243 KB uncompressed, ~80 KB compressed; Midnight + Arator zones only; extracted from GatherMate2_Data at build time — not required at runtime |
| Live node collector | `QuestHUD_Gathering.lua` (self-contained) | Replicates GatherMate2 Collector.lua logic for Herb + Mine only; enriches bundled DB over time |
| Packaging | BigWigsMods Packager (GitHub Actions) | FarmHUD's existing `.pkgmeta` + workflow — fork and adapt |

### Reused from FarmHUD (direct fork candidates)

- `FarmHud.xml` — frame structure (extend, don't replace)
- `FarmHud.lua` — minimap hijack, show/hide, module system, event wiring
- `FarmHud_Options.lua` — options pattern (replace content, keep structure)
- `FarmHud_DataBroker.lua` — minimap button (minor rename)
- `modules/CardinalPoints.lua` — retain as-is
- `modules/TrailPath.lua` — retain as-is (optional feature)
- `QuestArrow/FarmHud_QuestArrow.lua` — **replace with QuestHUD's own arrow logic**
- All `libs/` — retain as-is
- `Bindings.xml` — extend with QuestHUD-specific keybinds

---

## 5. Conceptual Data Model

### SavedVariables Schema (`QuestHUDDB`)

```lua
QuestHUDDB = {
  -- Settings (account-wide)
  settings = {
    hudSize = "medium",           -- "small" | "medium" | "large"
    showXP = true,
    showTime = true,
    showDistance = true,
    includeSideQuests = true,
    autoAdvanceHub = true,
    arrowColor = {
      campaign = {1, 0.82, 0, 1},  -- RGBA gold
      side      = {0, 0.8, 0.8, 1}, -- teal
      delve     = {0.6, 0, 1, 1},   -- purple
    },
    showGatheringNodes = true,
    gatheringRadius = 80,           -- yards
    showHerbNodes = true,
    showMineNodes = true,
    showFirstCraftReminder = true,
    panelAnchor = {point="BOTTOM", x=0, y=180},
  },
  -- Per-character progress (keyed by character name + realm)
  ["CharName-Realm"] = {
    routePosition = 1,            -- current step index in QuestHUD_Route
    completedQuestIDs = {},       -- mirror of server state for fast lookup
    bonusDetected = {
      warMode = false,
      restedXP = false,
      heirlooms = false,
      darkmoon = false,
      warbandMentor = false,
    },
    firstCraftDismissed = {
      -- keyed by professionName: true = reminder shown and dismissed
      -- e.g. ["Alchemy"] = true
    },
  }
}
```

### Route Data Table (`QuestHUD_Route`)

Stored in a separate `QuestHUD_RouteData.lua` file. Structure defined in Section 3.3 above. This file is the **primary content authoring artifact** — it will need to be populated with real quest IDs from Wowhead before beta.

---

## 6. UI Design Principles

### HUD

- **Aesthetic:** Functional, dark, minimal. No decorative chrome. Gold accents only.
- **Arrow:** Large (60×60px default), centred, animated rotation, smooth 24fps update.
- **Cardinal points:** Retained from FarmHUD — white text, semi-transparent.
- **Background:** Optional semi-transparent dark circle (same as FarmHUD toggle).

### Info Panel

- **Position:** Bottom-centre of screen by default, above action bars. Draggable.
- **Size:** ~380px wide × 80px tall (medium preset).
- **Font:** `GameFontNormal` (Friz Quadrata — WoW standard, legible at small sizes).
- **Colour coding:**
  - Campaign quests: gold text
  - Side quests: white text
  - Delves: purple text
  - XP value: green text
  - Distance: light grey text

### Minimap Button

- Uses FarmHUD's LibDBIcon pattern.
- Tooltip shows: current step name, quests remaining at hub, estimated time.

---

## 7. Security & Compatibility Considerations

### Known Midnight API Restrictions

- **`PingLocation` is protected** in Midnight (same issue FarmHUD documents in its README). QuestHUD does not use `PingLocation` — uses HereBeDragons bearing instead. Not affected.
- **`C_SuperTrack.SetSuperTrackedQuestID`** may be protected in some contexts. Use the same replacement wrapper pattern as `FarmHud_QuestArrow.lua` — wrap the function and restore on hide.
- **`ADDON_ACTION_FORBIDDEN`** — any protected function called from an addon event handler will throw this. Test all C_SuperTrack calls in a `pcall()` wrapper during development.

### FarmHUD Coexistence

When TomTom is loaded:
- QuestHUD detects it via `C_AddOns.IsAddOnLoaded("TomTom")`
- QuestHUD suppresses TomTom's crazy arrow for its own managed quest waypoints
- TomTom's user-set waypoints (non-quest) are unaffected

### TomTom Coexistence

When TomTom is loaded:
- QuestHUD detects it via `C_AddOns.IsAddOnLoaded("TomTom")`
- QuestHUD suppresses TomTom's crazy arrow for its own managed quest waypoints
- TomTom's user-set waypoints (non-quest) are unaffected

### FarmHUD Coexistence

QuestHUD and FarmHUD **cannot run simultaneously** (both hijack the minimap). If FarmHUD is detected:
- Show a one-time chat warning: "QuestHUD: FarmHUD detected. Disable FarmHUD or QuestHUD to avoid conflicts."
- QuestHUD remains disabled until FarmHUD is toggled off.

### Interface Version Support

Target: Retail only (`## Interface: 120001`). No Classic/Cataclysm/Wrath support.

---

## 8. Development Phases & Milestones

### Phase 1 — Foundation (Week 1–2)

**Goal:** Working HUD overlay with directional arrow and static test route.

- [ ] Fork FarmHUD repository, rename addon to QuestHUD
- [ ] Strip farming-specific code (node tracking, GatherMate2 integration, RangeCircles)
- [ ] Rename all `FarmHud*` globals to `QuestHUD*` (use find-replace, be thorough)
- [ ] Confirm HUD renders in Midnight with no errors
- [ ] Implement static arrow pointing to a hardcoded test coordinate
- [ ] Confirm `HereBeDragons` bearing calculation is correct against known coords
- [ ] Stub `QuestHUD_RouteData.lua` with 3 Eversong Woods quests

**Deliverable:** HUD shows, arrow points to a hardcoded location. No crashes.

---

### Phase 2 — Route Engine (Week 3–4)

**Goal:** Live quest state drives the arrow.

- [ ] Implement `QuestHUD_RouteData.lua` with full Eversong Woods chapter 1–3 quest IDs + coords
- [ ] Implement route engine: `QUEST_LOG_UPDATE` handler, completion filtering, priority sort
- [ ] Implement `C_SuperTrack` integration — auto-set super-tracked quest to match active step
- [ ] Implement hub advancement logic (all hub quests done → move to next hub)
- [ ] Implement mid-playthrough placement (character with some quests already done loads into correct step)
- [ ] Test on a level 80 character entering Midnight fresh

**Deliverable:** Arrow guides correctly through Eversong Woods chapter 1–3.

---

### Phase 3 — Info Panel & Full Route Data (Week 5–6)

**Goal:** All zones populated, info panel working.

- [ ] Implement `SimpleHTML` info panel with objective text, XP, distance
- [ ] Populate `QuestHUD_RouteData.lua` for Zul'Aman, Harandar (+ Shadow Enclave delve), Arator's Journey, Voidstorm
- [ ] Research and confirm all quest IDs via Wowhead (Midnight quest database)
- [ ] Implement side quest filtering (toggle in options)
- [ ] Implement delve first-time quest integration
- [ ] Implement TomTom coexistence / arrow suppression
- [ ] Implement GatherMate2 node overlay — Herb + Mine nodes on HUD using `GetNodesForZone()` iterator
- [ ] Implement profession detection for node filtering (`GetProfessions()`)
- [ ] Implement first craft reminder: Alchemy route injection at Silvermoon hub, `C_TradeSkillUI` detection, `SavedVariables` dismissal tracking

**Deliverable:** Full 80→90 route playable end-to-end.

---

### Phase 4 — XP Bonuses, Options & Polish (Week 7–8)

**Goal:** Time estimator, full options panel, polish.

- [ ] Implement XP bonus detector (War Mode, Rested, Heirlooms, Darkmoon, Warband Mentor)
- [ ] Implement time estimator with empirical baseline calibration
- [ ] Build full AceConfig options panel
- [ ] Implement `SavedVariables` persistence for all settings
- [ ] Implement draggable info panel with position save
- [ ] FarmHUD / TomTom conflict detection and warnings
- [ ] Localisation stub (enUS only for v1.0)
- [ ] README, `.pkgmeta`, GitHub Actions packager setup

**Deliverable:** v0.1 alpha release on GitHub / Wago.io.

---

### Phase 5 — Alpha Testing & Route Calibration (Week 9–10)

**Goal:** Verify sub-2-hour target on alt with full bonus stack.

- [ ] Full timed run with War Mode + Warband Mentor + Rested XP + Heirlooms
- [ ] Calibrate `baselineXPPerHour` for time estimator
- [ ] Fix any route ordering issues discovered in testing
- [ ] Community feedback on Wago.io
- [ ] Fix reported bugs

**Deliverable:** v0.2 beta with calibrated time estimates.

---

## 9. Potential Challenges & Solutions

| Challenge | Risk | Solution |
|---|---|---|
| Quest IDs not yet datamined | High (pre-launch) | Use the Wowhead PTR database; Midnight quest IDs will be scraped before launch. Stub with `0` and populate in a pre-launch update. |
| Objective coordinates not in API | Medium | `C_QuestLog.GetQuestObjectives()` returns text but not coords. Coords must be sourced from Wowhead and hardcoded in `QuestHUD_RouteData.lua`. |
| Route ordering wrong at launch | Medium | The route is based on the leveling guide. Any post-patch quest reordering (Blizzard changes) requires a route data update — not an engine fix. |
| `ADDON_ACTION_FORBIDDEN` | Medium | Wrap all `C_SuperTrack` calls in `pcall()`. Match FarmHUD's existing workaround pattern. |
| Sub-2-hour target only achievable with full bonus stack | Known | Document clearly in README: "Sub-2-hour requires: Alt + War Mode + Warband Mentor + Rested XP + Heirlooms." Provide the per-bonus time estimates from the time estimator. |
| Bundled node data goes stale | Low | The bundled DB is a snapshot. Live collection enriches it over time. A data refresh can be shipped as an addon update (same as GatherMate2_Data does via point releases). |
| Mining spell ID changes post-launch | Low | Four mining spell IDs are already confirmed (2575, 195122, 423341, 471013). If Blizzard adds a new one in a patch, a single-line update to `QuestHUD_Gathering.lua` fixes it — no architectural change needed. |
| Bundled data size concern | None | 243 KB uncompressed / ~80 KB compressed is well within CurseForge/Wago limits. Modern addons routinely ship 1–5 MB. |
| Arator's Journey cross-continent travel | Low | Route engine handles mapID transitions — HereBeDragons supports multi-map coords. Ensure Plaguelands, Arathi, Blackrock Mountain mapIDs are correctly referenced. |

---

## 10. Future Expansion Possibilities

| Feature | Description |
|---|---|
| **Route profiles** | Multiple selectable routes (speed / loremaster / alt) — selectable in options |
| **Dungeon integration** | Optional "include one dungeon at the right point" mode (Den of Nalorakk triple-stack method) |
| **Fishing node overlay** | Add GatherMate2 fishing pool pins (node IDs 1131–1141 for Midnight) for players with Fishing |
| **Community route sharing** | Wago.io-linked route import/export via a simple JSON format |
| **Other level brackets** | 70→80 (The War Within), 60→70 (Dragonflight) routes using the same engine |
| **Session stats panel** | Post-session summary: total XP gained, time taken, nodes gathered, quests completed vs. estimated — shareable screenshot format |
| **Mercyful integration** | Guild-specific route notes / annotations for guild leveling events |

---

## 11. Pre-Population Checklist (Before Coding Starts)

Before writing any code, the following research must be completed:

- [ ] **Node data extraction:** Run the build-time Python extraction script against GatherMate2_Data source to generate `QuestHUD_NodeData.lua` for Midnight mapIDs (2393, 2395, 2405, 2413, 2437) and Arator's Journey zones (14, 25, 27). Validate node counts match expected totals (~8,800 herb, ~5,200 mine).
- [ ] **Quest IDs:** Source all Midnight quest IDs from Wowhead PTR for all 17 campaign chapters + side quests at each hub. Record in a spreadsheet before adding to `QuestHUD_RouteData.lua`.
- [ ] **Objective coordinates:** For each quest, record the coordinates of each objective from the PTR or Wowhead comments. These cannot be auto-detected and must be hardcoded.
- [ ] **Delve quest IDs:** Confirm the Shadow Enclave first-time completion quest ID and any additional Tier 1 delves with associated quests.
- [ ] **Warband Mentor spell ID:** Confirm the exact `spellID` for the Warband Mentor XP buff for the bonus detector.
- [ ] **MapIDs:** Confirm Blizzard `mapID` values for all Midnight zones, Plaguelands, Arathi Highlands, and Blackrock Mountain (for Arator's Journey cross-continent steps).

---

## Appendix A: File Structure

```
QuestHUD/
├── QuestHUD.toc                  # Addon metadata, interface version, load order
├── QuestHUD.xml                  # Frame definitions (forked from FarmHud.xml)
├── QuestHUD.lua                  # Core: HUD, minimap hijack, module system, events
├── QuestHUD_Options.lua          # AceConfig options panel
├── QuestHUD_DataBroker.lua       # Minimap button (LibDBIcon)
├── QuestHUD_RouteEngine.lua      # Route algorithm: filtering, sorting, advancement
├── QuestHUD_RouteData.lua        # The route backbone: all quest IDs, coords, metadata
├── QuestHUD_InfoPanel.lua        # SimpleHTML info panel: render, update, drag
├── QuestHUD_BonusDetector.lua    # XP bonus detection + time estimate calculation
├── QuestHUD_Arrow.lua            # Directional arrow: bearing, rotation, colour
├── QuestHUD_NodeData.lua         # Bundled herb+mine node database (Midnight + Arator zones, ~243KB)
├── QuestHUD_Gathering.lua        # Self-contained node collector + HUD pin renderer
├── QuestHUD_FirstCraft.lua       # First craft XP reminder: detection, route injection, dismissal
├── Localization.lua              # Strings (enUS only for v1.0)
├── Bindings.xml                  # Keybinds
├── modules/
│   └── CardinalPoints.lua        # Retained from FarmHUD as-is
├── media/
│   ├── arrow.tga                 # Custom quest arrow texture
│   └── options.tga               # Options button icon
└── libs/                         # All FarmHUD libs retained unchanged
    ├── LibStub/
    ├── AceGUI-3.0/
    ├── AceConfig-3.0/
    ├── CallbackHandler-1.0/
    ├── LibDataBroker-1.1/
    ├── LibDBIcon-1.0/
    ├── HereBeDragons/
    └── HizurosSharedTools/
```

---

## Appendix B: Key WoW API Reference Links

- Quest Log API: https://warcraft.wiki.gg/wiki/API_C_QuestLog
- Super Track API: https://warcraft.wiki.gg/wiki/API_C_SuperTrack
- Map API: https://warcraft.wiki.gg/wiki/API_C_Map
- PvP / War Mode: https://warcraft.wiki.gg/wiki/API_C_PvP
- HereBeDragons: https://github.com/Nevcairiel/HereBeDragons
- AceConfig-3.0: https://www.wowace.com/projects/ace3/pages/api/ace-config-3-0
- SimpleHTML frame: https://warcraft.wiki.gg/wiki/UIOBJECT_SimpleHTML
- Wowhead Midnight Quest DB: https://www.wowhead.com/quests (filter: Midnight)

---

*QuestHUD PRD v1.0 — For Mercyful. See you in Voidstorm.*
