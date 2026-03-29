-- QuestHUD_Arrow.lua
-- Phase 2: Directional arrow — HereBeDragons bearing, 24 fps rotation, colour by quest type

local addon, ns = ...

local HBD   = LibStub("HereBeDragons-2.0")
local media = "Interface\\AddOns\\" .. addon .. "\\media\\"

-- Arrival threshold: ~50 yards in zone-relative units (0‒1 scale, zone ≈ 1000 yards wide)
local ARRIVAL_DIST_SQ = (50 / 1000) ^ 2   -- squared to avoid sqrt

-- Arrow colours per quest type (vertex colour tint on a white arrow texture)
local QUEST_COLORS = {
    campaign  = {1.00, 0.85, 0.00},  -- gold
    side      = {0.00, 0.85, 0.85},  -- teal
    delve     = {0.60, 0.00, 1.00},  -- purple
    firstcraft= {0.00, 1.00, 0.50},  -- green-mint
}
local DEFAULT_COLOR = {1.0, 1.0, 1.0}

ns.Arrow = {}

local arrowFrame   -- Frame
local arrowTex     -- Texture
local arrowTicker  -- C_Timer.NewTicker handle
local target = {}  -- {mapID, x, y, questType}

local function getColor(questType)
    local c = QUEST_COLORS[questType] or DEFAULT_COLOR
    return c[1], c[2], c[3]
end

local function ArrowTick()
    if not (arrowFrame and arrowFrame:IsVisible()) then return end
    if not (target.mapID and target.x and target.y)     then return end

    local facing = GetPlayerFacing()
    if not facing then
        -- No facing (loading screen / vehicle without facing)
        arrowFrame:SetAlpha(0.3)
        return
    end

    -- HereBeDragons: bearing from player TO the target coordinate
    local angle, _, distSq = HBD:GetDirectionToPlayerFromCoords(target.mapID, target.x, target.y)
    if not angle then
        -- Target is on a different continent or unreachable
        arrowFrame:SetAlpha(0.3)
        return
    end

    arrowFrame:SetAlpha(1.0)

    -- Rotate the texture so it points toward the target
    arrowTex:SetRotation(angle - facing)

    -- Arrival pulse: scale-pulse when within ~50 yards
    if distSq and distSq <= ARRIVAL_DIST_SQ then
        local pulse = 1.0 + 0.35 * math.abs(math.sin(GetTime() * math.pi / 0.6))
        arrowFrame:SetScale(pulse)
    else
        arrowFrame:SetScale(1.0)
    end
end

--- Set the arrow's tracking target.
-- @param x        zone-relative x (0‒1)
-- @param y        zone-relative y (0‒1)
-- @param mapID    uiMapID for HereBeDragons lookup
-- @param questType string: "campaign"|"side"|"delve"|"firstcraft" (default=white)
function ns.Arrow:SetTarget(x, y, mapID, questType)
    target.x, target.y, target.mapID, target.questType = x, y, mapID, questType
    if arrowTex then
        arrowTex:SetVertexColor(getColor(questType))
    end
    if arrowFrame then
        arrowFrame:SetAlpha(1.0)
        arrowFrame:Show()
    end
end

--- Remove the tracking target and hide the arrow.
function ns.Arrow:ClearTarget()
    target.x, target.y, target.mapID, target.questType = nil, nil, nil, nil
    if arrowFrame then arrowFrame:Hide() end
end

--- Called once on PLAYER_LOGIN to create the arrow overlay.
function ns.Arrow:Init()
    if arrowFrame then return end   -- guard against double-init

    -- Parent to QuestHUD so it moves with the HUD overlay
    arrowFrame = CreateFrame("Frame", "QuestHUDArrowFrame", QuestHUD)
    arrowFrame:SetSize(52, 52)
    arrowFrame:SetPoint("CENTER", QuestHUD, "CENTER", 0, 0)
    arrowFrame:SetFrameStrata("HIGH")
    arrowFrame:SetFrameLevel(25)
    arrowFrame:Hide()

    -- Arrow texture (white so vertex colour tints it cleanly)
    arrowTex = arrowFrame:CreateTexture(nil, "OVERLAY")
    arrowTex:SetAllPoints(arrowFrame)
    arrowTex:SetTexture(media .. "trail-arrow-1")
    arrowTex:SetVertexColor(getColor(nil))

    -- 24 fps rotation ticker (matches cardinal-points ticker rate)
    arrowTicker = C_Timer.NewTicker(1 / 24, ArrowTick)

    -- Show/hide based on option
    if QuestHUDDB and QuestHUDDB.showArrow == false then
        arrowFrame:Hide()
    end
end

--- Called by the module system when QuestHUD is shown.
function ns.Arrow:OnShow()
    if arrowFrame and target.mapID then
        arrowFrame:Show()
    end
end

--- Called by the module system when QuestHUD is hidden.
function ns.Arrow:OnHide()
    if arrowFrame then arrowFrame:Hide() end
end

--- Module: db defaults + options registration
ns.Arrow.dbDefaults = {
    showArrow            = true,
    arrowCampaignColor   = {1.00, 0.85, 0.00, 1.0},
    arrowSideColor       = {0.00, 0.85, 0.85, 1.0},
    arrowDelveColor      = {0.60, 0.00, 1.00, 1.0},
}

function ns.Arrow:UpdateOptions(key)
    if key == "showArrow" then
        if arrowFrame then
            if QuestHUDDB.showArrow and target.mapID then
                arrowFrame:Show()
            else
                arrowFrame:Hide()
            end
        end
    elseif key == "arrowCampaignColor" then
        QUEST_COLORS.campaign = {unpack(QuestHUDDB.arrowCampaignColor or {1,0.85,0})}
        if target.questType == "campaign" and arrowTex then
            arrowTex:SetVertexColor(getColor("campaign"))
        end
    elseif key == "arrowSideColor" then
        QUEST_COLORS.side = {unpack(QuestHUDDB.arrowSideColor or {0,0.85,0.85})}
        if target.questType == "side" and arrowTex then
            arrowTex:SetVertexColor(getColor("side"))
        end
    elseif key == "arrowDelveColor" then
        QUEST_COLORS.delve = {unpack(QuestHUDDB.arrowDelveColor or {0.6,0,1})}
        if target.questType == "delve" and arrowTex then
            arrowTex:SetVertexColor(getColor("delve"))
        end
    end
end

function ns.Arrow:AddOptions()
    return {
        questArrow = {
            type = "group", order = 10,
            name = "Quest Arrow",
            args = {
                showArrow = {
                    type = "toggle", order = 1, width = "full",
                    name = "Show quest arrow",
                    desc = "Display a directional arrow pointing toward the active quest objective.",
                },
                arrowCampaignColor = {
                    type = "color", order = 2, hasAlpha = true,
                    name = "Campaign quest colour",
                    desc = "Arrow colour for main campaign quests.",
                },
                arrowSideColor = {
                    type = "color", order = 3, hasAlpha = true,
                    name = "Side quest colour",
                    desc = "Arrow colour for optional side quests.",
                },
                arrowDelveColor = {
                    type = "color", order = 4, hasAlpha = true,
                    name = "Delve quest colour",
                    desc = "Arrow colour for delve and dungeon quests.",
                },
            },
        },
    }
end

-- Register with the module system (enables OnShow/OnHide propagation)
ns.modules["Arrow"] = ns.Arrow
