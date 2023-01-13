-- Made by: VilleOlof
-- https://github.com/VilleOlof
local _Version = "1.0.0"

--Main save data file name
local SaveFileName = "ZoomData.json"

--The file location where most of the script data will be saved at
local ScriptMainPath = os.getenv('APPDATA')..[[/Blackmagic Design/DaVinci Resolve/ZoomExtended/]]
ScriptMainPath = ScriptMainPath:gsub('\\','/') --corrects the backslashes incase, so you dont have to
--combines the main path and save file name
local SavePath = ScriptMainPath..SaveFileName

local ZoomIconPath = ScriptMainPath..[[ZoomManagerButtonIcons/]] --Managers Button Icon Directory
--Icons in this directory goes as follows: "UI_Zoom_Tab_Row_Column_Icon.png"
--Example: "UI_Zoom_1_1_1_Icon.png", "UI_Zoom_3_2_4_Icon.png"

local ZoomProjectPath = ScriptMainPath..[[ZoomProjectData/]] --Managers Project Tab Save Directory
--###########################################

--Amount of tabs, script is strictly based on 11, dont recommend changing as it is gonna break
local TabCount = 11
local DefaultTabIndex = 1 --Which tab the script starts on (1-TabCount)

--The gap between the zoom button icon and text
local ZoomButtonIconGap = "   "

--Only used at the start for tab index names
local TopBar_IndexToName = {}
--default tab names
for i = 1, TabCount do TopBar_IndexToName[i] = tostring(i) end

--Main ZoomData table and setup
local ZoomData = {} --   1-10 Normal tabs, 11 project tab, 12 currentTab selected, 13 current tracks selected
local function SetupZoomData()
    for i = 1, TabCount do --Tab
        ZoomData[i] = {}
        
        for j = 1, 4 do --Row

            ZoomData[i][j] = {}
            for k = 1, 4 do --Column
                ZoomData[i][j][k] = {}
                --Default Values
                ZoomData[i][j][k].ZoomData = {}
                ZoomData[i][j][k].TrackData = {1}
                ZoomData[i][j][k].ZoomName = ""
                ZoomData[i][j][k].AppendMode = false
            end
        end
        if i ~= 11 then ZoomData[i][5] = TopBar_IndexToName[i] else ZoomData[i][5] = "Project" end
    end
end
--If no project save was found it will create a new empty version
local function SetupEmptyProjectTab()
    local tmp = {}

    for j = 1, 4 do --Row
        tmp[j] = {}
        for k = 1, 4 do --Column
            tmp[j][k] = {}
            --Default Values
            tmp[j][k].ZoomData = {}
            tmp[j][k].TrackData = {1}
            tmp[j][k].ZoomName = ""
            tmp[j][k].AppendMode = false
        end
    end
    tmp[5] = "Project"

    return tmp
end
SetupZoomData()

--Decides which clip proprties it will use when getting and setting clip property values
local ClipProprtiesToSave = {
    "Yaw","Pitch",
    "AnchorPointX","AnchorPointY",
    "RotationAngle",
    "Tilt","Pan",
    "ZoomGang","ZoomX","ZoomY",
    "Opacity",
    "CropLeft","CropRight","CropTop","CropBottom","CropSoftness","CropRetain",
    "FlipX","FlipY"
}

------------------------------------------
--#DavinkiThings
local projman = resolve:GetProjectManager()
local proj = projman:GetCurrentProject()
local mediapool = proj:GetMediaPool()
local mediaStorage = resolve:GetMediaStorage()
local timeline = proj:GetCurrentTimeline()

--Ensures that there is always a timeline to calculate from:
if not timeline then mediapool:CreateEmptyTimeline("Timeline 1") end

