--[[
MWM-Render_config.lua - REAPER Render Configuration Utilities

This file is derived from the Ultraschall project (http://ultraschall.fm)
with modifications and additions by Mount West Music AB.

LICENSING:
  - Original Ultraschall code: MIT License (c) 2014-2019 Ultraschall
  - Modifications: MIT License (c) 2026 Mount West Music AB

The full license text and attribution details are provided in
THIRD_PARTY_LICENSES.txt and must be included in any distribution.

SPDX-License-Identifier: MIT
]] --

local mwm_lib_path = reaper.GetExtState("AMAPP", "lib_path")

function Error_Message(err_line, func, type, msg, retval)
  local h = "!!! ERROR !!!\n==================\n"
  local info = "AMAPP crashed when running MWM-Render_config.lua at line " .. tostring(err_line) .. "\n"
  local f = "Function " .. func .. " caught error with title: " .. type .. "\n"
  local err = "Error message: " .. msg .. "\n"
  local error_msg = h .. info .. f .. err
  reaper.ReaScriptError(error_msg)
  return retval
end

local function Windows_Find(title, exact)
  if type(title) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "Windows_Find", "title", "must be a string", -1)
    return -1
  end
  if type(exact) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "Windows_Find", "exact", "must be a boolean", -2)
    return -1
  end
  local retval, list = reaper.JS_Window_ListFind(title, exact)
  local list = list .. ","
  local hwnd_list = {}
  local hwnd_list2 = {}
  local count = 0
  local parenthwnd
  for i = 1, retval do
    local temp, offset = list:match("(.-),()")
    local temphwnd = reaper.JS_Window_HandleFromAddress(temp)
    parenthwnd = reaper.JS_Window_GetParent(temphwnd)
    while parenthwnd ~= nil do
      if parenthwnd == reaper.GetMainHwnd() then
        count = count + 1
        hwnd_list[count] = temphwnd
        hwnd_list2[count] = temp
      end
      parenthwnd = reaper.JS_Window_GetParent(parenthwnd)
    end
    if Tudelu ~= nil then
    end
    list = list:sub(offset, -1)
  end
  return count, hwnd_list, hwnd_list2
end

local function ReadFullFile(filename_with_path, binary)
  if filename_with_path == nil then
    Error_Message(debug.getinfo(1).currentline, "ReadFullFile", "filename_with_path", "must be a string", -1)
    return nil
  end
  if reaper.file_exists(filename_with_path) == false then
    Error_Message(debug.getinfo(1).currentline, "ReadFullFile", "filename_with_path", "file does not exist", -2)
    return nil
  end

  if binary == true then binary = "b" else binary = "" end
  local linenumber = 0

  local file = io.open(filename_with_path, "r" .. binary)
  local filecontent = file:read("a")

  if binary ~= true then
    for w in string.gmatch(filecontent, "\n") do
      linenumber = linenumber + 1
    end
  else
    linenumber = -1
  end
  file:close()
  return filecontent, filecontent:len(), linenumber
end

local function WriteValueToFile(filename_with_path, value, binarymode, append)
  if type(filename_with_path) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "WriteValueToFile", "filename_with_path",
      "invalid filename " .. tostring(filename_with_path), -1)
    return -1
  end
  value = tostring(value)
  local binary, appendix, file
  if binarymode == nil or binarymode == true then binary = "b" else binary = "" end
  if append == nil or append == false then appendix = "w" else appendix = "a" end
  file = io.open(filename_with_path, appendix .. binary)
  if file == nil then
    Error_Message(debug.getinfo(1).currentline, "WriteValueToFile", "filename_with_path",
      "can't create file " .. filename_with_path, -3)
    return -1
  end
  file:write(value)
  file:close()
  return 1
end

local function CSV2IndividualLinesAsArray(csv_line, separator)

  if type(csv_line) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "CSV2IndividualLinesAsArray", "csv_line", "only string is allowed", -1)
    return -1
  end
  if separator == nil then separator = "," end

  local count = 1
  local line_array = {}

  csv_line = csv_line .. separator

  for line in csv_line:gmatch("(.-)" .. separator) do
    line_array[count] = line
    count = count + 1
  end

  return count - 1, line_array
end

local function HasHWNDChildWindowNames(HWND, childwindownames)

  local count, individual_values = CSV2IndividualLinesAsArray(childwindownames, "\0")
  local retval, list = reaper.JS_Window_ListAllChild(HWND)
  local count2, individual_values2 = CSV2IndividualLinesAsArray(list)
  local Title = {}
  for i = 1, count2 do
    if individual_values2[i] ~= "" then
      local tempHwnd = reaper.JS_Window_HandleFromAddress(individual_values2[i])
      Title[i] = reaper.JS_Window_GetTitle(tempHwnd)
      for a = 1, count do
        if Title[i] == individual_values[a] then individual_values[a] = "found" end
      end
    end
  end
  for i = 1, count do
    if individual_values[i] ~= "found" then return false end
  end
  return true
end

function GetRenderToFileHWND()

  local translation = reaper.JS_Localize("Render to File", "DLG_506")

  local presets = reaper.JS_Localize("Presets", "DLG_506")
  local monofiles = reaper.JS_Localize("Tracks with only mono media to mono files", "DLG_506")
  local render_to = reaper.JS_Localize("Render to", "DLG_506")

  local count_hwnds, hwnd_array, hwnd_adresses = Windows_Find(translation, true)
  if count_hwnds == 0 or hwnd_array == nil then
    return nil
  else
    for i = count_hwnds, 1, -1 do
      if HasHWNDChildWindowNames(hwnd_array[i],
            monofiles,
            render_to,
            presets) == true then
        return hwnd_array[i]
      end
    end
  end
  return nil
end

function GetRenderProgressHWND()

  local main_hwnd = reaper.GetMainHwnd()
  local _os = reaper.GetOS()
  local is_windows = _os == "Win32" or _os == "Win64"

  local function hasChildWithClass(hwnd, class_name)
    local child = reaper.JS_Window_GetRelated(hwnd, "CHILD")
    while child do
      local child_class = reaper.JS_Window_GetClassName(child)
      if child_class == class_name then
        return true
      end
      child = reaper.JS_Window_GetRelated(child, "NEXT")
    end
    return false
  end

  local function hasChildWithTitle(hwnd, title)
    local child = reaper.JS_Window_GetRelated(hwnd, "CHILD")
    while child do
      local child_title = reaper.JS_Window_GetTitle(child)
      if child_title == title then
        return true
      end
      child = reaper.JS_Window_GetRelated(child, "NEXT")
    end
    return false
  end

  local function isReaperWindow(hwnd)
    local parent = hwnd
    for i = 1, 10 do
      parent = reaper.JS_Window_GetParent(parent)
      if not parent then return false end
      if parent == main_hwnd then return true end
    end
    return false
  end

  local count, list = reaper.JS_Window_ListAllTop()
  if count == 0 or not list then return nil end

  for addr in list:gmatch("([^,]+)") do
    local hwnd = reaper.JS_Window_HandleFromAddress(addr)
    if hwnd then
      local title = reaper.JS_Window_GetTitle(hwnd)
      if title then

        if title:find("^Rendering") or title:find("^Finished") then

          if is_windows then
            local parent = reaper.JS_Window_GetParent(hwnd)
            if parent == main_hwnd then
              return hwnd
            end
          else

            return hwnd
          end
        end
      end

      if is_windows then
        local parent = reaper.JS_Window_GetParent(hwnd)
        if parent == main_hwnd then
          if hasChildWithClass(hwnd, "msctls_progress32") and
             hasChildWithTitle(hwnd, "Output file") then
            return hwnd
          end
        end
      end
    end
  end

  return nil
end

local function SetRender_ProjectSampleRateForMix(state)

  if type(state) ~= "boolean" then
    Error_Message("SetRender_ProjectSampleRateForMix", "state", "must be a boolean", -1)
    return false
  end
  local SaveCopyOfProject, hwnd, retval
  if state == false then state = 0 else state = 1 end
  hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    reaper.SNM_SetIntConfigVar("projrenderrateinternal", state)
  else
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1062), "BM_SETCHECK", state, 0, 0, 0)
    reaper.SNM_SetIntConfigVar("projrenderrateinternal", state)
  end
  return true
end

local function ReadBinaryFile_Offset(input_filename_with_path, startoffset, numberofbytes)

  local temp = ""
  local length, eof
  local temp2
  if input_filename_with_path == nil then
    Error_Message(debug.getinfo(1).currentline, "ReadBinaryFile_Offset", "filename_with_path",
      "nil not allowed as filename", -1)
    return -1
  end
  if math.type(startoffset) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "ReadBinaryFile_Offset", "startoffset",
      "no valid startoffset. Only integer allowed.", -2)
    return -1
  end
  if math.type(numberofbytes) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "ReadBinaryFile_Offset", "numberofbytes",
      "no valid value. Only integer allowed.", -3)
    return -1
  end
  if numberofbytes < -1 then
    Error_Message(debug.getinfo(1).currentline, "ReadBinaryFile_Offset", "numberofbytes",
      "must be positive value (0 to n) or -1 for until end of file.", -4)
    return -1
  end

  if reaper.file_exists(input_filename_with_path) == true then
    local fileread = io.open(input_filename_with_path, "rb")
    if numberofbytes == -1 then numberofbytes = fileread:seek("end", 0) - startoffset end
    if startoffset >= 0 then fileread:seek("set", startoffset) else
      eof = fileread:seek("end")
      fileread:seek("set", eof - 1 - (startoffset * -1))
    end
    temp = fileread:read(numberofbytes)
    fileread:close()
    if temp == nil then temp = "" end
    return temp:len(), temp
  else
    Error_Message(debug.getinfo(1).currentline, "ReadBinaryFile_Offset", "filename_with_path",
      "file does not exist." .. input_filename_with_path, -6)
    return -1
  end
end

local function Base64_Encoder(source_string, base64_type, remove_newlines, remove_tabs)

  if type(source_string) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "Base64_Encoder", "source_string", "must be a string", -1)
    return nil
  end
  if remove_newlines ~= nil and math.type(remove_newlines) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "Base64_Encoder", "remove_newlines", "must be an integer", -2)
    return nil
  end
  if remove_tabs ~= nil and math.type(remove_tabs) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "Base64_Encoder", "remove_tabs", "must be an integer", -3)
    return nil
  end
  if base64_type ~= nil and math.type(base64_type) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "Base64_Encoder", "base64_type", "must be an integer", -4)
    return nil
  end

  local tempstring = {}
  local a = 1
  local temp

  local base64_string = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

  if remove_newlines == 1 then
    source_string = string.gsub(source_string, "\n", "")
    source_string = string.gsub(source_string, "\r", "")
  elseif remove_newlines == 2 then
    source_string = string.gsub(source_string, "\n", " ")
    source_string = string.gsub(source_string, "\r", "")
  end

  if remove_tabs == 1 then
    source_string = string.gsub(source_string, "\t", "")
  elseif remove_tabs == 2 then
    source_string = string.gsub(source_string, "\t", " ")
  end

  for i = 1, source_string:len() do
    temp = string.byte(source_string:sub(i, i))

    if temp & 1 == 0 then tempstring[a + 7] = 0 else tempstring[a + 7] = 1 end
    if temp & 2 == 0 then tempstring[a + 6] = 0 else tempstring[a + 6] = 1 end
    if temp & 4 == 0 then tempstring[a + 5] = 0 else tempstring[a + 5] = 1 end
    if temp & 8 == 0 then tempstring[a + 4] = 0 else tempstring[a + 4] = 1 end
    if temp & 16 == 0 then tempstring[a + 3] = 0 else tempstring[a + 3] = 1 end
    if temp & 32 == 0 then tempstring[a + 2] = 0 else tempstring[a + 2] = 1 end
    if temp & 64 == 0 then tempstring[a + 1] = 0 else tempstring[a + 1] = 1 end
    if temp & 128 == 0 then tempstring[a] = 0 else tempstring[a] = 1 end
    a = a + 8
  end

  local encoded_string = ""
  local temp2 = 0

  local Entries = {}
  local Entries_Count = 1
  Entries[Entries_Count] = ""
  local Count = 0

  for i = 0, a - 2, 6 do
    temp2 = 0
    if tempstring[i + 1] == 1 then temp2 = temp2 + 32 end
    if tempstring[i + 2] == 1 then temp2 = temp2 + 16 end
    if tempstring[i + 3] == 1 then temp2 = temp2 + 8 end
    if tempstring[i + 4] == 1 then temp2 = temp2 + 4 end
    if tempstring[i + 5] == 1 then temp2 = temp2 + 2 end
    if tempstring[i + 6] == 1 then temp2 = temp2 + 1 end

    if Count > 810 then
      Entries_Count = Entries_Count + 1
      Entries[Entries_Count] = ""
      Count = 0
    end
    Count = Count + 1
    Entries[Entries_Count] = Entries[Entries_Count] .. base64_string:sub(temp2 + 1, temp2 + 1)
  end

  local Count = 0
  local encoded_string2 = ""
  local encoded_string = ""
  for i = 1, Entries_Count do
    Count = Count + 1
    encoded_string2 = encoded_string2 .. Entries[i]
    if Count == 6 then
      encoded_string = encoded_string .. encoded_string2
      encoded_string2 = ""
      Count = 0
    end
  end
  encoded_string = encoded_string .. encoded_string2

  if encoded_string:len() % 4 == 2 then
    encoded_string = encoded_string .. "=="
  elseif encoded_string:len() % 2 == 1 then
    encoded_string = encoded_string .. "="
  end

  return encoded_string
