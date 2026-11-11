from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
ns={}; frames={}; now=10; combat=false; hovered=false; mine="MAGE"
known={[1459]=true,[1460]=true,[19740]=true,[19742]=true}
units={player={guid="me",class="MAGE"},nameplate1={guid="friend",class="PRIEST"}}
units.target=units.nameplate1
BuffyLoverDB={}
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetAttribute(k,v) assert(not combat,"insecure combat write"); self.attrs[k]=v end
function methods:Show() assert(not combat); self.shown=true end
function methods:Hide() assert(not combat or self.template=="BackdropTemplate"); self.shown=false end
function methods:IsShown() return self.shown end
function methods:IsMouseOver() return hovered end
function methods:GetEffectiveScale() return 1 end
function methods:GetRect() return rawget(self,"left") or 300,rawget(self,"bottom") or 400,rawget(self,"width") or 122,rawget(self,"height") or 21 end
function methods:SetPoint(...) self.point={...} end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:CreateTexture() return CreateFrame() end
function methods:CreateMaskTexture() return CreateFrame() end
function methods:CreateFontString() return CreateFrame() end
function methods:SetText(text) self.text=text end
setmetatable(methods,{__index=function() return function() end end})
function CreateFrame(_,name,_,template)
 local f=setmetatable({scripts={},attrs={},shown=true,template=template},{__index=methods})
 table.insert(frames,f); if name then _G[name]=f end; return f
