--#region IMPORTS

local function inxNoti(text)
    GUI.AddToast("inxlua", text, 5000, eToastPos.TOP_RIGHT)
end

local function download_natives_file()
    if FileMgr.DoesFileExist(FileMgr.GetMenuRootPath() .. "\\Lua\\natives.lua") then
        return
    end

    inxNoti("Downloading the natives, please wait.")

    local url = "https://raw.githubusercontent.com/inxanedev/inxlua/refs/heads/main/natives.lua"

    local curlObject = Curl.Easy()
    curlObject:Setopt(eCurlOption.CURLOPT_URL, url)
    curlObject:AddHeader("User-Agent: Lua-Curl-Client")
    curlObject:Perform()

    while not curlObject:GetFinished() do end

    local responseCode, responseString = curlObject:GetResponse()

    FileMgr.WriteFileContent(FileMgr.GetMenuRootPath() .. "\\Lua\\natives.lua", responseString, false)
end

download_natives_file()

dofile(FileMgr.GetMenuRootPath() .. "\\Lua\\natives.lua")

--#endregion

--#region UTILS
local function plainTextReplace(input, pattern, replacement)
    -- Escape all magic characters in the pattern
    local escapedPattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
    
    -- Escape percent signs in the replacement string
    local escapedReplacement = replacement:gsub("%%", "%%%%")
    
    -- Perform the replacement
    return input:gsub(escapedPattern, escapedReplacement)
end

local function tprint(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
      local formatting = string.rep("  ", indent) .. k .. ": "
      if type(v) == "table" then
        print(formatting)
        tprint(v, indent+1)
      elseif type(v) == 'boolean' then
        print(formatting .. tostring(v))      
      else
        print(formatting .. v)
      end
    end
  end

local previous_global_values = {}
local function set_global_int(id, value)
    previous_global_values[id] = ScriptGlobal.GetInt(id)
    ScriptGlobal.SetInt(id, value)
end
local function revert_global_int(id)
    ScriptGlobal.SetInt(id, previous_global_values[id])
    previous_global_values[id] = nil
end
local function set_global_bool(id, value)
    previous_global_values[id] = ScriptGlobal.GetBool(id)
    ScriptGlobal.SetBool(id, value)
end
local function revert_global_bool(id)
    ScriptGlobal.SetBool(id, previous_global_values[id])
    previous_global_values[id] = nil
end

local j = Utils.Joaat
--#endregion

--#region CHAMELEON WHEEL COLORS
local currentWheelColor = 0
FeatureMgr.AddFeature(j("Next Wheel Color"), "Next Wheel Color", eFeatureType.Button, "Cycles to the next wheel color", function ()
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
    local pearlColor = Memory.AllocInt()
    local wheelColor = Memory.AllocInt()
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, pearlColor, wheelColor)
    Memory.WriteInt(wheelColor, Memory.ReadInt(wheelColor) + 1)
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, Memory.ReadInt(pearlColor), Memory.ReadInt(wheelColor))
    currentWheelColor = Memory.ReadInt(wheelColor)
    Memory.Free(pearlColor)
    Memory.Free(wheelColor)
end)
FeatureMgr.AddFeature(j("Last Wheel Color"), "Last Wheel Color", eFeatureType.Button, "Cycles back to the last wheel color", function ()
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
    local pearlColor = Memory.AllocInt()
    local wheelColor = Memory.AllocInt()
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, pearlColor, wheelColor)
    Memory.WriteInt(wheelColor, Memory.ReadInt(wheelColor) - 1)
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, Memory.ReadInt(pearlColor), Memory.ReadInt(wheelColor))
    currentWheelColor = Memory.ReadInt(wheelColor)
    Memory.Free(pearlColor)
    Memory.Free(wheelColor)
end)

FeatureMgr.AddFeature(j("Set Wheel Color"), "Set Wheel Color", eFeatureType.Button, "Sets the selected wheel color", function ()
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
    local pearlColor = Memory.AllocInt()
    local wheelColor = Memory.AllocInt()
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, pearlColor, wheelColor)
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, Memory.ReadInt(pearlColor), FeatureMgr.GetFeature(j("inxWheelColor")):GetIntValue())
    currentWheelColor = FeatureMgr.GetFeature(j("inxWheelColor")):GetIntValue()
    Memory.Free(pearlColor)
    Memory.Free(wheelColor)