end

local function SplitIntegerIntoBytes(integervalue)

  if math.type(integervalue) ~= "integer" then
    Error_Message("SplitIntegerIntoBytes", "integervalue", "Must be an integer", -1)
    return -1
  end
  if integervalue < -4294967296 or integervalue > 4294967295 then
    Error_Message("SplitIntegerIntoBytes", "integervalue", "Must be between -4294967296 and 4294967295", -2)
    return -1
  end
  local vars = {}
  vars[1] = 0
  vars[2] = 0
  vars[3] = 0
  vars[4] = 0
  local entry = 1
  local bitcount = 0
  local count = 0
  for bitcount = 0, 31 do
    count = count + 1
    if count == 9 then
      count = 1
      entry = entry + 1
    end
    if integervalue & (math.floor(2 ^ bitcount)) ~= 0 then
      vars[entry] = math.floor(vars[entry] + (2 ^ (count - 1)))
    end
  end
  return table.unpack(vars)
end

local function ConvertIntegerIntoString2(Size, ...)

  if math.type(Size) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "ConvertIntegerIntoString2", "Size", "must be an integer", -1)
    return nil
  end
  if Size < 1 or Size > 4 then
    Error_Message(debug.getinfo(1).currentline, "ConvertIntegerIntoString2", "Size",
      "must be between 1(for 8 bit) and 4(for 32 bit)", -2)
    return nil
  end
  local Table = { ... }
  local String = ""
  local count = 1
  while Table[count] ~= nil do
    if math.type(Table[count]) ~= "integer" then
      Error_Message(debug.getinfo(1).currentline, "ConvertIntegerIntoString2", "parameter " .. count,
        "must be an integer", -3)
      return
    end
    if Table[count] > 2 ^ 32 then
      Error_Message(debug.getinfo(1).currentline, "ConvertIntegerIntoString2", "parameter " .. count,
        "must be between 0 and 2^32", -4)
      return
    end
    local Byte1, Byte2, Byte3, Byte4 = SplitIntegerIntoBytes(Table[count])
    String = String .. string.char(Byte1)
    if Size > 1 then String = String .. string.char(Byte2) end
    if Size > 2 then String = String .. string.char(Byte3) end
    if Size > 3 then String = String .. string.char(Byte4) end
    count = count + 1
  end
  return String
end

local function LimitFractionOfFloat(number, length_of_fraction)

  if type(number) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "LimitFractionOfFloat", "number", "must be a number", -1)
    return
  end
  if math.type(length_of_fraction) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "LimitFractionOfFloat", "length_of_fraction", "must be an integer", -2)
    return
  end
  if math.floor(number) == number then return number end

  return tonumber(tostring(tonumber(string.format("%." .. length_of_fraction .. "f", number))))
end

local function DoubleToInt(float, selector)
  float = float + 0.0
  float = LimitFractionOfFloat(float, 2, true)
  float = tostring(float)
  local String, retval
  if selector == nil then

    if (float:match("%.(.*)")):len() == 1 then float = float .. "0" end

    local found = ""
    local one, two, three, four, A
    local finalcounter = string.gsub(tostring(float), "%.", "")
    finalcounter = tonumber(finalcounter)

    local ini_file = reaper.GetExtState("AMAPP", "lib_path") .. "util/init/double_to_int_2.ini"
    local length, k = ReadBinaryFile_Offset(ini_file, finalcounter * 4, 4)

    one = tostring(string.byte(k:sub(1, 1)) - 1)
    if one:len() == 1 then one = "0" .. one end
    two = tostring(string.byte(k:sub(2, 2)) - 1)
    if two:len() == 1 then two = "0" .. two end
    three = tostring(string.byte(k:sub(3, 3)) - 1)
    if three:len() == 1 then three = "0" .. three end
    four = tostring(string.byte(k:sub(4, 4)) - 1)
    if four:len() == 1 then four = "0" .. four end
    found = tonumber(one .. two .. three .. four)

    if finalcounter > 1808 then
      found = found + 100000000
    end
    if found > 0 then found = found + 1000000000 end
    return found
  else

    retval, String = reaper.BR_Win32_GetPrivateProfileString("OpusFloatsInt", math.tointeger(float), "-1",
      mwm_lib_path .. "util/init/double_to_int_24bit.ini")

    String = tonumber(String) + 4000000
  end
  return String
end

local function AddIntToChar(character, int)

  if type(character) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "AddIntToChar", "character", "must be a string with one character", -1)
    return nil
  end
  if character:len() ~= 1 then
    Error_Message(debug.getinfo(1).currentline, "AddIntToChar", "character", "must be a string with one character", -2)
    return nil
  end
  if math.type(int) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "AddIntToChar", "int", "must be an integer", -3)
    return nil
  end
  if string.byte(character) + int > 255 or string.byte(character) + int < 0 then
    Error_Message(debug.getinfo(1).currentline, "AddIntToChar", "char + int", "calculated value is out of range of ASCII",
      -4)
    return nil
  end
  local charcode = string.byte(character)
  local newchar = string.char(charcode + int)
  return newchar
end

local function MKVOL2DB(mkvol_value)

  if type(mkvol_value) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "MKVOL2DB", "mkvol_value", "must be a number", -1)
    return nil
  end
  if mkvol_value < 0.00000002980232 then return -144 end
  mkvol_value = math.log(mkvol_value) * 8.68588963806
  return mkvol_value
end

local function DB2MKVOL(db_value)

  if type(db_value) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "DB2MKVOL", "db_value", "must be a number", -1)
    return nil
  end
  return math.exp(db_value / 8.68588963806)
end
function CountEntriesInTable_Main(the_table)

  if type(the_table) ~= "table" then
    Error_Message(debug.getinfo(1).currentline, "CountEntriesInTable_Main", "table", "Must be a table!", -1)
    return -1
  end
  local count = 1
  local SubTables = {}
  local SubTablesCount = 1
  while the_table[count] ~= nil do

    if type(the_table[count]) == "table" then
      SubTables[SubTablesCount] = v
      SubTablesCount = SubTablesCount + 1
    end
    count = count + 1
  end
  return count - 1, SubTables, SubTablesCount - 1
end

local function GetDuplicatesFromArrays(array1, array2)

  if type(array1) ~= "table" then
    Error_Message(debug.getinfo(1).currentline, "GetDuplicatesFromArrays", "array1", "must be a table", -1)
    return -1
  end
  if type(array2) ~= "table" then
    Error_Message(debug.getinfo(1).currentline, "GetDuplicatesFromArrays", "array2", "must be a table", -2)
    return -1
  end
  local count1 = CountEntriesInTable_Main(array1)
  local count2 = CountEntriesInTable_Main(array2)
  local duplicates = {}
  local originals1 = {}
  local originals2 = {}
  local dupcount = 0
  local orgcount1 = 0
  local orgcount2 = 0
  local found = false

  for i = 1, count2 do
    for a = 1, count1 do
      if array2[i] == array1[a] then
        dupcount = dupcount + 1
        duplicates[dupcount] = array2[i]
        found = true
      end
    end
    if found == false then
      orgcount2 = orgcount2 + 1
      originals2[orgcount2] = array2[i]
    end
    found = false
  end

  for i = 1, count1 do
    for a = 1, count2 do
      if array1[i] == array2[a] then
        found = true
      end
    end
    if found == false then
      orgcount1 = orgcount1 + 1
      originals1[orgcount1] = array1[i]
    end
    found = false
  end

  return dupcount, duplicates, orgcount1, originals1, orgcount2, originals2
end

local function GetReaperAppVersion()

  local portable
  if reaper.GetExePath() == reaper.GetResourcePath() then portable = true else portable = false end

  local majvers = tonumber(reaper.GetAppVersion():match("(.-)%..-/"))
  local subvers = tonumber(reaper.GetAppVersion():match("%.(%d*)"))
  local bits = reaper.GetAppVersion():match("/(.*)")
  local OS = reaper.GetOS():match("(.-)%d")
  local beta = reaper.GetAppVersion():match("%.%d*(.-)/")
  return majvers, subvers, bits, OS, portable, beta
end

local function GetRender_ResampleMode()

  local oldfocus = reaper.JS_Window_GetFocus()

  local hwnd = GetRenderToFileHWND()
  if hwnd == nil then return reaper.SNM_GetIntConfigVar("projrenderresample", -1) end

  local mode = reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1000), "CB_GETCURSEL", 0, 100, 0, 100)

  local majorversion, subversion = GetReaperAppVersion()
  local version = tonumber(majorversion .. "." .. subversion)
  local LookupTable_Old_ResampleModes_vs_New
  if version < 6.43 then
    LookupTable_Old_ResampleModes_vs_New = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
  else
    LookupTable_Old_ResampleModes_vs_New = { 2, 1, 5, 6, 7, 0, 3, 4, 8, 9, 10 }
  end

  return LookupTable_Old_ResampleModes_vs_New[mode + 1]
end

local function GetRender_OfflineOnlineMode()

  local oldfocus = reaper.JS_Window_GetFocus()

  local hwnd = GetRenderToFileHWND()
  if hwnd == nil then return reaper.SNM_GetIntConfigVar("projrenderlimit", -1) end

  return reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1001), "CB_GETCURSEL", 0, 100, 0, 100)
end

local function GetRender_QueueDelay()

  local SaveCopyOfProject, hwnd, retval, length, state
  hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    length = reaper.SNM_GetIntConfigVar("renderqdelay", 0)
    if length < 1 then
      length = -length
      state = false
    else state = true end
  else
    state = reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1808), "BM_GETCHECK", 0, 0, 0, 0)
    length = reaper.SNM_GetIntConfigVar("renderqdelay", 0)
    if length < 0 then length = -length end
    if state == 0 then state = false else state = true end
  end
  return state, length
end

local function GetRender_ProjectSampleRateForMix()

  local SaveCopyOfProject, hwnd, retval, length, state
  hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    state = reaper.SNM_GetIntConfigVar("projrenderrateinternal", 0)
  else
    state = reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1062), "BM_GETCHECK", 0, 0, 0, 0)
  end
  if state == 0 then state = false else state = true end
  return state
end

local function GetRender_AutoIncrementFilename()

  local SaveCopyOfProject, hwnd, retval, length, state
  hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    state = reaper.SNM_GetIntConfigVar("renderclosewhendone", 0)
    if state & 16 == 0 then state = 0 end
  else
    state = reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1042), "BM_GETCHECK", 1, 0, 0, 0)
  end
  if state == 0 then state = false else state = true end
  return state
end

local function SetRender_AutoIncrementFilename(state)

  if type(state) ~= "boolean" then
    Error_Message("SetRender_AutoIncrementFilename", "state", "must be a boolean", -1)
    return false
  end
  local SaveCopyOfProject, hwnd, retval
  if state == false then state = 0 else state = 1 end
  hwnd = GetRenderToFileHWND()
  local oldval = reaper.SNM_GetIntConfigVar("renderclosewhendone", -1)
  if state == 1 and oldval & 16 == 0 then
    oldval = oldval + 16
  elseif state == 0 and oldval & 16 == 16 then
    oldval = oldval - 16
  end
  if hwnd ~= nil then
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1042), "BM_SETCHECK", state, 0, 0, 0)
  end
  reaper.SNM_SetIntConfigVar("renderclosewhendone", oldval)
  return true
end

function IsValidReaProject(ReaProject)

  if ReaProject == nil then return true end
  if ReaProject == 0 then return true end
  local count = 0
  while reaper.EnumProjects(count, "") ~= nil do
    if reaper.EnumProjects(count, "") == ReaProject then return true end
    count = count + 1
  end
  return false
end

