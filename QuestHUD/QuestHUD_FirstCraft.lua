-- QuestHUD_FirstCraft.lua
-- Phase 4: First-craft XP reminder.
--
-- Background: The first time a character crafts any recipe they receive a
-- large bonus XP ("First Craft" award).  QuestHUD injects a special
-- "firstcraft" step into the Silvermoon City hub at Step 2 to remind
-- Alchemy + Herbalism players to make their first flask.
--
-- Behaviour:
--   1. On PLAYER_LOGIN, check profession loadout.
--   2. If player has Alchemy AND Herbalism (or sufficient gathered herbs),
--      and QuestHUDDB[charKey].firstCraftDismissed is not set,
--      the "first flask" quest entry in RouteData is left visible.
--   3. If TRADE_SKILL_RECIPE_CRAFTED fires and a first-craft XP event is
--      detected, mark firstCraftDismissed = true and hide the entry.
--   4. The player may also dismiss manually via /questhud firstcraft done.

local addon, ns = ...

ns.FirstCraft = {}

local charKey
local reminded = false  -- becomes true once we have shown the reminder

local function GetCharKey()
    if charKey then return charKey end
    charKey = GetRealmName() .. "-" .. UnitName("player")
    return charKey
end

local function IsDismissed()
    local key = GetCharKey()
    return QuestHUDDB and QuestHUDDB[key] and QuestHUDDB[key].firstCraftDismissed
end

local function SetDismissed()
    local key = GetCharKey()
    if not QuestHUDDB then return end
    if not QuestHUDDB[key] then QuestHUDDB[key] = {} end
    QuestHUDDB[key].firstCraftDismissed = true
    -- Trigger a route recalculation so the "firstcraft" step is no longer shown
    if ns.RouteEngine then ns.RouteEngine:Init() end
    ns:print("First Craft reminder dismissed.")
end

--- Returns true if the player has Alchemy or Herbalism (both useful for first-craft XP).
local function HasAlchemyOrHerbalism()
    local p1, p2 = GetProfessions()
    local slots = {}
    if p1 then slots[#slots + 1] = p1 end
    if p2 then slots[#slots + 1] = p2 end
    for _, slot in ipairs(slots) do
        local name = GetProfessionInfo(slot)
        if name then
            local lname = name:lower()
            if lname:find("alch") or lname:find("herb") then
                return true
            end
        end
    end
    return false
end

--- Remove all "firstcraft" type entries from QuestHUD_Route when dismissed.
local function PruneFirstCraftEntries()
    if not QuestHUD_Route then return end
    for _, step in ipairs(QuestHUD_Route) do
        if step.quests then
            for i = #step.quests, 1, -1 do
                if step.quests[i].type == "firstcraft" then
                    table.remove(step.quests, i)
                end
            end
        end
    end
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function ns.FirstCraft:Init()
    -- Prune if already dismissed (handles reload / re-log)
    if IsDismissed() then
        PruneFirstCraftEntries()
        return
    end

    -- Prune if the player has no relevant professions
    if not HasAlchemyOrHerbalism() then
        PruneFirstCraftEntries()
        return
    end

    reminded = true
    ns:print("QuestHUD: |cff00ff88First Craft reminder|r active — make your first flask at Silvermoon Apothecary for bonus XP!")
end

-- ── Events ────────────────────────────────────────────────────────────────────

local function OnRecipeCrafted(frame, recipeID)
    if not reminded then return end
    -- We can't directly detect "first craft XP" from the event, but we can
    -- assume that if the player crafts anything while on step 2 and the
    -- firstcraft entry is pending, they have done it.
    SetDismissed()
    PruneFirstCraftEntries()
end

--- Slash command support: /questhud firstcraft done
-- This is wired up in ns.SlashCommands if available; otherwise the player
-- can also complete the "firstcraft" quest entry naturally.
function ns.FirstCraft:Dismiss()
    if not IsDismissed() then
        SetDismissed()
        PruneFirstCraftEntries()
    end
end

ns.FirstCraft.dbDefaults = {
    showFirstCraftReminder = true,
}

ns.FirstCraft.events = {
    TRADE_SKILL_ITEM_CRAFTED_RESULT = OnRecipeCrafted,
}

function ns.FirstCraft:AddOptions()
    return {
        firstCraft = {
            type = "group", order = 14,
            name = "First Craft Reminder",
            args = {
                showFirstCraftReminder = {
                    type = "toggle", order = 1, width = "full",
                    name = "Show First Craft reminder",
                    desc = "Remind Alchemy/Herbalism players to craft their first recipe "
                        .. "at Silvermoon City for the First Craft XP bonus.",
                },
                dismissFirstCraft = {
                    type = "execute", order = 2,
                    name = "Dismiss reminder",
                    desc = "Mark the First Craft step as done for this character.",
                    func = function() ns.FirstCraft:Dismiss() end,
                    disabled = function() return IsDismissed() end,
                },
            },
        },
    }
end

-- Register with module system
ns.modules["FirstCraft"] = ns.FirstCraft
