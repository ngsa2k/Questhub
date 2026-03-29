-- QuestHUD_Gathering.lua
-- Phase 3: Self-contained gathering node collector + HUD minimap pin renderer.
--   • Merges bundled DB (QuestHUD_NodeData.lua) with live-collected SavedVariables nodes.
--   • Detects player herbs/mines from UNIT_SPELLCAST_SENT + CURSOR_CHANGED.
--   • Renders pins via HereBeDragons-Pins-2.0 on the minimap cluster.

local addon, ns = ...

local HBD     = LibStub("HereBeDragons-2.0")
local tinsert = table.insert
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

ns.Gathering = {}

-- ── Constants ─────────────────────────────────────────────────────────────────

-- Herb spell IDs (herbalism gather cast)
local HERB_SPELLS = { [2366]=true, [2368]=true, [11993]=true, [28695]=true,
                      [50300]=true, [50301]=true, [73901]=true, [158748]=true,
                      [171700]=true, [210053]=true, [269423]=true, [294373]=true }

-- Mining spell IDs
local MINE_SPELLS = { [2575]=true, [195122]=true, [423341]=true, [471013]=true }

-- Display radius in zone-relative units (~80 yards out of ~1000 = 0.08)
local function GetDisplayRadius()
    local r = QuestHUDDB and QuestHUDDB.gatheringRadius or 80
    return r / 1000
end

-- Pin textures (using atlas or solid colour circles)
local HERB_PIN_ATLAS = "Minimap-Herb-Tracked"    -- fallback: green circle
local MINE_PIN_ATLAS = "Minimap-Mine-Tracked"    -- fallback: orange circle

-- ── State ─────────────────────────────────────────────────────────────────────

local charKey            -- "RealmName-CharacterName"
local pendingSpell       -- spellID of the gather cast that was started
local pendingNodePos     -- {mapID, x, y} of the cursor when cast started
local activePins = {}    -- track handles returned by HBDPins

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function GetCharKey()
    if charKey then return charKey end
    charKey = GetRealmName() .. "-" .. UnitName("player")
    return charKey
end

local function EnsureSavedDBEntry()
    local key = GetCharKey()
    if not QuestHUDDB[key] then
        QuestHUDDB[key] = { collectedHerbNodes={}, collectedMineNodes={} }
    end
    if not QuestHUDDB[key].collectedHerbNodes then
        QuestHUDDB[key].collectedHerbNodes = {}
    end
    if not QuestHUDDB[key].collectedMineNodes then
        QuestHUDDB[key].collectedMineNodes = {}
    end
end

--- Encode (x,y) to GatherMate2-compatible packed integer.
local function EncodeCoord(x, y)
    return math.floor(x * 10000 + 0.5) * 1000000
         + math.floor(y * 10000 + 0.5) * 100
end

--- Decode packed coord back to (x,y).
local function DecodeCoord(coord)
    return math.floor(coord / 1000000) / 10000,
           math.floor(coord % 1000000 / 100) / 10000
end

