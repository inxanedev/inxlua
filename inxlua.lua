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

local function load_json_lib()
    --
    -- json.lua
    --
    -- Copyright (c) 2020 rxi
    --
    -- Permission is hereby granted, free of charge, to any person obtaining a copy of
    -- this software and associated documentation files (the "Software"), to deal in
    -- the Software without restriction, including without limitation the rights to
    -- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
    -- of the Software, and to permit persons to whom the Software is furnished to do
    -- so, subject to the following conditions:
    --
    -- The above copyright notice and this permission notice shall be included in all
    -- copies or substantial portions of the Software.
    --
    -- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    -- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    -- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    -- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    -- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    -- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    -- SOFTWARE.
    --

    local json = { _version = "0.1.2" }

    -------------------------------------------------------------------------------
    -- Encode
    -------------------------------------------------------------------------------

    local encode

    local escape_char_map = {
        ["\\"] = "\\",
        ["\""] = "\"",
        ["\b"] = "b",
        ["\f"] = "f",
        ["\n"] = "n",
        ["\r"] = "r",
        ["\t"] = "t",
    }

    local escape_char_map_inv = { ["/"] = "/" }
    for k, v in pairs(escape_char_map) do
        escape_char_map_inv[v] = k
    end


    local function escape_char(c)
        return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
    end


    local function encode_nil(val)
        return "null"
    end


    local function encode_table(val, stack)
        local res = {}
        stack = stack or {}

        -- Circular reference?
        if stack[val] then error("circular reference") end

        stack[val] = true

        if rawget(val, 1) ~= nil or next(val) == nil then
            -- Treat as array -- check keys are valid and it is not sparse
            local n = 0
            for k in pairs(val) do
                if type(k) ~= "number" then
                    error("invalid table: mixed or invalid key types")
                end
                n = n + 1
            end
            if n ~= #val then
                error("invalid table: sparse array")
            end
            -- Encode
            for i, v in ipairs(val) do
                table.insert(res, encode(v, stack))
            end
            stack[val] = nil
            return "[" .. table.concat(res, ",") .. "]"
        else
            -- Treat as an object
            for k, v in pairs(val) do
                if type(k) ~= "string" then
                    error("invalid table: mixed or invalid key types")
                end
                table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
            end
            stack[val] = nil
            return "{" .. table.concat(res, ",") .. "}"
        end
    end


    local function encode_string(val)
        return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
    end


    local function encode_number(val)
        -- Check for NaN, -inf and inf
        if val ~= val or val <= -math.huge or val >= math.huge then
            error("unexpected number value '" .. tostring(val) .. "'")
        end
        return string.format("%.14g", val)
    end


    local type_func_map = {
        ["nil"] = encode_nil,
        ["table"] = encode_table,
        ["string"] = encode_string,
        ["number"] = encode_number,
        ["boolean"] = tostring,
    }


    encode = function(val, stack)
        local t = type(val)
        local f = type_func_map[t]
        if f then
            return f(val, stack)
        end
        error("unexpected type '" .. t .. "'")
    end


    function json.encode(val)
        return (encode(val))
    end

    -------------------------------------------------------------------------------
    -- Decode
    -------------------------------------------------------------------------------

    local parse

    local function create_set(...)
        local res = {}
        for i = 1, select("#", ...) do
            res[select(i, ...)] = true
        end
        return res
    end

    local space_chars  = create_set(" ", "\t", "\r", "\n")
    local delim_chars  = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
    local escape_chars = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
    local literals     = create_set("true", "false", "null")

    local literal_map  = {
        ["true"] = true,
        ["false"] = false,
        ["null"] = nil,
    }


    local function next_char(str, idx, set, negate)
        for i = idx, #str do
            if set[str:sub(i, i)] ~= negate then
                return i
            end
        end
        return #str + 1
    end


    local function decode_error(str, idx, msg)
        local line_count = 1
        local col_count = 1
        for i = 1, idx - 1 do
            col_count = col_count + 1
            if str:sub(i, i) == "\n" then
                line_count = line_count + 1
                col_count = 1
            end
        end
        error(string.format("%s at line %d col %d", msg, line_count, col_count))
    end


    local function codepoint_to_utf8(n)
        -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
        local f = math.floor
        if n <= 0x7f then
            return string.char(n)
        elseif n <= 0x7ff then
            return string.char(f(n / 64) + 192, n % 64 + 128)
        elseif n <= 0xffff then
            return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
        elseif n <= 0x10ffff then
            return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                f(n % 4096 / 64) + 128, n % 64 + 128)
        end
        error(string.format("invalid unicode codepoint '%x'", n))
    end


    local function parse_unicode_escape(s)
        local n1 = tonumber(s:sub(1, 4), 16)
        local n2 = tonumber(s:sub(7, 10), 16)
        -- Surrogate pair?
        if n2 then
            return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
        else
            return codepoint_to_utf8(n1)
        end
    end


    local function parse_string(str, i)
        local res = ""
        local j = i + 1
        local k = j

        while j <= #str do
            local x = str:byte(j)

            if x < 32 then
                decode_error(str, j, "control character in string")
            elseif x == 92 then -- `\`: Escape
                res = res .. str:sub(k, j - 1)
                j = j + 1
                local c = str:sub(j, j)
                if c == "u" then
                    local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                        or str:match("^%x%x%x%x", j + 1)
                        or decode_error(str, j - 1, "invalid unicode escape in string")
                    res = res .. parse_unicode_escape(hex)
                    j = j + #hex
                else
                    if not escape_chars[c] then
                        decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
                    end
                    res = res .. escape_char_map_inv[c]
                end
                k = j + 1
            elseif x == 34 then -- `"`: End of string
                res = res .. str:sub(k, j - 1)
                return res, j + 1
            end

            j = j + 1
        end

        decode_error(str, i, "expected closing quote for string")
    end


    local function parse_number(str, i)
        local x = next_char(str, i, delim_chars)
        local s = str:sub(i, x - 1)
        local n = tonumber(s)
        if not n then
            decode_error(str, i, "invalid number '" .. s .. "'")
        end
        return n, x
    end


    local function parse_literal(str, i)
        local x = next_char(str, i, delim_chars)
        local word = str:sub(i, x - 1)
        if not literals[word] then
            decode_error(str, i, "invalid literal '" .. word .. "'")
        end
        return literal_map[word], x
    end


    local function parse_array(str, i)
        local res = {}
        local n = 1
        i = i + 1
        while 1 do
            local x
            i = next_char(str, i, space_chars, true)
            -- Empty / end of array?
            if str:sub(i, i) == "]" then
                i = i + 1
                break
            end
            -- Read token
            x, i = parse(str, i)
            res[n] = x
            n = n + 1
            -- Next token
            i = next_char(str, i, space_chars, true)
            local chr = str:sub(i, i)
            i = i + 1
            if chr == "]" then break end
            if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
        end
        return res, i
    end


    local function parse_object(str, i)
        local res = {}
        i = i + 1
        while 1 do
            local key, val
            i = next_char(str, i, space_chars, true)
            -- Empty / end of object?
            if str:sub(i, i) == "}" then
                i = i + 1
                break
            end
            -- Read key
            if str:sub(i, i) ~= '"' then
                decode_error(str, i, "expected string for key")
            end
            key, i = parse(str, i)
            -- Read ':' delimiter
            i = next_char(str, i, space_chars, true)
            if str:sub(i, i) ~= ":" then
                decode_error(str, i, "expected ':' after key")
            end
            i = next_char(str, i + 1, space_chars, true)
            -- Read value
            val, i = parse(str, i)
            -- Set
            res[key] = val
            -- Next token
            i = next_char(str, i, space_chars, true)
            local chr = str:sub(i, i)
            i = i + 1
            if chr == "}" then break end
            if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
        end
        return res, i
    end


    local char_func_map = {
        ['"'] = parse_string,
        ["0"] = parse_number,
        ["1"] = parse_number,
        ["2"] = parse_number,
        ["3"] = parse_number,
        ["4"] = parse_number,
        ["5"] = parse_number,
        ["6"] = parse_number,
        ["7"] = parse_number,
        ["8"] = parse_number,
        ["9"] = parse_number,
        ["-"] = parse_number,
        ["t"] = parse_literal,
        ["f"] = parse_literal,
        ["n"] = parse_literal,
        ["["] = parse_array,
        ["{"] = parse_object,
    }


    parse = function(str, idx)
        local chr = str:sub(idx, idx)
        local f = char_func_map[chr]
        if f then
            return f(str, idx)
        end
        decode_error(str, idx, "unexpected character '" .. chr .. "'")
    end


    function json.decode(str)
        if type(str) ~= "string" then
            error("expected argument of type string, got " .. type(str))
        end
        local res, idx = parse(str, next_char(str, 1, space_chars, true))
        idx = next_char(str, idx, space_chars, true)
        if idx <= #str then
            decode_error(str, idx, "trailing garbage")
        end
        return res
    end

    return json
