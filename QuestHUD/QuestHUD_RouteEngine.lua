-- QuestHUD_RouteEngine.lua
-- Dynamic quest planner for the Midnight 80-90 quest catalog.

local addon, ns = ...

local HBD  = LibStub("HereBeDragons-2.0")

ns.RouteEngine = {}

local activeStep  = nil
local activeQuest = nil
local activePlan  = {}
local lastQuestID = nil

local TYPE_WEIGHT = {
    campaign = 3,
    side = 2,
    firstcraft = 1,
}

local function NormalizeQuestName(name)
    if not name or name == "" then return "" end
    return name:lower():gsub("[%c%p]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function IsCompleted(questID)
    if not questID or questID == 0 then return false end
    return C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end

local function DistSqToCoords(mapID, x, y)
    if not (mapID and x and y) then return math.huge end
    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then return math.huge end
    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then return math.huge end
    local px, py = pos:GetXY()
    if not (px and py) then return math.huge end
    -- Cross-map: use HBD world coords for accurate distance
    local px_w, py_w = HBD:GetWorldCoordinatesFromZone(px, py, playerMap)
    local tx_w, ty_w = HBD:GetWorldCoordinatesFromZone(x, y, mapID)
    if not (px_w and tx_w) then return math.huge end
    local dx, dy = tx_w - px_w, ty_w - py_w
    return dx * dx + dy * dy
end

local function SetSuperTrack(questID)
    if questID == lastQuestID then return end
    lastQuestID = questID
    local ok, err = pcall(function()
        C_SuperTrack.SetSuperTrackedQuestID(questID or 0)
    end)
    if not ok then
        ns:print("SuperTrack error: " .. tostring(err))
    end
end

local function BuildQuestLogState()
    local state = {
        level = UnitLevel("player") or 80,
        playerMap = C_Map.GetBestMapForUnit("player"),
        activeByID = {},
        activeByName = {},
        activeQuestIDByName = {},
        activeByKey = {},
        actualCompletedByKey = {},
        chainFrontier = {},
        resolvedIDByKey = {},
    }

    local questCount = C_QuestLog.GetNumQuestLogEntries() or 0
    for index = 1, questCount do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.title then
            local questID = info.questID
            local normalized = NormalizeQuestName(info.title)
            state.activeByName[normalized] = true
            state.activeQuestIDByName[normalized] = questID
            if questID and questID > 0 then
                state.activeByID[questID] = true
            end
        end
    end

    for _, quest in ipairs(QuestHUD_QuestCatalog or {}) do
        local normalized = NormalizeQuestName(quest.name)
        local isActive = (quest.id and quest.id > 0 and state.activeByID[quest.id]) or state.activeByName[normalized] or false
        local isCompleted = IsCompleted(quest.id)
        state.activeByKey[quest.key] = isActive
        state.actualCompletedByKey[quest.key] = isCompleted
        if isActive then
            state.resolvedIDByKey[quest.key] = state.activeQuestIDByName[normalized] or quest.id
        end
        if (isActive or isCompleted) and quest.chain and quest.sequence then
            state.chainFrontier[quest.chain] = math.max(state.chainFrontier[quest.chain] or 0, quest.sequence)
        end
    end

    return state
end

local function IsQuestDone(quest, state)
    if not quest or not state then return false end
    if state.actualCompletedByKey[quest.key] then return true end
    if quest.chain and quest.sequence then
        return (state.chainFrontier[quest.chain] or 0) > quest.sequence
    end
    return false
end

local function PrereqsMet(quest, state)
    if not quest or not quest.prereqs then return true end
    for _, prereqKey in ipairs(quest.prereqs) do
        local prereqQuest = QuestHUD_QuestCatalogByKey and QuestHUD_QuestCatalogByKey[prereqKey]
        if prereqQuest then
            if not IsQuestDone(prereqQuest, state) and not state.activeByKey[prereqKey] then
                return false
            end
        else
            return false
        end
    end
    return true
end

local function GetZoneRange(quest)
    for _, zone in ipairs(QuestHUD_ZoneRouting or {}) do
        if zone.zone == quest.zone then
            return zone.level_range
        end
    end
    return nil
end

local function GetZoneFit(level, quest)
    local range = GetZoneRange(quest)
    if not range then return 0 end
    local minLevel, maxLevel = range[1], range[2]
    if level >= minLevel and level <= maxLevel then
        return 10
    end
    if level < minLevel then
        return math.max(0, 10 - (minLevel - level) * 2)
    end
    return math.max(0, 10 - (level - maxLevel))
end

local function MakeCandidate(quest, state)
    local resolvedQuestID = state.resolvedIDByKey[quest.key] or quest.id
    local dist = DistSqToCoords(quest.mapID, quest.x, quest.y)
    return {
        quest = quest,
        dist = dist,
        isActive = state.activeByKey[quest.key] or false,
        onPlayerMap = quest.mapID == state.playerMap and 1 or 0,
        zoneFit = GetZoneFit(state.level, quest),
        typeWeight = TYPE_WEIGHT[quest.type] or 0,
        priority = quest.priority or 50,
        resolvedQuestID = resolvedQuestID and resolvedQuestID > 0 and resolvedQuestID or nil,
    }
end

local function CandidateLess(a, b)
    if a.isActive ~= b.isActive then
        return a.isActive
    end
    if a.zoneFit ~= b.zoneFit then
        return a.zoneFit > b.zoneFit
    end
    if a.onPlayerMap ~= b.onPlayerMap then
        return a.onPlayerMap > b.onPlayerMap
    end
    if a.typeWeight ~= b.typeWeight then
        return a.typeWeight > b.typeWeight
    end
    if a.priority ~= b.priority then
        return a.priority < b.priority
    end
    if a.dist ~= b.dist then
        return a.dist < b.dist
    end
    return (a.quest.name or "") < (b.quest.name or "")
end

local function BuildCandidates(state)
    local candidates = {}
    for _, quest in ipairs(QuestHUD_QuestCatalog or {}) do
        if not IsQuestDone(quest, state) and PrereqsMet(quest, state) and state.level + 1 >= (quest.level or 80) then
            candidates[#candidates + 1] = MakeCandidate(quest, state)
        end
    end
    table.sort(candidates, CandidateLess)
    return candidates
end

local function CopyQuest(quest, resolvedQuestID, isActive)
    local copy = {}
    for key, value in pairs(quest) do
        copy[key] = value
    end
    copy.resolvedQuestID = resolvedQuestID
    copy.isActive = isActive
    return copy
end

local function BuildActiveStep(topCandidate, candidates)
    if not topCandidate then return nil end

    local step = {
        zone = topCandidate.quest.zone,
        hub = topCandidate.quest.hub,
        mapID = topCandidate.quest.mapID,
        level_range = GetZoneRange(topCandidate.quest),
        quests = {},
    }

    for _, candidate in ipairs(candidates) do
        if candidate.quest.zone == step.zone and candidate.quest.hub == step.hub then
            step.quests[#step.quests + 1] = CopyQuest(candidate.quest, candidate.resolvedQuestID, candidate.isActive)
            if #step.quests >= 6 then
                break
            end
        end
    end

    return step
end

local function Recalculate()
    if not QuestHUD_QuestCatalog or not QuestHUDDB then return end

    local state = BuildQuestLogState()
    local candidates = BuildCandidates(state)
    activePlan = candidates

    if #candidates == 0 then
        activeStep = nil
        activeQuest = nil
        if ns.Arrow then ns.Arrow:ClearTarget() end
        SetSuperTrack(nil)
        if ns.InfoPanel then ns.InfoPanel:Update(nil) end
        return
    end

    local topCandidate = candidates[1]
    activeQuest = CopyQuest(topCandidate.quest, topCandidate.resolvedQuestID, topCandidate.isActive)
    activeStep = BuildActiveStep(topCandidate, candidates)

    if ns.Arrow and QuestHUDDB.showArrow then
        ns.Arrow:SetTarget(activeQuest.x, activeQuest.y, activeQuest.mapID, activeQuest.type)
    elseif ns.Arrow then
        ns.Arrow:ClearTarget()
    end

    if QuestHUDDB.SuperTrackedQuest then
        SetSuperTrack(activeQuest.resolvedQuestID)
    else
        SetSuperTrack(nil)
    end

    if ns.InfoPanel then ns.InfoPanel:Update(activeStep, activeQuest) end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function ns.RouteEngine:Init()
    if not QuestHUD_QuestCatalog then return end
    Recalculate()
end

function ns.RouteEngine:GetActiveStep()
    return activeStep
end

function ns.RouteEngine:GetActiveQuest()
    return activeQuest
end

function ns.RouteEngine:GetPlan()
    return activePlan
end

-- ── Module event wiring ───────────────────────────────────────────────────────

ns.RouteEngine.events = {
    PLAYER_LEVEL_UP = function()
        Recalculate()
    end,
    QUEST_LOG_UPDATE = function()
        Recalculate()
    end,
    ZONE_CHANGED_NEW_AREA = function()
        Recalculate()
        if ns.Gathering then ns.Gathering:UpdatePins() end
    end,
}

-- Register with the module system
ns.modules["RouteEngine"] = ns.RouteEngine
