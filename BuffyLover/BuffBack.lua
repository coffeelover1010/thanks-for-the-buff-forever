local _, ns = ...
local button, pending, anchor, preview
local buttons = {}
local queue, elapsed, needsClear = {}, 0, false
local status = "Disabled in settings."
local function Public(v) return not issecretvalue or not issecretvalue(v) end
local function Enabled()
    local db = BuffyLoverDB
    return db and db.buffBack == true
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
    for i=1,80 do
        if i<=4 and Match("party"..i) then return "party"..i end
        if i<=40 and Match("raid"..i) then return "raid"..i end
        if Match("nameplate"..i) then return "nameplate"..i end
    end
end
local function PvPOkay(unit)
    -- Do not flag an unflagged player through a return buff.
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
    for _, icon in ipairs(buttons) do icon:SetAttribute("type1",nil); icon:Hide() end
end
local function Prune()
    for i=#queue,1,-1 do
        if GetTime() >= queue[i].expires then
            if pending == queue[i] then pending=nil end
            table.remove(queue,i)
        end
    end
end
local function Choose(wantedFamily)
    if not Enabled() then status="Disabled in settings."; return end
    Prune()
    -- Keep the displayed recipient stable; a click must never silently
    -- substitute a different giver if the displayed one becomes unavailable.
    pending = pending or queue[1]
    if not pending then status="No pending givers."; return end
    local unit = Resolve(pending)
    if not unit then status="Waiting for the giver to become visible."; return end
    if not PvPOkay(unit) then status="Held by the PvP check (flagged or unreadable)."; return end
    local available, reason = ns.GetMissingBuffs(unit)
    local spell = available[1]
    if wantedFamily then
        spell = nil
        for _, candidate in ipairs(available) do if candidate.family == wantedFamily then spell = candidate; break end end
    end
    if not spell then status=reason or "No suitable missing buff."; return end
    status="Ready for " .. (UnitName(unit) or "giver") .. "; " .. #queue .. " pending."
    return unit, spell, available
end
local function Arm(frame,unit,spell)
    frame:SetAttribute("unit",unit)
    frame:SetAttribute("spell",spell.castName)
    frame:SetAttribute("macrotext1","/cast [@" .. unit .. ",help,nodead] " .. spell.castName)
    frame:SetAttribute("type1","macro")
end
function ns.RefreshBuffBack()
    if not Enabled() then queue={}; pending=nil end
    if InCombatLockdown() or not button then return end
    local ok, unit, spell, available = pcall(Choose)
    if not ok then status="Buff-back information is unreadable."; ClearActions(); return end
    if not unit then ClearActions(); return end
    needsClear=false
    for i=#available+1,#buttons do
        buttons[i]:SetAttribute("type1",nil)
        buttons[i]:Hide()
    end
    for i, candidate in ipairs(available) do
        local icon = buttons[i]
        if icon then
            Arm(icon,unit,candidate)
            icon.family = candidate.family
            icon.offer = pending
            icon.spellLabel = candidate.castName
            icon.icon:SetTexture(candidate.icon)
            if not icon:IsShown() then icon:Show() end
        end
    end
end
function ns.OfferBuffBack(unit,guid)
    if not Enabled() or InCombatLockdown() or not Public(unit) or type(unit)~="string"
        or not Public(guid) or type(guid)~="string" then return "Buff back is disabled or giver unavailable." end
    Prune()
    local duration=BuffyLoverDB.buffBackDuration or 30
    for _, offer in ipairs(queue) do
        if offer.guid==guid then offer.source=unit; offer.expires=GetTime()+duration; ns.RefreshBuffBack(); return "Updated existing offer." end
    end
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
ns.GetBuffBackStatus=function()
    if not Enabled() then return "Disabled in settings." end
    if InCombatLockdown() then return "Enabled; paused during combat." end
    if #queue == 0 then return "Enabled; no pending givers." end
    return status