end

local json = load_json_lib()

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

local function log(str)
    Logger.Log(eLogColor.GREEN, "inxlua", str)
end

local j = Utils.Joaat
local RenderFeat = ClickGUI.RenderFeature
local AddFeat = FeatureMgr.AddFeature
--#endregion

--#region CHAMELEON WHEEL COLORS
local currentWheelColor = 0
AddFeat(j("Next Wheel Color"), "Next Wheel Color", eFeatureType.Button, "Cycles to the next wheel color", function ()
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
AddFeat(j("Last Wheel Color"), "Last Wheel Color", eFeatureType.Button, "Cycles back to the last wheel color", function ()
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

AddFeat(j("Set Wheel Color"), "Set Wheel Color", eFeatureType.Button, "Sets the selected wheel color", function ()
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
    local pearlColor = Memory.AllocInt()
    local wheelColor = Memory.AllocInt()
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, pearlColor, wheelColor)
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, Memory.ReadInt(pearlColor), FeatureMgr.GetFeature(j("inxWheelColor")):GetIntValue())
    currentWheelColor = FeatureMgr.GetFeature(j("inxWheelColor")):GetIntValue()
    Memory.Free(pearlColor)
    Memory.Free(wheelColor)
end)

AddFeat(j("inxWheelColor"), "Wheel Color", eFeatureType.InputInt, "Put number of your wheel color here"):SetValue(222):SetMinValue(161):SetMaxValue(222)