end)

FeatureMgr.AddFeature(j("inxWheelColor"), "Wheel Color", eFeatureType.InputInt, "Put number of your wheel color here"):SetValue(222):SetMinValue(161):SetMaxValue(222)

--#endregion

--#region SMALLER RETICLE
local width, height = ImGui.GetDisplaySize()
FeatureMgr.AddFeature(j("Smaller Reticle"), "Smaller Reticle", eFeatureType.Toggle, "Makes the crosshair smaller, similar to Story Mode.")
local size = FeatureMgr.AddFeature(j("Reticle Size"), "Reticle Size", eFeatureType.SliderInt, "Controls the size of the custom crosshair."):SetMinValue(1):SetMaxValue(10):SetValue(2)

EventMgr.RegisterHandler(eLuaEvent.ON_PRESENT, function()
	if FeatureMgr.IsFeatureEnabled(j("Smaller Reticle")) then
		ImGui.AddCircleFilled(width / 2, height / 2, size:GetIntValue(), 255, 255, 255, 255)
	end
end)

Script.RegisterLooped(function()
	if FeatureMgr.IsFeatureEnabled(j("Smaller Reticle")) then
		Natives.InvokeVoid(0x6806C51AD12B83B8, 14)
	end
end)
--#endregion

--#region TELEPORTS

local tp_feats = {}

local function add_tp(hash, name, x, y, z, heading)
    table.insert(tp_feats, hash)
    FeatureMgr.AddFeature(j(hash), name, eFeatureType.Button, "", function ()
        PLAYER.START_PLAYER_TELEPORT(PLAYER.PLAYER_ID(), x, y, z, heading, true, false, true)
    end)
end

add_tp("VINEWOODGARAGE", "Vinewood Garage", 182.97068786621094, -1158.740234375, 29.445926666259766, 207.99546813964844)