local function SetRender_QueueDelay(state, length)

  if type(state) ~= "boolean" then
    Error_Message("SetRender_QueueDelay", "state", "must be a boolean", -1)
    return false
  end
  if math.type(length) ~= "integer" then
    Error_Message("SetRender_QueueDelay", "length", "must be an integer", -2)
    return false
  end
  local SaveCopyOfProject, hwnd, retval
  if state == false then
    state = 0
    length = -length
  else state = 1 end
  hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    reaper.SNM_SetIntConfigVar("renderqdelay", length)
    retval = reaper.BR_Win32_WritePrivateProfileString("REAPER", "renderqdelay", length, reaper.get_ini_file())
  else
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1808), "BM_SETCHECK", state, 0, 0, 0)
    reaper.SNM_SetIntConfigVar("renderqdelay", length)
    retval = reaper.BR_Win32_WritePrivateProfileString("REAPER", "renderqdelay", length, reaper.get_ini_file())
  end
  return retval
end

local function IsOS_Windows()

  local retval = reaper.GetOS()
  local Os, bits

  if retval:match("Win") ~= nil then
    Os = true
  else
    Os = false
  end
  if Os == true and retval:match("32") ~= nil then bits = 32 end
  if Os == true and retval:match("64") ~= nil then bits = 64 end
  return Os, bits
end

local function IsOS_Mac()

  local retval = reaper.GetOS()
  local Os, bits

  if retval:match("OSX") ~= nil or retval:match("macOS%-arm64") ~= nil then
    Os = true
  else
    Os = false
  end
  if Os == true and retval:match("32") ~= nil then bits = 32 end
  if Os == true and retval:match("64") ~= nil then bits = 64 end
  return Os, bits
end

function SetRender_ResampleMode(mode)

  if math.type(mode) ~= "integer" then
    Error_Message("SetRender_ResampleMode", "mode", "must be an integer", -1)
    return false
  end
  if mode < 0 or mode > 10 then
    Error_Message("SetRender_ResampleMode", "mode", "must be between 0 and 10", -2)
    return false
  end
  local oldfocus = reaper.JS_Window_GetFocus()

  local hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    reaper.SNM_SetIntConfigVar("projrenderresample", mode)
    return
  end

  local majorversion, subversion = GetReaperAppVersion()
  local version = tonumber(majorversion .. "." .. subversion)

  local LookupTable_Old_ResampleModes_vs_New

  if version < 6.43 then
    LookupTable_Old_ResampleModes_vs_New = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
  else
    LookupTable_Old_ResampleModes_vs_New = { 5, 1, 0, 6, 7, 2, 3, 4, 8, 9, 10 }
  end

  local mode = LookupTable_Old_ResampleModes_vs_New[mode + 1]

  if IsOS_Windows() == true then
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1000), "CB_SETCURSEL", mode, 0, 0, 0)
  elseif IsOS_Mac() == true then
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1000), "CB_SETCURSEL", mode, 0, 0, 0)
  else
    
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1000), "CB_SETCURSEL", mode, 0, 0, 0)
  end

  reaper.JS_Window_SetFocus(oldfocus)
  return true
end

local function SetRender_OfflineOnlineMode(mode)

  if math.type(mode) ~= "integer" then
    Error_Message("SetRender_OfflineOnlineMode", "mode", "must be an integer", -1)
    return false
  end
  if mode < 0 or mode > 4 then
    Error_Message("SetRender_OfflineOnlineMode", "mode", "must be between 0 and 4", -2)
    return false
  end
  local oldfocus = reaper.JS_Window_GetFocus()

  local hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    reaper.SNM_SetIntConfigVar("projrenderlimit", mode)
    return
  end

  if IsOS_Windows() == true then
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1001), "CB_SETCURSEL", mode, 0, 0, 0)

  elseif IsOS_Mac() == true then
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1001), "CB_SETCURSEL", mode, 0, 0, 0)
  else
    
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1001), "CB_SETCURSEL", mode, 0, 0, 0)
  end

  reaper.JS_Window_SetFocus(oldfocus)

  return true
end

local function GetPath(str, sep)

  if type(str) ~= "string" then
    Error_Message("GetPath", "str", "only a string allowed", -1)
    return "", ""
  end
  if sep ~= nil and type(sep) ~= "string" then
    Error_Message("GetPath", "sep", "only a string allowed", -2)
    return "", ""
  end

  local result, file

  if sep ~= nil then
    result = str:match("(.*" .. sep .. ")")
    file = str:match(".*" .. sep .. "(.*)")
    if result == nil then
      Error_Message("GetPath", "", "separator not found", -3)
      return "", ""
    end
  else
    result = str:match("(.*" .. "[\\/]" .. ")")
    file = str:match(".*" .. "[\\/]" .. "(.*)")
  end
  if result == nil then
    file = str
    result = ""
  end
  return result, file
end

local function ultraschall_type(object)

  if object == nil then
    return "nil"
  elseif math.type(object) == "integer" then
    return "number: integer", true
  elseif math.type(object) == "float" then
    return "number: float", true
  elseif type(object) == "boolean" then
    return "boolean"
  elseif type(object) == "string" then
    return "string"
  elseif type(object) == "function" then
    return "function"
  elseif type(object) == "table" then
    return "table"
  elseif type(object) == "thread" then
    return "thread"
  elseif IsValidReaProject(object) == true then
    return "ReaProject"
  elseif pcall(reaper.CreateTakeAudioAccessor, object) == true then
    return "MediaItem_Take"
  elseif pcall(reaper.CountTrackMediaItems, object) == true then
    return "MediaTrack"
  elseif pcall(reaper.CountTakes, object) == true then
    return "MediaItem"
  elseif reaper.ValidatePtr(object, "TrackEnvelope*") == true then
    return "TrackEnvelope"
  elseif pcall(reaper.AudioAccessorValidateState, object) == true then
    return "AudioAccessor"
  elseif pcall(reaper.joystick_getaxis, object, 0) == true then
    return "joystick_device"
  elseif pcall(reaper.GetMediaSourceFileName, object, "") == true then
    return "PCM_source"

  elseif type(object) == "userdata" then
    return "userdata"
  end
end

