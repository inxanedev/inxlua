--#region IMPORTS
dofile(FileMgr.GetMenuRootPath() .. "\\Lua\\natives.lua")
--#endregion

--#region CHAMELEON WHEEL COLORS
local currentWheelColor = 0
FeatureMgr.AddFeature(Utils.Joaat("Next Wheel Color"), "Next Wheel Color", eFeatureType.Button, "Cycles to the next wheel color", function ()
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), 0)
    local pearlColor = Memory.AllocInt()
    local wheelColor = Memory.AllocInt()
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, pearlColor, wheelColor)
    Memory.WriteInt(wheelColor, Memory.ReadInt(wheelColor) + 1)
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, Memory.ReadInt(pearlColor), Memory.ReadInt(wheelColor))
    currentWheelColor = Memory.ReadInt(wheelColor)
    Memory.Free(pearlColor)
    Memory.Free(wheelColor)
end)
FeatureMgr.AddFeature(Utils.Joaat("Last Wheel Color"), "Last Wheel Color", eFeatureType.Button, "Cycles back to the last wheel color", function ()
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), 0)
    local pearlColor = Memory.AllocInt()
    local wheelColor = Memory.AllocInt()
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, pearlColor, wheelColor)
    Memory.WriteInt(wheelColor, Memory.ReadInt(wheelColor) - 1)
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, Memory.ReadInt(pearlColor), Memory.ReadInt(wheelColor))
    currentWheelColor = Memory.ReadInt(wheelColor)
    Memory.Free(pearlColor)
    Memory.Free(wheelColor)
end)

FeatureMgr.AddFeature(Utils.Joaat("Set Wheel Color"), "Set Wheel Color", eFeatureType.Button, "Sets the selected wheel color", function ()
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), 0)
    local pearlColor = Memory.AllocInt()
    local wheelColor = Memory.AllocInt()
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, pearlColor, wheelColor)
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, Memory.ReadInt(pearlColor), FeatureMgr.GetFeature(Utils.Joaat("inxWheelColor")):GetIntValue())
    currentWheelColor = FeatureMgr.GetFeature(Utils.Joaat("inxWheelColor")):GetIntValue()
    Memory.Free(pearlColor)
    Memory.Free(wheelColor)
end)

FeatureMgr.AddFeature(Utils.Joaat("inxWheelColor"), "Wheel Color", eFeatureType.InputInt, "Put number of your wheel color here"):SetValue(222):SetMinValue(161):SetMaxValue(222)

--#endregion

--#region SMALLER RETICLE
local width, height = ImGui.GetDisplaySize()
FeatureMgr.AddFeature(Utils.Joaat("Smaller Reticle"), "Smaller Reticle", eFeatureType.Toggle, "Makes the crosshair smaller, similar to Story Mode.")
local size = FeatureMgr.AddFeature(Utils.Joaat("Reticle Size"), "Reticle Size", eFeatureType.SliderInt, "Controls the size of the custom crosshair."):SetMinValue(1):SetMaxValue(10):SetValue(2)

EventMgr.RegisterHandler(eLuaEvent.ON_PRESENT, function()
	if FeatureMgr.IsFeatureEnabled(Utils.Joaat("Smaller Reticle")) then
		ImGui.AddCircleFilled(width / 2, height / 2, size:GetIntValue(), 255, 255, 255, 255)
	end
end)

Script.RegisterLooped(function()
	if FeatureMgr.IsFeatureEnabled(Utils.Joaat("Smaller Reticle")) then
		Natives.InvokeVoid(0x6806C51AD12B83B8, 14)
	end
end)
--#endregion

--#region TELEPORTS

local tp_feats = {}

local function add_tp(hash, name, x, y, z, heading)
    table.insert(tp_feats, hash)
    FeatureMgr.AddFeature(Utils.Joaat(hash), name, eFeatureType.Button, "", function ()
        PLAYER.START_PLAYER_TELEPORT(PLAYER.PLAYER_ID(), x, y, z, heading, true, false, true)
    end)
end

add_tp("VINEWOODGARAGE", "Vinewood Garage", 182.97068786621094, -1158.740234375, 29.445926666259766, 207.99546813964844)

FeatureMgr.AddFeature(Utils.Joaat("BetterTpToWaypoint"), "Better Teleport to Waypoint", eFeatureType.Button, "Teleports you to your waypoint", function ()
    local blip = HUD.GET_FIRST_BLIP_INFO_ID(8)
    local coords = HUD.GET_BLIP_COORDS(blip)
    STREAMING.SET_FOCUS_POS_AND_VEL(coords.x, coords.y, coords.z, 0, 0, 0)
    Script.Yield(1000)
---@diagnostic disable-next-line: undefined-field
    local _, z = GTA.GetGroundZ(coords.x, coords.y)
    if PED.IS_PED_IN_ANY_VEHICLE(PLAYER.PLAYER_PED_ID(), true) then
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true), coords.x, coords.y, z, true, true, true)
    else
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(PLAYER.PLAYER_PED_ID(), coords.x, coords.y + 10, z, true, true, true)
    end
    STREAMING.CLEAR_FOCUS()
