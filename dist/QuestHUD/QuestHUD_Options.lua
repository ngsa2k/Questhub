
local addon, ns = ...;
local L = ns.L;
local playerDot_textures = {
	["blizz"]         = L["Blizzards player arrow"],
	["blizz-smaller"] = L["Blizzards player arrow (smaller)"],
	["gold"]          = L["Golden player dot"],
	["white"]         = L["White player dot"],
	["black"]         = L["Black player dot"],
	["hide"]          = L["Hide player arrow"],
};
local TrackingValues = {
	["true"] = SHOW,
	["false"] = HIDE,
	["client"] = L["TrackingOptionsLikeMinimap"]
}
local dbDefaults = {
	hud_scale=1.4, text_scale=1.4, hud_size=1,
	cardinalpoints_show=true,cardinalpoints_color1={1,0.82,0,0.7},cardinalpoints_color2={1,0.82,0,0.7},cardinalpoints_radius=0.47,
	coords_show=true,coords_bottom=false,coords_color={1,0.82,0,0.7},coords_radius=0.51,
	buttons_show=false,buttons_buttom=false,buttons_alpha=0.6,buttons_radius=0.56,
	time_show=true, time_server=true, time_local=true, time_radius = 0.48, time_bottom=false, time_color={1,0.82,0,0.7},
	mouseoverinfo_color={1,0.82,0,0.7},
	player_dot="blizz", holdKeyForMouseOn = "_none",
	rotation=true, SuperTrackedQuest = true, showDummy = true, showDummyBg = true,
	QuestArrowInfoMsg = false,
	hideInInstance=false, hideInCombat=false,
	background_alpha=0, background_alpha2=0.5, background_alpha_toggle=true, background_alpha_default=true,
	-- QuestHUD feature defaults (merged from module dbDefaults tables)
}
local modDB = {};
local excludeFrames = {}
local isAddOnsLoadedForOption = {}

local function printFrames(key,value)
	local keyType = type(key);
	if keyType=="table" then
		if not QuestHUD:IsVisible() then
			ns:print("QuestHUD must be enabled before use this option");
			return;
		end

		ns:print("Search for unwanted elements anchored on minimap...");
		local count = 0;
		local regions = {Minimap:GetRegions()};
		for r=1, #regions do
			ns:print("GetRegions(): "..regions[r]:GetDebugName());
			count = count + 1;
		end

		--ns:print("Search for unwanted frames anchored on minimap... (deep reverse search)");
		for k,v in pairs(_G) do
			if not (issecurevariable(_G,k)) and (not excludeFrames[key]) and (type(value)=="table") and (type(value[0])=="userdata") and (not (value:IsProtected() or value:IsForbidden())) then
				if printFrames(k,v) then
					count = count + 1;
				end
			end
		end

		--ns:print("Search for unwanted textures/fontstrings anchored on minimap...");
		local childs = {Minimap:GetChildren()};
		for i=1, #childs do
			ns:print("GetChildren(): "..childs[i]:GetDebugName());
			count = count + 1;
		end

		if count>0 then
			ns:print("Finished...");
		else
			ns:print("No elements found...");
		end
		return;
	end

	for i=1, value:GetNumPoints() do
		local _,parent = value:GetPoint(i);
		if parent==Minimap then
			ns:print("pairs(_G): "..value:GetDebugName());
			return true;
		end
	end
end

