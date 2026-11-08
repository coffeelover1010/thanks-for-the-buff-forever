local _, ns = ...
local button, keyButton, pending
local queue, elapsed, needsClear = {}, 0, false
local status = "Disabled in settings."
local function Public(v) return not issecretvalue or not issecretvalue(v) end
local function Enabled()
    local db = ThanksForTheBuffForeverDB
    return db and db.enabled ~= false and db.buffBack == true
end
local function Resolve(offer)
    local function Match(unit)
        if not unit then return end
        local guid = UnitGUID(unit)
        return Public(guid) and guid == offer.guid
    end
    for _, unit in ipairs({offer.source,"target","focus","mouseover"}) do
        if Match(unit) then return unit end
    end
    for i=1,40 do
        if i<=4 and Match("party"..i) then return "party"..i end
        if Match("raid"..i) then return "raid"..i end
        if Match("nameplate"..i) then return "nameplate"..i end
    end
end
local function PvPOkay(unit)
    if not ThanksForTheBuffForeverDB.buffBackSkipPvP then return true end
    if type(UnitIsPVP) ~= "function" then return false end
    local mine, theirs = UnitIsPVP("player"), UnitIsPVP(unit)
    if not Public(mine) or not Public(theirs) then return false end
    if mine == true then return true end
    if mine ~= false or theirs ~= false then return false end
    if type(UnitIsPVPFreeForAll) == "function" then
        local flag = UnitIsPVPFreeForAll(unit)
        if not Public(flag) or flag ~= false then return false end
    end
    return true
end
local function ClearActions()
    if InCombatLockdown() then needsClear=true; return end
    needsClear=false
    if keyButton then keyButton:SetAttribute("type1",nil) end
    if button then button:SetAttribute("type1",nil); button:Hide() end
end
local function Prune()
    for i=#queue,1,-1 do
        if GetTime() >= queue[i].expires then
            if pending == queue[i] then pending=nil end
            table.remove(queue,i)
        end
    end
end
local function Choose()
    if not Enabled() then status="Disabled in settings."; return end
    Prune()
    -- Keep the displayed recipient stable; a keypress must never silently
    -- substitute a different giver if the displayed one becomes unavailable.
    pending = pending or queue[1]
    if not pending then status="No pending givers."; return end
    local unit = Resolve(pending)
    if not unit then status="Waiting for the giver to become visible."; return end
    if not PvPOkay(unit) then status="Held by the PvP check (flagged or unreadable)."; return end
    local spell, reason = ns.GetMissingBuff(unit)
    if not spell then status=reason or "No suitable missing buff."; return end
    status="Ready for " .. (UnitName(unit) or "giver") .. "; " .. #queue .. " pending."
    return unit, spell
end
local function Arm(frame,unit,spell)
    frame:SetAttribute("unit",unit)
    frame:SetAttribute("spell",spell.castName)
    -- Direct unit casting preserves the current target. Selecting the giver
    -- remains an explicit opt-in preference for existing users.
    local target = ThanksForTheBuffForeverDB.targetBuffBack == true and ("/target [@" .. unit .. ",help,nodead]\n") or ""
    frame:SetAttribute("macrotext1",target .. "/cast [@" .. unit .. ",help,nodead] " .. spell.castName)
    frame:SetAttribute("type1","macro")
end
function ns.RefreshBuffBack(settingsChanged)
    if not Enabled() then queue={}; pending=nil end
    if settingsChanged and ThanksForTheBuffForeverDB.buffBackQueue ~= true then
        while #queue>1 do table.remove(queue) end
    end
    if InCombatLockdown() or not button then return end
    ClearActions()
    local ok, unit, spell = pcall(Choose)
    if not ok then status="Buff-back information is unreadable."; return end
    if not unit then return end
    Arm(keyButton,unit,spell)
    if ThanksForTheBuffForeverDB.buffBackPrompt == true then
        Arm(button,unit,spell)
        button.icon:SetTexture(spell.icon)
        button:Show()
    end
