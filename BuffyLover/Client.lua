local addonName, addon = ...
local engine = addon.NewEngine()
local returnEngine = addon.NewEngine()
local ready, inWorld = false, false
local generation = 0
local worldEpoch, quietUntil, settling = 0, 0, false
local lastStatus = "Waiting for world entry"
local function public(value)
    return not issecretvalue or not issecretvalue(value)
end
local function plain(value, kind)
    return public(value) and type(value) == kind
end
local function say(message)
    DEFAULT_CHAT_FRAME:AddMessage("BuffyLover! " .. message)
end
local function record(message)
    if not BuffyLoverDB then return end
    if type(BuffyLoverDB.activityLog)~="table" then BuffyLoverDB.activityLog={} end
    local log=BuffyLoverDB.activityLog
    log[#log+1]=string.format("%.1f: %s",GetTime(),message)
    while #log>30 do table.remove(log,1) end
    if BuffyLoverDB.debug then say(message) end
end
local function resultText(value)
    if not public(value) then return "restricted value" end
    if type(value)=="boolean" or type(value)=="number" or type(value)=="string" then return tostring(value):gsub("|","/"):sub(1,180) end
    return type(value)
end
local function status(message)
    if message ~= lastStatus and BuffyLoverDB.debug then say(message) end
    lastStatus = message
end
local function blocked()
    if InCombatLockdown() then return true end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local value = C_Secrets.ShouldAurasBeSecret()
        if not public(value) or value then return true end
    end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local value = C_ChatInfo.InChatMessagingLockdown()
        if not public(value) or value then return true end
    end
    return false
end
local function snapshot()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        error("Aura API unavailable")
    end
    local result = {}
    for index = 1, 256 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if not public(aura) then error("Restricted aura") end
        if aura == nil then return result end
        if not plain(aura.spellId, "number") then error("Unavailable spell") end
        if addon.buffs[aura.spellId] then
            local buff = {spell = aura.spellId}
            -- Only public expiration timestamps can establish a real refresh.
            if plain(aura.expirationTime, "number") then buff.expires = aura.expirationTime end
            local unit, unknown, casterGUID, casterName = addon.ResolveCaster(aura)
            if plain(unit, "string") and unit ~= "" then
                local player, guid, own = UnitIsPlayer(unit), UnitGUID(unit), UnitGUID("player")
                local party, raid = UnitInParty(unit), UnitInRaid(unit)
                -- Forever's second name component is a surname, not a realm.
                -- Let the client apply its native separator; never build Name-Realm.
                local name = GetUnitName(unit, true)
                if public(player) and player and plain(guid, "string") and guid ~= ""
                    and plain(own, "string") and public(party) and public(raid)
                    and plain(name, "string") and name ~= "" then
                    buff.guid, buff.self = guid, guid == own
                    buff.group = party or raid ~= nil
                    buff.unit = unit
                    buff.name = name
                end
            end
            if casterGUID and casterName then
                local group=addon.CasterGroupFromGUID(casterGUID)
                if group~=nil then
                    buff.guid,buff.name,buff.group=casterGUID,casterName,group
                    buff.byGUID=true
                end
            end
            if unknown and BuffyLoverDB.unknownThanks then
                buff.guid, buff.general = "unknown-caster", true
            end
            result[#result + 1] = buff
        end
    end
    error("Aura scan limit reached")
end
local function scan()
    if not ready or not inWorld then return end
    local ok, restricted = pcall(blocked)
    if not ok or restricted then
        generation = generation + 1
        engine:Reset(); returnEngine:Reset()
        status("Paused: combat or restricted API; next readable scan establishes baseline.")
        return
    end
    local success, buffs = pcall(snapshot)
    if not success then
        generation = generation + 1
        engine:Reset(); returnEngine:Reset()
        status("Aura snapshot unavailable; waiting for a complete baseline.")
        return
    end
    if settling then
        engine:Reset(); returnEngine:Reset()
        engine:Accept(buffs, GetTime(), BuffyLoverDB)
        returnEngine:Accept(buffs, GetTime(), {enabled=BuffyLoverDB.buffBack,group=true,cooldown=0})
        if GetTime() >= quietUntil then settling = false end
        status("Establishing buff baseline after loading; no thanks sent.")
        return
    end
    local offers = returnEngine:Accept(buffs, GetTime(), {enabled=BuffyLoverDB.buffBack,group=true,cooldown=0})
    for _, buff in ipairs(offers) do
        if buff.unit and not buff.general and addon.OfferBuffBack then addon.OfferBuffBack(buff.unit,buff.guid) end
    end
    local recipients = engine:Accept(buffs, GetTime(), BuffyLoverDB)
    status("Watching recognised buffs; caster fallbacks enabled.")
    for _, buff in ipairs(recipients) do
        local queuedGeneration = generation
        local function respond()
            if generation ~= queuedGeneration or not inWorld or not BuffyLoverDB.enabled then return end
            -- Revalidate the token immediately before output. Never change target.
            local sent, attempted = pcall(function()
                if blocked() then return end
                if buff.general then
                    -- Explicit 'none' avoids directing the fallback at the current target.
                    C_ChatInfo.PerformEmote("THANK", "none", false)
                    return true
                end
                local name,party,raid
                if buff.byGUID then
                    name=addon.CasterNameFromGUID(buff.guid)
                    party=addon.CasterGroupFromGUID(buff.guid)
                    if not name or name~=buff.name or party==nil then return end
                else
                    local guid=UnitGUID(buff.unit)
                    if not plain(guid,"string") or guid~=buff.guid then return end
                    name=GetUnitName(buff.unit,true)
                    if not plain(name,"string") or name=="" or name~=buff.name then return end
                    party,raid=UnitInParty(buff.unit),UnitInRaid(buff.unit)
                    if not public(party) or not public(raid) then return end
                end
                if not BuffyLoverDB.group and (party or raid~=nil) then return end
                local replies = addon.PlanResponses(BuffyLoverDB, addon.CharacterTraits(), name)
                if #replies==0 then return end
                for _,reply in ipairs(replies) do
                    -- Each channel gets one attempt; a failed channel must not
                    -- cause retry loops or suppress the other in Both mode.
                    local ok,result=pcall(function()
                        if blocked() then return "Skipped: messaging restricted" end
                        if reply.mode == "emote" then
                            return C_ChatInfo.PerformEmote(reply.text, name, false)
                        elseif reply.mode == "rp" then
                            local inside=IsInInstance and IsInInstance()
                            if not public(inside) or not inside then
                                addon.OfferManualReply(buff.guid,name,reply.text,function()
                                    if generation~=queuedGeneration or not inWorld or not BuffyLoverDB.enabled or blocked() then return false end
                                    local current,group
                                    if buff.byGUID then
                                        current=addon.CasterNameFromGUID(buff.guid)
                                        group=addon.CasterGroupFromGUID(buff.guid)
                                        if group==nil then return false end
                                    else
                                        local guid=UnitGUID(buff.unit)
                                        if not plain(guid,"string") or guid~=buff.guid then return false end
                                        current=GetUnitName(buff.unit,true)
                                        local party,raid=UnitInParty(buff.unit),UnitInRaid(buff.unit)
                                        if not public(party) or not public(raid) then return false end
                                        group=party or raid~=nil
                                    end
                                    return plain(current,"string") and current==name and (BuffyLoverDB.group or not group)
                                end,record)
                                return "Waiting for your click (custom RP outdoors)"
                            end
                            return C_ChatInfo.SendChatMessage(reply.text, "EMOTE")
                        elseif reply.mode == "whisper" then
                            return C_ChatInfo.SendChatMessage(reply.text, "WHISPER", nil, name)
                        end
                    end)
                    record(reply.mode.." to "..name..": "..reply.text.."; "..(ok and "API returned " or "API error: ")..resultText(result)..". Delivery unconfirmed.")
                    if not ok then status("Response channel failed; no retry will be made.") end
                end
                return true
            end)
            if not sent then status("Response attempt failed; no retry will be made.")
            elseif BuffyLoverDB.debug then
                if attempted and buff.general then say("Attempted general THANK; delivery is not confirmed by the API.")
                elseif not attempted then say("Skipped response: caster identity changed or output is restricted.") end
            end
        end
        if BuffyLoverDB.delay > 0 then C_Timer.After(BuffyLoverDB.delay, respond) else respond() end
    end
end
function addon.ConfigurationChanged()
    if addon.ClearManualReplies then addon.ClearManualReplies() end
    if addon.RefreshBuffBack then addon.RefreshBuffBack(true) end
    if addon.GivingCancel then addon.GivingCancel() end
    generation = generation + 1
    engine:Reset(); returnEngine:Reset()
    scan()
end
local function initialize()
    if type(BuffyLoverDB) ~= "table" then BuffyLoverDB = {} end
    for key, value in pairs({enabled = true, group = false, debug = false, giving = true, givingSound = true, unknownThanks = true}) do
        if type(BuffyLoverDB[key]) ~= "boolean" then BuffyLoverDB[key] = value end
    end
    local cooldown = BuffyLoverDB.cooldown
    if type(cooldown) ~= "number" or cooldown ~= cooldown or cooldown < 0 or cooldown > 2000 then
        cooldown = 60
    end
    BuffyLoverDB.cooldown = math.floor(cooldown)
    addon.InitResponses(BuffyLoverDB)
    addon.InitGivingStyle(BuffyLoverDB)
    if addon.InitBuffBack then addon.InitBuffBack(BuffyLoverDB) end
    ready = true
    addon.CreateSettings()
end
SLASH_BUFFYLOVER1 = "/buffy"
SlashCmdList.BUFFYLOVER = function(input)
    if not ready then return end
    local command, argument = input:lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "" or command == "settings" then addon.OpenSettings(); return end
    if command == "log" then
        local log=BuffyLoverDB.activityLog or {}
        say("Recent activity (API return values do not confirm delivery):")
        for _,line in ipairs(log) do say(line) end
        if #log==0 then say("No recorded activity yet.") end
        return
    end
    if command == "giving" then say("Lifetime players buffed: "..addon.GivingCount()); return end
    generation = generation + 1
    if command == "on" or command == "off" then
        BuffyLoverDB.enabled = command == "on"
        engine:Reset(); returnEngine:Reset()
        scan()
    elseif command == "debug" then
        BuffyLoverDB.debug = not BuffyLoverDB.debug
    elseif command == "group" and (argument == "on" or argument == "off") then
        BuffyLoverDB.group = argument == "on"
    elseif command == "cooldown" then
        local number = tonumber(argument)
        if not number or number ~= number or number < 0 or number > 2000 then
            say("Use /buffy cooldown 0-2000"); return
        end
        BuffyLoverDB.cooldown = math.floor(number)
    elseif command ~= "status" then
        say("/buffy on | off | status | debug | cooldown 0-2000 | group on/off")
        return
    end
    say("enabled=" .. tostring(BuffyLoverDB.enabled) .. "; cooldown=" .. BuffyLoverDB.cooldown
        .. "s; group=" .. tostring(BuffyLoverDB.group) .. "; debug=" .. tostring(BuffyLoverDB.debug)
        .. ". " .. lastStatus)
    if addon.GetBuffBackStatus then say("Buff back: "..addon.GetBuffBackStatus()) end
end
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit, action)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        record(event..": addon="..resultText(unit).."; action="..resultText(action))
    elseif event == "ADDON_LOADED" then
        if unit == addonName then initialize() end
    elseif event == "PLAYER_LEAVING_WORLD" or event == "LOADING_SCREEN_ENABLED" then
        generation = generation + 1
        worldEpoch = worldEpoch + 1
        if addon.ClearManualReplies then addon.ClearManualReplies() end
        inWorld = false; engine:Reset(); returnEngine:Reset()
    elseif event == "PLAYER_ENTERING_WORLD" then
        generation = generation + 1
        worldEpoch = worldEpoch + 1
        local epoch = worldEpoch
        quietUntil, settling = GetTime() + 5, true
        inWorld = true; engine:Reset(); returnEngine:Reset(); scan()
        C_Timer.After(5, function()
            if inWorld and worldEpoch == epoch then scan() end
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if addon.ClearManualReplies then addon.ClearManualReplies() end
        generation = generation + 1
        engine:Reset(); returnEngine:Reset()
    elseif event == "PLAYER_REGEN_ENABLED" then
        scan()
    elseif event == "UNIT_AURA" and public(unit) and unit == "player" then
        scan()
    end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
    "LOADING_SCREEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN"}) do events:RegisterEvent(event) end
events:RegisterUnitEvent("UNIT_AURA", "player")
