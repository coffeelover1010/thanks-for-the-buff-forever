local _, addon = ...
local function public(v) return not issecretvalue or not issecretvalue(v) end
local function stringValue(v) return public(v) and type(v)=="string" and v~="" end
-- Forever's GUID lookup supplies the character name; do not append a realm
-- or reinterpret its realm return as a surname.
function addon.CasterNameFromGUID(guid)
    if not stringValue(guid) or not guid:match("^Player%-") or type(GetPlayerInfoByGUID)~="function" then return end
    local ok,_,_,_,_,_,name=pcall(GetPlayerInfoByGUID,guid)
    if ok and stringValue(name) then return name end
end
function addon.CasterGroupFromGUID(guid)
    for _,prefix in ipairs({"party","raid"}) do
        for i=1,(prefix=="party" and 4 or 40) do
            local value=UnitGUID(prefix..i)
            if not public(value) then return nil end
            if value==guid then return true end
        end
    end
    return false
end
function addon.ResolveCaster(aura)
    local source=aura.sourceUnit
    if not public(source) then return nil,false end
    if stringValue(source) then
        local guid=UnitGUID(source)
        if not public(guid) then return nil,false end
        if stringValue(guid) then return source,false end
    end
    local caster
    if C_UnitAuras.GetAuraCasterGUID and public(aura.auraInstanceID) and type(aura.auraInstanceID)=="number" then
        local ok,value=pcall(C_UnitAuras.GetAuraCasterGUID,"player",aura.auraInstanceID)
        if not ok or not public(value) then return nil,false end
        if stringValue(value) then caster=value end
    elseif not public(aura.auraInstanceID) then return nil,false end
    if caster then
        local own=UnitGUID("player")
        if not stringValue(own) then return nil,false end
        if caster==own then return "player",false end
        local candidates={"target","mouseover","focus"}
        for i=1,4 do candidates[#candidates+1]="party"..i end
        for i=1,40 do candidates[#candidates+1]="raid"..i end
        for i=1,80 do candidates[#candidates+1]="nameplate"..i end
        for _,unit in ipairs(candidates) do
            local guid=UnitGUID(unit)
            if stringValue(guid) and guid==caster then return unit,false end
        end
        local name=addon.CasterNameFromGUID(caster)
        if name then return nil,false,caster,name end
    end
    -- No identity claim: only the caller's explicitly enabled general emote.
    return nil,true
end