end
function ns.OfferBuffBack(unit,guid)
    if not Enabled() or InCombatLockdown() or not Public(unit) or type(unit)~="string"
        or not Public(guid) or type(guid)~="string" then return "Buff back is disabled or giver unavailable." end
    Prune()
    local duration=ThanksForTheBuffForeverDB.buffBackDuration or 30
    for _, offer in ipairs(queue) do
        if offer.guid==guid then offer.source=unit; offer.expires=GetTime()+duration; ns.RefreshBuffBack(); return "Updated existing offer." end
    end
    if #queue>0 and ThanksForTheBuffForeverDB.buffBackQueue ~= true then return "Keeping the existing offer." end
    if #queue>=5 then return "Buff-back queue is full (five givers)." end
    -- Keep temporarily unavailable/dead/PvP-blocked recipients until expiry.
    queue[#queue+1]={source=unit,guid=guid,expires=GetTime()+duration}
    ns.RefreshBuffBack()
    return status
end
function ns.DismissBuffBack()
    if InCombatLockdown() then return end
    if pending then
        for i,offer in ipairs(queue) do if offer==pending then table.remove(queue,i); break end end
    end
    pending=nil
    ns.RefreshBuffBack()
end
ns.GetBuffBackStatus=function() return status end
local function PreClick(self, mouseButton, down)
    if InCombatLockdown() then return end
    self:SetAttribute("type1",nil)
    if mouseButton=="RightButton" then
        if not down then ns.DismissBuffBack() end
        self:SetAttribute("type1",nil); return
    end
    local previous=pending
    local ok,unit,spell=pcall(Choose)
    if ok and unit and (not previous or previous==pending) then Arm(self,unit,spell) else ClearActions() end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_LEAVING_WORLD","UNIT_AURA"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
    if event=="UNIT_AURA" then
        -- Advance only after the current recipient is observed wearing the buff;
        -- clicking, a failed cast, or a player-only success event is not proof.
        if pending and not InCombatLockdown() then
            local ok,done=pcall(function()
                local resolved=Resolve(pending)
                if resolved and resolved==unit and PvPOkay(resolved) then
                    local spell,_,state=ns.GetMissingBuff(resolved)
                    return not spell and state=="present"
                end
            end)
            if ok and done then ns.DismissBuffBack() end
        end
        return
    end
    if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_LEAVING_WORLD" then
        queue={}; pending=nil; status="Offers cleared for combat or loading."; ClearActions(); return
    end
    if event=="PLAYER_REGEN_ENABLED" and button then ns.RefreshBuffBack(); return end
    if button or InCombatLockdown() then return end
    local holder=CreateFrame("Frame",nil,UIParent,"SecureHandlerStateTemplate")
    holder:SetAllPoints(UIParent)
    RegisterStateDriver(holder,"visibility","[combat] hide; show")
    local function Make(name,parent)
        local frame=CreateFrame("Button",name,parent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
        frame:RegisterForClicks("AnyDown","AnyUp")
        frame:SetAttribute("checkselfcast",false)
        frame:SetAttribute("checkfocuscast",false)
        frame:SetAttribute("checkmouseovercast",false)
        frame:SetAttribute("_onstate-combat",[[if newstate == "yes" then self:SetAttribute("type1",nil) end]])
        RegisterStateDriver(frame,"combat","[combat] yes; no")
        frame:SetScript("PreClick",PreClick)
        return frame
    end
    -- No texture or screen position: this secure action exists for the binding.
    keyButton=Make("ThanksForTheBuffForeverBuffBackKey",UIParent)
    button=Make("ThanksForTheBuffForeverBuffBack",holder)
    button:SetSize(36,36)
    button:SetPoint("CENTER",UIParent,"CENTER",0,-180)
    button:SetClampedToScreen(true)
    button:SetFrameStrata("DIALOG")
    ns.StyleBuffButton(button)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Buff back",1,1,1)
        GameTooltip:AddLine(status,1,.82,0)
        GameTooltip:AddLine("Left-click to buff. Right-click to dismiss.",.65,.75,.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:HookScript("OnHide",function() if GameTooltip:IsOwned(button) then GameTooltip:Hide() end end)
    button:Hide()
end)
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<.2 then return end
    elapsed=0
    if #queue>0 or needsClear then ns.RefreshBuffBack() end
end)
