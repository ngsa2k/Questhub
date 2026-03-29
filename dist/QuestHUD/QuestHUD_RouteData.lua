-- QuestHUD_RouteData.lua
-- Pre-built route backbone for the 80→90 Midnight levelling path.
--
-- !! IMPORTANT: Quest IDs are placeholders (0) until Midnight launches.         !!
-- !! Once Wowhead PTR data is confirmed, replace IDs and verify coordinates.    !!
--
-- Table schema per quest entry:
--   id        = questID (number; 0 = not yet confirmed from PTR)
--   name      = display name (string)
--   type      = "campaign" | "side" | "delve" | "firstcraft"
--   x, y      = zone-relative coordinates 0-1 for the quest hand-in / objective
--   xp        = approximate XP reward at level 80 (0 = unknown)
--   priority  = sort order within hub; lower = do first (default 50)
--   prereqs   = {questID, ...} list of quest IDs that must be done first
--
-- mapID per zone (confirmed from extract_nodes.py / GatherMate2):
--   2393  Eversong Woods
--   2395  Zul'Aman
--   2405  Harandar
--   2413  Arator's Journey (Quel'Thalas segment)
--   2437  Voidstorm
--   14    Arathi Highlands   (Arator cross-continent)
--   25    Blackrock Mountain (Arator cross-continent)
--   27    Eastern Plaguelands(Arator cross-continent)