--Project save path and project file name combined
local ProjectSave = ZoomProjectPath.."Zoom_"..proj:GetName()..".json"
-------------------------------------------
--JSON RELATED FUNCTIONS:
--https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
local json = {}
local function kind_of(obj)
    if type(obj) ~= 'table' then return type(obj) end
    local i = 1
    for _ in pairs(obj) do
      if obj[i] ~= nil then i = i + 1 else return 'table' end
    end
    if i == 1 then return 'table' else return 'array' end
  end
  local function escape_str(s)
    local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
    local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
    for i, c in ipairs(in_char) do
      s = s:gsub(c, '\\' .. out_char[i])
    end
    return s
  end
  local function skip_delim(str, pos, delim, err_if_missing)
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) ~= delim then
      if err_if_missing then
        error('Expected ' .. delim .. ' near position ' .. pos)
      end
      return pos, false
    end
    return pos + 1, true
  end
  -- Expects the given pos to be the first character after the opening quote.
  -- Returns val, pos; the returned pos is after the closing quote character.
  local function parse_str_val(str, pos, val)
    val = val or ''
    local early_end_error = 'End of input found while parsing string.'
    if pos > #str then error(early_end_error) end
    local c = str:sub(pos, pos)
    if c == '"'  then return val, pos + 1 end
    if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
    -- We must have a \ character.
    local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
    local nextc = str:sub(pos + 1, pos + 1)
    if not nextc then error(early_end_error) end
    return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
  end
  
  -- Returns val, pos; the returned pos is after the number's final character.
  local function parse_num_val(str, pos)
    local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
    local val = tonumber(num_str)
    if not val then error('Error parsing number at position ' .. pos .. '.') end
    return val, pos + #num_str
  end
