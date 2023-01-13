-- Made by: VilleOlof
-- https://github.com/VilleOlof
local _Version = "1.0.0"

local clampAllTracks = false

--Other Configs that are mostly the same as the ones in the manager script
local SaveFileName = "ZoomData.json"
local ScriptMainPath = os.getenv('APPDATA')..[[/Blackmagic Design/DaVinci Resolve/ZoomExtended/]]
ScriptMainPath = ScriptMainPath:gsub('\\','/')
local SavePath = ScriptMainPath..SaveFileName

--#DavinkiThings
local projman = resolve:GetProjectManager()
local proj = projman:GetCurrentProject()
local timeline = proj:GetCurrentTimeline()

--Function to split text with a separator,maybe move into Getcurrentframe if this is the only use-case
local function StringSplit(string, sep)
	local segments = {}

	for segment in (string .. sep):gmatch("(.-)" .. sep) do
	  segments[#segments + 1] = segment
	end

	return segments
end

--Function to calculate the current frame your timeline cursor is on
local function GetCurrentFrame()
	local Timecode = timeline:GetCurrentTimecode()
	local Segments = StringSplit(Timecode, ":")
	
	local Frame = tonumber(Segments[1])*60
	Frame = (Frame+tonumber(Segments[2]))*60
	Frame = (Frame+tonumber(Segments[3]))*timeline:GetSetting("timelineFrameRate")
	Frame = Frame+tonumber(Segments[4])+1
	
	return Frame
end

--Function for getting the clip under the timeline cursor
local function GetSelectedVideo(TrackIndex)
    timeline = proj:GetCurrentTimeline()
	local Frame = GetCurrentFrame()
	for i,clip in ipairs(timeline:GetItemListInTrack("Video", TrackIndex)) do
		if clip:GetStart() <= Frame and clip:GetEnd() >= Frame then
			return clip
		end
	end
end

--########################################
local json = {}
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
local function parse_str_val(str, pos, val)
    val = val or ''
    local early_end_error = 'End of input found while parsing string.'
    if pos > #str then error(early_end_error) end
    local c = str:sub(pos, pos)
    if c == '"'  then return val, pos + 1 end
    if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
    local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
    local nextc = str:sub(pos + 1, pos + 1)
    if not nextc then error(early_end_error) end
    return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end
local function parse_num_val(str, pos)
    local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
    local val = tonumber(num_str)
    if not val then error('Error parsing number at position ' .. pos .. '.') end
    return val, pos + #num_str
end
json.null = {}
function json.parse(str, pos, end_delim)
    pos = pos or 1
    if pos > #str then error('Reached unexpected end of input.') end
    local pos = pos + #str:match('^%s*', pos) 
    local first = str:sub(pos, pos)
    if first == '{' then 
        local obj, key, delim_found = {}, true, true
        pos = pos + 1
        while true do
        key, pos = json.parse(str, pos, '}')
        if key == nil then return obj, pos end
        if not delim_found then error('Comma missing between object items.') end
        pos = skip_delim(str, pos, ':', true) 
        obj[key], pos = json.parse(str, pos)
        pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '[' then
        local arr, val, delim_found = {}, true, true
        pos = pos + 1
        while true do
        val, pos = json.parse(str, pos, ']')
        if val == nil then return arr, pos end
        if not delim_found then error('Comma missing between array items.') end
        arr[#arr + 1] = val
        pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '"' then
        return parse_str_val(str, pos + 1)
    elseif first == '-' or first:match('%d') then 
        return parse_num_val(str, pos)
    elseif first == end_delim then  
        return nil, pos + 1
    else
        local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
        for lit_str, lit_val in pairs(literals) do
        local lit_end = pos + #lit_str - 1
        if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
        end
        local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
        error('Invalid json syntax starting at ' .. pos_info_str)
    end
end

local function JSON_Load(filePath)
    local file = io.open(filePath, "r")
    local jsonString = file:read("*a")
    file:close() 
    return json.parse(jsonString, 1)
end

--Check if number is positive or negative
local function MathSign(x)
	return x < 0 and -1 or 1
end

local AllTracks = {1,2,3,4,5,6,7,8}

local ZoomData = JSON_Load(SavePath)
local ActiveTrackSelections = ZoomData[13]

if clampAllTracks then ActiveTrackSelections = AllTracks end

for i, trackIndex in pairs(ActiveTrackSelections) do
    local trackClip = GetSelectedVideo(trackIndex)
    
    if trackClip then 
        
        --Find and calculate what must be done to keep the clip in frame
        local ZoomLevel = trackClip:GetProperty("ZoomX")
        local PanLevel = trackClip:GetProperty("Pan")
        local TiltLevel = trackClip:GetProperty("Tilt")

        local Pan = 960*(ZoomLevel-1)
        local Tilt = 540*(ZoomLevel-1)

        --Keep clip in frame on the X axis
        if math.abs(PanLevel) > Pan then
        	trackClip:SetProperty("Pan",Pan*MathSign(PanLevel))
        end

        --Keep clip in frame on the Y axis
        if math.abs(TiltLevel) > Tilt then
        	trackClip:SetProperty("Tilt",Tilt*MathSign(TiltLevel))
        end
    end
end

