local _, ns = ...
local races = {{"ANY","General fallback"},{"Human","Human"},{"Dwarf","Dwarf"},{"NightElf","Night elf"},
    {"Gnome","Gnome"},{"Orc","Orc"},{"Troll","Troll"},{"Tauren","Tauren"},{"Scourge","Undead"}}
local modes = {{"BUILTIN","Built-in emotes"},{"WHISPER","Whisper"},{"EMOTE","Custom emote"}}
local function Known(options, key)
    for _, item in ipairs(options) do if item[1] == key then return item[2] end end
end
local function Lines(text)
    if type(text) ~= "string" or #text > 8000 then return nil,"Use at most 8,000 bytes per list." end
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            if #line > 255 then return nil,"Each line must be at most 255 bytes (including accented letters)." end
            if line:find("[%c|]") then return nil,"Use plain text without control characters or | codes." end
            lines[#lines+1] = line
        end
    end
    return lines
end
local function Config()
    local db = ThanksForTheBuffForeverDB
    if type(db.messages) ~= "table" then db.messages = {} end
    return db.messages
end
function ns.SaveMessages(mode, race, text)
    if not Known(modes,mode) or not Known(races,race) then return false,"Choose a mode and race." end
    local lines, issue = Lines(text)
    if not lines then return false,issue end
    local config = Config()
    if type(config[mode]) ~= "table" then config[mode] = {} end
    config[mode][race] = table.concat(lines,"\n")
    ThanksForTheBuffForeverDB.messageMode = mode
    return true,"Saved. This mode is now active for all your characters."
end
function ns.PrepareMessage(unit, fallbackName)
    local mode = ThanksForTheBuffForeverDB.messageMode
    if mode ~= "WHISPER" and mode ~= "EMOTE" then return end
    local config = Config()[mode]
    config = type(config) == "table" and config or {}
    local race
    if UnitRace then local _, token = UnitRace("player"); race = token end
    if issecretvalue and issecretvalue(race) then race = nil end
    local pool = Lines(type(race) == "string" and config[race] or "")
    if not pool or #pool == 0 then pool = Lines(config.ANY or "") end
    if not pool or #pool == 0 then return mode,nil,nil,"No messages saved for your race or General fallback." end
    local recipient = fallbackName
    if mode == "WHISPER" and unit then
        local getter = UnitFullName or UnitName
        if getter then
            local name, realm = getter(unit)
            if (not issecretvalue or (not issecretvalue(name) and not issecretvalue(realm))) and type(name) == "string" and name ~= "" then
                recipient = type(realm) == "string" and realm ~= "" and (name .. "-" .. realm) or name
            end
        end
    end
    if mode == "WHISPER" and (type(recipient) ~= "string" or recipient == "") then
        return mode,nil,nil,"Whisper skipped: the buff giver's name is unavailable."
    end
    return mode,pool[math.random(#pool)],mode == "WHISPER" and recipient or nil
end

local window
function ns.OpenMessages()
    if window then window:Show(); return end
    window = CreateFrame("Frame","ThanksForTheBuffForeverMessages",UIParent,"BasicFrameTemplateWithInset")
    window:SetSize(610,460); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window.TitleText:SetText("Thank-you messages")
    table.insert(UISpecialFrames,"ThanksForTheBuffForeverMessages")
    local function Text(text,y)
        local label=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        label:SetPoint("TOPLEFT",20,y); label:SetWidth(565); label:SetJustifyH("LEFT"); label:SetText(text)
        return label
    end
    Text("Choose your character's race. One line is picked randomly for each thanks.",-42)
    Text("Empty race lists use General fallback. Whisper and custom-emote lists are separate.",-62)
    local mode = ThanksForTheBuffForeverDB.messageMode or "BUILTIN"
    if not Known(modes,mode) then mode = "BUILTIN" end
    local race = "ANY"
    local status = Text("Save activates the selected mode. Built-in emotes restores normal emote rules.",-404)
    local scroll = CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",24,-170); scroll:SetSize(540,180)
    local edit = CreateFrame("EditBox",nil,scroll)
    edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(535); edit:SetHeight(180)
    edit:SetAutoFocus(false); edit:SetMaxLetters(8000); scroll:SetScrollChild(edit)
    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    local function Load()
        local config = Config()[mode]
        edit:SetText(type(config)=="table" and type(config[race])=="string" and config[race] or "")
        edit:SetCursorPosition(0); scroll:SetVerticalScroll(0)
    end
    local function Dropdown(options,x,current,change)
        local field = CreateFrame("Frame",nil,window,"UIDropDownMenuTemplate")
        field:SetPoint("TOPLEFT",x,-90); UIDropDownMenu_SetWidth(field,230)
        UIDropDownMenu_SetText(field,Known(options,current()))
        UIDropDownMenu_Initialize(field,function()
            for _,item in ipairs(options) do
                local key,label=item[1],item[2]
                local info=UIDropDownMenu_CreateInfo(); info.text=label; info.checked=current()==key
                info.func=function() change(key); UIDropDownMenu_SetText(field,label); Load(); status:SetText("Selection changed. Unsaved edits discarded; Save to activate.") end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    Dropdown(modes,4,function() return mode end,function(v) mode=v end)
    Dropdown(races,290,function() return race end,function(v) race=v end)
    Text("One plain-text message per line. Custom emotes appear after your character's name.",-140)
    local save=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    save:SetSize(150,24); save:SetPoint("TOPLEFT",20,-368); save:SetText("Save and activate")
    save:SetScript("OnClick",function()
        local ok,issue=ns.SaveMessages(mode,race,edit:GetText()); status:SetText(issue)
        if ok then edit:ClearFocus(); Load() end
    end)
    Load()
end