QuestHUD_Route = {

    -- ════════════════════════════════════════════════════════════════
    -- STEP 1 — Eversong Woods  (levels 80-83)   mapID 2393
    -- ════════════════════════════════════════════════════════════════
    {
        step        = 1,
        zone        = "Eversong Woods",
        hub         = "Silvermoon City",
        level_range = {80, 81},
        mapID       = 2393,
        quests = {
            -- Chapter 1: Arrival & orientation
            { id=0, name="Return to Quel'Thalas",          type="campaign", x=0.54, y=0.32, xp=12000, priority=1  },
            { id=0, name="The Sunwell's Call",              type="campaign", x=0.51, y=0.29, xp=12000, priority=2  },
            { id=0, name="Echoes of the Sunwell",           type="campaign", x=0.55, y=0.28, xp=12000, priority=3  },
            { id=0, name="Sins of the Past",                type="campaign", x=0.48, y=0.34, xp=14000, priority=4  },
            -- Chapter 1 side quests (Isle of Quel'Danas hub)
            { id=0, name="Suncrystal Deposits",             type="side",     x=0.42, y=0.25, xp=8000,  priority=10 },
            { id=0, name="Reclaiming the Isle",             type="side",     x=0.45, y=0.22, xp=8000,  priority=11 },
        },
    },
    {
        step        = 2,
        zone        = "Eversong Woods",
        hub         = "Fairbreeze Village",
        level_range = {81, 82},
        mapID       = 2393,
        quests = {
            -- Chapter 2: Amani resurgence
            { id=0, name="Amani Threat",                    type="campaign", x=0.64, y=0.55, xp=14000, priority=1  },
            { id=0, name="Trolls in the Forest",            type="campaign", x=0.68, y=0.60, xp=14000, priority=2  },
            { id=0, name="Bearing Witness",                 type="campaign", x=0.70, y=0.58, xp=14000, priority=3  },
            { id=0, name="Blood in the Eversong",           type="campaign", x=0.65, y=0.65, xp=16000, priority=4  },
            -- Side quests
            { id=0, name="Azure Dreamleaf",                 type="side",     x=0.60, y=0.52, xp=9000,  priority=10 },
            { id=0, name="Tending the Wound",               type="side",     x=0.72, y=0.57, xp=9000,  priority=11 },
            -- First Craft reminder (Alchemy + Herbalism players; injected by FirstCraft module)
            { id=0, name="First Flask: Silvermoon Apothecary", type="firstcraft", x=0.50, y=0.35, xp=20000, priority=5 },
        },
    },
    {
        step        = 3,
        zone        = "Eversong Woods",
        hub         = "Quel'Lithien Lodge",
        level_range = {82, 83},
        mapID       = 2393,
        quests = {
            -- Chapter 3: Void corruption in eastern Eversong
            { id=0, name="Corruption at the Lodge",         type="campaign", x=0.78, y=0.42, xp=16000, priority=1  },
            { id=0, name="Seeds of Doubt",                  type="campaign", x=0.80, y=0.38, xp=16000, priority=2  },
            { id=0, name="Burning the Evidence",            type="campaign", x=0.82, y=0.45, xp=16000, priority=3  },
            { id=0, name="Report to the Regent Lord",       type="campaign", x=0.54, y=0.32, xp=18000, priority=4  },
            -- Side quests
            { id=0, name="Stray Springpaw",                 type="side",     x=0.75, y=0.40, xp=9000,  priority=10 },
            { id=0, name="Gems of the Forest",              type="side",     x=0.83, y=0.50, xp=9000,  priority=11 },
        },
    },

    -- ════════════════════════════════════════════════════════════════
    -- STEP 4 — Zul'Aman  (levels 83-86)   mapID 2395
    -- ════════════════════════════════════════════════════════════════
    {
        step        = 4,
        zone        = "Zul'Aman",
        hub         = "Zul'Aman Staging Grounds",
        level_range = {83, 84},
        mapID       = 2395,
        quests = {
            { id=0, name="Into the Jungle",                 type="campaign", x=0.28, y=0.35, xp=18000, priority=1  },
            { id=0, name="Hex and Feathers",                type="campaign", x=0.32, y=0.40, xp=18000, priority=2  },
            { id=0, name="The Amani War Drums",             type="campaign", x=0.36, y=0.44, xp=18000, priority=3  },
            { id=0, name="Nalorakk's Shadow",               type="campaign", x=0.40, y=0.50, xp=20000, priority=4  },
            { id=0, name="Jungle Forage",                   type="side",     x=0.25, y=0.38, xp=10000, priority=10 },
            { id=0, name="Raptor Hides",                    type="side",     x=0.35, y=0.36, xp=10000, priority=11 },
        },
    },
    {
        step        = 5,
        zone        = "Zul'Aman",
        hub         = "Shrine of Nalorakk",
        level_range = {84, 85},
        mapID       = 2395,
        quests = {
            { id=0, name="The Bear God's Lair",             type="campaign", x=0.48, y=0.55, xp=20000, priority=1  },
            { id=0, name="Offerings to Nalorakk",           type="campaign", x=0.52, y=0.58, xp=20000, priority=2  },
            { id=0, name="Silencing the Drums",             type="campaign", x=0.45, y=0.62, xp=20000, priority=3  },
            { id=0, name="Den of Nalorakk",                 type="delve",    x=0.50, y=0.68, xp=25000, priority=5  },
            { id=0, name="Jungle Herbs",                    type="side",     x=0.42, y=0.52, xp=11000, priority=10 },
        },
    },
    {
        step        = 6,
        zone        = "Zul'Aman",
        hub         = "Altar of Har'koa",
        level_range = {85, 86},
        mapID       = 2395,
        quests = {
            { id=0, name="The Leopard Goddess",             type="campaign", x=0.62, y=0.48, xp=22000, priority=1  },
            { id=0, name="Har'koa's Bargain",               type="campaign", x=0.65, y=0.44, xp=22000, priority=2  },
            { id=0, name="Trolls Never Rest",               type="campaign", x=0.68, y=0.52, xp=22000, priority=3  },
            { id=0, name="Escaping the Jungle",             type="campaign", x=0.72, y=0.55, xp=24000, priority=4  },
            { id=0, name="Jungle Flowers",                  type="side",     x=0.58, y=0.46, xp=12000, priority=10 },
            { id=0, name="Talisman Fragments",              type="side",     x=0.66, y=0.60, xp=12000, priority=11 },
        },
    },

    -- ════════════════════════════════════════════════════════════════
    -- STEP 7 — Harandar  (levels 86-88)   mapID 2405
    -- ════════════════════════════════════════════════════════════════
    {
        step        = 7,
        zone        = "Harandar",
        hub         = "The Breach",
        level_range = {86, 87},
        mapID       = 2405,
        quests = {
            { id=0, name="Harandar Awaits",                 type="campaign", x=0.35, y=0.30, xp=24000, priority=1  },
            { id=0, name="Void Rifts",                      type="campaign", x=0.38, y=0.35, xp=24000, priority=2  },
            { id=0, name="Corruption Samples",              type="campaign", x=0.42, y=0.38, xp=24000, priority=3  },
            { id=0, name="Shadow Enclave",                  type="delve",    x=0.40, y=0.45, xp=30000, priority=5  },
            { id=0, name="Harandar Herbs",                  type="side",     x=0.30, y=0.28, xp=13000, priority=10 },
            { id=0, name="Voidstone Shards",                type="side",     x=0.44, y=0.32, xp=13000, priority=11 },
        },
    },
    {
        step        = 8,
        zone        = "Harandar",
        hub         = "Citadel of Harandar",
        level_range = {87, 88},
        mapID       = 2405,
        quests = {
            { id=0, name="The Void General",                type="campaign", x=0.55, y=0.50, xp=26000, priority=1  },
            { id=0, name="Siege Protocols",                 type="campaign", x=0.58, y=0.54, xp=26000, priority=2  },
            { id=0, name="Unmaking the Citadel",            type="campaign", x=0.60, y=0.60, xp=26000, priority=3  },
            { id=0, name="The Last Ritual",                 type="campaign", x=0.62, y=0.65, xp=28000, priority=4  },
            { id=0, name="Void Moss",                       type="side",     x=0.52, y=0.48, xp=14000, priority=10 },
            { id=0, name="Armour Salvage",                  type="side",     x=0.64, y=0.58, xp=14000, priority=11 },
        },
    },

    -- ════════════════════════════════════════════════════════════════
    -- STEP 9 — Arator's Journey  (levels 83-88, cross-continent)
    --   mapID 2413 for Quel'Thalas segment; also uses 14, 25, 27
    -- ════════════════════════════════════════════════════════════════
    {
        step        = 9,
        zone        = "Arator's Journey",
        hub         = "Eastern Plaguelands (Arator)",
        level_range = {83, 86},
        mapID       = 27,
        quests = {
            { id=0, name="Arator's Calling",                type="campaign", x=0.55, y=0.40, xp=20000, priority=1  },
            { id=0, name="Stratholme Memories",             type="campaign", x=0.60, y=0.45, xp=20000, priority=2  },
            { id=0, name="Ghosts of the Plague",            type="campaign", x=0.65, y=0.50, xp=20000, priority=3  },
            { id=0, name="Plaguebloom",                     type="side",     x=0.50, y=0.38, xp=11000, priority=10 },
        },
    },
    {
        step        = 10,
        zone        = "Arator's Journey",
        hub         = "Blackrock Mountain (Arator)",
        level_range = {85, 87},
        mapID       = 25,
        quests = {
            { id=0, name="Fire and Shadow",                 type="campaign", x=0.50, y=0.50, xp=22000, priority=1  },
            { id=0, name="Blackrock Alliance",              type="campaign", x=0.54, y=0.55, xp=22000, priority=2  },
            { id=0, name="The Dark Iron Pact",              type="campaign", x=0.58, y=0.60, xp=24000, priority=3  },
        },
    },
    {
        step        = 11,
        zone        = "Arator's Journey",
        hub         = "Arathi Highlands (Arator)",
        level_range = {86, 88},
        mapID       = 14,
        quests = {
            { id=0, name="Arathi Reckoning",                type="campaign", x=0.48, y=0.42, xp=24000, priority=1  },
            { id=0, name="The Witherbark Way",              type="campaign", x=0.52, y=0.48, xp=24000, priority=2  },
            { id=0, name="Cycle Complete",                  type="campaign", x=0.45, y=0.38, xp=26000, priority=3  },
            { id=0, name="Kingsblood",                      type="side",     x=0.44, y=0.40, xp=13000, priority=10 },
        },
    },

    -- ════════════════════════════════════════════════════════════════
    -- STEP 12 — Voidstorm  (levels 88-90)   mapID 2437
    -- ════════════════════════════════════════════════════════════════
    {
        step        = 12,
        zone        = "Voidstorm",
        hub         = "The Eye of the Void",
        level_range = {88, 89},
        mapID       = 2437,
        quests = {
            { id=0, name="Into the Voidstorm",              type="campaign", x=0.40, y=0.35, xp=30000, priority=1  },
            { id=0, name="Void Touched",                    x=0.44, y=0.40, type="campaign", xp=30000, priority=2  },
            { id=0, name="Ancient Engines",                 type="campaign", x=0.48, y=0.45, xp=30000, priority=3  },
            { id=0, name="The Voidweaver",                  type="campaign", x=0.52, y=0.50, xp=32000, priority=4  },
            { id=0, name="Void Petals",                     type="side",     x=0.38, y=0.33, xp=16000, priority=10 },
            { id=0, name="Rift Crystals",                   type="side",     x=0.50, y=0.42, xp=16000, priority=11 },
        },
    },
    {
        step        = 13,
        zone        = "Voidstorm",
        hub         = "The Shattering Spire",
        level_range = {89, 90},
        mapID       = 2437,
        quests = {
            { id=0, name="Heart of the Tempest",            type="campaign", x=0.60, y=0.55, xp=34000, priority=1  },
            { id=0, name="Unmaking the Storm",              type="campaign", x=0.64, y=0.60, xp=34000, priority=2  },
            { id=0, name="The Final Void",                  type="campaign", x=0.68, y=0.65, xp=36000, priority=3  },
            { id=0, name="Sealing the Rift",                type="campaign", x=0.70, y=0.70, xp=40000, priority=4  },
            { id=0, name="Voidbloom",                       type="side",     x=0.58, y=0.52, xp=18000, priority=10 },
            { id=0, name="Stormshards",                     type="side",     x=0.72, y=0.62, xp=18000, priority=11 },
        },
    },
}