FeatureMgr.AddFeature(j("BetterTpToWaypoint"), "Better Teleport to Waypoint", eFeatureType.Button, "Teleports you to your waypoint", function ()
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
FeatureMgr.AddFeature(j("Spawn Random Saved Vehicle"), "Spawn Random Saved Vehicle", eFeatureType.Button, "Spawns a random saved .json vehicle from Cherax/Vehicles", function (f)
    local feature = FeatureMgr.GetFeature(514776905)
    local spawn_feature = FeatureMgr.GetFeature(521937511)

    feature:SetListIndex(math.random(#feature:GetList()) - 1)
    spawn_feature:TriggerCallback()
end)
--#endregion

--#region PRINT FEATURE INFO
FeatureMgr.AddFeature(j("Print hovered feature info"), "Print Hovered Feature Info", eFeatureType.Button, "", function (f)
    local feature = FeatureMgr.GetHoveredFeature()
    print(feature:GetName(), feature:GetHash())
end)
--#endregion

--#region FORGE MODEL
FeatureMgr.AddFeature(j("ForgeModelName"), "Spoofed name", eFeatureType.InputText, "Name of the model to spoof the vehicle"):SetStringValue("ruffian")
local previous_forge_hash = 0
FeatureMgr.AddFeature(j("ForgeModelSpoof"), "Spoof", eFeatureType.Button, "Spoof the vehicle with the specified model", function (f)
    local spoof_model = FeatureMgr.GetFeatureString(j("ForgeModelName"))
    local spoof_hash = j(spoof_model)
    local cveh = Players.GetCPed(PLAYER.GET_PLAYER_PED(PLAYER.PLAYER_PED_ID())).CurVehicle
    local info = CVehicleModelInfo.FromBaseModelInfo(cveh.ModelInfo)
---@diagnostic disable-next-line: need-check-nil
    previous_forge_hash = info.Model
    info.Model = spoof_hash
end)

FeatureMgr.AddFeature(j("ForgeModelUnspoof"), "Unspoof", eFeatureType.Button, "Revert the model spoof", function (f)
    local spoof_model = FeatureMgr.GetFeatureString(j("ForgeModelName"))
    local spoof_hash = j(spoof_model)
    local cveh = Players.GetCPed(PLAYER.GET_PLAYER_PED(PLAYER.PLAYER_PED_ID())).CurVehicle
    local info = CVehicleModelInfo.FromBaseModelInfo(cveh.ModelInfo)
    info.Model = previous_forge_hash
end)
--#endregion

--#region STATS
FeatureMgr.AddFeature(j("UnlockChameleonPaints"), "Unlock Chameleon Paints", eFeatureType.Button, "Unlocks all chameleon paints from GTA+", function (f)
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

FeatureMgr.AddFeature(j("OpenStatsWebsite"), "Copy Stats List URL", eFeatureType.Button, "Copies the link to a website which contains a list of stats.", function (f)
---@diagnostic disable-next-line: undefined-field
    Utils.SetClipBoardText("https://gist.githubusercontent.com/1337Nexo/945fe9724b9dd20d33e7afeabd2746dc/raw/46af3968b55677688a1bc98798adcd174e72e48d/stats.txt", "")
    inxNoti("Copied link! Open it in your browser.")
end)

FeatureMgr.AddFeature(j("StatType"), "Stat Type", eFeatureType.Combo, "Stat Type"):SetList({"int", "float", "bool", "string"})

FeatureMgr.AddFeature(j("StatValueInt"), "Int value:", eFeatureType.InputInt, "Int value"):SetIntValue(-1):SetMinValue(-2147483647):SetMaxValue(2147483647)
FeatureMgr.AddFeature(j("StatValueBool"), "", eFeatureType.Toggle, "Bool value"):SetBoolValue(false)
FeatureMgr.AddFeature(j("StatValueFloat"), "Float value:", eFeatureType.InputFloat, "Float value"):SetFloatValue(420.69):SetMinValue(-math.huge):SetMaxValue(math.huge)
FeatureMgr.AddFeature(j("StatValueString"), "", eFeatureType.InputText, "String value"):SetValue("Example string")

FeatureMgr.AddFeature(j("StatName"), "", eFeatureType.InputText, "name of the stat to edit"):SetValue("MPPLY_XMASLIVERIES0")

FeatureMgr.AddFeature(j("SetStatInt"), "Set Int Stat", eFeatureType.Button, "Sets the int stat", function (f)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(j("StatName"))), FeatureMgr.GetFeatureInt(j("StatValueInt")), true)
end)

FeatureMgr.AddFeature(j("SetStatBool"), "Set Bool Stat", eFeatureType.Button, "Sets the bool stat", function (f)
    STATS.STAT_SET_BOOL(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(j("StatName"))), FeatureMgr.IsFeatureEnabled(j("StatValueBool")), true)
end)

FeatureMgr.AddFeature(j("SetStatFloat"), "Set Float Stat", eFeatureType.Button, "Sets the float stat", function (f)
    STATS.STAT_SET_FLOAT(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(j("StatName"))), FeatureMgr.GetFeatureFloat(j("StatValueFloat")), true)
end)

FeatureMgr.AddFeature(j("SetStatString"), "Set String/Text Stat", eFeatureType.Button, "Sets the string stat", function (f)
    STATS.STAT_SET_STRING(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(j("StatName"))), FeatureMgr.GetFeatureString(j("StatValueString")), true)
end)

--#endregion

--#region VEHICLE CONFIG SAVING

--#region BREATHING NEON KIT
function RGBtoHSV(r, g, b)
    -- Normalize RGB values to the range [0, 1]
    r, g, b = r / 255, g / 255, b / 255

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min

    local h, s, v

    -- Calculate Hue
    if delta == 0 then
        h = 0
    elseif max == r then
        h = (60 * ((g - b) / delta) + 360) % 360
    elseif max == g then
        h = (60 * ((b - r) / delta) + 120) % 360
    elseif max == b then
        h = (60 * ((r - g) / delta) + 240) % 360
    end

    -- Calculate Saturation
    if max == 0 then
        s = 0
    else
        s = delta / max
    end

    -- Calculate Value
    v = max

    -- Convert HSV to 0-255 range
    h = math.floor((h / 360) * 255)
    s = math.floor(s * 255)
    v = math.floor(v * 255)

    return h, s, v
end

