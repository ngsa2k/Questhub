-- QuestHUD_InfoPanel.lua
-- Phase 3: Draggable info panel showing active quest objective, XP, distance and
--           estimated time-to-level using the XP bonus multiplier from BonusDetector.

local addon, ns = ...

local HBD = LibStub("HereBeDragons-2.0")
local tinsert = table.insert

ns.InfoPanel = {}

local panel        -- Frame
local titleText    -- FontString – zone / hub
local questText    -- FontString – quest name + type badge
local objText      -- FontString – objective progress (multi-line)
local xpText       -- FontString – XP reward
local distText     -- FontString – distance to objective
local etaText      -- FontString – estimated time to level
local distTicker   -- C_Timer.NewTicker for live distance update

local BADGE = { campaign="[⚔]", side="[◆]", delve="[⚑]", firstcraft="[✦]" }
local BADGE_COLOR = {
    campaign  = "|cffffcc00",
    side      = "|cff00dddd",
    delve     = "|cff9900ff",
    firstcraft= "|cff00ff88",
}
local COLOR_END = "|r"

-- Approximate yards per zone-unit (zones are ~1000 yards wide at 1.0 scale)
local YARDS_PER_UNIT = 1000

local currentStep  = nil
local currentQuest = nil

-- ── Panel layout ───────────────────────────────────────────────────────────

local PANEL_W, PANEL_H = 260, 130
local FONT = "Fonts\\FRIZQT__.TTF"