end)
--#endregion

--#region RANDOM SAVED VEHICLE
FeatureMgr.AddFeature(Utils.Joaat("Spawn Random Saved Vehicle"), "Spawn Random Saved Vehicle", eFeatureType.Button, "Spawns a random saved .json vehicle from Cherax/Vehicles", function (f)
    local feature = FeatureMgr.GetFeature(514776905)
    local spawn_feature = FeatureMgr.GetFeature(521937511)

    feature:SetListIndex(math.random(#feature:GetList()) - 1)
    spawn_feature:TriggerCallback()
end)
--#endregion

--#region PRINT FEATURE INFO
FeatureMgr.AddFeature(Utils.Joaat("Print hovered feature info"), "Print Hovered Feature Info", eFeatureType.Button, "", function (f)
    local feature = FeatureMgr.GetHoveredFeature()
    print(feature:GetName(), feature:GetHash())
end)
--#endregion

--#region FORGE MODEL
FeatureMgr.AddFeature(Utils.Joaat("ForgeModelName"), "Spoofed name", eFeatureType.InputText, "Name of the model to spoof the vehicle"):SetStringValue("ruffian")
local previous_forge_hash = 0
FeatureMgr.AddFeature(Utils.Joaat("ForgeModelSpoof"), "Spoof", eFeatureType.Button, "Spoof the vehicle with the specified model", function (f)
    local spoof_model = FeatureMgr.GetFeatureString(Utils.Joaat("ForgeModelName"))
    local spoof_hash = Utils.Joaat(spoof_model)
    local cveh = Players.GetCPed(PLAYER.GET_PLAYER_PED(PLAYER.PLAYER_PED_ID())).CurVehicle
    local info = CVehicleModelInfo.FromBaseModelInfo(cveh.ModelInfo)
    previous_forge_hash = info.Model
    info.Model = spoof_hash
end)

FeatureMgr.AddFeature(Utils.Joaat("ForgeModelUnspoof"), "Unspoof", eFeatureType.Button, "Revert the model spoof", function (f)
    local spoof_model = FeatureMgr.GetFeatureString(Utils.Joaat("ForgeModelName"))
    local spoof_hash = Utils.Joaat(spoof_model)
    local cveh = Players.GetCPed(PLAYER.GET_PLAYER_PED(PLAYER.PLAYER_PED_ID())).CurVehicle
    local info = CVehicleModelInfo.FromBaseModelInfo(cveh.ModelInfo)
    info.Model = previous_forge_hash
end)
--#endregion

--#region STATS
FeatureMgr.AddFeature(Utils.Joaat("UnlockChameleonPaints"), "Unlock Chameleon Paints", eFeatureType.Button, "Unlocks all chameleon paints from GTA+", function (f)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES0"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES1"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES2"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES3"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES4"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES5"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES6"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES7"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES8"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES9"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES10"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES11"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES12"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES13"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES14"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES15"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMASLIVERIES16"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMAS22CPAINT0"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_XMAS22CPAINT1"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_SUM23WHEELCPAINT0"), -1, true)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY("MPPLY_SUM23WHEELCPAINT1"), -1, true)
    -- ScriptGlobal.SetInt(262145 + 32539, -1)
    -- ScriptGlobal.SetInt(262145 + 32540, -1)
    -- ScriptGlobal.SetInt(262145 + 32593, -1)
    -- ScriptGlobal.SetInt(262145 + 32594, -1)
    -- ScriptGlobal.SetInt(104632 + 50, 0)
    -- ScriptGlobal.SetInt(104632 + 51, 0)
end)

FeatureMgr.AddFeature(Utils.Joaat("StatName"), "", eFeatureType.InputText, "name of the stat to edit"):SetValue("MPPLY_XMASLIVERIES0")

FeatureMgr.AddFeature(Utils.Joaat("StatValueInt"), "Int value:", eFeatureType.InputInt, "Int value"):SetIntValue(-1):SetMinValue(-2147483647):SetMaxValue(2147483647)
FeatureMgr.AddFeature(Utils.Joaat("StatValueBool"), "", eFeatureType.Toggle, "Bool value"):SetBoolValue(false)
FeatureMgr.AddFeature(Utils.Joaat("StatValueFloat"), "Float value:", eFeatureType.InputFloat, "Float value"):SetFloatValue(420.69):SetMinValue(-math.huge):SetMaxValue(math.huge)
FeatureMgr.AddFeature(Utils.Joaat("StatValueString"), "", eFeatureType.InputText, "String value"):SetValue("Example string")

FeatureMgr.AddFeature(Utils.Joaat("SetStatInt"), "Set Int Stat", eFeatureType.Button, "Sets the int stat", function (f)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(Utils.Joaat("StatName"))), FeatureMgr.GetFeatureInt(Utils.Joaat("StatValueInt")), true)
end)