--#endregion

--#region SMALLER RETICLE
local width, height = ImGui.GetDisplaySize()
AddFeat(j("Smaller Reticle"), "Smaller Reticle", eFeatureType.Toggle, "Makes the crosshair smaller, similar to Story Mode.")
local size = AddFeat(j("Reticle Size"), "Reticle Size", eFeatureType.SliderInt, "Controls the size of the custom crosshair."):SetMinValue(1):SetMaxValue(10):SetValue(2)

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
    AddFeat(j(hash), name, eFeatureType.Button, "", function ()
        PLAYER.START_PLAYER_TELEPORT(PLAYER.PLAYER_ID(), x, y, z, heading, true, false, true)
    end)
end

add_tp("VINEWOODGARAGE", "Vinewood Garage", 182.97068786621094, -1158.740234375, 29.445926666259766, 207.99546813964844)

AddFeat(j("BetterTpToWaypoint"), "Better Teleport to Waypoint", eFeatureType.Button, "Teleports you to your waypoint", function ()
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
AddFeat(j("Spawn Random Saved Vehicle"), "Spawn Random Saved Vehicle", eFeatureType.Button, "Spawns a random saved .json vehicle from Cherax/Vehicles", function (f)
    local feature = FeatureMgr.GetFeature(514776905)
    local spawn_feature = FeatureMgr.GetFeature(521937511)

    feature:SetListIndex(math.random(#feature:GetList()) - 1)
    spawn_feature:TriggerCallback()
end)
--#endregion

--#region PRINT FEATURE INFO
AddFeat(j("Print hovered feature info"), "Print Hovered Feature Info", eFeatureType.Button, "", function (f)
    local feature = FeatureMgr.GetHoveredFeature()
    print(feature:GetName(), feature:GetHash())
end)
--#endregion

--#region FORGE MODEL
AddFeat(j("ForgeModelName"), "Spoofed name", eFeatureType.InputText, "Name of the model to spoof the vehicle"):SetStringValue("ruffian")
local previous_forge_hash = 0
AddFeat(j("ForgeModelSpoof"), "Spoof", eFeatureType.Button, "Spoof the vehicle with the specified model", function (f)
    local spoof_model = FeatureMgr.GetFeatureString(j("ForgeModelName"))
    local spoof_hash = j(spoof_model)
    local cveh = Players.GetCPed(PLAYER.GET_PLAYER_PED(PLAYER.PLAYER_PED_ID())).CurVehicle
    local info = CVehicleModelInfo.FromBaseModelInfo(cveh.ModelInfo)
---@diagnostic disable-next-line: need-check-nil
    previous_forge_hash = info.Model
    info.Model = spoof_hash
end)

AddFeat(j("ForgeModelUnspoof"), "Unspoof", eFeatureType.Button, "Revert the model spoof", function (f)
    local spoof_model = FeatureMgr.GetFeatureString(j("ForgeModelName"))
    local spoof_hash = j(spoof_model)
    local cveh = Players.GetCPed(PLAYER.GET_PLAYER_PED(PLAYER.PLAYER_PED_ID())).CurVehicle
    local info = CVehicleModelInfo.FromBaseModelInfo(cveh.ModelInfo)
    info.Model = previous_forge_hash
end)
--#endregion

--#region STATS
AddFeat(j("UnlockChameleonPaints"), "Unlock Chameleon Paints", eFeatureType.Button, "Unlocks all chameleon paints from GTA+", function (f)
    local stat_names = {
        "MPPLY_XMASLIVERIES0", "MPPLY_XMASLIVERIES1", "MPPLY_XMASLIVERIES2",
        "MPPLY_XMASLIVERIES3", "MPPLY_XMASLIVERIES4", "MPPLY_XMASLIVERIES5",
        "MPPLY_XMASLIVERIES6", "MPPLY_XMASLIVERIES7", "MPPLY_XMASLIVERIES8",
        "MPPLY_XMASLIVERIES9", "MPPLY_XMASLIVERIES10", "MPPLY_XMASLIVERIES11",
        "MPPLY_XMASLIVERIES12", "MPPLY_XMASLIVERIES13", "MPPLY_XMASLIVERIES14",
        "MPPLY_XMASLIVERIES15", "MPPLY_XMASLIVERIES16",
        "MPPLY_XMAS22CPAINT0", "MPPLY_XMAS22CPAINT1",
        "MPPLY_SUM23WHEELCPAINT0", "MPPLY_SUM23WHEELCPAINT1"
    }
    
    for _, statName in ipairs(stat_names) do
        STATS.STAT_SET_INT(MISC.GET_HASH_KEY(statName), -1, true)
    end
end)

AddFeat(j("OpenStatsWebsite"), "Copy Stats List URL", eFeatureType.Button, "Copies the link to a website which contains a list of stats.", function (f)
---@diagnostic disable-next-line: undefined-field
    Utils.SetClipBoardText("https://gist.githubusercontent.com/1337Nexo/945fe9724b9dd20d33e7afeabd2746dc/raw/46af3968b55677688a1bc98798adcd174e72e48d/stats.txt", "")
    inxNoti("Copied link! Open it in your browser.")
end)

AddFeat(j("StatType"), "Stat Type", eFeatureType.Combo, "Stat Type"):SetList({"int", "float", "bool", "string"})

AddFeat(j("StatValueInt"), "Int value:", eFeatureType.InputInt, "Int value"):SetIntValue(-1):SetMinValue(-2147483647):SetMaxValue(2147483647)
AddFeat(j("StatValueBool"), "", eFeatureType.Toggle, "Bool value"):SetBoolValue(false)
AddFeat(j("StatValueFloat"), "Float value:", eFeatureType.InputFloat, "Float value"):SetFloatValue(420.69):SetMinValue(-math.huge):SetMaxValue(math.huge)
AddFeat(j("StatValueString"), "", eFeatureType.InputText, "String value"):SetValue("Example string")

AddFeat(j("StatName"), "", eFeatureType.InputText, "name of the stat to edit"):SetValue("MPPLY_XMASLIVERIES0")

AddFeat(j("SetStatInt"), "Set Int Stat", eFeatureType.Button, "Sets the int stat", function (f)
    STATS.STAT_SET_INT(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(j("StatName"))), FeatureMgr.GetFeatureInt(j("StatValueInt")), true)
end)

AddFeat(j("SetStatBool"), "Set Bool Stat", eFeatureType.Button, "Sets the bool stat", function (f)
    STATS.STAT_SET_BOOL(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(j("StatName"))), FeatureMgr.IsFeatureEnabled(j("StatValueBool")), true)
end)

AddFeat(j("SetStatFloat"), "Set Float Stat", eFeatureType.Button, "Sets the float stat", function (f)
    STATS.STAT_SET_FLOAT(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(j("StatName"))), FeatureMgr.GetFeatureFloat(j("StatValueFloat")), true)
end)

