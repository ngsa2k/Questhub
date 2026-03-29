
# Build-QuestHUD.ps1 - Transforms FarmHud sources into QuestHUD

Set-Location "c:\Code\Questhub"

function ReplaceExact($text, $old, $new) {
    # Normalize line endings so CRLF here-strings match LF file content
    $old = $old.Replace("`r`n", "`n")
    $new = $new.Replace("`r`n", "`n")
    if (-not $text.Contains($old)) {
        Write-Host "WARNING: Could not find: [$($old.Substring(0,[Math]::Min(80,$old.Length)))]"
        return $text
    }
    return $text.Replace($old, $new)
}

# ============================================================
# QuestHUD.lua
# ============================================================
Write-Host "Processing QuestHUD.lua..."
$lua = Get-Content "FarmHud-master\FarmHud.lua" -Raw
# normalize to LF
$lua = $lua.Replace("`r`n", "`n")

# 1. HizurosSharedTools header replacement
$lua = ReplaceExact $lua @'
local addon,ns=...;
local L=ns.L;
ns.debugMode = "@project-version@"=="@".."project-version".."@";
LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"FH");
'@ @'
local addon, ns = ...
ns.debugMode = false
ns.print = function(_, msg) print("|cff00ff00[QuestHUD]|r " .. tostring(msg)) end
local L = ns.L;
'@

# 2. Remove QuestArrowToken
$lua = ReplaceExact $lua "`nns.QuestArrowToken = {};`n" "`n"

# 3. Remove tracking locals
$lua = ReplaceExact $lua "`nlocal trackingTypes,trackingTypesStates,numTrackingTypes,trackingHookLocked = {},{},0,false;`n" "`n"

# 4. Change ignoreFrames to empty
$lua = ReplaceExact $lua @'
local ignoreFrames = {
	FarmHudRangeCircles=true
}
'@ 'local ignoreFrames = {}'

# 5. Remove tracking options section (GetTrackingTypes + TrackingTypes_Update)
$startIdx = $lua.IndexOf("-- tracking options")
$endIdx   = $lua.IndexOf("-- repalce CreateTexture")
if ($startIdx -ge 0 -and $endIdx -ge 0) {
    $lua = $lua.Substring(0, $startIdx) + $lua.Substring($endIdx)
    Write-Host "  Tracking section removed"
} else {
    Write-Host "  WARNING: tracking section markers not found"
}

# 6. Remove GatherMate2 line in objectToDummy
$lua = ReplaceExact $lua @"
	or (_G["GatherMate2"] and objName:match("GatherMatePin")) -- ignore Gathermate2Pins
"@ ""

# 7. Remove GatherMate2 block in UpdateForeignAddOns
$lua = ReplaceExact $lua @"
	if _G["GatherMate2"] then
		_G["GatherMate2"]:GetModule("Display"):ReparentMinimapPins(Map);
	end
"@ ""

# 8. Remove tracking^%d+ block in UpdateOptions
$lua = ReplaceExact $lua @'
		elseif key:find("tracking^%d+") and not ns.IsClassic() then
			local id = tonumber((key:match("^tracking%^(%d+)$")));
			if id then
				TrackingTypes_Update(true,id);
			end
'@ ""

# 9. Remove SuperTrackedQuest block in UpdateOptions
$lua = ReplaceExact $lua @'
		elseif IsKey(key,"SuperTrackedQuest") and FarmHud_ToggleSuperTrackedQuest and FarmHud:IsShown() then
			FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,FarmHudDB.SuperTrackedQuest);
'@ ""

# 10. Remove FarmHud_ToggleSuperTrackedQuest block in OnShow
$lua = ReplaceExact $lua @'

	if FarmHud_ToggleSuperTrackedQuest and FarmHudDB.SuperTrackedQuest then
		FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,true); -- FarmHud_QuestArrow
	end

	SetPlayerDotTexture(true);
	TrackingTypes_Update(true);
'@ @'

	SetPlayerDotTexture(true);
'@

# 11. Remove FarmHud_ToggleSuperTrackedQuest block in OnHide
$lua = ReplaceExact $lua @'

	if FarmHud_ToggleSuperTrackedQuest and FarmHudDB.SuperTrackedQuest then
		FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,false); -- FarmHud_QuestArrow
	end

	ns.modules("OnHide");

	SetPlayerDotTexture(false);
	TrackingTypes_Update(false);
'@ @'

	ns.modules("OnHide");

	SetPlayerDotTexture(false);
'@