function GetRenderTable_Project()

  local _temp, ReaProject, hwnd, retval
  if ReaProject == nil then ReaProject = 0 end
  if ultraschall_type(ReaProject) ~= "ReaProject" and math.type(ReaProject) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "GetRenderTable_Project", "ReaProject",
      "no such project available, must be either a ReaProject-object or the projecttab-number(1-based)", -1)
    return nil
  end
  if ReaProject == -1 then
    ReaProject = 0x40000000
    _temp = true
  elseif ReaProject < -2 then
    Error_Message(debug.getinfo(1).currentline, "GetRenderTable_Project", "ReaProject",
      "no such project-tab available, must be 0, for the current; 1, for the first, etc; -1, for the currently rendering project",
      -3)
    return nil
  end

  if math.type(ReaProject) == "integer" then ReaProject = reaper.EnumProjects(ReaProject - 1, "") end
  if ReaProject == nil and _temp ~= true then
    Error_Message(debug.getinfo(1).currentline, "GetRenderTable_Project", "ReaProject",
      "no such project available, must be either a ReaProject-object or the projecttab-number(1-based)", -4)
    return nil
  elseif _temp == true then
    Error_Message(debug.getinfo(1).currentline, "GetRenderTable_Project", "ReaProject", "no project currently rendering",
      -5)
    return nil
  end

  local RenderTable = {}
  RenderTable["RenderTable"] = true
  RenderTable["Source"] = math.tointeger(reaper.GetSetProjectInfo(ReaProject, "RENDER_SETTINGS", 0, false))
  if RenderTable["Source"] & 4 ~= 0 then
    RenderTable["Source"] = RenderTable["Source"] - 4
    RenderTable["MultiChannelFiles"] = true
  else RenderTable["MultiChannelFiles"] = false end
  if RenderTable["Source"] & 16 ~= 0 then
    RenderTable["Source"] = RenderTable["Source"] - 16
    RenderTable["OnlyMonoMedia"] = true
  else RenderTable["OnlyMonoMedia"] = false end
  if RenderTable["Source"] & 256 ~= 0 then
    RenderTable["Source"] = RenderTable["Source"] - 256
    RenderTable["EmbedStretchMarkers"] = true
  else RenderTable["EmbedStretchMarkers"] = false end
  if RenderTable["Source"] & 512 ~= 0 then
    RenderTable["Source"] = RenderTable["Source"] - 512
    RenderTable["EmbedMetaData"] = true
  else RenderTable["EmbedMetaData"] = false end
  if RenderTable["Source"] & 1024 ~= 0 then
    RenderTable["Source"] = RenderTable["Source"] - 1024
    RenderTable["EmbedTakeMarkers"] = true
  else RenderTable["EmbedTakeMarkers"] = false end
  if RenderTable["Source"] & 2048 ~= 0 then
    RenderTable["Source"] = RenderTable["Source"] - 2048
    RenderTable["Enable2ndPassRender"] = true
  else RenderTable["Enable2ndPassRender"] = false end
  if RenderTable["Source"] & 8192 ~= 0 then
    RenderTable["Source"] = RenderTable["Source"] - 8192
    RenderTable["RenderStems_Prefader"] = true
  else RenderTable["RenderStems_Prefader"] = false end
  if RenderTable["Source"] & 16384 ~= 0 then
    RenderTable["Source"] = RenderTable["Source"] - 16384
    RenderTable["OnlyChannelsSentToParent"] = true
  else RenderTable["OnlyChannelsSentToParent"] = false end

  RenderTable["Bounds"] = math.tointeger(reaper.GetSetProjectInfo(ReaProject, "RENDER_BOUNDSFLAG", 0, false))
  RenderTable["Channels"] = math.tointeger(reaper.GetSetProjectInfo(ReaProject, "RENDER_CHANNELS", 0, false))
  RenderTable["SampleRate"] = math.tointeger(reaper.GetSetProjectInfo(ReaProject, "RENDER_SRATE", 0, false))
  if RenderTable["SampleRate"] == 0 then
    RenderTable["SampleRate"] = math.tointeger(reaper.GetSetProjectInfo(ReaProject, "PROJECT_SRATE", 0, false))
  end
  RenderTable["Startposition"] = reaper.GetSetProjectInfo(ReaProject, "RENDER_STARTPOS", 0, false)
  RenderTable["Endposition"] = reaper.GetSetProjectInfo(ReaProject, "RENDER_ENDPOS", 0, false)
  RenderTable["TailFlag"] = math.tointeger(reaper.GetSetProjectInfo(ReaProject, "RENDER_TAILFLAG", 0, false))
  RenderTable["TailMS"] = math.tointeger(reaper.GetSetProjectInfo(ReaProject, "RENDER_TAILMS", 0, false))
  RenderTable["AddToProj"] = reaper.GetSetProjectInfo(ReaProject, "RENDER_ADDTOPROJ", 0, false) & 1
  if RenderTable["AddToProj"] == 1 then RenderTable["AddToProj"] = true else RenderTable["AddToProj"] = false end
  RenderTable["NoSilentRender"] = reaper.GetSetProjectInfo(ReaProject, "RENDER_ADDTOPROJ", 0, false) & 2
  if RenderTable["NoSilentRender"] == 2 then RenderTable["NoSilentRender"] = true else RenderTable["NoSilentRender"] = false end
  RenderTable["Dither"] = math.tointeger(reaper.GetSetProjectInfo(ReaProject, "RENDER_DITHER", 0, false))
  RenderTable["ProjectSampleRateFXProcessing"] = GetRender_ProjectSampleRateForMix()
  RenderTable["SilentlyIncrementFilename"] = GetRender_AutoIncrementFilename()

  RenderTable["RenderQueueDelay"], RenderTable["RenderQueueDelaySeconds"] = GetRender_QueueDelay()
  RenderTable["RenderResample"] = GetRender_ResampleMode()
  RenderTable["OfflineOnlineRendering"] = GetRender_OfflineOnlineMode()
  _temp, RenderTable["RenderFile"] = reaper.GetSetProjectInfo_String(ReaProject, "RENDER_FILE", "", false)
  _temp, RenderTable["RenderPattern"] = reaper.GetSetProjectInfo_String(ReaProject, "RENDER_PATTERN", "", false)
  _temp, RenderTable["RenderString"] = reaper.GetSetProjectInfo_String(ReaProject, "RENDER_FORMAT", "", false)
  _temp, RenderTable["RenderString2"] = reaper.GetSetProjectInfo_String(ReaProject, "RENDER_FORMAT2", "", false)

  if reaper.SNM_GetIntConfigVar("renderclosewhendone", -111) & 1 == 0 then
    RenderTable["CloseAfterRender"] = false
  else
    RenderTable["CloseAfterRender"] = true
  end

  hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    retval, RenderTable["SaveCopyOfProject"] = reaper.BR_Win32_GetPrivateProfileString("REAPER", "autosaveonrender2", -1,
      reaper.get_ini_file())
    RenderTable["SaveCopyOfProject"] = tonumber(RenderTable["SaveCopyOfProject"])
  else
    RenderTable["SaveCopyOfProject"] = reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1060),
      "BM_GETCHECK", 0, 0, 0, 0)
  end
  if RenderTable["SaveCopyOfProject"] == 1 then RenderTable["SaveCopyOfProject"] = true else RenderTable["SaveCopyOfProject"] = false end

  RenderTable["Normalize_Method"] = math.tointeger(reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 0, false))
  RenderTable["FadeIn"] = reaper.GetSetProjectInfo(0, "RENDER_FADEIN", 0, false)
  RenderTable["FadeOut"] = reaper.GetSetProjectInfo(0, "RENDER_FADEOUT", 0, false)
  RenderTable["FadeIn_Shape"] = math.tointeger(reaper.GetSetProjectInfo(0, "RENDER_FADEINSHAPE", 0, false))
  RenderTable["FadeOut_Shape"] = math.tointeger(reaper.GetSetProjectInfo(0, "RENDER_FADEOUTSHAPE", 0, false))

  RenderTable["FadeIn_Enabled"] = RenderTable["Normalize_Method"] & 512 == 512
  if RenderTable["FadeIn_Enabled"] == true then RenderTable["Normalize_Method"] = RenderTable["Normalize_Method"] - 512 end
  RenderTable["FadeOut_Enabled"] = RenderTable["Normalize_Method"] & 1024 == 1024
  if RenderTable["FadeOut_Enabled"] == true then RenderTable["Normalize_Method"] = RenderTable["Normalize_Method"] - 1024 end

  local retval = reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 0, false) & 1 == 1
  RenderTable["Normalize_Enabled"] = retval
  if RenderTable["Normalize_Enabled"] == true then RenderTable["Normalize_Method"] = RenderTable["Normalize_Method"] - 1 end
  if reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE_TARGET", 0, false) ~= "" then
    RenderTable["Normalize_Target"] = MKVOL2DB(reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE_TARGET", 0, false))
  else
    RenderTable["Normalize_Target"] = -24
  end

  if RenderTable["Normalize_Method"] & 256 == 0 then
    RenderTable["Normalize_Only_Files_Too_Loud"] = false
  elseif RenderTable["Normalize_Method"] & 256 == 256 then
    RenderTable["Normalize_Only_Files_Too_Loud"] = true
    RenderTable["Normalize_Method"] = RenderTable["Normalize_Method"] - 256
  end

  if RenderTable["Normalize_Method"] & 128 == 0 then
    RenderTable["Brickwall_Limiter_Method"] = 1
  elseif RenderTable["Normalize_Method"] & 128 == 128 then
    RenderTable["Brickwall_Limiter_Method"] = 2
    RenderTable["Normalize_Method"] = RenderTable["Normalize_Method"] - 128
  end

  if RenderTable["Normalize_Method"] & 64 == 64 then
    RenderTable["Brickwall_Limiter_Enabled"] = true
    RenderTable["Normalize_Method"] = RenderTable["Normalize_Method"] - 64
  elseif RenderTable["Normalize_Method"] & 64 == 0 then
    RenderTable["Brickwall_Limiter_Enabled"] = false
  end

  RenderTable["Brickwall_Limiter_Target"] = MKVOL2DB(reaper.GetSetProjectInfo(0, "RENDER_BRICKWALL", 0, false))
  RenderTable["Normalize_Stems_to_Master_Target"] = RenderTable["Normalize_Method"] & 32 == 32
  if RenderTable["Normalize_Stems_to_Master_Target"] == true then RenderTable["Normalize_Method"] = RenderTable
    ["Normalize_Method"] - 32 end
  RenderTable["Normalize_Method"] = math.tointeger(RenderTable["Normalize_Method"] / 2)

  return RenderTable
end

function IsValidRenderTable(RenderTable)

  if type(RenderTable) ~= "table" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable", "must be a table", -1)
    return false
  end
  if type(RenderTable["RenderTable"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable", "no valid rendertable", -2)
    return false
  end
  if type(RenderTable["AddToProj"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"AddToProj\"] must be a boolean", -3)
    return false
  end
  if math.type(RenderTable["Bounds"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Bounds\"] must be an integer", -4)
    return false
  end
  if math.type(RenderTable["Channels"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Channels\"] must be an integer", -5)
    return false
  end
  if math.type(RenderTable["Dither"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Dither\"] must be an integer", -6)
    return false
  end
  if type(RenderTable["Endposition"]) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Endposition\"] must be an integer", -7)
    return false
  end
  if type(RenderTable["MultiChannelFiles"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"MultiChannelFiles\"] must be a boolean", -8)
    return false
  end
  if math.type(RenderTable["OfflineOnlineRendering"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"OfflineOnlineRendering\"] must be an integer", -9)
    return false
  end
  if type(RenderTable["OnlyMonoMedia"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"OnlyMonoMedia\"] must be a boolean", -10)
    return false
  end
  if type(RenderTable["ProjectSampleRateFXProcessing"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"ProjectSampleRateFXProcessing\"] must be a boolean", -11)
    return false
  end
  if type(RenderTable["RenderFile"]) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"RenderFile\"] must be a string", -12)
    return false
  end
  if type(RenderTable["RenderPattern"]) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"RenderPattern\"] must be a string", -13)
    return false
  end
  if type(RenderTable["RenderQueueDelay"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"RenderQueueDelay\"] must be a boolean", -14)
    return false
  end
  if math.type(RenderTable["RenderResample"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"RenderResample\"] must be an integer", -15)
    return false
  end
  if type(RenderTable["RenderString"]) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"RenderString\"] must be a string", -16)
    return false
  end
  if math.type(RenderTable["SampleRate"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"SampleRate\"] must be an integer", -17)
    return false
  end
  if type(RenderTable["SaveCopyOfProject"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"SaveCopyOfProject\"] must be a boolean", -18)
    return false
  end
  if type(RenderTable["SilentlyIncrementFilename"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"SilentlyIncrementFilename\"] must be a boolean", -19)
    return false
  end
  if math.type(RenderTable["Source"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Source\"] must be an integer", -20)
    return false
  end
  if type(RenderTable["Startposition"]) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Startposition\"] must be an integer", -21)
    return false
  end
  if math.type(RenderTable["TailFlag"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"TailFlag\"] must be an integer", -22)
    return false
  end
  if math.type(RenderTable["TailMS"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"TailMS\"] must be an integer", -23)
    return false
  end
  if math.type(RenderTable["RenderQueueDelaySeconds"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"RenderQueueDelaySeconds\"] must be an integer", -24)
    return false
  end
  if type(RenderTable["CloseAfterRender"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"CloseAfterRender\"] must be a boolean", -25)
    return false
  end
  if type(RenderTable["EmbedStretchMarkers"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"EmbedStretchMarkers\"] must be a boolean", -26)
    return false
  end
  if type(RenderTable["RenderString2"]) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"RenderString2\"] must be a string", -17)
    return false
  end
  if type(RenderTable["EmbedTakeMarkers"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"EmbedTakeMarkers\"] must be a boolean", -18)
    return false
  end
  if type(RenderTable["NoSilentRender"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"NoSilentRender\"] must be a boolean", -19)
    return false
  end
  if type(RenderTable["EmbedMetaData"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"EmbedMetaData\"] must be a boolean", -20)
    return false
  end
  if type(RenderTable["Enable2ndPassRender"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Enable2ndPassRender\"] must be a boolean", -21)
    return false
  end

  if type(RenderTable["Normalize_Enabled"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Normalize_Enabled\"] must be a boolean", -22)
    return false
  end
  if type(RenderTable["Normalize_Stems_to_Master_Target"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Normalize_Stems_to_Master_Target\"] must be a boolean", -23)
    return false
  end
  if type(RenderTable["Normalize_Target"]) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Normalize_Target\"] must be a number", -24)
    return false
  end
  if math.type(RenderTable["Normalize_Method"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Normalize_Method\"] must be a number", -25)
    return false
  end

  if math.type(RenderTable["Brickwall_Limiter_Method"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Brickwall_Limiter_Method\"] must be an integer", -26)
    return false
  end
  if type(RenderTable["Brickwall_Limiter_Enabled"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Brickwall_Limiter_Enabled\"] must be a boolean", -27)
    return false
  end
  if type(RenderTable["Brickwall_Limiter_Target"]) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Brickwall_Limiter_Target\"] must be a number", -28)
    return false
  end
  if type(RenderTable["Normalize_Only_Files_Too_Loud"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"Normalize_Only_Files_Too_Loud\"] must be a boolean", -29)
    return false
  end

  if type(RenderTable["FadeIn"]) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"FadeIn\"] must be a number", -30)
    return false
  end
  if type(RenderTable["FadeOut"]) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"FadeOut\"] must be a number", -31)
    return false
  end
  if type(RenderTable["FadeIn_Enabled"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"FadeIn_Enabled\"] must be a boolean", -32)
    return false
  end
  if type(RenderTable["FadeOut_Enabled"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"FadeOut_Enabled\"] must be a boolean", -33)
    return false
  end
  if math.type(RenderTable["FadeIn_Shape"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"FadeIn_Shape\"] must be an integer", -34)
    return false
  end
  if math.type(RenderTable["FadeOut_Shape"]) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"FadeOut_Shape\"] must be an integer", -35)
    return false
  end
  if type(RenderTable["OnlyChannelsSentToParent"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"OnlyChannelsSentToParent\"] must be a boolean", -36)
    return false
  end
  if type(RenderTable["RenderStems_Prefader"]) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "IsValidRenderTable", "RenderTable",
      "RenderTable[\"RenderStems_Prefader\"] must be a boolean", -37)
    return false
  end

  return true
end

function CreateNewRenderTable(
    Source, Bounds, Startposition, Endposition, TailFlag,
    TailMS, RenderFile, RenderPattern, SampleRate, Channels,
    OfflineOnlineRendering, ProjectSampleRateFXProcessing, RenderResample, OnlyMonoMedia, MultiChannelFiles,
    Dither, RenderString, SilentlyIncrementFilename, AddToProj, SaveCopyOfProject,
    RenderQueueDelay, RenderQueueDelaySeconds, CloseAfterRender, EmbedStretchMarkers, RenderString2,
    EmbedTakeMarkers, DoNotSilentRender, EmbedMetadata, Enable2ndPassRender,
    Normalize_Enabled, Normalize_Method, Normalize_Stems_to_Master_Target, Normalize_Target,
    Brickwall_Limiter_Enabled, Brickwall_Limiter_Method, Brickwall_Limiter_Target,
    Normalize_Only_Files_Too_Loud, FadeIn_Enabled, FadeIn, FadeIn_Shape, FadeOut_Enabled, FadeOut, FadeOut_Shape,
    OnlyChannelsSentToParent, RenderStems_Prefader)

  if Source ~= nil and math.type(Source) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Source", "#1: must be nil or an integer", -20)
    return
  end
  if Bounds ~= nil and math.type(Bounds) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Bounds", "#2: must be nil or an integer", -4)
    return
  end
  if Startposition ~= nil and type(Startposition) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Startposition", "#3: must be nil or an integer",
      -21)
    return
  end
  if Endposition ~= nil and type(Endposition) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Endposition", "#4: must be nil or an integer",
      -7)
    return
  end
  if TailFlag ~= nil and math.type(TailFlag) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "TailFlag", "#5: must be nil or an integer", -22)
    return
  end
  if TailMS ~= nil and math.type(TailMS) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "TailMS", "#6: must be nil or an integer", -23)
    return
  end
  if RenderFile ~= nil and type(RenderFile) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "RenderFile", "#7: must be nil or a string", -12)
    return
  end
  if RenderPattern ~= nil and type(RenderPattern) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "RenderPattern", "#8: must be nil or a string",
      -13)
    return
  end
  if SampleRate ~= nil and math.type(SampleRate) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "SampleRate", "#9: must be nil or an integer",
      -17)
    return
  end
  if Channels ~= nil and math.type(Channels) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Channels", "#10: must be nil or an integer", -5)
    return
  end
  if OfflineOnlineRendering ~= nil and math.type(OfflineOnlineRendering) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "OfflineOnlineRendering",
      "#11: must be nil or an integer", -9)
    return
  end
  if ProjectSampleRateFXProcessing ~= nil and type(ProjectSampleRateFXProcessing) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "ProjectSampleRateFXProcessing",
      "#12: must be nil or a boolean", -11)
    return
  end
  if RenderResample ~= nil and math.type(RenderResample) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "RenderResample",
      "#13: must be nil or an integer", -15)
    return
  end
  if OnlyMonoMedia ~= nil and type(OnlyMonoMedia) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "OnlyMonoMedia", "#14: must be nil or a boolean",
      -10)
    return
  end
  if MultiChannelFiles ~= nil and type(MultiChannelFiles) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "MultiChannelFiles",
      "#15: must be nil or a boolean", -8)
    return
  end
  if Dither ~= nil and math.type(Dither) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Dither", "#16: must be nil or an integer", -6)
    return
  end
  if RenderString ~= nil and type(RenderString) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "RenderString", "#17: must be nil or a string",
      -16)
    return
  end
  if SilentlyIncrementFilename ~= nil and type(SilentlyIncrementFilename) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "SilentlyIncrementFilename",
      "#18: must be nil or a boolean", -19)
    return
  end
  if AddToProj ~= nil and type(AddToProj) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "AddToProj", "#19: must be nil or a boolean", -3)
    return
  end
  if SaveCopyOfProject ~= nil and type(SaveCopyOfProject) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "SaveCopyOfProject",
      "#20: must be nil or a boolean", -18)
    return
  end
  if RenderQueueDelay ~= nil and type(RenderQueueDelay) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "RenderQueueDelay",
      "#21: must be nil or a boolean", -14)
    return
  end
  if RenderQueueDelaySeconds ~= nil and math.type(RenderQueueDelaySeconds) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "RenderQueueDelaySeconds",
      "#22: must be nil or an integer", -24)
    return
  end
  if CloseAfterRender ~= nil and type(CloseAfterRender) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "CloseAfterRender",
      "#23: must be nil or a boolean", -25)
    return
  end

  if EmbedStretchMarkers ~= nil and type(EmbedStretchMarkers) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "#24: EmbedStretchMarkers",
      "must be nil or boolean", -26)
    return
  end
  if RenderString2 ~= nil and type(RenderString2) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "RenderString2", "#25: must be nil or string",
      -27)
    return
  end
  if EmbedStretchMarkers == nil then EmbedStretchMarkers = false end
  if RenderString2 == nil then RenderString2 = "" end

  if EmbedTakeMarkers ~= nil and type(EmbedTakeMarkers) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "EmbedTakeMarkers", "#26: must be nil or boolean",
      -28)
    return
  end
  if DoNotSilentRender ~= nil and type(DoNotSilentRender) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "DoNotSilentRender",
      "#27: must be nil or boolean", -29)
    return
  end

  if EmbedMetadata ~= nil and type(EmbedMetadata) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "CloseAfterRender",
      "#28: must be nil or a boolean", -30)
    return
  end
  if Enable2ndPassRender ~= nil and type(Enable2ndPassRender) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Enable2ndPassRender",
      "#29: must be nil or a boolean", -31)
    return
  end

  if Normalize_Enabled ~= nil and type(Normalize_Enabled) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Normalize_Enabled",
      "#30: must be nil or a boolean", -32)
    return
  end
  if Normalize_Method ~= nil and math.type(Normalize_Method) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Normalize_Method",
      "#31: must be nil or a number", -33)
    return
  end
  if Normalize_Stems_to_Master_Target ~= nil and type(Normalize_Stems_to_Master_Target) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Normalize_Stems_to_Master_Target",
      "#32: must be nil or a boolean", -34)
    return
  end
  if Normalize_Target ~= nil and type(Normalize_Target) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Normalize_Target",
      "#33: must be nil or a number", -34)
    return
  end

  if Brickwall_Limiter_Enabled ~= nil and type(Brickwall_Limiter_Enabled) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Brickwall_Limiter_Enabled",
      "#34: must be nil or a boolean", -35)
    return
  end
  if Brickwall_Limiter_Method ~= nil and math.type(Brickwall_Limiter_Method) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Brickwall_Limiter_Method",
      "#35: must be nil or an integer", -36)
    return
  end
  if Brickwall_Limiter_Target ~= nil and type(Brickwall_Limiter_Target) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Brickwall_Limiter_Target",
      "#36: must be nil or a number", -37)
    return
  end

  if Normalize_Only_Files_Too_Loud ~= nil and type(Normalize_Only_Files_Too_Loud) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "Normalize_Only_Files_Too_Loud",
      "#37: must be nil or boolean", -38)
    return
  end

  if FadeIn_Enabled ~= nil and type(FadeIn_Enabled) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "FadeIn_Enabled", "#38: must be nil or boolean",
      -39)
    return
  end
  if FadeIn ~= nil and type(FadeIn) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "FadeIn", "#39: must be nil or a number", -40)
    return
  end
  if FadeIn_Shape ~= nil and math.type(FadeIn_Shape) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "FadeIn_Shape", "#40: must be nil or an integer",
      -41)
    return
  end
  if FadeOut_Enabled ~= nil and type(FadeOut_Enabled) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "FadeOut_Enabled", "#41: must be nil or boolean",
      -42)
    return
  end
  if FadeOut ~= nil and type(FadeOut) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "FadeOut", "#42: must be nil or a number", -43)
    return
  end
  if FadeOut_Shape ~= nil and math.type(FadeOut_Shape) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "FadeOut_Shape", "#43: must be nil or an integer",
      -44)
    return
  end

  if OnlyChannelsSentToParent ~= nil and type(OnlyChannelsSentToParent) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "OnlyChannelsSentToParent",
      "#44: must be nil or a boolean", -45)
    return
  end
  if RenderStems_Prefader ~= nil and type(RenderStems_Prefader) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateNewRenderTable", "RenderStems_Prefader",
      "#45: must be nil or a boolean", -46)
    return
  end

  local RenderTable = {}
  RenderTable["AddToProj"] = false
  RenderTable["Bounds"] = 1
  RenderTable["Channels"] = 2
  RenderTable["CloseAfterRender"] = true
  RenderTable["Dither"] = 0
  RenderTable["EmbedMetaData"] = false
  RenderTable["EmbedStretchMarkers"] = false
  RenderTable["EmbedTakeMarkers"] = false
  RenderTable["Endposition"] = 0
  RenderTable["MultiChannelFiles"] = false
  RenderTable["NoSilentRender"] = false
  RenderTable["OfflineOnlineRendering"] = 0
  RenderTable["OnlyMonoMedia"] = false
  RenderTable["ProjectSampleRateFXProcessing"] = true
  RenderTable["RenderFile"] = ""
  RenderTable["RenderPattern"] = ""
  RenderTable["RenderQueueDelay"] = false
  RenderTable["RenderQueueDelaySeconds"] = 0
  RenderTable["RenderResample"] = 3
  RenderTable["RenderString"] = "ZXZhdw=="
  RenderTable["RenderString2"] = ""
  RenderTable["RenderTable"] = true
  RenderTable["SampleRate"] = 44100
  RenderTable["SaveCopyOfProject"] = false
  RenderTable["SilentlyIncrementFilename"] = true
  RenderTable["Source"] = 0
  RenderTable["Startposition"] = 0
  RenderTable["TailFlag"] = 18
  RenderTable["TailMS"] = 0
  RenderTable["Enable2ndPassRender"] = false
  RenderTable["Normalize_Enabled"] = false
  RenderTable["Normalize_Method"] = 0
  RenderTable["Normalize_Stems_to_Master_Target"] = false
  RenderTable["Normalize_Target"] = -24
  RenderTable["Brickwall_Limiter_Enabled"] = false
  RenderTable["Brickwall_Limiter_Method"] = 1
  RenderTable["Brickwall_Limiter_Target"] = 1
  RenderTable["Normalize_Only_Files_Too_Loud"] = false
  RenderTable["FadeIn_Enabled"] = false
  RenderTable["FadeIn"] = 0
  RenderTable["FadeIn_Shape"] = 0
  RenderTable["FadeOut_Enabled"] = false
  RenderTable["FadeOut"] = 0
  RenderTable["FadeOut_Shape"] = 0
  RenderTable["OnlyChannelsSentToParent"] = false
  RenderTable["RenderStems_Prefader"] = false

  if AddToProj ~= nil then RenderTable["AddToProj"] = AddToProj end
  if Bounds ~= nil then RenderTable["Bounds"] = Bounds end
  if Channels ~= nil then RenderTable["Channels"] = Channels end
  if CloseAfterRender ~= nil then RenderTable["CloseAfterRender"] = CloseAfterRender end
  if Dither ~= nil then RenderTable["Dither"] = Dither end
  if EmbedMetadata ~= nil then RenderTable["EmbedMetaData"] = EmbedMetadata end
  if EmbedStretchMarkers ~= nil then RenderTable["EmbedStretchMarkers"] = EmbedStretchMarkers end
  if EmbedTakeMarkers ~= nil then RenderTable["EmbedTakeMarkers"] = EmbedTakeMarkers end
  if Endposition ~= nil then RenderTable["Endposition"] = Endposition end
  if MultiChannelFiles ~= nil then RenderTable["MultiChannelFiles"] = MultiChannelFiles end
  if OfflineOnlineRendering ~= nil then RenderTable["OfflineOnlineRendering"] = OfflineOnlineRendering end
  if OnlyMonoMedia ~= nil then RenderTable["OnlyMonoMedia"] = OnlyMonoMedia end
  if ProjectSampleRateFXProcessing ~= nil then RenderTable["ProjectSampleRateFXProcessing"] =
    ProjectSampleRateFXProcessing end
  if RenderFile ~= nil then RenderTable["RenderFile"] = RenderFile end
  if RenderPattern ~= nil then RenderTable["RenderPattern"] = RenderPattern end
  if RenderQueueDelaySeconds ~= nil then RenderTable["RenderQueueDelaySeconds"] = RenderQueueDelaySeconds end
  if RenderQueueDelay ~= nil then RenderTable["RenderQueueDelay"] = RenderQueueDelay end
  if RenderResample ~= nil then RenderTable["RenderResample"] = RenderResample end
  if RenderString2 ~= nil then RenderTable["RenderString2"] = RenderString2 end
  if RenderString ~= nil then RenderTable["RenderString"] = RenderString end
  if SampleRate ~= nil then RenderTable["SampleRate"] = SampleRate end
  if SaveCopyOfProject ~= nil then RenderTable["SaveCopyOfProject"] = SaveCopyOfProject end
  if DoNotSilentRender ~= nil then RenderTable["NoSilentRender"] = DoNotSilentRender end
  if SilentlyIncrementFilename ~= nil then RenderTable["SilentlyIncrementFilename"] = SilentlyIncrementFilename end
  if Source ~= nil then RenderTable["Source"] = Source end
  if Startposition ~= nil then RenderTable["Startposition"] = Startposition end
  if TailFlag ~= nil then RenderTable["TailFlag"] = TailFlag end
  if TailMS ~= nil then RenderTable["TailMS"] = TailMS end
  if Enable2ndPassRender ~= nil then RenderTable["Enable2ndPassRender"] = Enable2ndPassRender end
  if Normalize_Enabled ~= nil then RenderTable["Normalize_Enabled"] = Normalize_Enabled end
  if Normalize_Method ~= nil then RenderTable["Normalize_Method"] = Normalize_Method end
  if Normalize_Stems_to_Master_Target ~= nil then RenderTable["Normalize_Stems_to_Master_Target"] =
    Normalize_Stems_to_Master_Target end
  if Normalize_Target ~= nil then RenderTable["Normalize_Target"] = Normalize_Target end
  if Brickwall_Limiter_Enabled ~= nil then RenderTable["Brickwall_Limiter_Enabled"] = Brickwall_Limiter_Enabled end
  if Brickwall_Limiter_Method ~= nil then RenderTable["Brickwall_Limiter_Method"] = Brickwall_Limiter_Method end
  if Brickwall_Limiter_Target ~= nil then RenderTable["Brickwall_Limiter_Target"] = Brickwall_Limiter_Target end

  if Normalize_Only_Files_Too_Loud ~= nil then RenderTable["Normalize_Only_Files_Too_Loud"] =
    Normalize_Only_Files_Too_Loud end
  if FadeIn_Enabled ~= nil then RenderTable["FadeIn_Enabled"] = FadeIn_Enabled end
  if FadeIn ~= nil then RenderTable["FadeIn"] = FadeIn end
  if FadeIn_Shape ~= nil then RenderTable["FadeIn_Shape"] = FadeIn_Shape end
  if FadeOut_Enabled ~= nil then RenderTable["FadeOut_Enabled"] = FadeOut_Enabled end
  if FadeOut ~= nil then RenderTable["FadeOut"] = FadeOut end
  if FadeOut_Shape ~= nil then RenderTable["FadeOut_Shape"] = FadeOut_Shape end

  return RenderTable
