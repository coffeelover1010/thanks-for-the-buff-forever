local _, addon = ...
addon.emotes = {THANK=true, BOW=true, SALUTE=true, CHEER=true, WAVE=true, NOD=true, APPLAUD=true}
addon.defaults = {
    emote = "THANK\nBOW\nSALUTE",
    rp = "bows gratefully to {name}.\nraises a hand in thanks to {name}.",
    whisper = "Thank you for the buff, {name}!\nYour kindness is appreciated, {name}.",
}
function addon.ValidateLines(text, mode)
    if type(text) ~= "string" or #text > 8000 then return nil, "Use at most 8,000 bytes per list." end
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            if #line > 255 or line:find("[%c|]") then return nil, "Lines must be plain text, at most 255 bytes." end
            if mode == "emote" then
                line = line:upper()
                if not addon.emotes[line] then return nil, "Emotes: THANK, BOW, SALUTE, CHEER, WAVE, NOD, APPLAUD." end
            else
                local rest = line:gsub("{name}", "")
                if rest:find("[{}]") then return nil, "Only the {name} placeholder is supported." end
            end
            lines[#lines+1] = line
        end
    end
    return lines
end
function addon.InitResponses(db)
    -- Retire settings from the removed typing protection feature.
    db.waitWhileTyping, db.typingWaitSeconds = nil, nil
    if db.mode ~= "emote" and db.mode ~= "rp" and db.mode ~= "whisper"
        and db.mode ~= "rp_first" and db.mode ~= "emote_first" and db.mode ~= "both" then db.mode = "emote" end
    if db.responseStrategy==nil then
        db.sendEmote=db.mode=="emote" or db.mode=="both" or db.mode=="rp_first" or db.mode=="emote_first"
        db.sendRP=db.mode=="rp" or db.mode=="both" or db.mode=="rp_first" or db.mode=="emote_first"
        db.sendWhisper=db.mode=="whisper"
        db.responseStrategy=db.mode=="both" and "all" or "priority"
        db.responseOrder=(db.mode=="rp_first" or db.mode=="both" or db.mode=="rp")
            and "rp,emote,whisper" or "emote,rp,whisper"
        if db.mode=="rp_first" or db.mode=="both" then db.responseOrder="rp,emote,whisper" end
    end
    for _,key in ipairs({"sendEmote","sendRP","sendWhisper"}) do
        if type(db[key])~="boolean" then db[key]=false end
    end
    if db.responseStrategy~="all" and db.responseStrategy~="random" and db.responseStrategy~="priority" then db.responseStrategy="priority" end
    local validOrders={ ["emote,rp,whisper"]=true,["emote,whisper,rp"]=true,["rp,emote,whisper"]=true,
        ["rp,whisper,emote"]=true,["whisper,emote,rp"]=true,["whisper,rp,emote"]=true }
    if not validOrders[db.responseOrder] then db.responseOrder="emote,rp,whisper" end
    if type(db.random) ~= "boolean" then db.random = false end
    if type(db.delay) ~= "number" or db.delay ~= db.delay or db.delay < 0 or db.delay > 40 then db.delay = 0 end
    if type(db.rules) ~= "table" then db.rules = {} end
    if type(db.replies) ~= "table" then db.replies = {} end
    for mode, value in pairs(addon.defaults) do
        if not addon.ValidateLines(db.replies[mode], mode) then db.replies[mode] = value end
    end
end
local function public(v) return not issecretvalue or not issecretvalue(v) end
function addon.CharacterTraits()
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local gender = UnitSex("player")
    return {class=public(class) and class or nil, race=public(race) and race or nil,
        gender=public(gender) and gender or nil}
end
-- Rules describe the responding character, not the buff giver.
-- Most specific matching rule wins; ties use the first row.
function addon.SelectResponse(db, traits, name, random, selectedMode)
    local mode = selectedMode or db.mode
    local text, score, source = db.replies[mode], -1, 0
    for index, rule in ipairs(db.rules) do
        if type(rule) == "table" and rule.mode == mode then
            local matches, weight = true, 0
            for _, key in ipairs({"class", "race", "gender"}) do
                if rule[key] ~= "ANY" then
                    weight = weight + 1
                    if traits[key] == nil or rule[key] ~= traits[key] then matches = false end
                end
            end
            if matches and weight > score and addon.ValidateLines(rule.text, mode) then
                text, score, source = rule.text, weight, index
            end
        end
    end
    local lines, issue = addon.ValidateLines(text, mode)
    if not lines or #lines == 0 then return nil, issue or "The matching reply list is empty.", source end
    local reply = lines[db.random and (random or math.random)(#lines) or 1]
    reply = reply:gsub("{name}", function() return name end)
    if #reply > 255 or reply:find("[%c|]") then return nil, "Expanded reply exceeds the plain-text limit." end
    return reply, mode, source
end
function addon.EditResponseMode(mode)
    if mode=="rp_first" or mode=="both" then return "rp" end
    if mode=="emote_first" then return "emote" end
    return mode
end
function addon.PlanResponses(db,traits,name,random)
    if db.responseStrategy then
        local enabled={emote=db.sendEmote,rp=db.sendRP,whisper=db.sendWhisper}
        local results={}
        for mode in (db.responseOrder or "emote,rp,whisper"):gmatch("[^,]+") do
            if enabled[mode] then
                local text=addon.SelectResponse(db,traits,name,random,mode)
                if text then
                    results[#results+1]={text=text,mode=mode}
                    if db.responseStrategy=="priority" then break end
                end
            end
        end
        if db.responseStrategy=="random" and #results>0 then return {results[(random or math.random)(#results)]} end
        return results
    end
    local order
    if db.mode=="rp_first" or db.mode=="both" then order={"rp","emote"}
    elseif db.mode=="emote_first" then order={"emote","rp"}
    else order={db.mode} end
    local results={}
    for _,mode in ipairs(order) do
        local text=addon.SelectResponse(db,traits,name,random,mode)
        if text then
            results[#results+1]={text=text,mode=mode}
            if db.mode~="both" then break end
        end
    end
    return results
end

function addon.ResponseSummary(db)
    local types={}
    if db.sendEmote then types[#types+1]="built-in emote" end
    if db.sendRP then types[#types+1]="RP (click outdoors)" end
    if db.sendWhisper then types[#types+1]="whisper" end
    if #types==0 then return "No response types enabled." end
    local labels={all="Send all",random="Choose one randomly",priority="First available in priority order"}
    return (labels[db.responseStrategy] or "Select responses")..": "..table.concat(types," + ")
end
