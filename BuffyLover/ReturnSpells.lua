local _, ns = ...
local spells = {}
-- Single-target, reagent-free buffs only. Prefer the highest learned rank.
local families = {
    MAGE = {{1459,1460,1461,10156,10157}},
    PRIEST = {{1243,1244,1245,2791,10937,10938}, {14752,14818,14819,27841}, {976,10957,10958}},
    DRUID = {{1126,5232,6756,5234,8907,9884,9885}, {467,782,1075,8914,9756,9910}},
    PALADIN = {{19740,19834,19835,19836,19837,19838,25291}, {19742,19850,19852,19853,19854,25290}},
}
local casters = {MAGE=true, PRIEST=true, WARLOCK=true}
local function Public(v) return not issecretvalue or not issecretvalue(v) end
local function Known(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
    if IsSpellKnown then return IsSpellKnown(id) end
    return IsPlayerSpell and IsPlayerSpell(id)
end
local function Rebuild()
    spells = {}
    local _, class = UnitClass("player")
    for family, ranks in ipairs(families[class] or {}) do
        spells[family] = {}
        for i = #ranks, 1, -1 do
            if Known(ranks[i]) then
                local name, icon
                if C_Spell and C_Spell.GetSpellInfo then
                    local info = C_Spell.GetSpellInfo(ranks[i])
                    if info then name, icon = info.name, info.iconID end
                elseif GetSpellInfo then name, _, icon = GetSpellInfo(ranks[i]) end
                if Public(name) and type(name) == "string" then
                    local matchingIDs = {}
                    for _, id in ipairs(ranks) do matchingIDs[id] = true end
                    local rank = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(ranks[i])
                    if not rank and GetSpellSubtext then rank = GetSpellSubtext(ranks[i]) end
                    local level = C_Spell and C_Spell.GetSpellLevelLearned and C_Spell.GetSpellLevelLearned(ranks[i])
                    if not level and GetSpellLevelLearned then level = GetSpellLevelLearned(ranks[i]) end
                    -- Never cast by bare name: that may resolve to the highest rank again.
                    local castName = Public(rank) and type(rank) == "string" and rank ~= "" and (name .. "(" .. rank .. ")") or nil
                    if castName and Public(level) and type(level) == "number" then
                        spells[family][#spells[family]+1] = {id=ranks[i], family=family, name=name, castName=castName,
                            icon=icon, matchingIDs=matchingIDs, minLevel=math.max(1,level-10)}
                    end
                end
            end
        end
    end
end
local function Eligible(unit)
    local guid = UnitGUID(unit)
    return Public(guid) and type(guid) == "string" and UnitIsPlayer(unit)
        and UnitCanAssist("player", unit)
        and not UnitIsDeadOrGhost(unit) and guid
end
local function Pick(unit)
    local level = UnitLevel(unit)
    if not Public(level) or type(level) ~= "number" or level < 1 then return end
    local function ForFamily(index)
        for _, spell in ipairs(spells[index] or {}) do
            if level >= spell.minLevel then return spell end
        end
    end
    local _, mine = UnitClass("player")
    if mine == "PALADIN" then
        local _, class = UnitClass(unit)
        if Public(class) and casters[class] then return ForFamily(2) or ForFamily(1) end
    end
    return ForFamily(1) or ForFamily(2)
end
-- nil means unreadable, false means absent, true means already present.
-- Match every supported rank, regardless of who supplied the buff.
local function HasBuff(unit, spell)
    for index = 1, 255 do
        local name, id
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
            if not Public(aura) then return nil end
            if not aura then return false end
            name, id = aura.name, aura.spellId
        elseif UnitBuff then
            name, _, _, _, _, _, _, _, _, id = UnitBuff(unit, index)
            if not Public(name) then return nil end
            if not name then return false end
        else
            return nil
        end
        if not Public(name) or not Public(id) then return nil end
        if (id and spell.matchingIDs[id]) or name == spell.name then return true end
    end
    return nil
end

function ns.GetMissingBuffs(unit)
    if not Eligible(unit) then return {}, "Giver is not an available living friendly player." end
    local level = UnitLevel(unit)
    if not Public(level) or type(level) ~= "number" or level < 1 then return {}, "Player level is unreadable." end
    local result, unreadable, learned = {}, false, false
    local _, class = UnitClass("player")
    local preferred = class == "PALADIN" and Pick(unit)
    for _, ranks in ipairs(spells) do
        for _, spell in ipairs(ranks) do
            if level >= spell.minLevel then
                if class ~= "PALADIN" or spell == preferred then
                    learned = true
                    local present = HasBuff(unit,spell)
                    if present == false then result[#result+1] = spell end
                    if present == nil then unreadable = true end
                end
                break
            end
        end
    end
    if #result > 0 then return result end
    return result, unreadable and "Giver buffs are unreadable." or "No suitable missing buff.",
        learned and not unreadable and "present" or "unreadable"
end
function ns.RebuildReturnSpells()
    local ok = pcall(Rebuild)
    if not ok then spells = {} end
end
