-- QuestHUD_RouteEngine.lua
-- Phase 2: Quest route algorithm — completion filtering, hub advancement,
--           C_SuperTrack integration, mid-playthrough placement.

local addon, ns = ...

local HBD  = LibStub("HereBeDragons-2.0")

ns.RouteEngine = {}

local activeStepIdx  = 1   -- index into QuestHUD_Route
local activeQuestIdx = nil -- index into step.quests
local lastQuestID    = nil -- cached super-tracked quest ID (avoids redundant pcall)

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function IsCompleted(questID)
    if not questID or questID == 0 then return false end
    return C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end

--- Squared distance from the player (in zone-relative units).
-- Returns math.huge when position cannot be determined.
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

--- Wrapped C_SuperTrack call; silently ignores ADDON_ACTION_FORBIDDEN.
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

--- Check whether ALL quests in a route step are completed.
local function IsStepComplete(step)
    if not step or not step.quests then return true end
    for _, q in ipairs(step.quests) do
        if not IsCompleted(q.id) then
            return false
        end
    end
    return true
end

--- Check that all prerequisite quest IDs for a quest entry are completed.
local function PrereqsMet(q)
    if not q.prereqs then return true end
    for _, pid in ipairs(q.prereqs) do
        if not IsCompleted(pid) then return false end
    end
    return true
end

-- ── Core algorithm ────────────────────────────────────────────────────────────

--- Advance the active step index to the first incomplete step.
local function AdvanceToFirstIncompleteStep()
    if not QuestHUD_Route then return end
    for i = activeStepIdx, #QuestHUD_Route do
        if not IsStepComplete(QuestHUD_Route[i]) then
            activeStepIdx = i
            return
        end
    end
    -- All steps done
    activeStepIdx = #QuestHUD_Route
end

--- Select the best quest within the active step:
--  1. Not yet completed
--  2. Prereqs satisfied
--  3. Sorted by priority ASC, then distance ASC
local function SelectBestQuest()
    if not QuestHUD_Route then return nil, nil end
    local step = QuestHUD_Route[activeStepIdx]
    if not step or not step.quests then return nil, nil end

    local best, bestIdx, bestPrio, bestDist = nil, nil, math.huge, math.huge
    for i, q in ipairs(step.quests) do
        if not IsCompleted(q.id) and PrereqsMet(q) then
            local prio = q.priority or 50
            local dist = DistSqToCoords(step.mapID, q.x, q.y)
            if prio < bestPrio or (prio == bestPrio and dist < bestDist) then
                best, bestIdx, bestPrio, bestDist = q, i, prio, dist
            end
        end
    end
    return best, bestIdx
end

--- Re-evaluate the route: advance step if necessary, pick the best quest,
--  update the arrow and super-track.
local function Recalculate()
    if not QuestHUD_Route or not QuestHUDDB then return end

    -- Advance past any fully-completed steps
    AdvanceToFirstIncompleteStep()

    local step = QuestHUD_Route[activeStepIdx]
    if not step then
        ns.Arrow:ClearTarget()
        SetSuperTrack(nil)
        if ns.InfoPanel then ns.InfoPanel:Update(nil) end
        return
    end

    local quest, qIdx = SelectBestQuest()
    activeQuestIdx = qIdx

    if quest then
        -- Update directional arrow
        if ns.Arrow and QuestHUDDB.showArrow then
            ns.Arrow:SetTarget(quest.x, quest.y, step.mapID, quest.type)
        end
        -- Super-track the quest
        if QuestHUDDB.SuperTrackedQuest then
            SetSuperTrack(quest.id)
        end
        -- Update info panel
        if ns.InfoPanel then ns.InfoPanel:Update(step, quest) end
    else
        -- No eligible quest found (e.g. all need prereqs from another zone)
        ns.Arrow:ClearTarget()
        SetSuperTrack(nil)
        if ns.InfoPanel then ns.InfoPanel:Update(step, nil) end
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Called on PLAYER_LOGIN to set the starting step (mid-playthrough placement).
function ns.RouteEngine:Init()
    if not QuestHUD_Route then return end

    -- Find the first step that still has incomplete quests
    activeStepIdx = 1
    AdvanceToFirstIncompleteStep()
    Recalculate()
end

--- Returns the active route step table (or nil).
function ns.RouteEngine:GetActiveStep()
    if not QuestHUD_Route then return nil end
    return QuestHUD_Route[activeStepIdx]
end

--- Returns the active quest table within the active step (or nil).
function ns.RouteEngine:GetActiveQuest()
    local step = self:GetActiveStep()
    if not step or not step.quests or not activeQuestIdx then return nil end
    return step.quests[activeQuestIdx]
end

-- ── Module event wiring ───────────────────────────────────────────────────────

ns.RouteEngine.events = {
    QUEST_LOG_UPDATE = function(frame)
        Recalculate()
    end,
    ZONE_CHANGED_NEW_AREA = function(frame)
        -- Refresh gathering pins through the Gathering module
        if ns.Gathering then ns.Gathering:UpdatePins() end
    end,
}

-- Register with the module system
ns.modules["RouteEngine"] = ns.RouteEngine
