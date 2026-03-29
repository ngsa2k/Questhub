-- QuestHUD_BonusDetector.lua
-- Phase 4: XP bonus detection + time-to-level estimate.
--
-- Detects five stacking multipliers:
--   War Mode       +10 % (C_PvP.IsWarModeDesired)
--   Rested XP      +50 % while rested (GetXPExhaustion > 0)
--   Heirlooms      +10 % per heirloom with XP bonus (C_Heirloom)
--   Darkmoon WHEE! +10 % (aura 46668)
--   Warband Mentor +10 % (aura 444756 — verify spellID on PTR)
--
-- Baseline XP/hour is an empirical constant calibrated during Phase 5 testing;
-- it is stored in QuestHUDDB so the user can recalibrate without patching.

local addon, ns = ...
local tinsert = table.insert

ns.BonusDetector = {}

-- ── Constants ─────────────────────────────────────────────────────────────────

-- SpellIDs for aura detection (confirm on Midnight PTR)
local DARKMOON_AURA_ID    = 46668   -- Darkmoon Faire WHEE! +10% XP
local WARBAND_MENTOR_ID   = 444756  -- Warband Mentor buff (placeholder — verify on PTR)

-- Empirical baseline XP per hour at level 80 with NO bonuses.
-- Will be calibrated during Phase 5 alpha testing.
local DEFAULT_BASELINE_XPH = 350000  -- conservative starter value

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function HasAura(spellID)
    if not C_UnitAuras then return false end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    return aura ~= nil
end

--- Returns the count of equipped heirlooms that grant an XP bonus.
-- C_Heirloom.GetEquippedHeirloomInfo is not available; we probe equipped items.
-- Returns 0 if the API is unavailable (unlikely for Retail).
local function CountXpHeirlooms()
    if not (C_Heirloom and C_Heirloom.IsHeirloomItem) then return 0 end
    local count = 0
    -- Slots that can hold XP-granting heirlooms: Head(1), Shoulder(3), Chest(5), Legs(7), Back(15)
    local xpSlots = {1, 3, 5, 7, 15}
    for _, slot in ipairs(xpSlots) do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            if itemID and C_Heirloom.IsHeirloomItem(itemID) then
                count = count + 1
            end
        end
    end
    return count
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Detect all active XP bonuses and return a breakdown table.
-- @return {
--   warMode (bool), restedXP (bool), heirlooms (int),
--   darkmoon (bool), warbandMentor (bool),
--   multiplier (number, e.g. 1.80 for 80% total bonus)
-- }
function ns.BonusDetector:Detect()
    local warMode       = C_PvP and C_PvP.IsWarModeDesired() or false
    local restedXP      = (GetXPExhaustion() or 0) > 0
    local heirlooms     = CountXpHeirlooms()
    local darkmoon      = HasAura(DARKMOON_AURA_ID)
    local warbandMentor = HasAura(WARBAND_MENTOR_ID)

    -- Compute multiplicative bonus (WoW stacks these additively in practice;
    -- using additive here to match in-game tooltip math)
    local pct = 1.0
    if warMode       then pct = pct + 0.10 end
    if restedXP      then pct = pct + 0.50 end
    if heirlooms > 0 then pct = pct + 0.10 * heirlooms end
    if darkmoon      then pct = pct + 0.10 end
    if warbandMentor then pct = pct + 0.10 end

    return {
        warMode       = warMode,
        restedXP      = restedXP,
        heirlooms     = heirlooms,
        darkmoon      = darkmoon,
        warbandMentor = warbandMentor,
        multiplier    = pct,
    }
end

--- Estimate minutes remaining until max level (90).
-- @param xpRemaining  number of XP still needed (defaults to UnitXPMax-UnitXP)
-- @return minutes (number) or nil if level 90 already
function ns.BonusDetector:TimeEstimate(xpRemaining)
    if UnitLevel("player") >= 90 then return nil end

    local baseXPH = (QuestHUDDB and QuestHUDDB.baselineXPH) or DEFAULT_BASELINE_XPH
    if not xpRemaining then
        xpRemaining = UnitXPMax("player") - UnitXP("player")
    end
    if xpRemaining <= 0 then return 0 end

    local bonuses = self:Detect()
    local adjustedXPH = baseXPH * bonuses.multiplier
    if adjustedXPH <= 0 then return nil end

    return math.ceil((xpRemaining / adjustedXPH) * 60)  -- minutes
end

--- Build a short summary string for the info panel, e.g. "+80% (WM+Rested+2x Heir)"
function ns.BonusDetector:Summary()
    local b = self:Detect()
    local parts = {}
    if b.warMode       then tinsert(parts, "WM")               end
    if b.restedXP      then tinsert(parts, "Rested")           end
    if b.heirlooms > 0 then tinsert(parts, b.heirlooms.."×Heir") end
    if b.darkmoon      then tinsert(parts, "DMF")              end
    if b.warbandMentor then tinsert(parts, "Mentor")           end
    local pct = math.floor((b.multiplier - 1.0) * 100 + 0.5)
    if #parts == 0 then
        return string.format("+%d%% (no bonuses)", pct)
    end
    return string.format("+%d%% (%s)", pct, table.concat(parts, "+"))
end

ns.BonusDetector.dbDefaults = {
    baselineXPH = DEFAULT_BASELINE_XPH,
}

function ns.BonusDetector:AddOptions()
    return {
        bonusDetector = {
            type = "group", order = 13,
            name = "XP Bonus & Time Estimate",
            args = {
                desc = {
                    type = "description", order = 0,
                    name = "The time estimate uses a baseline XP/hour figure multiplied "
                        .. "by your active XP bonuses (War Mode, Rested, Heirlooms, "
                        .. "Darkmoon Faire, Warband Mentor).\n\n"
                        .. "Increase the baseline after a full timed run to improve accuracy.",
                },
                baselineXPH = {
                    type = "range", order = 1,
                    name = "Baseline XP/hour (no bonuses)",
                    desc = "Empirical XP per hour at your level with zero bonus stacks. "
                        .. "Raise this after calibrating in a timed run.",
                    min = 50000, max = 1000000, step = 10000,
                    get = function() return (QuestHUDDB and QuestHUDDB.baselineXPH) or DEFAULT_BASELINE_XPH end,
                    set = function(_, v)
                        if QuestHUDDB then QuestHUDDB.baselineXPH = v end
                    end,
                },
            },
        },
    }
end

-- Register with module system
ns.modules["BonusDetector"] = ns.BonusDetector
