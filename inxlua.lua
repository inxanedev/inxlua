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

ClickGUI.AddTab("inxlua", function ()
    ImGui.Text("Welcome to inxlua!")
    ImGui.Text("Report bugs to inxanedev on discord")
end)

ClickGUI.AddTab("Vehicles", function()
    ClickGUI.BeginCustomChildWindow("Chameleon Wheel Paints")
    ClickGUI.RenderFeature(Utils.Joaat("Next Wheel Color"))
    ClickGUI.RenderFeature(Utils.Joaat("Last Wheel Color"))
    ClickGUI.RenderFeature(Utils.Joaat("inxWheelColor"))
    ClickGUI.RenderFeature(Utils.Joaat("Set Wheel Color"))
    ImGui.Text("Current Wheel Color: " .. currentWheelColor)
    ClickGUI.EndCustomChildWindow()

    ClickGUI.BeginCustomChildWindow("Random Vehicles")
    ClickGUI.RenderFeature(Utils.Joaat("Spawn Random Saved Vehicle"))
    ClickGUI.EndCustomChildWindow()
end)

ClickGUI.AddTab("UI", function ()
    ClickGUI.BeginCustomChildWindow("Smaller Reticle (crosshair)")
    ClickGUI.RenderFeature(Utils.Joaat("Smaller Reticle"))
    ClickGUI.RenderFeature(Utils.Joaat("Reticle Size"))
    ClickGUI.EndCustomChildWindow()
end)

ClickGUI.AddTab("Teleports", function ()
    for _, feat in ipairs(tp_feats) do
        ClickGUI.RenderFeature(Utils.Joaat(feat))
    end
end)

ClickGUI.AddTab("Debug", function ()
    ClickGUI.RenderFeature(Utils.Joaat("Print hovered feature info"))
end)