local function checkAddOnLoaded(info)
	local key,pKey = info[#info],info[#info-1];
	if isAddOnsLoadedForOption[key] then
		return not C_AddOns.IsAddOnLoaded(isAddOnsLoadedForOption[key].addon);
	elseif isAddOnsLoadedForOption[pKey] then
		local isLoaded = C_AddOns.IsAddOnLoaded(isAddOnsLoadedForOption[pKey].addon) and "Loaded" or "NotLoaded";
		if isAddOnsLoadedForOption[pKey][key..isLoaded] then
			return isAddOnsLoadedForOption[pKey][key..isLoaded];
		elseif isAddOnsLoadedForOption[pKey][key] then
			return isAddOnsLoadedForOption[pKey][key];
		end
	end
end

local function opt(info,value,...)
	local key,reset = info[#info],info[#info]:gsub("reset","");
	if key~=reset then
		if dbDefaults[reset]~=nil then
			QuestHUDDB[reset] = type(dbDefaults[reset])=="table" and CopyTable(dbDefaults[reset]) or dbDefaults[reset];
			QuestHUD:UpdateOptions(reset);
		end
		return;
	elseif value~=nil then
		if key=="MinimapIcon" then
			QuestHUDDB[key].hide = not value;
			LibStub("LibDBIcon-1.0", true):Refresh(addon);
		else
			if (...) then
				value = {value,...}; -- color table
			end
			QuestHUDDB[key] = value;
		end
		if modDB[key] and ns.modules[modDB[key]] then
			ns.modules[modDB[key]].UpdateOptions(key,value)
		else
			QuestHUD:UpdateOptions(key);
		end
		return;
	elseif key=="MinimapIcon" then
		return not QuestHUDDB[key].hide;
	elseif type(QuestHUDDB[key])=="table" then
		return unpack(QuestHUDDB[key]); -- color table
	end
	return QuestHUDDB[key];
end

local function optKeyBind(info,value)
	local key = info[#info];
	if value~=nil then
		local valueB = GetBindingKey(key);
		if valueB then
			SetBinding(valueB);
		end
		if value~="" then
			SetBinding(value, key);
		end
		SaveBindings(GetCurrentBindingSet());
	end
	return GetBindingKey(key);
end

local function optTracking(info,value)
	local key = info[#info];
	if not key:find("^tracking^%d+$") then return end

	if value~=nil then
		QuestHUDDB[key] = value;
		QuestHUD:UpdateOptions(key);
		return;
	end
	return QuestHUDDB[key];
end

local options = {
	type = "group",
	name = addon,
	childGroups = "tree",
	get = opt,
	set = opt,
	func = opt,
	args = {
		general = {
			type = "group", order = 0,
			name = COMPACT_UNIT_FRAME_PROFILE_SUBTYPE_ALL,
			args = {
				MinimapIcon = {
					type = "toggle", order = 1,
					name = L["MinimapIcon"], desc = L["MinimapIconDesc"]
				},
				AddOnLoaded = {
					type = "toggle", order = 2,
					name = L["AddOnLoaded"], desc = L["AddOnLoadedDesc"].."|n|n|cff44ff44"..L["AddOnLoadedDescAlt"].."|r"
				},
				rotation = {
					type = "toggle", order = 3, width="full",
					name = L["Rotation"], desc = L["RotationDesc"]
				},
				hud_scale = {
					type = "range", order = 11,
					name = L["HudSymbolScale"], desc = L["HudSymbolScaleDesc"],
					min = 1, max = 2.5, step = 0.1, isPercent = true
				},
				hud_size = {
					type = "range", order = 12,
					name = L["HudSize"], desc = L["HudSizeDesc"],
					min = 0.1, max = 1, step = 0.1, isPercent = true
				},
				text_scale = {
					type = "range", order = 13,
					name = L["TextScale"], desc = L["TextScaleDesc"],
					min = 1, max = 2.5, step = 0.1, isPercent = true
				},
				player_dot = {
					type = "select", order = 15,
					name = L["PlayerDot"], desc = L["PlayerDotDesc"],
					values = playerDot_textures
				},
				autohide = {
					type="group", order = 20, inline=true,
					name = L["AutoHide"],
					args = {
						hideInInstance = {type="toggle", order=1, name=L["HideInInstance"], desc=L["HideInInstanceDesc"]},
						hideInCombat = {type="toggle", order=2, name=L["hideInCombat"], desc=L["hideInCombatDesc"]},
					}
				},
				placeholder = {
					type = "group", order = 98, inline = true,
					name = L["Placeholder"],
					args = {
						desc = {
							type = "description", order = 0, fontSize = "medium",
							name = L["PlaceholderDesc"]
						},
						showDummy = {
							type = "toggle", order = 1,
							name = L["ShowPlaceholder"], desc = L["ShowPlaceholderDesc"]
						},
						showDummyBg = {
							type = "toggle", order = 2,
							name = L["ShowPlaceholderBg"], desc = L["ShowPlaceholderBgDesc"]
						},
					}
				},
				mouseover = {
					type = "group", order = 99, inline=true,
					name = L["MouseOver"],
					args = {
						holdKeyForMouseOn = {
							type = "select", order = 3, width="double";
							name = L["MouseOverOnHold"],
							desc = L["MouseOverOnHoldDesc"],
							values = {
								["_NONE"] = NONE.."/"..ADDON_DISABLED,
								A  = ALT_KEY,
								AL = LALT_KEY_TEXT,
								AR = RALT_KEY_TEXT,
								C  = CTRL_KEY,
								CL = LCTRL_KEY_TEXT,
								CR = RCTRL_KEY_TEXT,
								S  = SHIFT_KEY,
								SL = LSHIFT_KEY_TEXT,
								SR = RSHIFT_KEY_TEXT,
							}
						},
						mouseoverinfo_color = {
							type = "color", order = 1,
							name = COLOR, desc = L["MouseOverInfoColorDesc"],
							hasAlpha = true
						},
						mouseoverinfo_resetcolor = {
							type = "execute", order = 2,
							name = L["ResetColor"], --desc = L["ResetColorDesc"]
						},
					}
				}
			}
		},
		----------------------------------------------
		background = {
			type="group", order = 1,
			name=L["BgMinimap"],
			args={
				desc = {
					type="description", order=0,
					name=L["BgMinimapDesc"]
				},
				background_alpha = {
					type = "range", order = 1,
					name = L["BgTransparency1"], desc = L["BgTransparencyDesc1"],
					min = 0.0, max = 1, step = 0.1, isPercent = true,
					get = function()
						return 1-QuestHUDDB.background_alpha
					end,
					set = function(info,value)
						QuestHUDDB.background_alpha = 1-value;
						QuestHUD:UpdateOptions("background_alpha");
					end
				},
				background_alpha2 = {
					type = "range", order = 2,
					name = L["BgTransparency2"], desc = L["BgTransparencyDesc2"],
					min = 0.0, max = 1, step = 0.1, isPercent = true,
					get = function()
						return 1-QuestHUDDB.background_alpha2
					end,
					set = function(info,value)
						QuestHUDDB.background_alpha2 = 1-value;
						QuestHUD:UpdateOptions("background_alpha2");
					end
				},
				background_alpha_default = {
					type = "toggle", order = 4,
					name = L["BgAlphaDefault"],
					desc = L["BgAlphaDefaultDesc"]
				}
			}
		},
		SuperTrackedQuest = {
			type = "group", order = 1,
			name = L["QuestArrow"],
			args = {
				desc = {
					type = "description", order=1, fontSize="medium",
					name = checkAddOnLoaded,-- ({"SuperTrackedQuest","desc"}),
				},
				SuperTrackedQuest = {
					type = "toggle", order = 2, width = "full",
					name = L["QuestArrowHide"], --desc = L["QuestArrowHideDesc"],
					disabled = checkAddOnLoaded
				},
				QuestArrowInfoMsg = {
					type = "toggle", order = 3, width = "full",
					name = L["QuestArrowInfoMsg"], desc = L["QuestArrowInfoMsgDesc"]
				}
			}
		},
		rangecircles_old = {
			type = "group", order = 2, hidden=true,
			name = L["RangeCircles"],
			args = {
				-- gathercircle
				gathercircle = {
					type = "header", order = 10,
					name = L["GatherCircle"],
				},
				gathercircle_desc = {
					type = "description", order = 11, fontSize = "medium",
					name = L["GatherCircleDesc"]
				},
				gathercircle_show = {
					type = "toggle", order = 12, width = "double",
					name = L["GatherCircleShow"], desc = L["GatherCircleShowDesc"]
				},
				gathercircle_color = {
					type = "color", order = 13,
					name = COLOR, desc = L["GatherCircleColorDesc"],
					hasAlpha = true
				},
				gathercircle_resetcolor = {
					type = "execute", order = 14,
					name = L["ResetColor"], --desc = L["ResetColorDesc"]
				},
				-- healcircle
				healcircle = {
					type = "header", order = 20,
					name = L["HealCircle"],
				},
				healcircle_desc = {
					type = "description", order = 21, fontSize = "medium",
					name = L["HealcircleDesc"]
				},
				healcircle_show = {
					type = "toggle", order = 22, width = "double",
					name = L["HealcircleShow"], desc = L["HealcircleShowDesc"]
				},
				healcircle_color = {
					type = "color", order = 23,
					name = COLOR, desc = L["HealcircleColorDesc"],
					hasAlpha = true
				},
				healcircle_resetcolor = {
					type = "execute", order = 24,
					name = L["ResetColor"], --desc = L["ResetColorDesc"]
				},
			}
		},
		coords = {
			type = "group", order = 4,
			name = L["Coords"],
			args = {
				coords_show = {
					type = "toggle", order = 1,
					name = L["CoordsShow"], desc = L["CoordsShowDesc"]
				},
				coords_radius = {
					type = "range", order = 2,
					name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				coords_bottom = {
					type = "toggle", order = 3, width = "double",
					name = L["CoordsBottom"], desc = L["CoordsBottomDesc"]
				},
				coords_color = {
					type = "color", order = 4, hasAlpha = true,
					name = COLOR, desc = L["CoordsColorDesc"]
				},
				coords_resetcolor = {
					type = "execute", order = 5,
					name = L["ResetColor"], desc = L["CoordsColorResetDesc"]
				}
			}
		},
		time = {
			type = "group", order = 5,
			name = L["Time"],
			args = {
				time_show = {
					type = "toggle", order = 1, width = "full",
					name = L["TimeShow"], desc = L["TimeShowDesc"]
				},
				time_server = {
					type = "toggle", order = 2,
					name = L["TimeServer"], desc = L["TimeServerDesc"]
				},
				time_local = {
					type = "toggle", order = 3,
					name = L["TimeLocal"], desc = L["TimeLocalDesc"]
				},
				time_radius = {
					type = "range", order = 4,
					name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				time_bottom = {
					type = "toggle", order = 5, width = "double",
					name = L["TimeBottom"], desc = L["TimeBottomDesc"]
				},
				time_color = {
					type = "color", order = 6, hasAlpha = true,
					name = COLOR, desc = L["TimeColorDesc"]
				},
				time_resetcolor = {
					type = "execute", order = 7,
					name = L["ResetColor"], desc = L["TimeColorResetDesc"]
				},
			}
		},
		onscreenbuttons = {
			type = "group", order = 6,
			name = L["OnScreen"],
			args = {
				buttons_show = {
					type = "toggle", order = 1, width = "double",
					name = L["OnScreenShow"], desc = L["OnScreenShowDesc"]
				},
				buttons_bottom = {
					type = "toggle", order = 2, width = "double",
					name = L["OnScreenBottom"], desc = L["OnScreenBottomDesc"],
				},
				buttons_radius = {
					type = "range", order = 3,
					name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				buttons_alpha = {
					type = "range", order = 4,
					name = OPACITY, desc = L["OnScreenAlphaDesc"],
					min = 0, max = 1, step = 0.1, isPercent = true
				}
			}
		},
		tracking = {
			type = "group", order = 8,
			name = L["TrackingOptions"],
			get = optTracking, set = optTracking,
			childGroups = "tab",
			args = {
				desc = {
					type = "description", order = 1, fontSize = "medium",
					name = L["TrackingOptionsDesc"]
				},
				misc = {
					type = "group", order = 2,
					name = MISCELLANEOUS,
					args = {
						-- filled by function updateTrackingOptions
					},
					hidden = true,
				},
				townsfolk = {
					type = "group", order = 3,
					name = TOWNSFOLK_TRACKING_TEXT,
					args = {
						-- filled by function updateTrackingOptions
					},
					hidden = true,
				}
			}
		},
		keybindings = {
			type = "group", order = 99,
			name = KEY_BINDINGS,
			get = optKeyBind,
			set = optKeyBind,
			args = {
				TOGGLEQUESTHUD = {
					type = "keybinding", order = 1, width = "double",
					name = L["KeyBindToggle"], desc = L["KeyBindToggleDesc"]
				},
				TOGGLEQUESTHUDMOUSE = {
					type = "keybinding", order = 2, width = "double",
					name = L["KeyBindMouse"], desc = L["KeyBindMouseDesc"]
				},
				TOGGLEQUESTHUDBACKGROUND = {
					type = "keybinding", order = 3, width = "double",
					name = L["KeyBindBackground"], desc = L["KeyBindBackgroundDesc"]
				},
			}
		},
		debugging = {
			type = "group", order = 100,
			name = BINDING_HEADER_DEBUG,
			args = {
				info = {
					type = "description", order = 1, fontSize = "med",
					name = L["DebugOptInfo"]
				},
				frames = {
					type = "execute", order = 2,
					name = L["DebugOptFrames"],
					func = printFrames
				}
			}
		},
		credits = {
			type = "group", order = 200,
			name = L["Credits"],
			args = {}
		},
	}
};

local trackingTypes,trackingOpts,trackingTemplate = {},{},{
	type = "select", name = "", values = TrackingValues
};
local trackingPattern = "|T%d:26:26:0:0|t %s"

local function sortTrackingTypes(a,b)
	return a.index<b.index;
end

local function updateTrackingOptions(info)
	if info[#info]~="tracking" then return false end
	-- QuestHUD does not use minimap tracking-type options; keep section hidden.
	return true
end

function ns.RegisterOptions()
	if QuestHUDDB==nil then
		QuestHUDDB={};
	end

	if QuestHUDDB.MinimapIcon==nil then
		QuestHUDDB.MinimapIcon = {
			hide = false,
			minimapPos = 220,
			radius = 80
		};
	end

	-- Tracking types not used by QuestHUD (ns.GetTrackingTypes returns {})

	local modOptsOrder = 50;
	for modName, mod in pairs(ns.modules)do
		if mod.dbDefaults then
			for k,v in pairs(mod.dbDefaults)do
				if (dbDefaults[k]==nil) then
					dbDefaults[k] = v
					modDB[k] = modName;
				end
			end
		end
		if mod.AddOptions then
			local opts = mod.AddOptions()
			if type(opts)=="table" then
				for k,v in pairs(opts)do
					options.args[k] = v;
					if v.order==nil then
						v.order = modOptsOrder;
						modOptsOrder = modOptsOrder + 1;
					end
				end
			end
		end
	end

	for k,v in pairs(dbDefaults)do
		if (QuestHUDDB[k]==nil) then
			QuestHUDDB[k]=v;
		end
	end

	if QuestHUDDB.hud_size==0 then
		QuestHUDDB.hud_size=1;
	end

	if QuestHUDDB.MinimapIcon.show~=nil then
		QuestHUDDB.MinimapIcon.hide = not QuestHUDDB.MinimapIcon.show;
		QuestHUDDB.MinimapIcon.show = nil;
	end

	-- Hide the old tracking section (not used by QuestHUD)
	options.args.tracking.hidden = true;

	LibStub("AceConfig-3.0"):RegisterOptionsTable(addon, options);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addon);
end

if AddonCompartmentFrame then
	AddonCompartmentFrame:RegisterAddon({
		icon = 134215,
		text = addon,
		notCheckable = true,
		func = QuestHUDMixin.ToggleOptions
	 })
end