end

function ApplyRenderTable_Project(RenderTable, apply_rendercfg_string, dirtyness)

  if IsValidRenderTable(RenderTable) == false then
    Error_Message(debug.getinfo(1).currentline, "ApplyRenderTable_Project", "RenderTable", "not a valid RenderTable", -1)
    return false
  end
  if dirtyness == true then
    local RenderTable2 = GetRenderTable_Project()
    if AreRenderTablesEqual(RenderTable, RenderTable2) == true then return true, false end
  end

  if apply_rendercfg_string ~= nil and type(apply_rendercfg_string) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "ApplyRenderTable_Project", "apply_rendercfg_string", "must be boolean",
      -2)
    return false
  end
  local _temp, retval, hwnd, AddToProj, ProjectSampleRateFXProcessing, ReaProject, SaveCopyOfProject, retval
  if ReaProject == nil then ReaProject = 0 end
  local Source = RenderTable["Source"]

  if RenderTable["EmbedStretchMarkers"] == true then
    if Source & 256 == 0 then Source = Source + 256 end
  else
    if Source & 256 ~= 0 then Source = Source - 256 end
  end

  if RenderTable["EmbedMetaData"] == true then
    if Source & 512 == 0 then Source = Source + 512 end
  else
    if Source & 512 ~= 0 then Source = Source - 512 end
  end

  if RenderTable["EmbedTakeMarkers"] == true then
    if Source & 1024 == 0 then Source = Source + 1024 end
  else
    if Source & 1024 ~= 0 then Source = Source - 1024 end
  end

  if RenderTable["Enable2ndPassRender"] == true then
    if Source & 2048 == 0 then Source = Source + 2048 end
  else
    if Source & 2048 ~= 0 then Source = Source - 2048 end
  end

  if RenderTable["RenderStems_Prefader"] == true then
    if Source & 8192 == 0 then Source = Source + 8192 end
  else
    if Source & 8192 ~= 0 then Source = Source - 8192 end
  end

  if RenderTable["OnlyChannelsSentToParent"] == true then
    if Source & 16384 == 0 then Source = Source + 16384 end
  else
    if Source & 16384 ~= 0 then Source = Source - 16384 end
  end

  if RenderTable["MultiChannelFiles"] == true and Source & 4 == 0 then
    Source = Source + 4
  elseif RenderTable["MultiChannelFiles"] == false and Source & 4 == 4 then
    Source = Source - 4
  end

  if RenderTable["OnlyMonoMedia"] == true and Source & 16 == 0 then
    Source = Source + 16
  elseif RenderTable["OnlyMonoMedia"] == false and Source & 16 == 16 then
    Source = Source - 16
  end

  local normalize_method = RenderTable["Normalize_Method"]
  normalize_method = normalize_method * 2
  local normalize_target = DB2MKVOL(RenderTable["Normalize_Target"])
  if RenderTable["Normalize_Enabled"] == true and normalize_method & 1 == 0 then normalize_method = normalize_method + 1 end
  if RenderTable["Normalize_Enabled"] == false and normalize_method & 1 == 1 then normalize_method = normalize_method - 1 end

  if RenderTable["Normalize_Only_Files_Too_Loud"] == true and normalize_method & 256 == 0 then normalize_method =
    normalize_method + 256 end
  if RenderTable["Normalize_Only_Files_Too_Loud"] == false and normalize_method & 256 == 1 then normalize_method =
    normalize_method - 256 end

  if RenderTable["Normalize_Stems_to_Master_Target"] == true and normalize_method & 32 == 0 then normalize_method =
    normalize_method + 32 end
  if RenderTable["Normalize_Stems_to_Master_Target"] == false and normalize_method & 32 == 32 then normalize_method =
    normalize_method - 32 end

  if RenderTable["Brickwall_Limiter_Enabled"] == true and normalize_method & 64 == 0 then normalize_method =
    normalize_method + 64 end
  if RenderTable["Brickwall_Limiter_Enabled"] == false and normalize_method & 64 == 64 then normalize_method =
    normalize_method - 64 end

  if RenderTable["Brickwall_Limiter_Method"] == 2 and normalize_method & 128 == 0 then normalize_method =
    normalize_method + 128 end
  if RenderTable["Brickwall_Limiter_Method"] == 1 and normalize_method & 128 == 128 then normalize_method =
    normalize_method - 128 end

  if RenderTable["FadeIn_Enabled"] == true and normalize_method & 512 == 0 then normalize_method = normalize_method + 512 end
  if RenderTable["FadeOut_Enabled"] == true and normalize_method & 1024 == 0 then normalize_method = normalize_method +
    1024 end

  reaper.GetSetProjectInfo_String(ReaProject, "RENDER_FILE", RenderTable["RenderFile"], true)
  reaper.GetSetProjectInfo_String(ReaProject, "RENDER_PATTERN", RenderTable["RenderPattern"], true)
  if apply_rendercfg_string ~= false then
    reaper.GetSetProjectInfo_String(ReaProject, "RENDER_FORMAT", RenderTable["RenderString"], true)
    reaper.GetSetProjectInfo_String(ReaProject, "RENDER_FORMAT2", RenderTable["RenderString2"], true)
  end

  reaper.GetSetProjectInfo(ReaProject, "RENDER_FADEIN", RenderTable["FadeIn"], true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_FADEOUT", RenderTable["FadeOut"], true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_FADEINSHAPE", RenderTable["FadeIn_Shape"], true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_FADEOUTSHAPE", RenderTable["FadeOut_Shape"], true)

  reaper.GetSetProjectInfo(0, "RENDER_BRICKWALL", DB2MKVOL(RenderTable["Brickwall_Limiter_Target"]), true)

  reaper.GetSetProjectInfo(ReaProject, "RENDER_NORMALIZE", normalize_method, true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_NORMALIZE_TARGET", normalize_target, true)

  reaper.GetSetProjectInfo(ReaProject, "RENDER_SETTINGS", Source, true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_BOUNDSFLAG", RenderTable["Bounds"], true)

  reaper.GetSetProjectInfo(ReaProject, "RENDER_CHANNELS", RenderTable["Channels"], true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_SRATE", RenderTable["SampleRate"], true)

  reaper.GetSetProjectInfo(ReaProject, "RENDER_STARTPOS", RenderTable["Startposition"], true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_ENDPOS", RenderTable["Endposition"], true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_TAILFLAG", RenderTable["TailFlag"], true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_TAILMS", RenderTable["TailMS"], true)

  if RenderTable["AddToProj"] == true then AddToProj = 1 else AddToProj = 0 end
  if RenderTable["NoSilentRender"] == true then AddToProj = AddToProj + 2 end

  reaper.GetSetProjectInfo(ReaProject, "RENDER_ADDTOPROJ", AddToProj, true)
  reaper.GetSetProjectInfo(ReaProject, "RENDER_DITHER", RenderTable["Dither"], true)

  SetRender_ProjectSampleRateForMix(RenderTable["ProjectSampleRateFXProcessing"])
  SetRender_AutoIncrementFilename(RenderTable["SilentlyIncrementFilename"])
  SetRender_QueueDelay(RenderTable["RenderQueueDelay"], RenderTable["RenderQueueDelaySeconds"])
  SetRender_ResampleMode(RenderTable["RenderResample"])
  SetRender_OfflineOnlineMode(RenderTable["OfflineOnlineRendering"])

  if RenderTable["RenderFile"] == nil then RenderTable["RenderFile"] = "" end
  if RenderTable["RenderPattern"] == nil then
    local path, filename = GetPath(RenderTable["RenderFile"])
    if filename:match(".*(%.).") ~= nil then
      RenderTable["RenderPattern"] = filename:match("(.*)%.")
      RenderTable["RenderFile"] = string.gsub(path, "\\\\", "\\")
    else
      RenderTable["RenderPattern"] = filename
      RenderTable["RenderFile"] = string.gsub(path, "\\\\", "\\")
    end
  end

  if RenderTable["SaveCopyOfProject"] == true then SaveCopyOfProject = 1 else SaveCopyOfProject = 0 end
  hwnd = GetRenderToFileHWND()
  if hwnd == nil then
    retval = reaper.BR_Win32_WritePrivateProfileString("REAPER", "autosaveonrender2", SaveCopyOfProject,
      reaper.get_ini_file())
  else
    reaper.JS_WindowMessage_Send(reaper.JS_Window_FindChildByID(hwnd, 1060), "BM_SETCHECK", SaveCopyOfProject, 0, 0, 0)
  end

  if reaper.SNM_GetIntConfigVar("renderclosewhendone", -199) & 1 == 0 and RenderTable["CloseAfterRender"] == true then
    local temp = reaper.SNM_GetIntConfigVar("renderclosewhendone", -199) + 1
    reaper.SNM_SetIntConfigVar("renderclosewhendone", temp)
  elseif reaper.SNM_GetIntConfigVar("renderclosewhendone", -199) & 1 == 1 and RenderTable["CloseAfterRender"] == false then
    local temp = reaper.SNM_GetIntConfigVar("renderclosewhendone", -199) - 1
    reaper.SNM_SetIntConfigVar("renderclosewhendone", temp)
  end
  if dirtyness == true then
    reaper.MarkProjectDirty(0)
    return true, true
  end
  return true, false
end

function GetRenderPreset_Names()

  local Output_Preset_Counter = 0
  local Output_Preset = {}
  local Preset_Counter = 0
  local Preset = {}
  local Presetname, Presetname2, Quote

  local A = ReadFullFile(reaper.GetResourcePath() .. "/reaper-render.ini")
  if A == nil then A = "" end
  for A in string.gmatch(A, "(RENDERPRESET_OUTPUT .-)\n") do
    Quote = A:sub(21, 21)
    if Quote == "\"" then
      Presetname2 = A:match(" [\"](.-)[\"]")
    else
      Quote = ""
      Presetname2 = A:match("%s(.-)%s")
    end
    Output_Preset_Counter = Output_Preset_Counter + 1
    Output_Preset[Output_Preset_Counter] = Presetname2
  end

  for A2 in string.gmatch(A, "<RENDERPRESET.->") do
    Quote = A2:sub(15, 15)
    if Quote == "\"" then
      Presetname = A2:match(" [\"](.-)[\"]")
    else
      Quote = ""
      Presetname = A2:match("%s(.-)%s")
    end
    Preset_Counter = Preset_Counter + 1
    Preset[Preset_Counter] = Presetname
  end

  local duplicate_count, duplicate_array = GetDuplicatesFromArrays(Preset, Output_Preset)
  return Output_Preset_Counter, Output_Preset, Preset_Counter, Preset, duplicate_count, duplicate_array
end

function AddRenderPreset(Bounds_Name, Options_and_Format_Name, RenderTable)

  if Bounds_Name == nil and Options_and_Format_Name == nil then
    Error_Message(debug.getinfo(1).currentline, "AddRenderPreset", "RenderTable/Options_and_Format_Name",
      "can't be both set to nil", -6)
    return false
  end
  if IsValidRenderTable(RenderTable) == false then
    Error_Message(debug.getinfo(1).currentline, "AddRenderPreset", "RenderTable", "must be a valid render-table", -1)
    return false
  end
  if Bounds_Name ~= nil and type(Bounds_Name) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "AddRenderPreset", "Bounds_Name", "must be a string", -2)
    return false
  end
  if Options_and_Format_Name ~= nil and type(Options_and_Format_Name) ~= "string" then
    Error_Message(debug.getinfo(1).currentline, "AddRenderPreset", "Options_and_Format_Name", "must be a string", -3)
    return false
  end

  local A, B, Source, RenderPattern, ProjectSampleRateFXProcessing, String, String2, Checkboxes
  local A = ReadFullFile(reaper.GetResourcePath() .. "/reaper-render.ini")
  if A == nil then A = "" end

  local CheckBoxes = 0
  if RenderTable["MultiChannelFiles"] == true then CheckBoxes = CheckBoxes + 4 end
  if RenderTable["OnlyMonoMedia"] == true then CheckBoxes = CheckBoxes + 16 end
  if RenderTable["EmbedStretchMarkers"] == true then CheckBoxes = CheckBoxes + 256 end
  if RenderTable["EmbedMetaData"] == true then CheckBoxes = CheckBoxes + 512 end
  if RenderTable["EmbedTakeMarkers"] == true then CheckBoxes = CheckBoxes + 1024 end
  if RenderTable["Enable2ndPassRender"] == true then CheckBoxes = CheckBoxes + 2048 end
  if RenderTable["RenderStems_Prefader"] == true then CheckBoxes = CheckBoxes + 8192 end
  if RenderTable["OnlyChannelsSentToParent"] == true then CheckBoxes = CheckBoxes + 16384 end

  if RenderTable["ProjectSampleRateFXProcessing"] == true then ProjectSampleRateFXProcessing = 1 else ProjectSampleRateFXProcessing = 0 end
  if RenderTable["RenderPattern"] == "" or RenderTable["RenderPattern"]:match("%s") ~= nil then
    RenderPattern = "\"" .. RenderTable["RenderPattern"] .. "\""
  else
    RenderPattern = RenderTable["RenderPattern"]
  end

  if Bounds_Name ~= nil and (Bounds_Name:match("%s") ~= nil or Bounds_Name == "") then Bounds_Name = "\"" ..
    Bounds_Name .. "\"" end
  if Options_and_Format_Name ~= nil and (Options_and_Format_Name:match("%s") ~= nil or Options_and_Format_Name == "") then Options_and_Format_Name =
    "\"" .. Options_and_Format_Name .. "\"" end

  if Bounds_Name ~= nil and ("\n" .. A):match("\nRENDERPRESET_OUTPUT " .. Bounds_Name) ~= nil then
    Error_Message(debug.getinfo(1).currentline, "AddRenderPreset", "Bounds_Name", "bounds-preset already exists", -4)
    return false
  end
  if Options_and_Format_Name ~= nil and ("\n" .. A):match("\n<RENDERPRESET " .. Options_and_Format_Name) ~= nil then
    Error_Message(debug.getinfo(1).currentline, "AddRenderPreset", "Options_and_Format_Name",
      "renderformat/options-preset already exists", -5)
    return false
  end

  if RenderPattern:match("%s") and RenderPattern:match("\"") == nil then RenderPattern = "\"" .. RenderPattern .. "\"" end
  if Options_and_Format_Name:match("%s") and Options_and_Format_Name:match("\"") == nil then Options_and_Format_Name =
    "\"" .. Options_and_Format_Name .. "\"" end
  if Bounds_Name:match("%s") and Bounds_Name:match("\"") == nil then Bounds_Name = "\"" .. Bounds_Name .. "\"" end

  if Bounds_Name ~= nil then
    String = "\nRENDERPRESET_OUTPUT " .. Bounds_Name .. " " .. RenderTable["Bounds"] ..
        " " .. RenderTable["Startposition"] ..
        " " .. RenderTable["Endposition"] ..
        " " .. RenderTable["Source"] ..
        " " .. "0" ..
        " " .. RenderPattern ..
        " " .. RenderTable["TailFlag"] ..
        " \"" .. RenderTable["RenderFile"] .. "\" " ..
        RenderTable["TailMS"] .. "\n"
    A = A .. String
  end

  if Options_and_Format_Name ~= nil then
    String = "<RENDERPRESET " .. Options_and_Format_Name ..
        " " .. RenderTable["SampleRate"] ..
        " " .. RenderTable["Channels"] ..
        " " .. RenderTable["OfflineOnlineRendering"] ..
        " " .. ProjectSampleRateFXProcessing ..
        " " .. RenderTable["RenderResample"] ..
        " " .. RenderTable["Dither"] ..
        " " .. CheckBoxes ..
        "\n  " .. RenderTable["RenderString"] .. "\n>"

    if RenderTable["RenderString2"] ~= "" then
      String2 = "\n<RENDERPRESET2 " .. Options_and_Format_Name ..
          "\n  " .. RenderTable["RenderString2"] .. "\n>"
    else
      String2 = ""
    end
    local normalize_method = RenderTable["Normalize_Method"] * 2
    if RenderTable["Normalize_Enabled"] == true then normalize_method = normalize_method + 1 end
    if RenderTable["Normalize_Stems_to_Master_Target"] == true then normalize_method = normalize_method + 32 end
    if RenderTable["Brickwall_Limiter_Enabled"] == true then normalize_method = normalize_method + 64 end
    if RenderTable["Brickwall_Limiter_Method"] == 2 then normalize_method = normalize_method + 128 end
    if RenderTable["Normalize_Only_Files_Too_Loud"] == true then normalize_method = normalize_method + 256 end
    local brickwall_target = DB2MKVOL(RenderTable["Brickwall_Limiter_Target"])
    local normalize_target = DB2MKVOL(RenderTable["Normalize_Target"])

    local String3 = "\nRENDERPRESET_EXT " ..
    Options_and_Format_Name ..
    " " ..
    normalize_method ..
    " " ..
    normalize_target ..
    " " ..
    brickwall_target ..
    " " ..
    RenderTable["FadeIn"] ..
    " " .. RenderTable["FadeOut"] .. " " .. RenderTable["FadeIn_Shape"] .. " " .. RenderTable["FadeOut_Shape"]
    A = A .. String .. String2 .. String3
  end

  local AA = WriteValueToFile(reaper.GetResourcePath() .. "/reaper-render.ini", A)
  if A == -1 then
    Error_Message(debug.getinfo(1).currentline, "AddRenderPreset", "",
      "can't access " .. reaper.GetResourcePath() .. "/reaper-render.ini", -7)
    return false
  end
  return true
end

function CreateRenderCFG_WAV(BitDepth, LargeFiles, BWFChunk, IncludeMarkers, EmbedProjectTempo)

  if math.type(BitDepth) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "BitDepth", "Must be an integer.", -1)
    return nil
  end
  if math.type(LargeFiles) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "LargeFiles", "Must be an integer.", -2)
    return nil
  end
  if math.type(BWFChunk) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "BWFChunk", "Must be an integer.", -3)
    return nil
  end
  if math.type(IncludeMarkers) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "IncludeMarkers", "Must be an integer.", -4)
    return nil
  end
  if type(EmbedProjectTempo) ~= "boolean" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "EmbedProjectTempo", "Must be a boolean.", -5)
    return nil
  end

  if BitDepth < 0 or BitDepth > 8 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "Bitdepth", "Must be between 0 and 8.", -6)
    return nil
  end
  if LargeFiles < 0 or LargeFiles > 4 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "LargeFiles", "Must be between 0 and 4.", -7)
    return nil
  end
  if BWFChunk < 0 or BWFChunk > 3 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "BWFChunk", "Must be between 0 and 3.", -8)
    return nil
  end
  if IncludeMarkers < 0 or IncludeMarkers > 6 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_WAV", "IncludeMarkers", "Must be between 0 and 6.", -9)
    return nil
  end

  local WavHeader = "ZXZhd"
  local A0, A, B, C

  if BitDepth == 0 then
    BitDepth = "w"
    A0 = "g"
  elseif BitDepth == 1 then
    BitDepth = "x"
    A0 = "A"
  elseif BitDepth == 2 then
    BitDepth = "x"
    A0 = "g"
  elseif BitDepth == 3 then
    BitDepth = "y"
    A0 = "A"
  elseif BitDepth == 7 then
    BitDepth = "y"
    A0 = "E"
  elseif BitDepth == 4 then
    BitDepth = "0"
    A0 = "A"
  elseif BitDepth == 5 then
    BitDepth = "w"
    A0 = "Q"
  elseif BitDepth == 6 then
    BitDepth = "w"
    A0 = "I"
  elseif BitDepth == 8 then
    BitDepth = "w"
    A0 = "4"
  else
    return nil
  end

  if LargeFiles == 0 then
    A = "B"
    B = "A"
    C = "A"
  elseif LargeFiles == 1 then
    A = "B"
    B = "A"
    C = "Q"
  elseif LargeFiles == 2 then
    A = "D"
    B = "A"
    C = "A"
  elseif LargeFiles == 3 then
    A = "B"
    B = "A"
    C = "g"
  elseif LargeFiles == 4 then
    A = "B"
    B = "A"
    C = "w"
  else
    return nil
  end

  if BWFChunk == 0 then
  elseif BWFChunk == 1 then
    A = AddIntToChar(A, -1)
  elseif BWFChunk == 2 then
    A = AddIntToChar(A, 4)
  elseif BWFChunk == 3 then
    A = AddIntToChar(A, -1 + 4)
  end

  if IncludeMarkers == 0 then
  elseif IncludeMarkers == 1 then
    A = AddIntToChar(A, 8)
  elseif IncludeMarkers == 2 then
    A = AddIntToChar(A, 30)
  elseif IncludeMarkers == 3 then
    A0 = AddIntToChar(A0, 1)
    A = AddIntToChar(A, 8)
  elseif IncludeMarkers == 4 then
    A0 = AddIntToChar(A0, 1)
    A = AddIntToChar(A, 30)
  elseif IncludeMarkers == 5 then
    A0 = AddIntToChar(A0, 2)
    A = AddIntToChar(A, 8)
  elseif IncludeMarkers == 6 then
    A0 = AddIntToChar(A0, 2)
    A = AddIntToChar(A, 30)
  end

  if EmbedProjectTempo == true and IncludeMarkers < 2 then
    A = AddIntToChar(A, 38)
  elseif EmbedProjectTempo == true and IncludeMarkers == 2 then
    A = AddIntToChar(A, -43)
  elseif EmbedProjectTempo == true and IncludeMarkers == 3 then
    A = AddIntToChar(A, 38)
  elseif EmbedProjectTempo == true and IncludeMarkers == 4 then
    A = AddIntToChar(A, -43)
  elseif EmbedProjectTempo == true and IncludeMarkers == 5 then
    A = AddIntToChar(A, 38)
  elseif EmbedProjectTempo == true and IncludeMarkers == 6 then
    A = AddIntToChar(A, -43)
  end

  local WavEnder = "=="
  return WavHeader .. BitDepth .. A0 .. A .. B .. C .. WavEnder