--- Check whether the player has a given profession by name fragment.
local function HasProfession(fragment)
    local p1, p2 = GetProfessions()
    local slots = {}
    if p1 then slots[#slots + 1] = p1 end
    if p2 then slots[#slots + 1] = p2 end
    for _, slot in ipairs(slots) do
        local name = GetProfessionInfo(slot)
        if name and name:find(fragment) then return true end
    end
    return false
end

-- ── Pin rendering ─────────────────────────────────────────────────────────────

local function PinFactory(frame, r, g, b)
    frame:SetSize(8, 8)
    local tex = frame:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(frame)
    -- Try atlas first; fall back to a solid square
    local ok = pcall(function() tex:SetAtlas(r == 0 and MINE_PIN_ATLAS or HERB_PIN_ATLAS) end)
    if not ok then
        tex:SetColorTexture(r, g, b, 0.90)
    end
end

local function AddPin(mapID, x, y, isHerb)
    local key = isHerb and "herb" or "mine"
    local r, g, b = isHerb and 0.10 or 1.00,
                    isHerb and 0.80 or 0.55,
                    isHerb and 0.10 or 0.00
    -- HBDPins:AddMinimapIconMap(provider, frame, mapID, x, y, showInMenu)
    -- We use a per-pin frame factory
    local pin = CreateFrame("Frame")
    pin:Hide()
    PinFactory(pin, r, g, b)
    HBDPins:AddMinimapIconMap(ns.Gathering, pin, mapID, x, y, false)
    tinsert(activePins, pin)
end

local function ClearPins()
    HBDPins:RemoveAllMinimapIcons(ns.Gathering)
    wipe(activePins)
end

--- Rebuild minimap pins for all nodes within display radius of the player.
function ns.Gathering:UpdatePins()
    if not QuestHUDDB then return end
    if not QuestHUDDB.showGathering then return end

    ClearPins()

    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then return end
    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then return end
    local px, py = pos:GetXY()
    if not (px and py) then return end

    local radius = GetDisplayRadius()
    local radiusSq = radius * radius
    local showHerb = QuestHUDDB.gatheringHerb ~= false
    local showMine = QuestHUDDB.gatheringMine ~= false

    local function RenderZoneNodes(db, isHerb)
        if not db then return end
        if (isHerb and not showHerb) or (not isHerb and not showMine) then return end

        -- Render bundled nodes for the player's current map
        local zoneNodes = db[playerMap]
        if not zoneNodes then return end

        for coord, _ in pairs(zoneNodes) do
            local x, y = DecodeCoord(coord)
            local dx, dy = x - px, y - py
            if dx * dx + dy * dy <= radiusSq then
                AddPin(playerMap, x, y, isHerb)
            end
        end
    end

    -- Bundled DB (may be nil if QuestHUD_NodeData.lua was not loaded)
    if QuestHUD_BundledHerbDB then
        RenderZoneNodes(QuestHUD_BundledHerbDB, true)
    end
    if QuestHUD_BundledMineDB then
        RenderZoneNodes(QuestHUD_BundledMineDB, false)
    end

    -- Live-collected nodes from SavedVariables
    EnsureSavedDBEntry()
    local charDB = QuestHUDDB[GetCharKey()]
    RenderZoneNodes(charDB.collectedHerbNodes, true)
    RenderZoneNodes(charDB.collectedMineNodes, false)
end

-- ── Live node collection ───────────────────────────────────────────────────────

local function OnSpellCastSent(frame, unit, _, spellID)
    if unit ~= "player" then return end
    if HERB_SPELLS[spellID] or MINE_SPELLS[spellID] then
        pendingSpell = spellID
        -- Record cursor world position at cast time
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                local x, y = pos:GetXY()
                pendingNodePos = {mapID=mapID, x=x, y=y}
            end
        end
    end
end

local function CommitNode(isHerb)
    if not pendingNodePos then return end
    EnsureSavedDBEntry()
    local charDB = QuestHUDDB[GetCharKey()]
    local db = isHerb and charDB.collectedHerbNodes or charDB.collectedMineNodes
    local mapDB = db[pendingNodePos.mapID]
    if not mapDB then
        mapDB = {}
        db[pendingNodePos.mapID] = mapDB
    end
    local coord = EncodeCoord(pendingNodePos.x, pendingNodePos.y)
    mapDB[coord] = 1   -- bare flag; no node ID needed for display
    pendingNodePos = nil
    pendingSpell = nil
end

local function OnSpellCastStop(frame, unit, _, spellID)
    if unit ~= "player" then return end
    if spellID ~= pendingSpell then return end
    CommitNode(HERB_SPELLS[spellID] ~= nil)
    ns.Gathering:UpdatePins()
end

local function OnSpellCastFailed(frame, unit, _, spellID)
    if unit == "player" and spellID == pendingSpell then
        pendingNodePos = nil
        pendingSpell   = nil
    end
end

-- ── Init / lifecycle ──────────────────────────────────────────────────────────

function ns.Gathering:Init()
    -- Initial pin update deferred until first zone load
end

function ns.Gathering:OnShow()
    ns.Gathering:UpdatePins()
end

function ns.Gathering:OnHide()
    ClearPins()
end

ns.Gathering.dbDefaults = {
    showGathering  = false,
    gatheringRadius= 80,
    gatheringHerb  = true,
    gatheringMine  = true,
}

ns.Gathering.events = {
    UNIT_SPELLCAST_SENT    = OnSpellCastSent,
    UNIT_SPELLCAST_STOP    = OnSpellCastStop,
    UNIT_SPELLCAST_FAILED  = OnSpellCastFailed,
    PLAYER_ENTERING_WORLD  = function(frame) ns.Gathering:UpdatePins() end,
}

function ns.Gathering:AddOptions()
    return {
        gathering = {
            type = "group", order = 12,
            name = "Gathering Nodes",
            args = {
                showGathering = {
                    type = "toggle", order = 1, width = "full",
                    name = "Show gathering nodes",
                    desc = "Overlay herb and mining nodes on the minimap HUD.",
                },
                gatheringRadius = {
                    type = "range", order = 2,
                    name = "Display radius (yards)",
                    desc = "How far from the player to show nodes (20–200 yards).",
                    min = 20, max = 200, step = 5,
                },
                gatheringHerb = {
                    type = "toggle", order = 3,
                    name = "Show herb nodes",
                },
                gatheringMine = {
                    type = "toggle", order = 4,
                    name = "Show mine nodes",
                },
            },
        },
    }
end

function ns.Gathering:UpdateOptions(key)
    if key == "showGathering" or key == "gatheringRadius"
    or key == "gatheringHerb" or key == "gatheringMine" then
        ns.Gathering:UpdatePins()
    end
end

-- Register with module system
ns.modules["Gathering"] = ns.Gathering