# 12. Remove hooksecurefunc SetTracking block
$lua = ReplaceExact $lua @'

	if not ns.IsClassic() then
		local function hookSetTracking(index,bool)
			if not trackingHookLocked and FarmHud:IsVisible() and trackingTypesStates[index]~=nil then
				trackingTypesStates[index]=nil;
			end
		end
		hooksecurefunc(C_Minimap,"SetTracking",hookSetTracking);
	end

	function self.cluster:GetZoom()
'@ @'

	function self.cluster:GetZoom()
'@

# 13. Remove AddChatMessage method (references QuestArrowToken)
$lua = ReplaceExact $lua @'

function FarmHudMixin:AddChatMessage(token,msg)
	local from = (token==ns.QuestArrowToken and "QuestArrow") or false
	if from and type(msg)=="string" then
		ns:print("()",from,L[msg]);
	end
end

'@ "`n"

# 14. Remove debug-only Localization.imported / Localization.workfile references stay (they're in XML, not Lua)

# === Global Renames ===
# Most specific first
$lua = $lua.Replace("FarmHudonScreenButtonTemplate", "QuestHUDOnScreenButtonTemplate")
$lua = $lua.Replace("FarmHudMinimapDummyMixin", "QuestHUDMinimapDummyMixin")
$lua = $lua.Replace("FarmHudMinimapDummy", "QuestHUDMinimapDummy")
$lua = $lua.Replace("FarmHudMixin", "QuestHUDMixin")
$lua = $lua.Replace("FarmHudFont", "QuestHUDFont")
$lua = $lua.Replace("FarmHudDB", "QuestHUDDB")
$lua = $lua.Replace("FarmHud_Options", "QuestHUD_Options")
$lua = $lua.Replace("FarmHud_DataBroker", "QuestHUD_DataBroker")
# FarmHud generic (covers FarmHud: FarmHud. etc.)
$lua = $lua.Replace("FarmHud", "QuestHUD")
# Binding names (uppercase)
$lua = $lua.Replace("FARMHUD", "QUESTHUD")
$lua = $lua.Replace("TOGGLEFARMHUD", "TOGGLEQUESTHUD")

# Write output
[System.IO.File]::WriteAllText("$PWD\QuestHUD\QuestHUD.lua", $lua, [System.Text.UTF8Encoding]::new($false))
Write-Host "QuestHUD.lua written ($($lua.Length) chars)"

# Verify no FarmHud remaining
if ($lua -match "FarmHud") { Write-Host "WARNING: FarmHud refs remain in QuestHUD.lua:" ; ($lua | Select-String "FarmHud" -AllMatches).Matches | ForEach-Object { $_.Value } | Select-Object -First 10 }
else { Write-Host "OK - no FarmHud refs in QuestHUD.lua" }

# ============================================================
# QuestHUD.xml
# ============================================================
Write-Host "`nProcessing QuestHUD.xml..."
$xml = Get-Content "FarmHud-master\FarmHud.xml" -Raw
$xml = $xml.Replace("`r`n", "`n")

# Remove dev-only localization imports
$xml = ReplaceExact $xml @'
	<!--@do-not-package@-->
	<Script file="Localization.imported.lua"/>
	<Script file="Localization.workfile.lua"/>
	<!--@end-do-not-package@-->
'@ ""

# Remove TrailPath and RangeCircles script loads
$xml = ReplaceExact $xml @'
	<Script file="modules/TrailPath.lua"/>
	<Script file="modules/RangeCircles.lua" />
'@ ""

# Update main script references (FarmHud.lua -> QuestHUD.lua, etc.)
$xml = ReplaceExact $xml '<Script file="FarmHud.lua"/>' '<Script file="QuestHUD.lua"/>'
$xml = ReplaceExact $xml '<Script file="FarmHud_Options.lua"/>' '<Script file="QuestHUD_Options.lua"/>'
$xml = ReplaceExact $xml '<Script file="FarmHud_DataBroker.lua"/>' '<Script file="QuestHUD_DataBroker.lua"/>'