end

function CreateRenderCFG_OGG(Mode, VBR_Quality, CBR_KBPS, ABR_KBPS, ABR_KBPS_MIN, ABR_KBPS_MAX)

  local ini_file = reaper.GetExtState("AMAPP", "lib_path") .. "util/init/double_to_int_2.ini"
  if reaper.file_exists(ini_file) == false then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "Ooops",
      "external render-code-ini-file does not exist. Reinstall Ultraschall-API again, please!", -1)
    return nil
  end
  if math.type(Mode) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "Kbps", "Must be an integer!", -2)
    return nil
  end
  if type(VBR_Quality) ~= "number" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "VBR_Quality", "Must be a float!", -3)
    return nil
  end
  if math.type(CBR_KBPS) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "CBR_KBPS", "Must be an integer!", -4)
    return nil
  end
  if math.type(ABR_KBPS) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "ABR_KBPS", "Must be an integer!", -5)
    return nil
  end
  if math.type(ABR_KBPS_MIN) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "ABR_KBPS_MIN", "Must be an integer!", -6)
    return nil
  end
  if math.type(ABR_KBPS_MAX) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "ABR_KBPS_MAX", "Must be an integer!", -7)
    return nil
  end
  if Mode < 0 or Mode > 2 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "Mode", "must be between 0 and 2", -8)
    return nil
  end
  if VBR_Quality < 0 or LimitFractionOfFloat(VBR_Quality, 2) > 1.0 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "VBR_Quality",
      "must be a float-value between 0 and 1", -9)
    return nil
  end
  if CBR_KBPS < 0 or CBR_KBPS > 2147483647 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "CBR_KBPS", "must be between 0 and 2048", -10)
    return nil
  end
  if ABR_KBPS < 0 or ABR_KBPS > 2147483647 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "ABR_KBPS", "must be between 0 and 2048", -11)
    return nil
  end
  if ABR_KBPS_MIN < 0 or ABR_KBPS_MIN > 2147483647 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "ABR_KBPS_MIN", "must be between 0 and 2048", -12)
    return nil
  end
  if ABR_KBPS_MAX < 0 or ABR_KBPS_MAX > 2147483647 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_OGG", "ABR_KBPS_MAX", "must be between 0 and 2048", -13)
    return nil
  end

  local RenderString
  VBR_Quality = VBR_Quality + 0.0
  VBR_Quality = ConvertIntegerIntoString2(4, DoubleToInt(VBR_Quality))
  CBR_KBPS = ConvertIntegerIntoString2(4, CBR_KBPS)
  ABR_KBPS = ConvertIntegerIntoString2(4, ABR_KBPS)
  ABR_KBPS_MIN = ConvertIntegerIntoString2(4, ABR_KBPS_MIN)
  ABR_KBPS_MAX = ConvertIntegerIntoString2(4, ABR_KBPS_MAX)

  local EncodeChannelAudio = 0
  if channel_audio == true then EncodeChannelAudio = EncodeChannelAudio + 1 end
  if per_channel == true then EncodeChannelAudio = EncodeChannelAudio + 2 end

  RenderString = "vggo" .. VBR_Quality .. string.char(Mode) .. CBR_KBPS .. ABR_KBPS .. ABR_KBPS_MIN .. ABR_KBPS_MAX ..
  "\0"

  return Base64_Encoder(RenderString)