end
local function PreClick(self, mouseButton, down)
    if InCombatLockdown() then return end
    self:SetAttribute("type1",nil)
    if mouseButton=="RightButton" then
        if not down then ns.DismissBuffBack() end
        self:SetAttribute("type1",nil); return
    end
    local previous=pending
    local ok,unit,spell=pcall(Choose,self.family)
    if ok and unit and (not self.offer or self.offer==pending) and (not previous or previous==pending) then Arm(self,unit,spell) else ClearActions() end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","SPELLS_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_LEAVING_WORLD","LOADING_SCREEN_ENABLED","UNIT_AURA"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
    if not BuffyLoverDB then return end
    if event=="PLAYER_LOGIN" or event=="SPELLS_CHANGED" or event=="PLAYER_REGEN_ENABLED" then
        if not InCombatLockdown() then ns.RebuildReturnSpells() end
    end
    if event=="UNIT_AURA" then
        -- Advance only after the current recipient is observed wearing the buff;
        -- clicking, a failed cast, or a player-only success event is not proof.
        if pending and not InCombatLockdown() then
            local ok,done=pcall(function()
                local resolved=Resolve(pending)
                if resolved and resolved==unit and PvPOkay(resolved) then
                    local missing,_,state=ns.GetMissingBuffs(resolved)
                    return #missing==0 and state=="present"
                end
            end)
            if ok and done then ns.DismissBuffBack() end
        end
        return
    end
    if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_LEAVING_WORLD" or event=="LOADING_SCREEN_ENABLED" then
        queue={}; pending=nil; status="Offers cleared for combat or loading."; if preview then preview:Hide() end; ClearActions(); return
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
    anchor=CreateFrame("Frame",nil,holder)
    anchor:SetSize(116,36)
    anchor:SetClampedToScreen(true)
    ns.PlaceBuffBack()
    for i=1,3 do
        button=Make(i==1 and "BuffyLoverBuffBack" or "BuffyLoverBuffBack"..i,anchor)
        buttons[i]=button
        button:SetSize(36,36)
        button:SetPoint("LEFT",anchor,"LEFT",(i-1)*40,0)
        button:SetClampedToScreen(true)
        button:SetFrameStrata("DIALOG")
        button.icon=button:CreateTexture(nil,"ARTWORK")
        button.icon:SetAllPoints()
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        button:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText("Buff back",1,1,1)
            if self.spellLabel then GameTooltip:AddLine(self.spellLabel,1,1,1) end
            GameTooltip:AddLine(status,1,.82,0)
            GameTooltip:AddLine("Left-click to buff. Right-click to dismiss.",.65,.75,.8)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function() GameTooltip:Hide() end)
        button:HookScript("OnHide",function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        button:Hide()
    end
    button=buttons[1]
end)
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<.2 then return end
    elapsed=0
    if #queue>0 or needsClear then ns.RefreshBuffBack() end
end)

function ns.PlaceBuffBack()
    if not anchor or InCombatLockdown() then return end
    local db = BuffyLoverDB
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER",UIParent,"CENTER",db.buffBackX or 0,db.buffBackY or -180)
end
function ns.ResetBuffBackPosition()
    if InCombatLockdown() then return end
    if preview then preview:Hide() end
    BuffyLoverDB.buffBackX=0
    BuffyLoverDB.buffBackY=-180
    ns.PlaceBuffBack()
end
function ns.ToggleBuffBackPlacement()
    if InCombatLockdown() then return end
    if not preview then
        preview=CreateFrame("Frame","BuffyLoverBuffBackPlacement",UIParent,"BackdropTemplate")
        preview:SetSize(240,76)
        preview:SetFrameStrata("TOOLTIP")
        preview:SetClampedToScreen(true)
        preview:SetMovable(true)
        preview:EnableMouse(true)
        preview:RegisterForDrag("LeftButton")
        preview:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
        preview:SetBackdropColor(.08,.12,.18,.95)
        local text=preview:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        text:SetAllPoints()
        text:SetText("Buff-back icons appear here\nDrag to position\nRight-click to save and close")
        preview:SetScript("OnDragStart",function(self) self:StartMoving() end)
        local function Save(self)
            self:StopMovingOrSizing()
            local x,y=self:GetCenter()
            local px,py=UIParent:GetCenter()
            BuffyLoverDB.buffBackX=x-px
            BuffyLoverDB.buffBackY=y-py
            ns.PlaceBuffBack()
        end
        preview:SetScript("OnDragStop",Save)
        preview:SetScript("OnMouseUp",function(self,key) if key=="RightButton" then Save(self); self:Hide() end end)
        preview:SetScript("OnHide",function(self) self:StopMovingOrSizing() end)
        preview:Hide()
    end
    if preview:IsShown() then preview:Hide(); return end
    preview:ClearAllPoints()
    local db=BuffyLoverDB
    preview:SetPoint("CENTER",UIParent,"CENTER",db.buffBackX or 0,db.buffBackY or -180)
    preview:Show()
end
function ns.InitBuffBack(db)
    if type(db.buffBack) ~= "boolean" then db.buffBack=false end
    local duration=db.buffBackDuration
    if type(duration) ~= "number" or duration ~= duration then duration=30 end
    db.buffBackDuration=math.floor(math.max(5,math.min(120,duration)))
    for key,default in pairs({buffBackX=0,buffBackY=-180}) do
        local value=db[key]
        if type(value) ~= "number" or value ~= value or math.abs(value)==math.huge then db[key]=default end
    end
end