AddFeat(j("SetStatString"), "Set String/Text Stat", eFeatureType.Button, "Sets the string stat", function (f)
    STATS.STAT_SET_STRING(MISC.GET_HASH_KEY(FeatureMgr.GetFeatureString(j("StatName"))), FeatureMgr.GetFeatureString(j("StatValueString")), true)
end)

--#endregion

--#region ENABLE FESTIVE HORNS

AddFeat(j("EnableFestiveHorns"), "Enable Festive Horns", eFeatureType.Toggle, "Prevents the game from removing your festive horn modification", function (f)
    if (f:IsToggled()) then
        set_global_bool(262145 + 13135, true)
        set_global_int(262145 + 2325, 1)
    else
        revert_global_bool(262145 + 13135)
        revert_global_int(262145 + 2325)
    end
end)

--#endregion

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

local speed = AddFeat(j("BreathingNeonSlider"), "Speed", eFeatureType.SliderInt):SetMaxValue(20):SetMinValue(1):SetValue(3)

local colorfeat = FeatureMgr.GetFeatureByName("Neon Color")
local currentAlpha = 0
local down = false
AddFeat(j("BreathingNeon"), "Breathing Neon Kit", eFeatureType.Toggle, "Toggles the breathing neon kit effect.", function()
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

--#region VEHICLE CONFIG SAVING

local vehicle_config_dir = FileMgr.GetMenuRootPath() .. "\\VehicleConfigs"
FileMgr.CreateDir(vehicle_config_dir)

AddFeat(j("Saved Vehicle Configs"), "Saved Vehicle Configs", eFeatureType.Combo, "Select a saved vehicle config")

local function update_vehicle_configs()
    local files = FileMgr.FindFiles(vehicle_config_dir, ".txt", false) or {}
    local parsed_files = {}
    for _, file in ipairs(files) do
        table.insert(parsed_files, (plainTextReplace(plainTextReplace(file, vehicle_config_dir .. "\\", ""), ".txt", "")))
    end
    FeatureMgr.GetFeature(j("Saved Vehicle Configs")):SetList(parsed_files)
end

update_vehicle_configs()

AddFeat(j("Config Name"), "Config name", eFeatureType.InputText, "Name for the config you want to save")

AddFeat(j("Save Vehicle Config"), "Save Vehicle Config", eFeatureType.Button, "Saves the modification on the current vehicle, for applying them to other cars later.", function (f)
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

AddFeat(j("Refresh Vehicle Configs"), "Refresh Files", eFeatureType.Button, "Refreshes the vehicle configs", function (f)
    update_vehicle_configs()
end)

AddFeat(j("VehicleConfigSpawnUpgraded"), "Apply Performance Upgrades", eFeatureType.Toggle, "If enabled, the vehicle will have performance upgrades applied as well."):Toggle(true)

AddFeat(j("Apply Vehicle Config"), "Load Vehicle Config", eFeatureType.Button, "Applies your selected vehicle config to the car you're inside of.", function (f)
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

--#region BETTER SAVED VEHICLES
local saved_vehicles_feat = FeatureMgr.GetFeature(514776905)

local preview_entity = nil

local function calculate_vehicle_coords()
    local distance = 8.0
    local camera_coords = CAM.GET_GAMEPLAY_CAM_COORD()
    local camera_direction = CAM.GET_GAMEPLAY_CAM_ROT(2)
    local pitch = camera_direction.x * (math.pi / 180.0)
    local yaw = camera_direction.z * (math.pi / 180.0)

    local vehicle_coords = V3.New(
        camera_coords.x + (distance * -math.sin(yaw) * math.cos(pitch)),
        camera_coords.y + (distance * math.cos(yaw) * math.cos(pitch)),
        camera_coords.z + (distance * math.sin(pitch))
    )

    return vehicle_coords
end

local function create_preview_entity(filename)
    log("CREATING ENTITY")
    local content = FileMgr.ReadFileContent(FileMgr.GetMenuRootPath() .. "\\Vehicles\\" .. filename .. ".json")
    local parsed = json.decode(content)

    local heading = ENTITY.GET_ENTITY_HEADING(PLAYER.PLAYER_PED_ID())
    local vehicle_coords = calculate_vehicle_coords()
    STREAMING.REQUEST_MODEL(parsed["model"])
    while not STREAMING.HAS_MODEL_LOADED(parsed["model"]) do Script.Yield() end
    -- local vehicle = VEHICLE.CREATE_VEHICLE(parsed["model"], vehicle_coords.x, vehicle_coords.y, vehicle_coords.z, heading, true, true, true)

    local vehicle = GTA.SpawnVehicle(parsed["model"], vehicle_coords.x, vehicle_coords.y, vehicle_coords.z, heading, false, false)

    -- STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(parsed["model"])
    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(vehicle, true, true)

    ENTITY.SET_ENTITY_VISIBLE(vehicle, false, false)
    VEHICLE.SET_VEHICLE_GRAVITY(vehicle, false)
    ENTITY.SET_ENTITY_COLLISION(vehicle, false, false)
    ENTITY.SET_ENTITY_VELOCITY(vehicle, 0, 0, 0)
    VEHICLE.SET_VEHICLE_UNDRIVEABLE(vehicle, true)
    ENTITY.SET_ENTITY_ALPHA(vehicle, 153, false)
    ENTITY.FREEZE_ENTITY_POSITION(vehicle, true)

    VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
    VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicle, parsed["wheelType"])
    for i=0,49,1 do
        --log("setting mod " .. i .. " to " .. parsed["mods"]["mod" .. i]["index"] - 1)
        VEHICLE.SET_VEHICLE_MOD(vehicle, i, parsed["mods"]["mod" .. i]["index"] - 1, false)
    end
    VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicle, parsed["windowTint"])
    --log(parsed["wheelColor"])
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, parsed["pearlescentColor"], parsed["wheelColor"])
    VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(vehicle, parsed["plateTextIndex"])
    VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(vehicle, parsed["plateText"])
    VEHICLE.SET_VEHICLE_COLOURS(vehicle, parsed["primaryColor"], parsed["secondaryColor"])

    ENTITY.SET_ENTITY_VISIBLE(vehicle, true, false)

    log("vehicle created")
    return vehicle