end

function CreateRenderCFG_FLAC(BitDepth, CompressionLevel)

  if math.type(BitDepth) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_FLAC", "BitDepth", "Must be an integer.", -1)
    return nil
  end
  if math.type(CompressionLevel) ~= "integer" then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_FLAC", "CompressionLevel", "Must be an integer.", -2)
    return nil
  end
  if BitDepth < 0 or BitDepth > 1 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_FLAC", "BitDepth", "Must be 0 (16-bit) or 1 (24-bit).", -3)
    return nil
  end
  if CompressionLevel < 0 or CompressionLevel > 8 then
    Error_Message(debug.getinfo(1).currentline, "CreateRenderCFG_FLAC", "CompressionLevel", "Must be between 0 and 8.", -4)
    return nil
  end

  local RenderString = "calf" .. string.char(BitDepth) .. string.char(CompressionLevel)

  return Base64_Encoder(RenderString)
end

function ResolvePresetName(bounds_name, options_and_formats_name, both_name)

   if bounds_name~=nil and type(bounds_name)~="string" then Error_Message("ResolvePresetName", "bounds_name", "must be a string", -1) return end
   if options_and_formats_name~=nil and type(options_and_formats_name)~="string" then Error_Message("ResolvePresetName", "options_and_formats_name", "must be a string", -2) return end
   if both_name~=nil and type(both_name)~="string" then Error_Message("ResolvePresetName", "both_name", "must be a string", -3) return end
   local bounds_presets, bounds_names, options_format_presets, options_format_names, both_presets, both_names = GetRenderPreset_Names()
   local foundbounds=nil
   local found_options=nil
   local found_both=nil

   if bounds_name~=nil then
     for i=1, #bounds_names do
       if bounds_name:lower()==bounds_names[i]:lower() then foundbounds=bounds_names[i] break end
     end
   end
   if options_and_formats_name~=nil then
     for i=1, #options_format_names do
       if options_and_formats_name:lower()==options_format_names[i]:lower() then found_options=options_format_names[i] break end
     end
   end
   if both_name~=nil then
     for i=1, #both_names do
       if both_names ~= nil and both_name:lower()==both_names[i]:lower() then found_both=both_names[i] break end
     end
   end
   return foundbounds, found_options, found_both
 end

