local addonName, ns = ...
local frame = CreateFrame("Frame")
local seen, cooldowns = {}, {}
local ready, baseline, active = false, true, false
local quietUntil, lastThanks = 0, nil
local pendingThanks, thanksGeneration = {}, 0
local function SafeText(value)
    if issecretvalue and issecretvalue(value) then return "<restricted>" end
    if type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" then return type(value) end
    return tostring(value):sub(1,400)
end
local function Log(event, ...)
    local db = ThanksForTheBuffForeverDB
    if not db or db.logging == false then return end
    if type(db.log) ~= "table" then db.log = {} end
    local parts = {}
    for i=1,select("#",...) do parts[i] = SafeText(select(i,...)) end
    local stamp = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime())
    db.log[#db.log+1] = stamp .. " [" .. event .. "] " .. table.concat(parts," | ")
    while #db.log > 400 do table.remove(db.log,1) end
end
ns.Log = Log
local function CancelThanks()
    local count = 0; for _ in pairs(pendingThanks) do count=count+1 end
    if count > 0 then Log("CANCEL", "pending", count) end
    pendingThanks = {}
    thanksGeneration = thanksGeneration + 1
end
local lastIssue = "none"
local detectionStatus = "Waiting for a new helpful buff."
local thanksStatus = "No thanks queued."
local backStatus = "No buff-back offer yet."
local emotes = { "THANK", "CHEER", "BOW", "SALUTE", "APPLAUD", "WAVE", "NOD", "KISS", "DANCE" }
local allowed = { RANDOM=true }
for _, token in ipairs(emotes) do allowed[token] = true end
local function ParseExtras(text)
    local lookup, list, used = {}, {}, {}
    for _, token in ipairs(emotes) do lookup[token:lower()] = token end
    for i=1,1000 do
        local token = _G["EMOTE"..i.."_TOKEN"]
        if type(token) == "string" then
            lookup[token:lower()] = token
            for j=1,20 do
                local command = _G["EMOTE"..i.."_CMD"..j]
                if type(command) == "string" then lookup[command:lower():gsub("^/", "")] = token end
            end
        end
    end
    for part in text:gmatch("[^,]+") do
        local command = part:match("^%s*(.-)%s*$"):lower():gsub("^/", "")
        if command ~= "" then
            local token = lookup[command]
            if not token then return nil, "Unknown emote: " .. command end
            if not used[token] then list[#list+1] = token; used[token] = true end
        end
    end
    return list
end
ns.ParseEmotes = ParseExtras
function ns.SetExtraEmotes(text)
    if type(text) ~= "string" or #text>500 then return false, "Use up to 500 characters." end
    local list, issue = ParseExtras(text)
    if not list then return false, issue end
    local commands = {}
    for part in text:gmatch("[^,]+") do
        local command = part:match("^%s*(.-)%s*$"):lower():gsub("^/", "")
        if command ~= "" then commands[#commands+1] = "/" .. command end
    end
    ThanksForTheBuffForeverDB.extraEmoteText = table.concat(commands, ", ")
    ThanksForTheBuffForeverDB.extraEmotes = list
    return true, "Saved. Extra emotes are included when Random is on."
end

local function Public(value)
    return not issecretvalue or not issecretvalue(value)
end

local function PlainString(value)
    return Public(value) and type(value) == "string" and value ~= ""
end

-- Unknown sources are common for consumables and system effects. Only use the
-- general-thanks fallback for recognised buffs that players can give others.
local function KnownGift(name, spellId)
    for _, id in ipairs(ns.buffIDs or {}) do
        if Public(spellId) and spellId == id then return true end
        local getter = C_Spell and C_Spell.GetSpellName or GetSpellInfo
        if getter then
            local ok, knownName = pcall(getter, id)
            if ok and PlainString(knownName) and knownName == name then return true end
        end
    end
    return false
end

local function Message(text)
    print("|cff80d0ffThanks for the Buff Forever:|r " .. text)
end

-- GetTime() is the start time of the current frame, so it is stale at
-- PLAYER_ENTERING_WORLD after a loading screen and jumps forward on the next
-- frame. Time the quiet windows with a clock read at call time instead.
local function Clock()
    if type(GetTimePreciseSec) == "function" then return GetTimePreciseSec() end
    return GetTime()
end

-- Seconds of slack between a buff landing and the scan that sees it.
local FRESH_SLACK = 5

-- A buff someone has just cast has (nearly) its full duration left. A buff
-- carried over from the last session, or one that loaded late after a loading
-- screen, has already run down and must not be thanked as new.
local function JustApplied(aura, now)
    local duration, expiry = aura.duration, aura.expirationTime
    if not Public(duration) or type(duration) ~= "number" or duration <= 0 then return true end
    if not Public(expiry) or type(expiry) ~= "number" or expiry <= 0 then return true end
    return expiry - now >= duration - FRESH_SLACK
end

local function GetAura(index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        return C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
    elseif UnitBuff then
        local name, _, _, _, duration, expirationTime, source, _, _, spellId = UnitBuff("player", index)
        if not Public(name) then return {} end
        if not name then return nil end
        return { name=name, sourceUnit=source, spellId=spellId, duration=duration, expirationTime=expirationTime }
    end
    lastIssue = "No supported buff-reading API on this client."
    Log("API_ERROR",lastIssue)
end

local function IsGroupMember(guid)
    for i=1,40 do
        local unit = i <= 4 and ("party" .. i) or nil
        if unit then
            local other = UnitGUID(unit)
            if Public(other) and other == guid then return true end
        end
        local other = UnitGUID("raid" .. i)
        if Public(other) and other == guid then return true end
    end
    return false
end

local function ResolveCaster(source, guid)
    if not PlainString(guid) then return end
    local function Match(unit)
        if not PlainString(unit) then return false end
        local ok, current = pcall(UnitGUID, unit)
        return ok and Public(current) and current == guid
    end
    if Match(source) then return source end
    if type(UnitTokenFromGUID) == "function" then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok and Match(unit) then return unit end
    end
    for _, unit in ipairs({"player", "target", "focus", "mouseover"}) do
        if Match(unit) then return unit end
    end
    for i=1,40 do
        if i<=4 and Match("party"..i) then return "party"..i end
        if Match("raid"..i) then return "raid"..i end
        if Match("nameplate"..i) then return "nameplate"..i end
    end
end

local function AuraCaster(aura, source)
    if PlainString(source) then
        local ok, guid = pcall(UnitGUID, source)
        if ok and PlainString(guid) then return source, guid end
    end
    local id = aura.auraInstanceID
    local getter = C_UnitAuras and C_UnitAuras.GetAuraCasterGUID
    if type(getter) ~= "function" or not Public(id) or type(id) ~= "number" then return end
    local ok, guid = pcall(getter, "player", id)
    if not ok or not PlainString(guid) then
        Log("CASTER_GUID_SKIP",ok and "Unavailable or restricted caster GUID" or "Caster lookup failed")
        return
    end
    local unit = ResolveCaster(nil, guid)
    Log("CASTER_GUID",guid,"unit",unit or "unresolved")
    return unit, guid
end

local function CasterName(guid)
    if not PlainString(guid) or not guid:match("^Player%-") or type(GetPlayerInfoByGUID) ~= "function" then return end
    local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
    if not ok or not PlainString(name) or not Public(realm) then return end
    return PlainString(realm) and (name .. "-" .. realm) or name
end

local function Thank(unit, guid, now)
    local db = ThanksForTheBuffForeverDB
    local function Skip(reason)
        thanksStatus = reason; Log("THANK_SKIP",reason,guid)
    end
    if not db.enabled then Skip("Automatic thanks disabled."); return end
    if lastThanks and now-lastThanks < db.thanksInterval then Skip("Overall cooldown: " .. (db.thanksInterval-(now-lastThanks)) .. " seconds remaining."); return end
    if cooldowns[guid] and now-cooldowns[guid] < db.playerInterval then Skip("Player cooldown: " .. (db.playerInterval-(now-cooldowns[guid])) .. " seconds remaining."); return end
    if not db.group and IsGroupMember(guid) then Skip("Skipped a party or raid member."); return end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then Skip("Chat messaging is locked by the client."); return end
    -- A passing player need not have a unit token. Keep the aura's GUID and
    -- resolve its name without changing the player's current target.
    unit = ResolveCaster(unit, guid)
    local recipientName = not unit and CasterName(guid)
    local fallback = not unit and not recipientName
    if fallback and db.directThanks ~= false then
        Skip("Directed thanks skipped: the buff giver is unavailable."); return
    end
    if fallback then Log("FALLBACK","General thanks: caster unavailable.") end
    if type(DoEmote) ~= "function" then
        lastIssue = "DoEmote is unavailable on this client."; Log("API_ERROR",lastIssue)
        return
    end
    local emote, ruleIndex
    if unit and ns.RuleEmote then
        local ok, result, index = pcall(ns.RuleEmote,unit)
        if ok then emote,ruleIndex=result,index else Log("RULE_ERROR",result) end
    end
    if ruleIndex then Log("RULE_MATCH",ruleIndex,emote,unit) end
    emote = emote or db.emote
    if emote == "RANDOM" then
        local pool = {}
        for _, value in ipairs(emotes) do
            if db.randomEmotes[value] then pool[#pool+1] = value end
        end
        local included = {}
        for _, value in ipairs(pool) do included[value] = true end
        for _, value in ipairs(db.extraEmotes or {}) do
            if not included[value] then pool[#pool+1] = value; included[value] = true end
        end
        if #pool == 0 then Skip("No emotes selected."); return end
        emote = pool[math.random(#pool)]
    end
    -- Consume the cooldown even if the client rejects the emote; never retry in a loop.
    cooldowns[guid], lastThanks = now, now
    local recipient = db.directThanks ~= false and (unit or recipientName) or nil
    Log("EMOTE_REQUEST",emote,recipient or "untargeted",guid)
    local ok, issue = pcall(DoEmote, emote, recipient or "none")
    Log(ok and "EMOTE_RETURN" or "EMOTE_ERROR",ok and "Call returned; delivery not confirmed." or issue)
    thanksStatus = ok and "Emote requested; check chat for delivery." or "Client rejected the emote."
    if not ok then lastIssue = "The client blocked an emote. Try again out of combat." end
end

local function QueueThanks(unit, guid, now)
    local delay = ThanksForTheBuffForeverDB.thanksDelay
    if not ThanksForTheBuffForeverDB.enabled then Log("THANK_SKIP","Automatic thanks disabled.",guid); return end
    if pendingThanks[guid] then Log("THANK_SKIP","Already queued for this player.",guid); return end
    Log("QUEUE",unit,guid,"delay",delay)
    if delay == 0 then Thank(unit, guid, now); return end
    local generation = thanksGeneration
    pendingThanks[guid] = true
    thanksStatus = "Thanks queued for " .. delay .. " seconds after the buff."
    C_Timer.After(delay, function()
        if generation ~= thanksGeneration then return end
        pendingThanks[guid] = nil
        if ready and active and not InCombatLockdown() then
            local ok, issue = pcall(Thank,unit,guid,GetTime())
            if not ok then lastIssue = "Delayed thanks failed: " .. SafeText(issue); Log("TIMER_ERROR",issue) end
        else Log("THANK_SKIP","Timer fired while inactive or in combat.") end
    end)
end

local function Scan()
    local now = GetTime()
    local quietLeft = math.max(0,quietUntil-Clock())
    local quiet = quietLeft > 0
    local current = {}
    Log("SCAN","baseline",baseline,"quiet remaining",quietLeft)
    for index=1,255 do
        local aura = GetAura(index)
        if not Public(aura) then Log("AURA_SKIP","Restricted aura data",index); break end
        if not aura then break end
        local name, spellId, unit = aura.name, aura.spellId, aura.sourceUnit
        Log("AURA",index,name,spellId,"source",unit,"expires",aura.expirationTime,
            "filter","HELPFUL")
        -- Honorless Target is a system effect, not a gift from another player.
        -- Keep the name fallback for clients that do not expose the spell ID.
        local ignored = (Public(spellId) and (spellId == 2479 or spellId == 1283391))
            or (PlainString(name) and (name == "Honorless Target" or name == "Honourless Target" or name == "Campfire Nearby"))
        local eligible = PlainString(name) and not ignored
        if ignored then Log("AURA_SKIP","System effect",name) end
        local casterGUID
        if eligible then unit, casterGUID = AuraCaster(aura, unit) end
        local newAura = false
        if eligible then
            local auraKey = "aura:" .. name
            local expiry = aura.expirationTime
            if not Public(expiry) or type(expiry) ~= "number" then expiry = 0 end
            current[auraKey] = expiry
            newAura = not seen[auraKey] or expiry > seen[auraKey] + 0.5
            if newAura and not JustApplied(aura, now) then
                newAura = false
                Log("AURA_SKIP","Not freshly applied",name,"remaining",expiry-now,"duration",aura.duration)
            end
        end
        if eligible and not PlainString(unit) then
            detectionStatus = name .. ": the client did not provide an identifiable caster."
            Log("UNIDENTIFIED",detectionStatus)
            if newAura and not baseline and not quiet then
                local own = UnitGUID("player")
                if not PlainString(casterGUID) then
                    -- Only unidentified effects need the known-gift allowlist.
                    -- A verified player GUID works for every helpful aura,
                    -- including heals such as Renew without a visible unit.
                    if KnownGift(name, spellId) then QueueThanks(nil,"unknown-caster",now) end
                elseif Public(own) and casterGUID ~= own and casterGUID:match("^Player%-") then
                    detectionStatus = "Detected " .. name .. "; resolving giver by GUID."
                    QueueThanks(nil,casterGUID,now)
                end
            end
        end
        if eligible and PlainString(unit) then
            local isPlayer = UnitIsPlayer(unit)
            local guid, own = UnitGUID(unit), UnitGUID("player")
            Log("CASTER",unit,guid,"is player",isPlayer,"self",Public(guid) and Public(own) and guid==own)
            if not Public(isPlayer) or not isPlayer or not PlainString(guid) then
                detectionStatus = name .. ": the caster unit could not be resolved to a player."
                if not PlainString(guid) and newAura and not baseline and not quiet and KnownGift(name, spellId) then
                    QueueThanks(nil,"unknown-caster",now)
                end
            end
            if Public(isPlayer) and isPlayer and PlainString(guid) and PlainString(own) and guid ~= own then
                do -- Every helpful aura from another player is eligible.
                    local key = guid .. ":" .. name
                    local expiration = aura.expirationTime
                    if not Public(expiration) or type(expiration) ~= "number" then expiration = 0 end
                    current[key] = expiration
                    -- A recast extends the existing aura without removing it first.
                    local refreshed = seen[key] and expiration > seen[key] + 0.5
                    Log("CANDIDATE",name,guid,"previous expiry",seen[key],"refreshed",refreshed,"baseline",baseline,"quiet",quiet)
                    if not baseline and not quiet and newAura then
                        detectionStatus = "Detected " .. name .. " from another player."
                        if ns.OfferBuffBack then
                            local ok, reason = pcall(ns.OfferBuffBack, unit, guid)
                            backStatus = ok and (reason or "Offer checked.") or "Buff-back check failed."
                            Log("BUFF_BACK",ok,reason)
                        end
                        QueueThanks(unit, guid, now)
                    end
                end
            end
        end
    end
    seen, baseline = current, false
    for guid, thankedAt in pairs(cooldowns) do
        if now-thankedAt >= 3600 then cooldowns[guid] = nil end
    end
end

local function SafeScan()
    if not ready or not active then Log("SCAN_SKIP","Not ready or outside world."); return end
    if InCombatLockdown() then baseline = true; detectionStatus = "Buff detection skipped during combat."; Log("SCAN_SKIP",detectionStatus); return end
    local ok, issue = pcall(Scan)
    if not ok then
        baseline = true
        lastIssue = "Buff scan failed: " .. SafeText(issue)
        Log("SCAN_ERROR",issue)
    end
end

local function Init()
    if type(ThanksForTheBuffForeverDB) ~= "table" then ThanksForTheBuffForeverDB = {} end
    local db = ThanksForTheBuffForeverDB
    if type(db.logging) ~= "boolean" then db.logging = true end
    CancelThanks()
    for key, default in pairs({thanksDelay=2, thanksInterval=15, playerInterval=90}) do
        local value = db[key]
        if type(value) ~= "number" or value ~= value or value < 0 or value > 3600 then value = default end
        db[key] = math.floor(value)
    end
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.group) ~= "boolean" then db.group = false end
    if type(db.directThanks) ~= "boolean" then db.directThanks = true end
    if type(db.targetBuffBack) ~= "boolean" then db.targetBuffBack = true end
    if type(db.emote) ~= "string" or not allowed[db.emote] then db.emote = "THANK" end
    if type(db.randomEmotes) ~= "table" then
        db.randomEmotes = {}
        for _, value in ipairs(emotes) do db.randomEmotes[value] = true end
    end
    local count = 0
    for _, value in ipairs(emotes) do
        db.randomEmotes[value] = db.randomEmotes[value] == true
        if db.randomEmotes[value] then count = count + 1 end
    end
    if count == 0 then db.randomEmotes.THANK = true end
    if not allowed[db.singleEmote or ""] or db.singleEmote == "RANDOM" then db.singleEmote = "THANK" end
    if db.emote ~= "RANDOM" then db.singleEmote = db.emote end
    if type(db.extraEmoteText) ~= "string" then db.extraEmoteText = "" end
    if not ns.SetExtraEmotes(db.extraEmoteText) then db.extraEmotes = {} end
    if ns.InitRules then ns.InitRules() end
    ready = true
    Log("INIT","enabled",db.enabled,"group",db.group,"emote",db.emote,"delay",db.thanksDelay,"overall cooldown",db.thanksInterval,"player cooldown",db.playerInterval)
end

-- Both slash commands and the settings window use the same live settings path.
function ns.SetOption(key, value)
    if not ready then return end
    if key == "enabled" or key == "group" or key == "clickBuff" or key == "directThanks" or key == "targetBuffBack" then
        if type(value) ~= "boolean" then return end
    elseif key == "thanksDelay" or key == "thanksInterval" or key == "playerInterval" then
        if type(value) ~= "number" or value ~= value or value < 0 or value > 3600 or value ~= math.floor(value) then return end
    elseif key == "emote" then
        if not allowed[value] then return end
    else return end
    ThanksForTheBuffForeverDB[key] = value
    Log("SETTING",key,value)
    if key == "emote" and value ~= "RANDOM" then ThanksForTheBuffForeverDB.singleEmote = value end
    if key == "enabled" then CancelThanks(); baseline = true; SafeScan() end
    if key == "thanksDelay" then CancelThanks() end
    if key == "clickBuff" and ns.RefreshClickBuff then ns.RefreshClickBuff() end
    if ns.RefreshSettings then ns.RefreshSettings() end
end

function ns.ToggleEmote(value, checked)
    if not ready or not allowed[value] then return end
    local db = ThanksForTheBuffForeverDB
    if value == "RANDOM" then
        ns.SetOption("emote", checked and "RANDOM" or db.singleEmote)
    elseif db.emote ~= "RANDOM" then
        ns.SetOption("emote", value)
    else
        local count = 0
        for _, emote in ipairs(emotes) do if db.randomEmotes[emote] then count=count+1 end end
        if checked or not db.randomEmotes[value] or count > 1 then
            db.randomEmotes[value] = checked and true or false
        end
        if ns.RefreshSettings then ns.RefreshSettings() end
    end
end

frame:SetScript("OnEvent", function(_, event, unit, ...)
    Log("EVENT",event,unit)
    if event == "ADDON_LOADED" and unit == addonName then Init()
    elseif event == "UI_ERROR_MESSAGE" then
        Log("CLIENT_ERROR",unit,...)
    elseif (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") then
        Log("BLOCKED_ACTION",unit,...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        CancelThanks()
        active, baseline, quietUntil = true, true, Clock() + 5
        SafeScan()
    elseif event == "PLAYER_LEAVING_WORLD" then CancelThanks(); active, baseline = false, true
    elseif event == "PLAYER_REGEN_DISABLED" then CancelThanks(); baseline = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        baseline, quietUntil = true, Clock() + 2
        SafeScan()
    elseif event == "UNIT_AURA" and Public(unit) and unit == "player" then SafeScan() end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterUnitEvent("UNIT_AURA", "player")

SLASH_THANKSBUFFFOREVER1 = "/tftbf"
SLASH_THANKSBUFFFOREVER2 = "/buffthanks"
SlashCmdList.THANKSBUFFFOREVER = function(msg)
    if not ready then return end
    local command = (msg or ""):upper():match("^%s*(.-)%s*$")
    local db = ThanksForTheBuffForeverDB
    if command == "" or command == "OPTIONS" or command == "SETTINGS" then
        if ns.OpenSettings then ns.OpenSettings() end
    elseif command == "ON" or command == "OFF" then
        ns.SetOption("enabled", command == "ON")
        Message(db.enabled and "Enabled." or "Disabled.")
    elseif command == "GROUP ON" or command == "GROUP OFF" then
        ns.SetOption("group", command == "GROUP ON")
        Message(db.group and "Party and raid buffs included." or "Only players outside your group.")
    elseif allowed[command] then
        ns.SetOption("emote", command)
        Message("Emote: " .. command:lower() .. ".")
    elseif command == "LOG" then
        local entries = db.log or {}
        Message("Diagnostic log: " .. #entries .. "/400 entries; " .. (db.logging and "recording" or "paused") .. ". Showing last 25:")
        for i=math.max(1,#entries-24),#entries do Message(entries[i]) end
    elseif command == "LOG CLEAR" then
        db.log = {}; Message("Diagnostic log cleared.")
    elseif command == "LOG ON" or command == "LOG OFF" then
        db.logging = command == "LOG ON"
        Log("LOGGING","Enabled")
        Message(db.logging and "Diagnostic logging enabled." or "Diagnostic logging paused.")
    elseif command == "STATUS" then
        Message("Diagnostic logging: " .. (db.logging and "on" or "off") .. "; " .. #(db.log or {}) .. "/400 entries. /tftbf log shows recent entries.")
        Message((db.enabled and "On" or "Off") .. "; emote " .. db.emote:lower() .. "; group " .. (db.group and "on" or "off") .. ".")
        Message("Cooldowns: " .. db.thanksInterval .. " seconds overall, " .. db.playerInterval .. " seconds per player. Last issue: " .. lastIssue)
        Message("Delay before thanks: " .. db.thanksDelay .. " seconds. " .. thanksStatus)
        Message("Detection: " .. detectionStatus)
        Message("Last buff-back check: " .. backStatus)
        if ns.GetClickBuffStatus then Message("Buff helper: " .. ns.GetClickBuffStatus()) end
    else
        Message("/tftbf on | off | thank | cheer | bow | salute | applaud | wave | nod | kiss | dance | random")
        Message("/tftbf group on | group off | status | log | log clear | log on | log off")
    end
end