function json.stringify(obj, as_key)
  local s = {}  -- We'll build the string as an array of strings to be concatenated.
  local kind = kind_of(obj)  -- This is 'array' if it's an array or type(obj) otherwise.
  if kind == 'array' then
      if as_key then error('Can\'t encode array as key.') end
      s[#s + 1] = '['
      for i, val in ipairs(obj) do
        if i > 1 then s[#s + 1] = ', ' end
        s[#s + 1] = json.stringify(val)
      end
      s[#s + 1] = ']'
    elseif kind == 'table' then
      if as_key then error('Can\'t encode table as key.') end
      s[#s + 1] = '{'
      for k, v in pairs(obj) do
        if #s > 1 then s[#s + 1] = ', ' end
        s[#s + 1] = json.stringify(k, true)
        s[#s + 1] = ':'
        s[#s + 1] = json.stringify(v)
      end
      s[#s + 1] = '}'
    elseif kind == 'string' then
      return '"' .. escape_str(obj) .. '"'
    elseif kind == 'number' then
      if as_key then return '"' .. tonumber(obj) .. '"' end
      return tonumber(obj)
    elseif kind == 'boolean' then
      return tostring(obj)
    elseif kind == 'nil' then
      return 'null'
    else
      error('Unjsonifiable type: ' .. kind .. '.')
    end
    return table.concat(s)
end
json.null = {}  -- This is a one-off table to represent the null value.
function json.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then error('Reached unexpected end of input.') end
  local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
  local first = str:sub(pos, pos)
  if first == '{' then  -- Parse an object.
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      key, pos = json.parse(str, pos, '}')
      if key == nil then return obj, pos end
      if not delim_found then error('Comma missing between object items.') end
      pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
      obj[key], pos = json.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '[' then  -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      val, pos = json.parse(str, pos, ']')
      if val == nil then return arr, pos end
      if not delim_found then error('Comma missing between array items.') end
      arr[#arr + 1] = val
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '"' then  -- Parse a string.
    return parse_str_val(str, pos + 1)
  elseif first == '-' or first:match('%d') then  -- Parse a number.
    return parse_num_val(str, pos)
  elseif first == end_delim then  -- End of an object or array.
    return nil, pos + 1
  else  -- Parse true, false, or null.
    local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
    end
    local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
    error('Invalid json syntax starting at ' .. pos_info_str)
  end
end

--Saves JSON with passed in table at desired filePath
local function JSON_Save(tbl, filePath)
    local file = io.open(filePath, "w")
    local jsonString = json.stringify(tbl,false)
    file:write(jsonString)
    file:close()
end

--Saves both the Main Save Data and the Project Data
local function SaveAll()
    --print(ProjectSave)
    JSON_Save(ZoomData, SavePath)
    JSON_Save(ZoomData[11], ProjectSave) --Project specific saving
end

--Returns a table when given the filePath where the json data is located at
local function JSON_Load(filePath)
    local file = io.open(filePath, "r")
    local jsonString = file:read("*a")
    file:close() 

    return json.parse(jsonString, 1)
end

------------------------------------
--Tries to rename the file (or dir) to its exact same name to see if the file exists
local function FileExists(file)
   local ok, err, code = os.rename(file, file)
   if not ok then
      if code == 13 then
         -- Permission denied, but it exists
         return true
      end
   end
   return ok, err
end

--Doesn't exit the loop until either the specified file exists or it reached its retry limit
local function FileTimeout(file, limit)
    local count = 0

    while true do
        local success = FileExists(file)
        if success then return true end
        count = count + 1
        if count >= limit then return false end
        bmd.wait(0.25)
    end
end

--Makes sure the scripts directory exists
if not FileExists(ScriptMainPath) then io.popen("mkdir \""..ScriptMainPath.."\"") end --Makes sure the directory exists
if not FileExists(ZoomIconPath) then io.popen("mkdir \""..ZoomIconPath.."\"") end --Makes sure the icon directory exists
if not FileExists(ZoomProjectPath) then io.popen("mkdir \""..ZoomProjectPath.."\"") end --Makes sure the project directory exists

--Makes sure the save file exists
if not FileExists(SavePath) then 
    io.popen("type nul > \""..SavePath.."\"") 
    local success = FileTimeout(SavePath,10)
    if success then 
        SaveAll()
    end
else
    ZoomData = JSON_Load(SavePath)
end

--Load in project specific data
if FileExists(ProjectSave) then
    ProjectData = JSON_Load(ProjectSave)
    ZoomData[11] = ProjectData 
else
    ZoomData[11] = SetupEmptyProjectTab()
end

--Function for getting the clip under the timeline cursor
function GetSelectedVideo(TrackIndex)
    timeline = proj:GetCurrentTimeline()
	local Frame = GetCurrentFrame()
	for i,clip in ipairs(timeline:GetItemListInTrack("Video", TrackIndex)) do
		if clip:GetStart() <= Frame and clip:GetEnd() >= Frame then
			return clip
		end
	end
end

--Function to calculate the current frame your timeline cursor is on
function GetCurrentFrame()
	local Timecode = timeline:GetCurrentTimecode()
	local Segments = StringSplit(Timecode, ":")
	
	local Frame = tonumber(Segments[1])*60
	Frame = (Frame+tonumber(Segments[2]))*60
	Frame = (Frame+tonumber(Segments[3]))*timeline:GetSetting("timelineFrameRate")
	Frame = Frame+tonumber(Segments[4])+1
	
	return Frame
end

--Function to split text with a separator,maybe move into Getcurrentframe if this is the only use-case
function StringSplit(string, sep)
	local segments = {}

	for segment in (string .. sep):gmatch("(.-)" .. sep) do
	  segments[#segments + 1] = segment
	end

	return segments
end

local function GetCurrentTabIndex(itm)
    return itm.UI_Top_TabBar:GetCurrentIndex()
end

--Zoom TAB UI Related Functions:

--Adds in the zoom element group (Button,LineEdit,XButton)
local function SubZoomGroupUI(ui, ID_Start, CurrentTab, rowIndex, ColumnIndex)
    local groupButton = ui:VGroup{
        ui:Button{
            ID = ID_Start..ColumnIndex.."__Button",
            Text = ZoomButtonIconGap..ZoomData[CurrentTab][rowIndex][ColumnIndex].ZoomName,
            Icon = ui:Icon{
                File = ZoomIconPath..ID_Start..ColumnIndex.."_Icon.png",
            },
            FixedSize = {100, 25},
        },
        ui:HGroup{
            ui:LineEdit{
                ID = ID_Start..ColumnIndex.."__LineEdit",
                PlaceholderText = CurrentTab.."."..rowIndex.."."..ColumnIndex,
                Text = ZoomData[CurrentTab][rowIndex][ColumnIndex].ZoomName,
                FixedSize = {75, 20},
            },
            ui:Button{
                ID = ID_Start..ColumnIndex.."__XButton",
                Text = "S",
                FixedSize = {20, 20},
            },
        },
    }
    return groupButton
end

--Adds in the zoom UI columns
local function ZoomTabUI(ui, CurrentTab, rowIndex)
    local ID_Start = "UI_Zoom_"..CurrentTab.."_"..rowIndex.."_"
    local ZoomTAB = ui:HGroup{
        ID = "UI_Zoom_"..CurrentTab..rowIndex,

        SubZoomGroupUI(ui, ID_Start, CurrentTab, rowIndex, 1),
        ui:HGap(5),
        SubZoomGroupUI(ui, ID_Start, CurrentTab, rowIndex, 2),
        ui:HGap(5),
        SubZoomGroupUI(ui, ID_Start, CurrentTab, rowIndex, 3),
        ui:HGap(5),
        SubZoomGroupUI(ui, ID_Start, CurrentTab, rowIndex, 4),
    }
    return ZoomTAB
end

--Adds in the zoom UI rows
local function AddZoomUI(ui,CurrentTab)
    local zoomUI = ui:VGroup{
        ID = "UI_Zoom_"..CurrentTab,

        ZoomTabUI(ui, CurrentTab, 1),
        ui:VGap(5),
        ZoomTabUI(ui, CurrentTab, 2),
        ui:VGap(5),
        ZoomTabUI(ui, CurrentTab, 3),
        ui:VGap(5),
        ZoomTabUI(ui, CurrentTab, 4),
    }
    return zoomUI
end

--Adds in track selection checkbox UI
local function AddTrackCheckboxes(ui)
    return ui:VGroup{
        ui:CheckBox{
            ID = "UI_TrackSelection_8",
            Text = "Track 8",
        },
        ui:CheckBox{
            ID = "UI_TrackSelection_7",
            Text = "Track 7",
        },
        ui:CheckBox{
            ID = "UI_TrackSelection_6",
            Text = "Track 6",
        },
        ui:CheckBox{
            ID = "UI_TrackSelection_5",
            Text = "Track 5",
        },
        ui:CheckBox{
            ID = "UI_TrackSelection_4",
            Text = "Track 4",
        },
        ui:CheckBox{
            ID = "UI_TrackSelection_3",
            Text = "Track 3",
        },
        ui:CheckBox{
            ID = "UI_TrackSelection_2",
            Text = "Track 2",
        },
        --Default enabled track selection
        ui:CheckBox{
            ID = "UI_TrackSelection_1",
            Text = "Track 1",
            Checked = true,
        },

        ui:VGap(5),
        ui:CheckBox{
            ID = "UI_Append_ClipProperty_Toggle",
            Text = "Append",
        }
    }
end
--######################

--Gets all current selected video track checkboxes which are enabled
local function GetEnabledTrackSelections(itm)
    local TrackSelections = {}

    local IDStart = "UI_TrackSelection_"
    for i = 1, 8 do
        local ID = IDStart..i

        if itm[ID].Checked then TrackSelections[i] = i end
    end

    return TrackSelections
end

--Adds all the UI elements into one window and returns it.
local function WindowElements(disp, ui)
    local width, height = 600, 300

    local win = disp:AddWindow({
        ID = 'MainWindow',
        WindowTitle ="ZoomExtended V".._Version.." | "..proj:GetName(),

        --posX, posY, width, height
        Geometry = {750, 450, width, height},
        Weight = 0,

        ui:HGroup{
            ID = "UI_Main-TrackSelection_Split",
            Weight = 0,

            ui:VGroup{
                ID = "UI_MainButtons-TabBar",

                ui:TabBar{
                    ID = "UI_Top_TabBar",
                    DrawBase = true,
                    CurrentIndex = DefaultTabIndex,
                    Weight = 0,
                },
                --The Zoom UI Stack, Each "AddZoomUI(ui)" Is One Tab "Page"
                ui:Stack{
                    ID = "UI_MainStack",
                    Weight = 1,
                    AddZoomUI(ui,1),
                    AddZoomUI(ui,2),
                    AddZoomUI(ui,3),
                    AddZoomUI(ui,4),
                    AddZoomUI(ui,5),
                    AddZoomUI(ui,6),
                    AddZoomUI(ui,7),
                    AddZoomUI(ui,8),
                    AddZoomUI(ui,9),
                    AddZoomUI(ui,10),
                    AddZoomUI(ui,11), --Project
                },
            },

            ui:VGroup{
                ID = "UI_TrackSelection",
                FixedSize = {80, height},

                ui:VGap(2),
                ui:LineEdit{
                    ID = "UI_CurrentTabName",
                    Text = TopBar_IndexToName[DefaultTabIndex],
                    FixedSize = {80, 20},
                },
                AddTrackCheckboxes(ui)
            },
        },
    })
    return win
end

--Handles UI-Element Buttons Etc.
local function WindowDynamics(win, itm, ui, disp)

    --Switches the stack "page" and changes the tab lineEdit text
    function win.On.UI_Top_TabBar.CurrentChanged(ev)
        if ev.Index ~= 10 then itm.UI_CurrentTabName.Text = ZoomData[GetCurrentTabIndex(itm) + 1][5] else itm.UI_CurrentTabName.Text = "Project" end
        
        itm.UI_MainStack.CurrentIndex = ev.Index
        if ev.Index == 10 then itm.UI_CurrentTabName.Enabled = false else itm.UI_CurrentTabName.Enabled = true end --Disables project tab renaming

        ZoomData[TabCount+1] = ev.Index+1
        SaveAll()
    end

    --saves and changes the current tab name when lineEdit changes
    function win.On.UI_CurrentTabName.TextChanged(ev)
        local currentTabIndex = GetCurrentTabIndex(itm)

        TopBar_IndexToName[currentTabIndex + 1] = itm.UI_CurrentTabName.Text
        
        itm.UI_Top_TabBar:SetTabText(currentTabIndex, TopBar_IndexToName[currentTabIndex + 1])

        ZoomData[currentTabIndex + 1][5] = itm.UI_CurrentTabName.Text
        SaveAll()
    end

    --Saves track selection in data, used for clamp external script
    local function TrackSelectionTrigger(ev, index)
        if ZoomData[TabCount+2] == nil then ZoomData[TabCount+2] = {} end

        ZoomData[TabCount+2] = GetEnabledTrackSelections(itm)
        SaveAll()
    end

    for i = 1, 8 do
        win.On["UI_TrackSelection_"..i].Clicked = function(ev)
            TrackSelectionTrigger(ev, i)
        end
    end

    --The main zoom button, this applies the clip properties if the data exists, otherwise nothing happens
    local function MainZoomButton(ev, tab,row,column )
        if ZoomData[tab][row][column].ZoomData ~= nil then
            --Data exists, now zoooooom
            local Data = ZoomData[tab][row][column].ZoomData

            for i, track in pairs(ZoomData[tab][row][column].TrackData) do
                local clip = GetSelectedVideo(track)
                if clip then
                    for i,setting in pairs(ClipProprtiesToSave) do
                        local settingNew_Value = ZoomData[tab][row][column].ZoomData[setting]
                        local settingPrev_Value = clip:GetProperty(setting)

                        --Skip non zoom number values if they are default, no point on setting the property 
                        if type(settingNew_Value) == "number" and not setting == "ZoomX" and not setting == "ZoomY" then if settingChanged_Value == 0 then goto MainZoomButton_Continue end end

                        local settingChanged_Value = nil

                        if type(settingNew_Value) == "number" and ZoomData[tab][row][column].AppendMode then

                            if clip:GetProperty("ZoomGang") and setting == "ZoomX" then
                                settingChanged_Value = settingPrev_Value + (settingNew_Value - 1)
                            elseif clip:GetProperty("ZoomGang") and setting == "ZoomY" then
                            else settingChanged_Value = settingPrev_Value + (settingNew_Value) end

                        else settingChanged_Value = settingNew_Value end

                        clip:SetProperty(setting, settingChanged_Value)
                        ::MainZoomButton_Continue::
                    end
                end
            end
        end
    end --now thats a lot of ends

    --This changes the zoom buttons text upon TextChanged, also saves the zoom name
    local function MainZoomLineEdit(ev, tab,row,column, ColumnNameStart)
        --change the zoom button text
        local ButtonID = ColumnNameStart.."__Button"
        local LineEditID = ColumnNameStart.."__LineEdit"

        if itm[ButtonID].Icon == nil then
            itm[ButtonID].Text = itm[LineEditID].Text
        else
            itm[ButtonID].Text = ZoomButtonIconGap..itm[LineEditID].Text
        end
        ZoomData[tab][row][column].ZoomName = itm[LineEditID].Text

        SaveAll()
    end

    --Sets the current zoom button clip properties to the current clip properties
    local function MainZoomX_Button(ev, tab,row,column )
        --reset the zoomData or reset and ask directly for new data
        ZoomData[tab][row][column].TrackData = GetEnabledTrackSelections(itm)
        ZoomData[tab][row][column].AppendMode = itm.UI_Append_ClipProperty_Toggle.Checked

        for i, track in pairs(ZoomData[tab][row][column].TrackData) do
            local clip = GetSelectedVideo(track)
            if not clip then return end

            for i,setting in pairs(ClipProprtiesToSave) do
                ZoomData[tab][row][column].ZoomData[setting] = clip:GetProperty(setting)
            end
        end

        SaveAll()
    end

    --Adds all the event functions for the zoom UI itself
    --Tabs
    for i = 1, TabCount do
        local MainTabNameStart = "UI_Zoom_"..i
        --Rows
        for j = 1, 4 do 
            local RowNameStart = MainTabNameStart.."_"..j
            --Column
            for k = 1, 4 do
                local ColumnNameStart = RowNameStart.."_"..k

                win.On[ColumnNameStart.."__Button"].Clicked = function(ev)
                    MainZoomButton(ev, i,j,k )
                end

                win.On[ColumnNameStart.."__LineEdit"].TextChanged = function(ev)
                    MainZoomLineEdit(ev, i,j,k, ColumnNameStart)
                end

                win.On[ColumnNameStart.."__XButton"].Clicked = function(ev)
                    MainZoomX_Button(ev, i,j,k )
                end
            end
        end
    end
end

--Main UI Function
local function UIMain()
    --UI Setup
    local ui = fu.UIManager
    local disp = bmd.UIDispatcher(ui)

    --Creates All The UI Elements
    local win = WindowElements(disp, ui)
    local itm = win:GetItems()

    --Adds all the tab and their respective ID > name
    for i = 1, TabCount do 
        if i ~= 11 then
            itm.UI_Top_TabBar:AddTab(ZoomData[i][5]) 
        else
            itm.UI_Top_TabBar:AddTab("Project")
        end
    end
    
    --Stack begins at index 0 (first tab)
    itm.UI_MainStack.CurrentIndex = 0
    --fix the tab names
    itm.UI_CurrentTabName.Text = ZoomData[GetCurrentTabIndex(itm) + 1][5]
    
    --Close The Window
    function win.On.MainWindow.Close(ev)
        SaveAll()
    	disp:ExitLoop()
    end

    -- Handles all the element events
    WindowDynamics(win, itm, ui, disp)

    win:Show()
    disp:RunLoop()
    win:Hide()

    --Does something?
    collectgarbage()
end

--Basically the main function
UIMain()