# Remove FarmHudTrailPathPinTemplate block
$startPinIdx = $xml.IndexOf("`n`t<Frame name=`"FarmHudTrailPathPinTemplate`"")
$endPinMarker = "`n`t<Frame name=`"FarmHudCircleLineTemplate`""
$endPinIdx = $xml.IndexOf($endPinMarker)
if ($startPinIdx -ge 0 -and $endPinIdx -ge 0) {
    $xml = $xml.Substring(0, $startPinIdx) + $xml.Substring($endPinIdx)
    Write-Host "  TrailPathPinTemplate removed"
}

# Remove FarmHudCircleLineTemplate block
$startCLIdx = $xml.IndexOf("`n`t<Frame name=`"FarmHudCircleLineTemplate`"")
$endCLMarker = "`n`t<Frame name=`"FarmHudRangeCircles`""
$endCLIdx = $xml.IndexOf($endCLMarker)
if ($startCLIdx -ge 0 -and $endCLIdx -ge 0) {
    $xml = $xml.Substring(0, $startCLIdx) + $xml.Substring($endCLIdx)
    Write-Host "  CircleLineTemplate removed"
}

# Remove FarmHudRangeCircles frame
$xml = ReplaceExact $xml "`n`t<Frame name=`"FarmHudRangeCircles`" mixin=`"FarmHudRangeCirclesMixin`" />`n" "`n"

# Update media texture paths (FarmHud -> QuestHUD in paths)
$xml = $xml.Replace("Interface\AddOns\FarmHud\media\", "Interface\AddOns\QuestHUD\media\")
$xml = $xml.Replace("Interface\\AddOns\\FarmHud\\media\\", "Interface\\AddOns\\QuestHUD\\media\\")

# Global renames
$xml = $xml.Replace("FarmHudonScreenButtonTemplate", "QuestHUDOnScreenButtonTemplate")
$xml = $xml.Replace("FarmHudMinimapDummyMixin", "QuestHUDMinimapDummyMixin")
$xml = $xml.Replace("FarmHudMinimapDummy", "QuestHUDMinimapDummy")
$xml = $xml.Replace("FarmHudMixin", "QuestHUDMixin")
$xml = $xml.Replace("FarmHudFont", "QuestHUDFont")
$xml = $xml.Replace("FarmHud", "QuestHUD")

[System.IO.File]::WriteAllText("$PWD\QuestHUD\QuestHUD.xml", $xml, [System.Text.UTF8Encoding]::new($false))
Write-Host "QuestHUD.xml written"
if ($xml -match "FarmHud") { Write-Host "WARNING: FarmHud refs remain in QuestHUD.xml" } else { Write-Host "OK - no FarmHud refs in QuestHUD.xml" }

# ============================================================
# QuestHUD_Options.lua
# ============================================================
Write-Host "`nProcessing QuestHUD_Options.lua..."
$opts = Get-Content "FarmHud-master\FarmHud_Options.lua" -Raw
$opts = $opts.Replace("`r`n", "`n")

# Remove QuestArrow/SuperTrackedQuest option entry
$opts = ReplaceExact $opts @'
local isAddOnsLoadedForOption = {
	SuperTrackedQuest = {
		addon="FarmHud_QuestArrow",
		descLoaded=GREEN_FONT_COLOR_CODE..L["ExtraAddOnLoaded"]:format("FarmHud [QuestArrow]").."|r",
		descNotLoaded=ORANGE_FONT_COLOR_CODE..L["ExtraAddOnNotLoaded"]:format("FarmHud [QuestArrow]").."|r"
	}
}
'@ 'local isAddOnsLoadedForOption = {}'

# Global renames
$opts = $opts.Replace("FarmHudonScreenButtonTemplate", "QuestHUDOnScreenButtonTemplate")
$opts = $opts.Replace("FarmHudMinimapDummyMixin", "QuestHUDMinimapDummyMixin")
$opts = $opts.Replace("FarmHudMinimapDummy", "QuestHUDMinimapDummy")
$opts = $opts.Replace("FarmHudMixin", "QuestHUDMixin")
$opts = $opts.Replace("FarmHudFont", "QuestHUDFont")
$opts = $opts.Replace("FarmHudDB", "QuestHUDDB")
$opts = $opts.Replace("FarmHud_QuestArrow", "QuestHUD_QuestArrow")
$opts = $opts.Replace("FarmHud_Options", "QuestHUD_Options")
$opts = $opts.Replace("FarmHud_DataBroker", "QuestHUD_DataBroker")
$opts = $opts.Replace("FarmHud", "QuestHUD")
$opts = $opts.Replace("FARMHUD_INVALID_INSTALLATION", "QUESTHUD_INVALID_INSTALLATION")

[System.IO.File]::WriteAllText("$PWD\QuestHUD\QuestHUD_Options.lua", $opts, [System.Text.UTF8Encoding]::new($false))
Write-Host "QuestHUD_Options.lua written"
if ($opts -match "FarmHud") { Write-Host "WARNING: FarmHud refs remain" } else { Write-Host "OK" }

# ============================================================
# QuestHUD_DataBroker.lua
# ============================================================
Write-Host "`nProcessing QuestHUD_DataBroker.lua..."
$db = Get-Content "FarmHud-master\FarmHud_DataBroker.lua" -Raw
$db = $db.Replace("`r`n", "`n")

$db = $db.Replace("FarmHudDB", "QuestHUDDB")
$db = $db.Replace("FarmHud", "QuestHUD")

[System.IO.File]::WriteAllText("$PWD\QuestHUD\QuestHUD_DataBroker.lua", $db, [System.Text.UTF8Encoding]::new($false))
Write-Host "QuestHUD_DataBroker.lua written"
if ($db -match "FarmHud") { Write-Host "WARNING: FarmHud refs remain" } else { Write-Host "OK" }

# ============================================================
# Localization.lua
# ============================================================
Write-Host "`nProcessing Localization.lua..."
$loc = Get-Content "FarmHud-master\Localization.lua" -Raw
$loc = $loc.Replace("`r`n", "`n")

$loc = $loc.Replace("BINDING_HEADER_FARMHUD", "BINDING_HEADER_QUESTHUD")
$loc = $loc.Replace("BINDING_NAME_TOGGLEFARMHUD", "BINDING_NAME_TOGGLEQUESTHUD")
$loc = $loc.Replace("FARMHUD", "QUESTHUD")
# keep the rest as-is (localization stubs etc.)

[System.IO.File]::WriteAllText("$PWD\QuestHUD\Localization.lua", $loc, [System.Text.UTF8Encoding]::new($false))
Write-Host "Localization.lua written"
if ($loc -match "FARMHUD|FarmHud") { Write-Host "WARNING: FarmHud refs remain" } else { Write-Host "OK" }

# ============================================================
# Bindings.xml
# ============================================================
Write-Host "`nProcessing Bindings.xml..."
$bindings = Get-Content "FarmHud-master\Bindings.xml" -Raw
$bindings = $bindings.Replace("`r`n", "`n")

$bindings = $bindings.Replace("TOGGLEFARMHUDBACKGROUND", "TOGGLEQUESTHUDBACKGROUND")
$bindings = $bindings.Replace("TOGGLEFARMHUDMOUSE", "TOGGLEQUESTHUDMOUSE")
$bindings = $bindings.Replace("TOGGLEFARMHUD", "TOGGLEQUESTHUD")
$bindings = $bindings.Replace("FARMHUD", "QUESTHUD")
$bindings = $bindings.Replace("FarmHud", "QuestHUD")

[System.IO.File]::WriteAllText("$PWD\QuestHUD\Bindings.xml", $bindings, [System.Text.UTF8Encoding]::new($false))
Write-Host "Bindings.xml written"
if ($bindings -match "FarmHud|FARMHUD") { Write-Host "WARNING: FarmHud refs remain" } else { Write-Host "OK" }

# ============================================================
# modules/CardinalPoints.lua
# ============================================================
Write-Host "`nProcessing modules/CardinalPoints.lua..."
$cp = Get-Content "FarmHud-master\modules\CardinalPoints.lua" -Raw
$cp = $cp.Replace("`r`n", "`n")

# Remove gather circle bind section from the ticker function
$cp = ReplaceExact $cp @'
	if FarmHudDB.cardinalpoints_gathercircle_bind then
		local lp,radius,_ = FarmHudRangeCircles.CirclesDefault[1].linePool,nil,nil; -- gather circle
		_,_,radius = lp[#lp-1]:GetEndPoint()
		local distance = FarmHudDB.cardinalpoints_gathercircle_distance;
		if FarmHudDB.cardinalpoints_gathercircle_pos=="inside" then
			distance = -distance;
		end
		scaledRadius = radius * 0.725 + distance;
	else
		scaledRadius = FarmHud.TextFrame.ScaledHeight * FarmHudDB.cardinalpoints_radius;
	end
'@ @'
	scaledRadius = QuestHUDDB.cardinalpoints_radius and (QuestHUD.TextFrame.ScaledHeight * QuestHUDDB.cardinalpoints_radius) or (QuestHUD.TextFrame.ScaledHeight * 0.47)
'@

# Remove the gather circle option entries from AceConfig options
$cp = ReplaceExact $cp @'
			cardinalpoints_gathercircle_bind = {
				type = "toggle", order = 2, width = "full",
				name = L["CardinalPointsGatherCircleBind"], desc = L["CardinalPointsGatherCircleBindDesc"]
			},
'@ ""

$cp = ReplaceExact $cp @'
			cardinalpoints_gathercircle_pos = {
				type = "select", order = 4,
				name = L["CardinalPointsGatherCirclePos"], desc = L["CardinalPointsGatherCirclePosDesc"],
				values = {
					inside = L["CardinalPointsInside"],
					outside = L["CardinalPointsOutside"]
				},
				disabled = function() return not FarmHudDB.cardinalpoints_gathercircle_bind; end
			},
			cardinalpoints_gathercircle_distance = {
				type = "range", order = 5,
				name = L["CardinalPointsGatherCircleDistance"], desc = L["CardinalPointsGatherCircleDistanceDesc"],
				min = 10, max = 100, step=2,
				disabled = function() return not FarmHudDB.cardinalpoints_gathercircle_bind; end
			},
'@ ""

# Remove disabled = function() in radius option that referenced gather circle
$cp = ReplaceExact $cp @'
			cardinalpoints_radius = {
				type = "range", order = 3, width = "double",
				name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
				min = 0.1, max = 0.95, step=0.005, isPercent=true,
				disabled = function() return FarmHudDB.cardinalpoints_gathercircle_bind; end
			},
'@ @'
			cardinalpoints_radius = {
				type = "range", order = 3, width = "double",
				name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
				min = 0.1, max = 0.95, step=0.005, isPercent=true,
			},
'@

# Remove gather circle db defaults
$cp = ReplaceExact $cp @'
		cardinalpoints_gathercircle_bind = false,
		cardinalpoints_gathercircle_pos = "inside",
		cardinalpoints_gathercircle_distance = 10,
'@ ""

# Global renames
$cp = $cp.Replace("FarmHudDB", "QuestHUDDB")
$cp = $cp.Replace("FarmHudRangeCircles", "QuestHUDRangeCircles")
$cp = $cp.Replace("FarmHud", "QuestHUD")

[System.IO.File]::WriteAllText("$PWD\QuestHUD\modules\CardinalPoints.lua", $cp, [System.Text.UTF8Encoding]::new($false))
Write-Host "CardinalPoints.lua written"
if ($cp -match "FarmHud") { Write-Host "WARNING: FarmHud refs remain" } else { Write-Host "OK" }

# ============================================================
# .pkgmeta
# ============================================================
Write-Host "`nWriting .pkgmeta..."
$pkgmeta = @'
package-as: QuestHUD

externals:
    libs/LibStub:
        url: https://repos.curseforge.com/wow/libstub/trunk
        tag: latest

    libs/CallbackHandler-1.0:
        url: https://repos.curseforge.com/wow/callbackhandler/trunk/CallbackHandler-1.0
        tag: latest

    libs/AceGUI-3.0:
        url: https://repos.curseforge.com/wow/ace3/trunk/AceGUI-3.0
        tag: latest

    libs/AceConfig-3.0:
        url: https://repos.curseforge.com/wow/ace3/trunk/AceConfig-3.0
        tag: latest

    libs/LibDataBroker-1.1:
        url: https://repos.curseforge.com/wow/libdatabroker-1-1
        tag: latest

    libs/LibDBIcon-1.0:
        url: https://repos.curseforge.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0
        tag: latest

    libs/HereBeDragons:
        url: https://repos.curseforge.com/wow/herebedragons
        tag: latest

    libs/LibColors-1.0:
        url: https://github.com/HizurosWoWAddOns/LibColors-1.0.git
        tag: latest

enable-nolib-creation: no
enable-toc-creation: yes

ignore:
    - libs/LibStub/tests
    - libs/HereBeDragons/CallbackHandler-1.0
    - libs/HereBeDragons/LibStub
'@
[System.IO.File]::WriteAllText("$PWD\QuestHUD\.pkgmeta", $pkgmeta, [System.Text.UTF8Encoding]::new($false))
Write-Host ".pkgmeta written"

# ============================================================
# .github/workflows/packager.yml
# ============================================================
Write-Host "`nWriting packager.yml..."
$yml = Get-Content "FarmHud-master\.github\workflows\packager.yml" -Raw
$yml = $yml.Replace("`r`n", "`n")
# No changes needed - it's generic
[System.IO.File]::WriteAllText("$PWD\QuestHUD\.github\workflows\packager.yml", $yml, [System.Text.UTF8Encoding]::new($false))
Write-Host "packager.yml written"

Write-Host "`nAll files processed!"