function HSVtoRGB(h, s, v)
    -- Normalize HSV values to the range [0, 1]
    h, s, v = h / 255, s / 255, v / 255

    local r, g, b

    if s == 0 then
        -- Achromatic (gray)
        r, g, b = v, v, v
    else
        -- Chromatic case
        local sector = math.floor(h * 6)
        local f = h * 6 - sector
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)

        if sector == 0 then
            r, g, b = v, t, p
        elseif sector == 1 then
            r, g, b = q, v, p
        elseif sector == 2 then
            r, g, b = p, v, t
        elseif sector == 3 then
            r, g, b = p, q, v
        elseif sector == 4 then
            r, g, b = t, p, v
        elseif sector == 5 then
            r, g, b = v, p, q
        end
    end

    -- Convert RGB to 0-255 range
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)


    return r, g, b
end
--#endregion

--#region ENABLE FESTIVE HORNS
FeatureMgr.AddFeature(j("EnableFestiveHorns"), "Enable Festive Horns", eFeatureType.Toggle, "Prevents the game from removing your festive horn modification", function (f)
    if (f:IsToggled()) then
        set_global_bool(262145 + 13135, true)
        set_global_int(262145 + 2325, 1)
    else
        revert_global_bool(262145 + 13135)
        revert_global_int(262145 + 2325)
    end
end)
--#endregion

local speed = FeatureMgr.AddFeature(j("BreathingNeonSlider"), "Speed", eFeatureType.SliderInt):SetMaxValue(20):SetMinValue(1):SetValue(3)

local colorfeat = FeatureMgr.GetFeatureByName("Neon Color")
local currentAlpha = 0
local down = false
FeatureMgr.AddFeature(j("BreathingNeon"), "Breathing Neon Kit", eFeatureType.Toggle, "Toggles the breathing neon kit effect.", function()
	local feat = FeatureMgr.GetFeature(j("BreathingNeon"))
	while feat:IsToggled() do
		if down then
			currentAlpha = currentAlpha - speed:GetIntValue()
		else
			currentAlpha = currentAlpha + speed:GetIntValue()
		end

		if currentAlpha >= 254 and not down then
			currentAlpha = 254
			down = true
		elseif currentAlpha <= 1 and down then
			currentAlpha = 1
			down = false
		end
		
		

		local r, g, b = colorfeat:GetColor()
		local h, s, v = RGBtoHSV(r, g, b)
		
		local nr, ng, nb = HSVtoRGB(h, s, currentAlpha)
---@diagnostic disable-next-line: missing-parameter
		colorfeat:SetColor(nr, ng, nb)
		colorfeat:TriggerCallback()

		
		Script.Yield()
	end
end, true)

--#endregion

local vehicle_config_dir = FileMgr.GetMenuRootPath() .. "\\VehicleConfigs"
FileMgr.CreateDir(vehicle_config_dir)

FeatureMgr.AddFeature(j("Saved Vehicle Configs"), "Saved Vehicle Configs", eFeatureType.Combo, "Select a saved vehicle config")

local function update_vehicle_configs()
    local files = FileMgr.FindFiles(vehicle_config_dir, ".txt", false) or {}
    local parsed_files = {}
    for _, file in ipairs(files) do
        table.insert(parsed_files, (plainTextReplace(plainTextReplace(file, vehicle_config_dir .. "\\", ""), ".txt", "")))
    end
    FeatureMgr.GetFeature(j("Saved Vehicle Configs")):SetList(parsed_files)
end

update_vehicle_configs()

FeatureMgr.AddFeature(j("Config Name"), "Config name", eFeatureType.InputText, "Name for the config you want to save")

FeatureMgr.AddFeature(j("Save Vehicle Config"), "Save Vehicle Config", eFeatureType.Button, "Saves the modification on the current vehicle, for applying them to other cars later.", function (f)
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
    if vehicle == 0 then
        inxNoti("You're not inside a vehicle!")
        return
    end

    local primary_color = Memory.AllocInt()
    local secondary_color = Memory.AllocInt()
    local pearlescent_color = Memory.AllocInt()
    local wheel_color = Memory.AllocInt()

    VEHICLE.GET_VEHICLE_COLOURS(vehicle, primary_color, secondary_color)
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, pearlescent_color, wheel_color)

    local config = string.format("%d\n%d\n%d\n%d\n%d\n%d\n%d\n%s", 
        VEHICLE.GET_VEHICLE_WHEEL_TYPE(vehicle),
        VEHICLE.GET_VEHICLE_MOD(vehicle, 23),
        VEHICLE.GET_VEHICLE_WINDOW_TINT(vehicle),
        Memory.ReadInt(primary_color),
        Memory.ReadInt(secondary_color),
        Memory.ReadInt(pearlescent_color),
        Memory.ReadInt(wheel_color),
        tostring(VEHICLE.GET_VEHICLE_NUMBER_PLATE_TEXT(vehicle)) 
    )
    Memory.Free(primary_color)
    Memory.Free(secondary_color)
    Memory.Free(pearlescent_color)
    Memory.Free(wheel_color)

    local filename = FeatureMgr.GetFeatureString(j("Config Name"))
    if filename == "" then
        inxNoti("You need to type a valid config name!")
        return
    end

    local path = vehicle_config_dir .. "\\" .. filename .. ".txt"
    FileMgr.WriteFileContent(path, config, false)
    inxNoti("Saved vehicle config as " .. filename .. ".txt!")
    update_vehicle_configs()
