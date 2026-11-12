local _, addon = ...
local seen, pending, floats = {}, {}, {}
local function ledger()
    if type(BuffyLoverDB.givingLifetime) ~= "table" then BuffyLoverDB.givingLifetime = {} end
    local data = BuffyLoverDB.givingLifetime
    if type(data.total) ~= "number" or data.total ~= data.total or data.total < 0 or data.total == math.huge then data.total = 0 end
    data.total = math.floor(data.total)
    if type(data.people) ~= "table" then data.people = {} end
    return data
end
function addon.GivingMilestone(total)
    if total>0 and addon.GivingRank(total)>addon.GivingRank(total-1) then return 2 end
    if total > 0 and total % 10 == 0 then return 1 end
    return 0
end
local function public(v) return not issecretvalue or not issecretvalue(v) end
function addon.OfferRankEmote(total)
    if not BuffyLoverDB.rankEmote or not addon.OfferManualReply or addon.GivingMilestone(total)~=2 then return end
    local name=GetUnitName and GetUnitName("player",true)
    if not public(name) or type(name)~="string" then return end
    local rank=addon.GivingRank(total)
    local message="BuffyLove: "..name.." has obtained rank "..rank.." for buffing "..total.." players!"
    addon.OfferManualReply("rank-"..rank,name,message,function()
        return BuffyLoverDB.rankEmote and not InCombatLockdown()
    end,function() end,{title="Buff rank "..rank.." earned",button="Share rank-up"})
end
local function plain(v,t) return public(v) and type(v)==t end
local function readable()
    if InCombatLockdown() then return false end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local secret=C_Secrets.ShouldAurasBeSecret()
        if not public(secret) or secret then return false end
    end
    return true