end

local function delete_preview_entity(entity)
    if ENTITY.DOES_ENTITY_EXIST(entity) then
        ENTITY.SET_ENTITY_AS_MISSION_ENTITY(entity, true, true)
        ENTITY.DELETE_ENTITY(entity)
    end
end

local function preview_entity_on_tick(entity)

end

AddFeat(j("ToggleVehiclePreview"), "Toggle Vehicle Preview", eFeatureType.Toggle, "Toggles a 3D preview of the hovered Saved Vehicle.", function (f)
    while (f:IsToggled()) do
        local hovered = FeatureMgr.GetHoveredFeature()
        if hovered ~= nil and hovered:GetHash() == saved_vehicles_feat:GetHash() then
            if preview_entity == nil then
                preview_entity = create_preview_entity(saved_vehicles_feat:GetList()[saved_vehicles_feat:GetListIndex() + 1])
            end
        else
            if preview_entity ~= nil then
                delete_preview_entity(preview_entity)
                preview_entity = nil
            end
        end
        Script.Yield()
    end
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
        RenderFeat(j("Next Wheel Color"))
        RenderFeat(j("Last Wheel Color"))
        RenderFeat(j("inxWheelColor"))
        RenderFeat(j("Set Wheel Color"))
        ImGui.Text("Current Wheel Color: " .. currentWheelColor)
        ClickGUI.EndCustomChildWindow()
        ImGui.NextColumn()

        ClickGUI.BeginCustomChildWindow("Random Vehicles")
        RenderFeat(j("Spawn Random Saved Vehicle"))
        ClickGUI.EndCustomChildWindow()

        ClickGUI.BeginCustomChildWindow("Forge Model")
        RenderFeat(j("ForgeModelName"))
        RenderFeat(j("ForgeModelSpoof"))
        RenderFeat(j("ForgeModelUnspoof"))
        ClickGUI.EndCustomChildWindow()

        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Save/Load Vehicle Configs")
        RenderFeat(j("Saved Vehicle Configs"))
        RenderFeat(j("Config Name"))
        RenderFeat(j("Refresh Vehicle Configs"))
        RenderFeat(j("Save Vehicle Config"))
        RenderFeat(j("Apply Vehicle Config"))
        RenderFeat(j("VehicleConfigSpawnUpgraded"))
        ClickGUI.EndCustomChildWindow()

        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Breathing Neon Kit")
        RenderFeat(j("BreathingNeon"))
        RenderFeat(j("BreathingNeonSlider"))
        ClickGUI.EndCustomChildWindow()

        ClickGUI.BeginCustomChildWindow("Toggles")
        RenderFeat(j("EnableFestiveHorns"))
        ClickGUI.EndCustomChildWindow()

        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Better Saved Vehicles")
        RenderFeat(j("ToggleVehiclePreview"))
        ClickGUI.EndCustomChildWindow()

        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("UI") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Smaller Reticle (crosshair)")
        RenderFeat(j("Smaller Reticle"))
        RenderFeat(j("Reticle Size"))
        ClickGUI.EndCustomChildWindow()
        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Teleports") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Better Teleport")
        ImGui.TextWrapped("Cherax's Teleport to Waypoint is broken, it sometimes puts you high up into the sky.")
        ImGui.TextWrapped("The feature below first puts the camera at the waypoint coords, to load collision data.")
        RenderFeat(j("BetterTpToWaypoint"))
        ClickGUI.EndCustomChildWindow()
        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Preset teleports")
        for _, feat in ipairs(tp_feats) do
            RenderFeat(j(feat))
        end
        ClickGUI.EndCustomChildWindow()
        ImGui.Columns()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Stats") then
        ImGui.Columns(2, "", false)
        ClickGUI.BeginCustomChildWindow("Stat Editor")
        RenderFeat(j("OpenStatsWebsite"))
        ImGui.Text("Stat name:")
        RenderFeat(j("StatName"))
        local type = FeatureMgr.GetFeatureListIndex(j("StatType"))
        RenderFeat(j("StatType"))
        if type == 0 then
            RenderFeat(j("StatValueInt"))
            RenderFeat(j("SetStatInt"))
        elseif type == 1 then
            RenderFeat(j("StatValueFloat"))
            RenderFeat(j("SetStatFloat"))
        elseif type == 2 then
            ImGui.Text("Bool value:")
            ImGui.SameLine()
            RenderFeat(j("StatValueBool"))
            RenderFeat(j("SetStatBool"))
        elseif type == 3 then
            ImGui.Text("String value:")
            ImGui.SameLine()
            RenderFeat(j("StatValueString"))
            RenderFeat(j("SetStatString"))
        end

        ClickGUI.EndCustomChildWindow()
        ImGui.NextColumn()
        ClickGUI.BeginCustomChildWindow("Unlocks")
        RenderFeat(j("UnlockChameleonPaints"))
        ClickGUI.EndCustomChildWindow()

        ImGui.Columns()
        
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Debug") then
        RenderFeat(j("Print hovered feature info"))
        ImGui.EndTabItem()
    end

    ImGui.EndTabBar()
end)