end)

FeatureMgr.AddFeature(j("Refresh Vehicle Configs"), "Refresh Files", eFeatureType.Button, "Refreshes the vehicle configs", function (f)
    update_vehicle_configs()
end)

FeatureMgr.AddFeature(j("VehicleConfigSpawnUpgraded"), "Apply Performance Upgrades", eFeatureType.Toggle, "If enabled, the vehicle will have performance upgrades applied as well."):Toggle(true)

FeatureMgr.AddFeature(j("Apply Vehicle Config"), "Load Vehicle Config", eFeatureType.Button, "Applies your selected vehicle config to the car you're inside of.", function (f)
    if #FeatureMgr.GetFeatureList(j("Saved Vehicle Configs")) == 0 then
        inxNoti("No saved vehicles found.")
        return
    end

    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
    if vehicle == 0 then
        inxNoti("You're not inside a vehicle!")
        return
    end

    local file = FeatureMgr.GetFeatureList(j("Saved Vehicle Configs"))[FeatureMgr.GetFeature(j("Saved Vehicle Configs")):GetListIndex() + 1]

    file = vehicle_config_dir .. "\\" .. file .. ".txt"

    local file_content = FileMgr.ReadFileContent(file)
    local values = {}
    for line in file_content:gmatch("[^\r\n]+") do
        table.insert(values, line)
    end

    tprint(values)

    VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
---@diagnostic disable-next-line: param-type-mismatch
    VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicle, tonumber(values[1]))
---@diagnostic disable-next-line: param-type-mismatch
    VEHICLE.SET_VEHICLE_MOD(vehicle, 23, tonumber(values[2]), false)
---@diagnostic disable-next-line: param-type-mismatch
    VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicle, tonumber(values[3]))
---@diagnostic disable-next-line: param-type-mismatch
    VEHICLE.SET_VEHICLE_COLOURS(vehicle, tonumber(values[4]), tonumber(values[5]))