end
local function units()
    local list={"target","mouseover","focus"}
    for i=1,4 do list[#list+1]="party"..i end
    for i=1,40 do list[#list+1]="raid"..i end
    for i=1,80 do list[#list+1]="nameplate"..i end
    return list
end
local function hide(f)
    f:SetScript("OnUpdate",nil); f:Hide(); f.busy=false
end
function addon.GivingFloat(unit,guid,name,total,spellID)
    if not BuffyLoverDB.showGiving then return end
    local plate, plateUnit
    for i=1,80 do
        local token="nameplate"..i
        local candidate=UnitGUID(token)
        if plain(candidate,"string") and candidate==guid then
            local frame=C_NamePlate and C_NamePlate.GetNamePlateForUnit(token,false)
            if frame and not frame:IsForbidden() then plate,plateUnit=frame,token; break end
        end
    end
    local f
    for _,candidate in ipairs(floats) do if not candidate.busy then f=candidate; break end end
    if not f then
        if #floats>=8 then f=floats[1]; hide(f)
        else
            f=CreateFrame("Frame",nil,UIParent); f:SetSize(160,40); f:SetFrameStrata("HIGH")
            f.text=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
            f.text:SetAllPoints(); f.text:SetTextColor(0.35,1,0.55)
            f.stars={}
            for i=1,24 do
                local star=f:CreateTexture(nil,"OVERLAY")
                star:SetAtlas("evergreen-toast-celebration-star")
                star:SetBlendMode("ADD"); star:Hide()
                f.stars[i]=star
            end
            floats[#floats+1]=f
        end
    end
    f.busy=true; f:ClearAllPoints(); f:SetAlpha(1)
    local milestone=addon.GivingMilestone(total)
    local duration=milestone==2 and 2.6 or (milestone==1 and 1.9 or 1.3)
    local text,font,size,r,g,b=addon.GivingAppearance(total,spellID)
    f.text:SetFont(font,size,"OUTLINE")
    f.text:SetText(text)
    f.text:SetTextColor(r,g,b)
    f:SetSize(math.min(600,math.max(160,f.text:GetStringWidth()+20)),size+20)
    f:SetScale(milestone==2 and 1.15 or 0.85)
    for i,star in ipairs(f.stars) do
        star:Hide()
        if i <= (milestone==2 and 24 or (milestone==1 and 10 or 0)) then
            star:SetSize(milestone==2 and 14 or 8,milestone==2 and 14 or 8)
            star:SetVertexColor(1,0.85,0.4); star:SetAlpha(0)
            star:ClearAllPoints(); star:SetPoint("CENTER",f,"CENTER",0,0); star:Show()
        end
    end
    if milestone==2 and BuffyLoverDB.givingSound~=false then addon.PlayGivingSound() end
    local elapsed=0
    f:SetPoint("BOTTOM",plate or UIParent,plate and "TOP" or "CENTER",0,plate and 10 or 100)
    f:Show()
    f:SetScript("OnUpdate",function(self,dt)
        elapsed=elapsed+dt
        if elapsed>=duration or InCombatLockdown() then hide(self); return end
        if plate then
            local current=UnitGUID(plateUnit)
            if not plain(current,"string") or current~=guid or not plate:IsShown() then hide(self); return end
        end
        self:ClearAllPoints()
        self:SetPoint("BOTTOM",plate or UIParent,plate and "TOP" or "CENTER",0,(plate and 10 or 100)+elapsed*20)
        self:SetAlpha(math.min(0.95,(duration-elapsed)/0.5))
        if milestone>0 then
            local n=milestone==2 and 24 or 10
            for i=1,n do
                local star=self.stars[i]
                local angle=i*2*math.pi/n
                local radius=8+elapsed*(milestone==2 and 48 or 27)
                star:ClearAllPoints()
                star:SetPoint("CENTER",self,"CENTER",math.cos(angle)*radius,math.sin(angle)*radius*0.65)
                star:SetAlpha(math.max(0,1-elapsed/duration)*(0.65+0.35*math.sin(elapsed*14+i)^2))
            end
        end
    end)
end
function addon.GivingCount() return ledger().total end
function addon.GivingCancel()
    pending={}
    for _,f in ipairs(floats) do hide(f) end
end
function addon.ResetGivingCount(confirmation)
    if confirmation~="RESET" or InCombatLockdown() then return false end
    addon.GivingCancel()
    if addon.ClearManualReplies then addon.ClearManualReplies() end
    seen={}
    BuffyLoverDB.givingLifetime={total=0,people={}}
    addon.lastGivenSpell=nil
    if addon.RefreshSettings then addon.RefreshSettings() end
    return true
end
local function confirm(record)
    if not BuffyLoverDB or not BuffyLoverDB.giving or not readable() then return end
    local own=UnitGUID("player")
    if not plain(own,"string") then return end
    for _,unit in ipairs(units()) do
        local guid,player=UnitGUID(unit),UnitIsPlayer(unit)
        if plain(guid,"string") and guid~=own and not seen[guid] and public(player) and player then
            local name=GetUnitName(unit,true)
            if plain(name,"string") and name==record.name and not ledger().people[name] then
                for i=1,256 do
                    local aura=C_UnitAuras.GetAuraDataByIndex(unit,i,"HELPFUL")
                    if not public(aura) then break end
                    if aura==nil then break end
                    if plain(aura.spellId,"number") and aura.spellId==record.spell and plain(aura.sourceUnit,"string") then
                        local source=UnitGUID(aura.sourceUnit)
                        if plain(source,"string") and source==own then
                            seen[guid]=true
                            local data=ledger()
                            data.people[name]=true; data.total=data.total+1
                            addon.OfferRankEmote(data.total)
                            addon.lastGivenSpell=record.spell
                            if addon.UpdateGivingTotal then addon.UpdateGivingTotal() end
                            addon.GivingFloat(unit,guid,name,data.total,record.spell)
                            return true
                        end
                    end
                end
            end
        end
    end
end
local function sweep()
    for cast,record in pairs(pending) do
        if GetTime()>record.expires then pending[cast]=nil
        elseif record.success then
            local ok,done=pcall(confirm,record)
            if not ok or done then pending[cast]=nil end
        end
    end
end
local frame=CreateFrame("Frame")
frame:SetScript("OnEvent",function(_,event,unit,a,b,c)
    if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_LEAVING_WORLD" then addon.GivingCancel(); return end
    if not BuffyLoverDB or not BuffyLoverDB.giving then return end
    if event=="UNIT_AURA" then sweep(); return end
    if not public(unit) or unit~="player" then return end
    if event=="UNIT_SPELLCAST_SENT" then
        sweep()
        if plain(a,"string") and a~="" and plain(b,"string") and plain(c,"number") and addon.buffs[c] then
            pending[b]={name=a,spell=c,expires=GetTime()+15}
            C_Timer.After(15.1,sweep)
        end
    elseif plain(a,"string") then
        local record=pending[a]
        if event=="UNIT_SPELLCAST_SUCCEEDED" and record and plain(b,"number") and b==record.spell then
            record.success=true; record.expires=GetTime()+2
            sweep(); C_Timer.After(0.2,sweep)
        elseif event~="UNIT_SPELLCAST_SUCCEEDED" then pending[a]=nil end
    end
end)
for _,event in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED","UNIT_AURA","PLAYER_REGEN_DISABLED","PLAYER_LEAVING_WORLD"}) do frame:RegisterEvent(event) end