function SetRenderPreset(Bounds_Name, Options_and_Format_Name, RenderTable)

   if Bounds_Name==nil and Options_and_Format_Name==nil then Error_Message("SetRenderPreset", "RenderTable/Options_and_Format_Name", "can't be both set to nil", -6) return false end
   if IsValidRenderTable(RenderTable)==false then Error_Message("SetRenderPreset", "RenderTable", "must be a valid render-table", -1) return false end
   if Bounds_Name~=nil and type(Bounds_Name)~="string" then Error_Message("SetRenderPreset", "Bounds_Name", "must be a string", -2) return false end
   if Options_and_Format_Name~=nil and type(Options_and_Format_Name)~="string" then Error_Message("SetRenderPreset", "Options_and_Format_Name", "must be a string", -3) return false end

   if Bounds_Name:match("%s") then Bounds_Name="\""..Bounds_Name.."\"" end
   if Options_and_Format_Name:match("%s") then Options_and_Format_Name="\""..Options_and_Format_Name.."\"" end
   local A,B, Source, RenderPattern, ProjectSampleRateFXProcessing, String, Bounds, RenderFormatOptions
   local A=ReadFullFile(reaper.GetResourcePath().."/reaper-render.ini")
   if A==nil then A="" end
   Bounds_Name, Options_and_Format_Name=ResolvePresetName(Bounds_Name, Options_and_Format_Name)
   if Bounds_Name==nil then Error_Message("SetRenderPreset", "Bounds_Name", "no bounds-preset with that name", -4) return false end
   if Options_and_Format_Name==nil then Error_Message("SetRenderPreset", "Options_and_Format_Name", "no renderformat/options-preset with that name", -5) return false end

   Source=RenderTable["Source"]
   local MonoMultichannelEmbed=0
   local CheckBoxes=0
   if RenderTable["MultiChannelFiles"]==true then MonoMultichannelEmbed=MonoMultichannelEmbed+4 end
   if RenderTable["OnlyMonoMedia"]==true then MonoMultichannelEmbed=MonoMultichannelEmbed+16 end
   if RenderTable["EmbedStretchMarkers"]==true then MonoMultichannelEmbed=MonoMultichannelEmbed+256 end
   if RenderTable["EmbedMetaData"]==true then CheckBoxes=CheckBoxes+512 end
   if RenderTable["EmbedTakeMarkers"]==true then MonoMultichannelEmbed=MonoMultichannelEmbed+1024 end
   if RenderTable["Enable2ndPassRender"]==true then MonoMultichannelEmbed=MonoMultichannelEmbed+2048 end
   if RenderTable["RenderStems_Prefader"]==true then CheckBoxes=CheckBoxes+8192 end
   if RenderTable["OnlyChannelsSentToParent"]==true then CheckBoxes=CheckBoxes+16384 end

   if RenderTable["Preserve_Start_Offset"]==true then CheckBoxes=CheckBoxes+65536 end
   if RenderTable["Preserve_Metadata"]==true then CheckBoxes=CheckBoxes+32768 end

   if RenderTable["ProjectSampleRateFXProcessing"]==true then ProjectSampleRateFXProcessing=1 else ProjectSampleRateFXProcessing=0 end
   if RenderTable["RenderPattern"]=="" or RenderTable["RenderPattern"]:match("%s")~=nil then
     RenderPattern="\""..RenderTable["RenderPattern"].."\""
   else
     RenderPattern=RenderTable["RenderPattern"]
   end

   if Bounds_Name~=nil then
     Bounds=("\n"..A):match("(\nRENDERPRESET_OUTPUT "..Bounds_Name..".-\n)")
     Bounds = EscapeMagicCharacters_String(Bounds)

     String="\nRENDERPRESET_OUTPUT "..Bounds_Name.." "..RenderTable["Bounds"]..
            " "..RenderTable["Startposition"]..
            " "..RenderTable["Endposition"]..
            " "..Source..
            " ".."0"..
            " "..RenderPattern..
            " "..RenderTable["TailFlag"]..
            " \""..RenderTable["RenderFile"].."\" "..
            RenderTable["TailMS"].."\n"

     A=string.gsub(A, Bounds, String)
   end

   if Options_and_Format_Name~=nil then
       RenderFormatOptions=A:match("<RENDERPRESET "..Options_and_Format_Name..".->")
       String="<RENDERPRESET "..Options_and_Format_Name..
              " "..RenderTable["SampleRate"]..
              " "..RenderTable["Channels"]..
              " "..RenderTable["OfflineOnlineRendering"]..
              " "..ProjectSampleRateFXProcessing..
              " "..RenderTable["RenderResample"]..
              " "..RenderTable["Dither"]..
              " "..CheckBoxes..
              "\n  "..RenderTable["RenderString"].."\n>"
     RenderFormatOptions = EscapeMagicCharacters_String(RenderFormatOptions)
     A=string.gsub(A, RenderFormatOptions, String)

     if RenderTable["RenderString2"]~="" then
       RenderFormatOptions=A:match("<RENDERPRESET2 "..Options_and_Format_Name..".->")
       String="<RENDERPRESET2 "..Options_and_Format_Name..
              "\n  "..RenderTable["RenderString2"].."\n>"
       if RenderFormatOptions~=nil then
         RenderFormatOptions = EscapeMagicCharacters_String(RenderFormatOptions)
         A=string.gsub(A, RenderFormatOptions, String)
       else
         A=A.."\n"..String
       end
     else
       RenderFormatOptions=A:match("<RENDERPRESET2 "..Options_and_Format_Name..".->")
       if RenderFormatOptions~=nil then
         RenderFormatOptions = EscapeMagicCharacters_String(RenderFormatOptions)
         A=string.gsub(A, RenderFormatOptions, "")
       end
     end

       local normalize_method=RenderTable["Normalize_Method"]*2
       if RenderTable["Normalize_Enabled"]==true then normalize_method=normalize_method+1 end
       if RenderTable["Normalize_Stems_to_Master_Target"]==true then normalize_method=normalize_method+32 end
       if RenderTable["Brickwall_Limiter_Enabled"]==true then normalize_method=normalize_method+64 end
       if RenderTable["Brickwall_Limiter_Method"]==2 then normalize_method=normalize_method+128 end
       if RenderTable["Normalize_Only_Files_Too_Loud"]==true then normalize_method=normalize_method+256 end

       local brickwall_target=DB2MKVOL(RenderTable["Brickwall_Limiter_Target"])
       local normalize_target=DB2MKVOL(RenderTable["Normalize_Target"])
       local String3="\nRENDERPRESET_EXT "..Options_and_Format_Name.." "..normalize_method.." "..normalize_target.. " "..brickwall_target.." "..RenderTable["FadeIn"].." "..RenderTable["FadeOut"].." "..RenderTable["FadeIn_Shape"].." "..RenderTable["FadeOut_Shape"]
       A=A.."\n"
       local RenderNormalization=A:match("\nRENDERPRESET_EXT "..Options_and_Format_Name..".-\n")

       if RenderNormalization~=nil then
         RenderNormalization=EscapeMagicCharacters_String(RenderNormalization)
         A=string.gsub(A, RenderNormalization, String3.."\n"):sub(1,-2)
       else
         A=A:sub(1,-2)
         A=A..String3
       end
   end

   local AA=WriteValueToFile(reaper.GetResourcePath().."/reaper-render.ini", A)
   if A==-1 then Error_Message("SetRenderPreset", "", "can't access "..reaper.GetResourcePath().."/reaper-render.ini", -7) return false end
   return true

 end

function DeleteRenderPreset_Bounds(Bounds_Name)

   if type(Bounds_Name)~="string" then Error_Message("DeleteRenderPreset_Bounds", "Bounds_Name", "must be a string", -1) return false end
   local Options_and_Format_Name
   Bounds_Name, Options_and_Format_Name=ResolvePresetName(Bounds_Name, Options_and_Format_Name)
   local A,B
   local A=ReadFullFile(reaper.GetResourcePath().."/reaper-render.ini")
   if A==nil then A="" end
   if Bounds_Name ~= nil and Bounds_Name:match("%s") then Bounds_Name="\""..Bounds_Name.."\"" end
   B=string.gsub(A, "RENDERPRESET_OUTPUT "..Bounds_Name.." (.-)\n", "")
   if A==B then Error_Message("DeleteRenderPreset_Bounds", "Bounds_Name", "no such Bounds-preset", -2) return false end
   A=WriteValueToFile(reaper.GetResourcePath().."/reaper-render.ini", B)
   if A==-1 then Error_Message("DeleteRenderPreset_Bounds", "", "can't access "..reaper.GetResourcePath().."/reaper-render.ini", -3) return false end
   return true
 end

 function DeleteRenderPreset_FormatOptions(Options_and_Format_Name)

   if type(Options_and_Format_Name)~="string" then Error_Message("DeleteRenderPreset_FormatOptions", "Options_and_Format_Name", "must be a string", -1) return false end
   local Bounds_Name
   Bounds_Name, Options_and_Format_Name=ResolvePresetName(Bounds_Name, Options_and_Format_Name)
   local A,B
   local A=ReadFullFile(reaper.GetResourcePath().."/reaper-render.ini")
   if A==nil then A="" end
   if Options_and_Format_Name ~= nil and Options_and_Format_Name:match("%s") then Options_and_Format_Name="\""..Options_and_Format_Name.."\"" end
   B=string.gsub(A, "<RENDERPRESET "..Options_and_Format_Name.." (.-\n>)\n", "")
   B=string.gsub(B, "<RENDERPRESET2 "..Options_and_Format_Name.."(.-\n>)\n", "")
   B=string.gsub(B, "RENDERPRESET_EXT "..Options_and_Format_Name.." .-\n", "")

   if A==B then Error_Message("DeleteRenderPreset_FormatOptions", "Options_and_Format_Name", "no such Options and Format-preset", -2) return false end
   A=WriteValueToFile(reaper.GetResourcePath().."/reaper-render.ini", B)
   if A==-1 then Error_Message("DeleteRenderPreset_FormatOptions", "", "can't access "..reaper.GetResourcePath().."/reaper-render.ini", -3) return false end
   return true
 end

function DeleteRenderPreset_Both(Both_Name)
  if type(Both_Name)~="string" then Error_Message("DeleteRenderPreset_FormatOptions", "Both_Name", "must be a string", -1) return false end
  Bounds_Name, Options_and_Format_Name, Both_Name=ResolvePresetName(Bounds_Name, Options_and_Format_Name, Both_Name)
  local A,B
  local A=ReadFullFile(reaper.GetResourcePath().."/reaper-render.ini")
  if A==nil then A="" end
  if Both_Name ~= nil and Both_Name:match("%s") then Both_Name="\""..Both_Name.."\"" end
  if Both_Name ~= nil then Both_Name = string.gsub(Both_Name, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") end
  B=string.gsub(A, "<RENDERPRESET "..Both_Name.." (.-\n>)\n", "")
  B=string.gsub(B, "<RENDERPRESET2 "..Both_Name.."(.-\n>)\n", "")
  B=string.gsub(B, "RENDERPRESET_EXT "..Both_Name.." .-\n", "")
  B=string.gsub(B, "RENDERPRESET_OUTPUT "..Both_Name.." (.-)\n", "")
  if A==B then Error_Message("DeleteRenderPreset_FormatOptions", "Both_Name", "no such Both-preset", -4) return false end
  A=WriteValueToFile(reaper.GetResourcePath().."/reaper-render.ini", B)
  if A==-1 then Error_Message("DeleteRenderPreset_FormatOptions", "", "can't access "..reaper.GetResourcePath().."/reaper-render.ini", -3) return false end
  return true
end