end
UIParent=CreateFrame(); plate=CreateFrame(); plate.namePlateUnitToken="nameplate1"
TargetFrame=CreateFrame(); TargetFrame.TargetFrameContainer={}; container=CreateFrame(); auraFrame=CreateFrame(); auraFrame.width=21
TargetFrame.GetAuraContainer=function() return container end
container.buffAuraGroup={GetFramesByIndex=function() return {auraFrame} end}
container.debuffAuraGroup={GetFramesByIndex=function() return {} end}
container.GetFlowLayoutMaximumLineSize=function() return 122 end
C_NamePlate={GetNamePlates=function() return {plate} end}
C_SpellBook={IsSpellKnown=function(id) return known[id] end}
C_Spell={GetSpellInfo=function(id) return {name="Spell"..id,iconID=id} end}
auras={}; secret={}
function issecretvalue(v) return v==secret end
C_UnitAuras={GetAuraDataByIndex=function(unit,index) return (auras[unit] or {})[index] end}
GameTooltip={IsOwned=function() return false end,Hide=function() end}
function RegisterStateDriver(f,state,driver) f[state.."Driver"]=driver end
function UnitLevel(u) return units[u] and (units[u].level or 60) end
C_Spell.GetSpellLevelLearned=function(id) return ({[1459]=1,[1460]=14,[19740]=4,[19742]=14})[id] end
C_Spell.GetSpellSubtext=function(id) return id==1460 and "Rank 2" or "Rank 1" end
function UnitGUID(u) return units[u] and units[u].guid end
function UnitClass(u) return "Class", u=="player" and mine or (units[u] and units[u].class) end
function UnitIsPlayer(u) return units[u] ~= nil and not units[u].npc end
function UnitCanAssist(_,u) return units[u] and not units[u].enemy end
function UnitIsDeadOrGhost(u) return units[u] and units[u].dead end
function UnitIsUnit(a,b) return UnitGUID(a)==UnitGUID(b) end
function UnitName(u) return UnitGUID(u) end
function InCombatLockdown() return combat end
function GetTime() return now end
''')

for name in ('ReturnSpells.lua','BuffBack.lua'):
    lua.execute('assert(loadstring(...))("BuffyLover",ns)', (root/'BuffyLover'/name).read_text())
lua.execute(r'''
function UnitIsPVP() return false end
ns.InitBuffBack(BuffyLoverDB)
assert(not BuffyLoverDB.buffBack and BuffyLoverDB.buffBackDuration==30)
backEvents=frames[#frames]
backEvents.scripts.OnEvent(backEvents,"PLAYER_LOGIN")
local back=BuffyLoverBuffBack
local second=BuffyLoverBuffBack2
local third=BuffyLoverBuffBack3
ns.OfferBuffBack("target","friend"); assert(not back.shown,"not off by default")
BuffyLoverDB.buffBack=true; BuffyLoverDB.buffBackDuration=10
assert(ns.GetBuffBackStatus()=="Enabled; no pending givers.","saved enabled setting reported disabled before first offer")
combat=true
assert(ns.GetBuffBackStatus()=="Enabled; paused during combat.")
BuffyLoverDB.buffBack=false
assert(ns.GetBuffBackStatus()=="Disabled in settings.")
BuffyLoverDB.buffBack=true; combat=false
ns.OfferBuffBack("target","friend")
assert(back.shown and back.attrs.spell=="Spell1460(Rank 2)")
assert(back.attrs.macrotext1=="/cast [@target,help,nodead] Spell1460(Rank 2)","target-changing macro")
units.target={guid="stranger",class="PRIEST"}; units.nameplate1=nil
back.scripts.PreClick(back,"LeftButton",false)
assert(not back.shown and back.attrs.type1==nil,"changed target cast")
units.focus={guid="friend",class="PRIEST",level=3}
ns.RefreshBuffBack()
assert(back.shown and back.attrs.unit=="focus" and back.attrs.spell=="Spell1459(Rank 1)")
units.focus.level=4
back.scripts.PreClick(back,"LeftButton",false)
assert(back.attrs.spell=="Spell1460(Rank 2)","rank not recalculated")
now=21; back.scripts.PreClick(back,"LeftButton",false)
assert(not back.shown and back.attrs.type1==nil,"expired offer cast")

mine="PRIEST"; known[1243]=true; known[14752]=true; known[976]=true
local oldLevel=C_Spell.GetSpellLevelLearned
C_Spell.GetSpellLevelLearned=function(id) if id==1243 or id==14752 or id==976 then return 1 end; return oldLevel(id) end
backEvents.scripts.OnEvent(backEvents,"SPELLS_CHANGED")
units.target={guid="giver",class="WARRIOR"}; auras.target={}
ns.OfferBuffBack("target","giver")
assert(back.shown and second.shown and third.shown,"three missing buffs not offered")
second.scripts.PreClick(second,"LeftButton",false)
assert(second.attrs.spell=="Spell14752(Rank 1)","wrong clicked spell")
auras.target={{name="Spell1243",spellId=1243}}
backEvents.scripts.OnEvent(backEvents,"UNIT_AURA","target")
ns.RefreshBuffBack()
assert(back.shown and second.shown and not third.shown,"partial completion dismissed giver")
assert(back.attrs.spell=="Spell14752(Rank 1)")
auras.target[2]={name="Spell14752",spellId=14752}
auras.target[3]={name="Spell976",spellId=976}
backEvents.scripts.OnEvent(backEvents,"UNIT_AURA","target")
assert(not back.shown and not second.shown,"completed offer retained")
auras.target={}; ns.OfferBuffBack("target","giver")
combat=true
backEvents.scripts.OnEvent(backEvents,"PLAYER_REGEN_DISABLED")
back.scripts.PreClick(back,"LeftButton",false); ns.RefreshBuffBack()
assert(back.combatDriver=="[combat] yes; no")
combat=false; backEvents.scripts.OnEvent(backEvents,"PLAYER_REGEN_ENABLED")
assert(not back.shown and not second.shown and not third.shown,"combat offer replayed")
ns.OfferBuffBack("target","giver"); assert(back.shown)
BuffyLoverDB.buffBack=false; ns.RefreshBuffBack(true)
assert(not back.shown and not second.shown)
BuffyLoverDB.buffBack=true
ns.OfferBuffBack("target","giver")
units.focus={guid="next",class="MAGE"}; ns.OfferBuffBack("focus","next")
back.scripts.PreClick(back,"RightButton",false)
assert(BuffyLoverBuffBack.attrs.unit=="focus","dismiss did not advance queue")
UnitIsPVP=function(u) return u~="player" end
back.scripts.PreClick(back,"LeftButton",false)
assert(back.attrs.type1==nil,"PvP revalidation missing")
UnitIsPVP=function() return false end

UIParent.GetCenter=function() return 500,400 end
ns.ToggleBuffBackPlacement()
local preview=BuffyLoverBuffBackPlacement
assert(preview.shown)
preview.GetCenter=function() return 700,300 end
preview.scripts.OnDragStop(preview)
assert(BuffyLoverDB.buffBackX==200 and BuffyLoverDB.buffBackY==-100)
preview.scripts.OnMouseUp(preview,"RightButton"); assert(not preview.shown)
ns.ToggleBuffBackPlacement()
assert(preview.point[4]==200 and preview.point[5]==-100,"position not restored")
combat=true; backEvents.scripts.OnEvent(backEvents,"PLAYER_REGEN_DISABLED")
assert(not preview.shown)
ns.ToggleBuffBackPlacement(); assert(not preview.shown)
combat=false; ns.ResetBuffBackPosition()
assert(BuffyLoverDB.buffBackY==-180)
BuffyLoverDB.buffBackX=0/0; BuffyLoverDB.buffBackY=math.huge
ns.InitBuffBack(BuffyLoverDB)
assert(BuffyLoverDB.buffBackX==0 and BuffyLoverDB.buffBackY==-180)
''')
print('PASS: buff-back defaults, multiple spells, recipient identity, rank selection, expiry, queue, PvP, combat guards and saved placement.')