local function MakeFontString(parent, justify, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(FONT, size or 11, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    return fs
end

local function FormatDistance(x, y, mapID)
    if not (mapID and x and y) then return "" end
    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then return "" end
    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then return "" end
    local px, py = pos:GetXY()
    if not (px and py) then return "" end
    local wx_p, wy_p = HBD:GetWorldCoordinatesFromZone(px, py, playerMap)
    local wx_t, wy_t = HBD:GetWorldCoordinatesFromZone(x, y, mapID)
    if not (wx_p and wx_t) then return "" end
    local dx, dy = wx_t - wx_p, wy_t - wy_p
    local dist = math.sqrt(dx * dx + dy * dy) * YARDS_PER_UNIT
    if dist < 1000 then
        return string.format("%.0f yd", dist)
    else
        return string.format("%.1f km", dist / 1760)
    end
end

local function FormatETA()
    if not ns.BonusDetector then return "" end
    local xpRemaining = UnitXPMax("player") - UnitXP("player")
    local eta = ns.BonusDetector:TimeEstimate(xpRemaining)
    if not eta then return "" end
    if eta < 60 then
        return string.format("ETA ~%dm", math.ceil(eta))
    else
        return string.format("ETA ~%dh %dm", math.floor(eta / 60), eta % 60)
    end
end

local function UpdateDistanceTick()
    if not (currentStep and currentQuest) then return end
    if distText then
        distText:SetText(FormatDistance(currentQuest.x, currentQuest.y, currentStep.mapID))
    end
    if etaText then etaText:SetText(FormatETA()) end
end

-- ── Public API ─────────────────────────────────────────────────────────────

--- Refresh the panel content for the given step + quest.
-- @param step   route step table (or nil to clear)
-- @param quest  quest entry table (or nil)
function ns.InfoPanel:Update(step, quest)
    currentStep, currentQuest = step, quest

    if not (panel and panel:IsVisible()) then return end
    if not step then
        titleText:SetText("")
        questText:SetText("")
        objText:SetText("Route complete!")
        xpText:SetText("")
        distText:SetText("")
        etaText:SetText(FormatETA())
        return
    end

    -- Zone / hub header
    titleText:SetText((step.zone or "") .. "  —  " .. (step.hub or ""))

    if quest then
        local badge = BADGE_COLOR[quest.type or "side"]
               .. (BADGE[quest.type] or "[?]") .. COLOR_END
        questText:SetText(badge .. "  " .. (quest.name or "Unknown quest"))

        -- Objective text from the quest log (if the player has the quest in log)
        local objLines = {}
        local questID = quest.resolvedQuestID or quest.id
        if questID and questID ~= 0 then
            local objectives = C_QuestLog.GetQuestObjectives(questID)
            if objectives then
                for _, obj in ipairs(objectives) do
                    local pct = (obj.numFulfilled or 0) / math.max(obj.numRequired or 1, 1)
                    local col = pct >= 1 and "|cff00ff00" or "|cffffff00"
                    tinsert(objLines, col .. obj.text .. COLOR_END)
                end
            end
        end
        if #objLines == 0 then
            tinsert(objLines, "|cffaaaaaa(no objectives tracked)|r")
        end
        objText:SetText(table.concat(objLines, "\n"))

        -- XP
        local xpReward = quest.xp or 0
        xpText:SetText(xpReward > 0 and string.format("|cffffff00%s XP|r", BreakUpLargeNumbers(xpReward)) or "")

        distText:SetText(FormatDistance(quest.x, quest.y, step.mapID))
        etaText:SetText(FormatETA())
    else
        questText:SetText("|cffaaaaaa(no eligible quest)|r")
        objText:SetText("")
        xpText:SetText("")
        distText:SetText("")
        etaText:SetText(FormatETA())
    end
end

--- Create the info panel frame (called once on PLAYER_LOGIN).
function ns.InfoPanel:Init()
    if panel then return end

    panel = CreateFrame("Frame", "QuestHUDInfoPanel", UIParent,
                        BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("MEDIUM")
    panel:SetFrameLevel(10)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save anchor to SavedVariables
        local pt, _, rpt, x, y = self:GetPoint()
        QuestHUDDB.infoPanelAnchor = {pt, "UIParent", rpt, x, y}
    end)

    -- Backdrop
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = {left=4, right=4, top=4, bottom=4},
        })
        panel:SetBackdropColor(0, 0, 0, 0.75)
        panel:SetBackdropBorderColor(0.4, 0.4, 0.8, 0.9)
    end

    -- Restore saved position (or default)
    local anchor = QuestHUDDB and QuestHUDDB.infoPanelAnchor
    if anchor then
        panel:ClearAllPoints()
        panel:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, -260)
    end

    -- Font strings
    local pad = 8
    titleText = MakeFontString(panel, "LEFT", 10, 0.7, 0.7, 1.0)
    titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -pad)
    titleText:SetWidth(PANEL_W - pad * 2)

    questText = MakeFontString(panel, "LEFT", 12, 1, 1, 1)
    questText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -3)
    questText:SetWidth(PANEL_W - pad * 2)

    objText = MakeFontString(panel, "LEFT", 10, 0.9, 0.9, 0.9)
    objText:SetPoint("TOPLEFT", questText, "BOTTOMLEFT", 0, -4)
    objText:SetWidth(PANEL_W - pad * 2)
    objText:SetHeight(36)

    xpText = MakeFontString(panel, "LEFT", 10)
    xpText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", pad, pad + 14)

    distText = MakeFontString(panel, "CENTER", 10, 0.7, 1.0, 0.7)
    distText:SetPoint("BOTTOM", panel, "BOTTOM", 0, pad + 14)

    etaText = MakeFontString(panel, "RIGHT", 10, 1.0, 0.8, 0.4)
    etaText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -pad, pad + 14)

    -- 1-second ticker to refresh distance / ETA
    distTicker = C_Timer.NewTicker(1, UpdateDistanceTick)

    -- Show/hide based on option
    if QuestHUDDB and QuestHUDDB.showInfoPanel == false then
        panel:Hide()
    end
end

function ns.InfoPanel:OnShow()
    if panel then panel:Show() end
end

function ns.InfoPanel:OnHide()
    -- Keep info panel visible even when HUD is hidden (player may still want to see it)
end

ns.InfoPanel.dbDefaults = {
    showInfoPanel    = true,
    infoPanelAnchor  = nil,
}

function ns.InfoPanel:AddOptions()
    return {
        infoPanel = {
            type = "group", order = 11,
            name = "Info Panel",
            args = {
                showInfoPanel = {
                    type = "toggle", order = 1, width = "full",
                    name = "Show info panel",
                    desc = "Display the quest objective, XP, distance and ETA panel.",
                },
            },
        },
    }
end

function ns.InfoPanel:UpdateOptions(key)
    if key == "showInfoPanel" and panel then
        panel:SetShown(QuestHUDDB.showInfoPanel)
    end
end

-- Register with module system
ns.modules["InfoPanel"] = ns.InfoPanel