---@diagnostic disable-next-line: param-type-mismatch
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, tonumber(values[6]), tonumber(values[7]))

    VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(veh, values[8])

    local function upgrade_vehicle_mod(vehicle, mod)
        VEHICLE.SET_VEHICLE_MOD(vehicle, mod, VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, mod) - 1, false)
    end

    if FeatureMgr.IsFeatureEnabled(j("VehicleConfigSpawnUpgraded")) then
        upgrade_vehicle_mod(11) -- engine
        upgrade_vehicle_mod(12) -- brakes
        upgrade_vehicle_mod(13) -- transmission
        upgrade_vehicle_mod(15) -- suspension
        upgrade_vehicle_mod(16) -- armor
    end

    inxNoti("Applied selected vehicle config!")
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
        ClickGUI.RenderFeature(j("Next Wheel Color"))
        ClickGUI.RenderFeature(j("Last Wheel Color"))
        ClickGUI.RenderFeature(j("inxWheelColor"))
        ClickGUI.RenderFeature(j("Set Wheel Color"))
        ImGui.Text("Current Wheel Color: " .. currentWheelColor)
        ClickGUI.EndCustomChildWindow()
        ImGui.NextColumn()

        ClickGUI.BeginCustomChildWindow("Random Vehicles")
        ClickGUI.RenderFeature(j("Spawn Random Saved Vehicle"))
        ClickGUI.EndCustomChildWindow()

        ClickGUI.BeginCustomChildWindow("Forge Model")
        ClickGUI.RenderFeature(j("ForgeModelName"))
        ClickGUI.RenderFeature(j("ForgeModelSpoof"))
        ClickGUI.RenderFeature(j("ForgeModelUnspoof"))
        ClickGUI.EndCustomChildWindow()

        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Save/Load Vehicle Configs")
        ClickGUI.RenderFeature(j("Saved Vehicle Configs"))
        ClickGUI.RenderFeature(j("Config Name"))
        ClickGUI.RenderFeature(j("Refresh Vehicle Configs"))
        ClickGUI.RenderFeature(j("Save Vehicle Config"))
        ClickGUI.RenderFeature(j("Apply Vehicle Config"))
        ClickGUI.RenderFeature(j("VehicleConfigSpawnUpgraded"))
        ClickGUI.EndCustomChildWindow()

        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Breathing Neon Kit")
        ClickGUI.RenderFeature(j("BreathingNeon"))
        ClickGUI.RenderFeature(j("BreathingNeonSlider"))
        ClickGUI.EndCustomChildWindow()

        ClickGUI.BeginCustomChildWindow("Toggles")
        ClickGUI.RenderFeature(j("EnableFestiveHorns"))
        ClickGUI.EndCustomChildWindow()

        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("UI") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Smaller Reticle (crosshair)")
        ClickGUI.RenderFeature(j("Smaller Reticle"))
        ClickGUI.RenderFeature(j("Reticle Size"))
        ClickGUI.EndCustomChildWindow()
        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Teleports") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Better Teleport")
        ImGui.TextWrapped("Cherax's Teleport to Waypoint is broken, it sometimes puts you high up into the sky.")
        ImGui.TextWrapped("The feature below first puts the camera at the waypoint coords, to load collision data.")
        ClickGUI.RenderFeature(j("BetterTpToWaypoint"))
        ClickGUI.EndCustomChildWindow()
        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Preset teleports")
        for _, feat in ipairs(tp_feats) do
            ClickGUI.RenderFeature(j(feat))
        end
        ClickGUI.EndCustomChildWindow()
        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Stats") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Stat Editor")
        ClickGUI.RenderFeature(j("OpenStatsWebsite"))
        ImGui.Text("Stat name:")
        ClickGUI.RenderFeature(j("StatName"))
        local type = FeatureMgr.GetFeatureListIndex(j("StatType"))
        ClickGUI.RenderFeature(j("StatType"))
        if type == 0 then
            ClickGUI.RenderFeature(j("StatValueInt"))
            ClickGUI.RenderFeature(j("SetStatInt"))
        elseif type == 1 then
            ClickGUI.RenderFeature(j("StatValueFloat"))
            ClickGUI.RenderFeature(j("SetStatFloat"))
        elseif type == 2 then
            ImGui.Text("Bool value:")
            ImGui.SameLine()
            ClickGUI.RenderFeature(j("StatValueBool"))
            ClickGUI.RenderFeature(j("SetStatBool"))
        elseif type == 3 then
            ImGui.Text("String value:")
            ImGui.SameLine()
            ClickGUI.RenderFeature(j("StatValueString"))
            ClickGUI.RenderFeature(j("SetStatString"))
        end
        -- ClickGUI.RenderFeature(j("StatValueInt"))
        -- ClickGUI.RenderFeature(j("StatValueFloat"))
        -- ImGui.Text("Bool value (checked is true):")
        -- ImGui.SameLine()
        -- ClickGUI.RenderFeature(j("StatValueBool"))
        -- ImGui.Text("String/text value:")
        -- ClickGUI.RenderFeature(j("StatValueString"))

        -- ClickGUI.RenderFeature(j("SetStatInt"))
        -- ImGui.SameLine()
        -- ClickGUI.RenderFeature(j("SetStatFloat"))
        -- ImGui.SameLine()
        -- ClickGUI.RenderFeature(j("SetStatBool"))
        -- ImGui.SameLine()
        -- ClickGUI.RenderFeature(j("SetStatString"))
        ClickGUI.EndCustomChildWindow()
        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Unlocks")
        ClickGUI.RenderFeature(j("UnlockChameleonPaints"))
        ClickGUI.EndCustomChildWindow()

        ImGui.Columns()
        
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Debug") then
        ClickGUI.RenderFeature(j("Print hovered feature info"))
        ImGui.EndTabItem()
    end

    ImGui.EndTabBar()
end)
