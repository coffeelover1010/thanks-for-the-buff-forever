local _, ns = ...
local button, holder, selected, elapsed = nil, nil, nil, 0
local spells = {}

-- Shared icon-only appearance for the target helper and Buff Back.
function ns.StyleBuffButton(button)
    button:SetSize(36,36)
    button.icon = button:CreateTexture(nil,"ARTWORK")
    button.icon:SetAllPoints(button)
    button.icon:SetTexCoord(0,1,0,1)
    local mask = button:CreateMaskTexture(nil,"ARTWORK")
    mask:SetAllPoints(button)
    mask:SetTexture("Interface\\AddOns\\ThanksForTheBuffForever\\Media\\RoundedIconMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    button.icon:AddMaskTexture(mask)
    button.iconMask = mask
    local highlight = button:CreateTexture(nil,"HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1,1,1,.2)
    highlight:AddMaskTexture(mask)
    button:SetHighlightTexture(highlight)
    local pushed = button:CreateTexture(nil,"ARTWORK")
    pushed:SetAllPoints(button)
    pushed:SetColorTexture(0,0,0,.3)
    pushed:AddMaskTexture(mask)
    button:SetPushedTexture(pushed)
end

local helperStatus = "Waiting for login."
BINDING_HEADER_THANKSBUFFFOREVER = "Thanks for the Buff Forever"
_G["BINDING_NAME_CLICK ThanksForTheBuffForeverMouseover:LeftButton"] = "Buff mouseover (out of combat)"
_G["BINDING_NAME_CLICK ThanksForTheBuffForeverBuffBackKey:LeftButton"] = "Buff back next giver (out of combat)"
-- Single-target, reagent-free buffs only. Prefer the highest learned rank.
local families = {
    MAGE = {{1459,1460,1461,10156,10157}},
    PRIEST = {{1243,1244,1245,2791,10937,10938}},
    DRUID = {{1126,5232,6756,5234,8907,9884,9885}},
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
                        spells[family][#spells[family]+1] = {id=ranks[i], name=name, castName=castName,
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
local function Clear()
    if not button or InCombatLockdown() then return end
    selected = nil
    button:SetAttribute("type1", nil)
    button:Hide()
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end
-- Read frame geometry; only the addon-owned button is moved.
local function Rect(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) or not frame:IsShown() then return end
    local l, b, w, h = frame:GetRect()
    if not Public(l) or not Public(b) or not Public(w) or not Public(h) then return end
    if not l or not b or not w or not h then return end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return {l=l*scale, b=b*scale, w=w*scale, h=h*scale}
end
local function Place()
    local target = TargetFrame
    if not target or not target:IsShown() then return false end
    local art = target.TargetFrameContainer and target.TargetFrameContainer.FrameTexture
    local base = Rect(art) or Rect(target)
    if not base then return false end
    local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local size = 26*scale
    local x, y = base.l+5*scale, base.b+base.h+6*scale
    button:ClearAllPoints()
    button:SetSize(size,size)
    button:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
    return true
end
local function Refresh()
    if not button or InCombatLockdown() then return end
    if not ThanksForTheBuffForeverDB.clickBuff then helperStatus = "Disabled in settings."; Clear(); return end
    local guid = Eligible("target")
    if not guid then helperStatus = "Select a living friendly player."; Clear(); return end
    local spell = guid and Pick("target")
    if not spell then helperStatus = "No learned buff rank available for this target level."; Clear(); return end
    local hasBuff = HasBuff("target",spell)
    if hasBuff ~= false then
        helperStatus = hasBuff and ("Target already has " .. spell.name .. ".") or "Target buffs are unreadable."
        Clear(); return
    end
    if not Place() then helperStatus = "Target-frame position unavailable."; Clear(); return end
    selected = {unit="target",guid=guid,spell=spell}
    button:SetAttribute("unit","target")
    button:SetAttribute("spell",spell.castName)
    button:SetAttribute("type1","spell")
    button.icon:SetTexture(spell.icon)
    button:Show()
    helperStatus = "Offering " .. spell.name .. "."
end
local function SafeRefresh()
    if InCombatLockdown() then helperStatus = "Hidden during combat."; return end
    local ok, issue = pcall(Refresh)
    if not ok then
        helperStatus = "Update failed: " .. (Public(issue) and tostring(issue) or "restricted data")
        Clear()
    end -- Restricted/unavailable data must never leave a stale action.
end
local function Create()
    if button or InCombatLockdown() then return end
    holder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    holder:SetAllPoints(UIParent)
    RegisterStateDriver(holder, "visibility", "[combat] hide; show")
    -- A separate binding uses the current mouseover, never the selected target.
    -- Resolve on the physical keypress so a fast mouse move cannot reuse an old spell.
    local mouseover = CreateFrame("Button", "ThanksForTheBuffForeverMouseover", UIParent,
        "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    mouseover:RegisterForClicks("AnyDown", "AnyUp")
    mouseover:SetAttribute("unit", "mouseover")
    mouseover:SetAttribute("checkselfcast", false)
    mouseover:SetAttribute("checkfocuscast", false)
    mouseover:SetAttribute("checkmouseovercast", false)
    mouseover:SetAttribute("_onstate-combat", [[if newstate == "yes" then self:SetAttribute("type1", nil) end]])
    RegisterStateDriver(mouseover, "combat", "[combat] yes; no")
    mouseover:SetScript("PreClick", function(self)
        if InCombatLockdown() then return end
        self:SetAttribute("type1", nil)
        self:SetAttribute("spell", nil)
        local ok, spell = pcall(function()
            if not Eligible("mouseover") then return end
            local candidate = Pick("mouseover")
            if candidate and HasBuff("mouseover", candidate) == false then return candidate end
        end)
        if ok and spell then
            self:SetAttribute("spell", spell.castName)
            self:SetAttribute("type1", "spell")
        end
    end)
    mouseover:Hide()
    button = CreateFrame("Button", "ThanksForTheBuffForeverClickBuff", holder,
        "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    button:SetSize(26, 26)
    button:SetClampedToScreen(true)
    button:SetFrameStrata("DIALOG")
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("checkselfcast", false)
    button:SetAttribute("checkfocuscast", false)
    button:SetAttribute("checkmouseovercast", false)
    button:SetAttribute("_onstate-combat", [[if newstate == "yes" then self:SetAttribute("type1", nil) end]])
    RegisterStateDriver(button, "combat", "[combat] yes; no")
    ns.StyleBuffButton(button)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
        GameTooltip:SetText("Click to buff",1,.82,0)
        if selected then GameTooltip:AddLine(selected.spell.castName .. " → " .. (UnitName(selected.unit) or "player"),1,1,1) end
        GameTooltip:AddLine("One click, one cast. Out of combat only.",.65,.75,.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("PreClick", function(self)
        if InCombatLockdown() then return end
        local ok, valid = pcall(function()
            return selected and ThanksForTheBuffForeverDB.clickBuff and Eligible(selected.unit) == selected.guid
                and Pick(selected.unit) == selected.spell and HasBuff(selected.unit, selected.spell) == false
        end)
        if not ok or not valid then self:SetAttribute("type1",nil) end
    end)
    button:Hide()
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function()
    if not ThanksForTheBuffForeverDB or InCombatLockdown() then return end
    if ThanksForTheBuffForeverDB.clickBuff == nil then ThanksForTheBuffForeverDB.clickBuff = false end
    Create()
    local ok = pcall(Rebuild)
    if not ok then spells = {} end
    Clear()
    SafeRefresh()
end)
events:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < .1 then return end
    elapsed = 0
    SafeRefresh()
end)
ns.RefreshClickBuff = SafeRefresh
ns.GetClickBuffStatus = function() return helperStatus end
ns.GetMissingBuff = function(unit)
    if not Eligible(unit) then return nil, "Caster is not an available living friendly player." end
    local spell = Pick(unit)
    if not spell then return nil, "No learned buff rank available for this player level." end
    local present = HasBuff(unit,spell)
    if present == false then return spell end
    return nil, present and ("Caster already has " .. spell.name .. ".") or "Caster buffs are unreadable.", present and "present" or "unreadable"
end