FeatureMgr.AddFeature(Utils.Joaat("SetStatBool"), "Set Bool Stat", eFeatureType.Button, "Sets the bool stat", function (f)
    STATS.STAT_SET_BOOL(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(Utils.Joaat("StatName"))), FeatureMgr.IsFeatureEnabled(Utils.Joaat("StatValueBool")), true)
end)

FeatureMgr.AddFeature(Utils.Joaat("SetStatFloat"), "Set Float Stat", eFeatureType.Button, "Sets the float stat", function (f)
    STATS.STAT_SET_FLOAT(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(Utils.Joaat("StatName"))), FeatureMgr.GetFeatureFloat(Utils.Joaat("StatValueFloat")), true)
end)

FeatureMgr.AddFeature(Utils.Joaat("SetStatString"), "Set String/Text Stat", eFeatureType.Button, "Sets the string stat", function (f)
    STATS.STAT_SET_STRING(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(Utils.Joaat("StatName"))), FeatureMgr.GetFeatureString(Utils.Joaat("StatValueString")), true)
end)

--#endregion

ClickGUI.AddTab("inxlua", function ()
    ImGui.Text("Welcome to inxlua!")
    ImGui.Text("Report bugs to inxanedev on discord")
    ---@diagnostic disable-next-line: missing-parameter
    ImGui.BeginTabBar("#inxlua")

    if ImGui.BeginTabItem("Vehicles") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Chameleon Wheel Paints")
        ClickGUI.RenderFeature(Utils.Joaat("Next Wheel Color"))
        ClickGUI.RenderFeature(Utils.Joaat("Last Wheel Color"))
        ClickGUI.RenderFeature(Utils.Joaat("inxWheelColor"))
        ClickGUI.RenderFeature(Utils.Joaat("Set Wheel Color"))
        ImGui.Text("Current Wheel Color: " .. currentWheelColor)
        ClickGUI.EndCustomChildWindow()
        ImGui.NextColumn()

        ClickGUI.BeginCustomChildWindow("Random Vehicles")
        ClickGUI.RenderFeature(Utils.Joaat("Spawn Random Saved Vehicle"))
        ClickGUI.EndCustomChildWindow()

        ClickGUI.BeginCustomChildWindow("Forge Model")
        ClickGUI.RenderFeature(Utils.Joaat("ForgeModelName"))
        ClickGUI.RenderFeature(Utils.Joaat("ForgeModelSpoof"))
        ClickGUI.RenderFeature(Utils.Joaat("ForgeModelUnspoof"))
        ClickGUI.EndCustomChildWindow()

        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("UI") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Smaller Reticle (crosshair)")
        ClickGUI.RenderFeature(Utils.Joaat("Smaller Reticle"))
        ClickGUI.RenderFeature(Utils.Joaat("Reticle Size"))
        ClickGUI.EndCustomChildWindow()
        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Teleports") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Better Teleport")
        ImGui.TextWrapped("Cherax's Teleport to Waypoint is broken, it sometimes puts you high up into the sky.")
        ImGui.TextWrapped("The feature below first puts the camera at the waypoint coords, to load collision data.")
        ClickGUI.RenderFeature(Utils.Joaat("BetterTpToWaypoint"))
        ClickGUI.EndCustomChildWindow()
        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Preset teleports")
        for _, feat in ipairs(tp_feats) do
            ClickGUI.RenderFeature(Utils.Joaat(feat))
        end
        ClickGUI.EndCustomChildWindow()
        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Stats") then
        ClickGUI.BeginCustomChildWindow("Stat Editor")
        ImGui.Text("Stat name:")
        ClickGUI.RenderFeature(Utils.Joaat("StatName"))
        ClickGUI.RenderFeature(Utils.Joaat("StatValueInt"))
        ClickGUI.RenderFeature(Utils.Joaat("StatValueFloat"))
        ImGui.Text("Bool value (checked is true):")
        ImGui.SameLine()
        ClickGUI.RenderFeature(Utils.Joaat("StatValueBool"))
        ImGui.Text("String/text value:")
        ClickGUI.RenderFeature(Utils.Joaat("StatValueString"))

        ClickGUI.RenderFeature(Utils.Joaat("SetStatInt"))
        ImGui.SameLine()
        ClickGUI.RenderFeature(Utils.Joaat("SetStatFloat"))
        ImGui.SameLine()
        ClickGUI.RenderFeature(Utils.Joaat("SetStatBool"))
        ImGui.SameLine()
        ClickGUI.RenderFeature(Utils.Joaat("SetStatString"))

        ClickGUI.EndCustomChildWindow()

        ImGui.Columns(2, "", false)

        ClickGUI.BeginCustomChildWindow("Unlocks")
        ClickGUI.RenderFeature(Utils.Joaat("UnlockChameleonPaints"))
        ClickGUI.EndCustomChildWindow()

        ImGui.Columns()
        
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Debug") then
        ClickGUI.RenderFeature(Utils.Joaat("Print hovered feature info"))
        ImGui.EndTabItem()
    end

    ImGui.EndTabBar()
end)