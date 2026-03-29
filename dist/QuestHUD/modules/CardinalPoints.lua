
local addon,ns = ...;
local L = ns.L;
local cardinalTicker;

local module = {
	dbDefaults={
		cardinalpoints_show=true,
		cardinalpoints_color1={1,0.82,0,0.7},
		cardinalpoints_color2={1,0.82,0,0.7},
		cardinalpoints_radius=0.47,

	},
	events = {},
	OnShow = nil,
	OnHide = nil
}


local function CardinalPointsUpdate_TickerFunc()
	local bearing = GetPlayerFacing();
	local scaledRadius;
	scaledRadius = QuestHUDDB.cardinalpoints_radius and (QuestHUD.TextFrame.ScaledHeight * QuestHUDDB.cardinalpoints_radius) or (QuestHUD.TextFrame.ScaledHeight * 0.47)

	for i=1, #QuestHUD.TextFrame.cardinalPoints do
		local cp = QuestHUD.TextFrame.cardinalPoints[i];
		cp:ClearAllPoints();
		if bearing then
			cp:SetPoint("CENTER", QuestHUD, "CENTER", math.sin(cp.rot+bearing)*scaledRadius, math.cos(cp.rot+bearing)*scaledRadius);
		end
	end
end

function module.ToggleCardicalPoints(state)
	if QuestHUDDB.cardinalpoints_show then
		if not cardinalTicker and state~=false then
			cardinalTicker = C_Timer.NewTicker(1/24, CardinalPointsUpdate_TickerFunc);
		elseif cardinalTicker and state==false then
			cardinalTicker:Cancel();
			cardinalTicker = nil;
		end
		if not GetPlayerFacing() then
			state = false;
		end
		for i,e in ipairs(QuestHUD.TextFrame.cardinalPoints) do
			e:SetShown(state);
		end
	else
		if cardinalTicker then
			cardinalTicker:Cancel();
			cardinalTicker = nil;
		end
		for i,e in ipairs(QuestHUD.TextFrame.cardinalPoints) do
			e:SetShown(false);
		end
	end
end

function module.OnShow()
	module.ToggleCardicalPoints(true)
end

function module.OnHide()
	module.ToggleCardicalPoints(false)
end

local function opt(info,value,...)
	local key = info[#info];
	if value~=nil then
		if (...)~=nil then
			value = {value,...}
		end
		QuestHUDDB[key] = value
		if key=="cardinalpoints_show" then
			module.ToggleCardicalPoints(QuestHUD:IsShown())
		end
	end
	if type(QuestHUDDB[key])=="table" then
		return unpack(QuestHUDDB[key]);
	end
	return QuestHUDDB[key]
end

local options = {
	cardinalpoints = {
		type = "group", order = 3,
		name = L["CardinalPoints"],
		get=opt,set=opt,
		args = {
			cardinalpoints_show = {
				type = "toggle", order = 1, width = "double",
				name = L["CardinalPointsShow"], desc = L["CardinalPointsShowDesc"],
			},

			cardinalpoints_radius = {
				type = "range", order = 3, width = "double",
				name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
				min = 0.1, max = 0.95, step=0.005, isPercent=true,
			},

			cardinalpoints_header1 = {
				type = "header", order = 6,
				name = L["CardinalPointsGroup1"]
			},
			cardinalpoints_color1 = {
				type = "color", order = 7, hasAlpha = true,
				name = COLOR, desc = L["CardinalPointsColorDesc"]:format(L["CardinalPointsGroup1"])
			},
			cardinalpoints_resetcolor1 = {
				type = "execute", order = 8,
				name = L["ResetColor"], desc = L["CardinalPointsColorResetDesc"]:format(L["CardinalPointsGroup1"])
			},
			cardinalpoints_header2 = {
				type = "header", order = 9,
				name = L["CardinalPointsGroup2"]
			},
			cardinalpoints_color2 = {
				type = "color", order = 10, hasAlpha = true,
				name = COLOR, desc = L["CardinalPointsColorDesc"]:format(L["CardinalPointsGroup2"])
			},
			cardinalpoints_resetcolor2 = {
				type = "execute", order = 11,
				name = L["ResetColor"], desc = L["CardinalPointsColorResetDesc"]:format(L["CardinalPointsGroup2"])
			}
		}
	},
}

function module.AddOptions()
	return options
end

--function module.events.ADDON_LOADED() end

function module.events.PLAYER_LOGIN()
	--QuestHUD:UpdateCardinalPoints();
	for k,v in pairs(module.dbDefaults)do
		if QuestHUDDB[k]==nil then
			QuestHUDDB[k] = CopyTable(module.dbDefaults);
		end
	end
end

ns.modules["CardinalPoints"] = module;
