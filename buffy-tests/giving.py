from pathlib import Path
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
ns={}; now=0; combat=false; secret={}; timers={}; output={}
BuffyLoverDB={giving=true}
function issecretvalue(v) return rawequal(v,secret) end
function GetTime() return now end
function InCombatLockdown() return combat end
function UnitGUID(u) if u=='player' then return 'own' elseif u=='target' then return recipient end end
function UnitIsPlayer(u) return u=='target' and isPlayer end
function GetUnitName(u) if u=='target' then return recipient .. ' Surname' end end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
C_UnitAuras={GetAuraDataByIndex=function(u,i)
 if unavailable then error('restricted') end
 if u=='target' and i==1 then return aura end
end}
function CreateFrame()
 frame={RegisterEvent=function() end,SetScript=function(self,_,fn) self.handler=fn end}; return frame
end
function event(e,...) frame:handler(e,...) end
function cast(id)
 event('UNIT_SPELLCAST_SENT','player',recipient .. ' Surname',id,1459)
 event('UNIT_SPELLCAST_SUCCEEDED','player',id,1459)
end
recipient='one'; isPlayer=true; aura={spellId=1459,sourceUnit='player'}
''')
for file in ('Buffs.lua','GivingStyle.lua','Giving.lua'):
    lua.execute('assert(loadstring(...))("BuffyLover",ns)',(root/'BuffyLover'/file).read_text(encoding='utf-8'))
lua.execute('''
originalFloat=ns.GivingFloat
ns.GivingFloat=function(unit,guid,name,count) output[#output+1]={guid,name,count} end
event('UNIT_AURA','target'); assert(ns.GivingCount()==0) -- existing auras don't count
cast('a'); assert(ns.GivingCount()==1 and output[1][2]=='one Surname')
cast('b'); assert(ns.GivingCount()==1) -- distinct players, not buffs
recipient='two'; cast('c'); assert(ns.GivingCount()==2)
recipient='own'; cast('d'); assert(ns.GivingCount()==2)
recipient='npc'; isPlayer=false; cast('e'); assert(ns.GivingCount()==2); isPlayer=true
recipient='three'; aura=nil; cast('f'); assert(ns.GivingCount()==2)
aura={spellId=1459,sourceUnit='player'}; event('UNIT_AURA','target'); assert(ns.GivingCount()==3)
recipient='four'; aura={spellId=1459,sourceUnit='target'}; cast('g'); assert(ns.GivingCount()==3)
ns.GivingCancel(); aura={spellId=1459,sourceUnit='player'}
event('UNIT_SPELLCAST_SENT','player',recipient .. ' Surname','h',1459)
event('UNIT_SPELLCAST_FAILED','player','h',1459)
event('UNIT_SPELLCAST_SUCCEEDED','player','h',1459); assert(ns.GivingCount()==3)
event('UNIT_SPELLCAST_SENT','player',secret,'i',1459)
event('UNIT_SPELLCAST_SUCCEEDED','player','i',1459); assert(ns.GivingCount()==3)
unavailable=true; cast('j'); unavailable=false; event('UNIT_AURA','target'); assert(ns.GivingCount()==3)
combat=true; cast('k'); event('PLAYER_REGEN_DISABLED'); combat=false
event('UNIT_AURA','target'); assert(ns.GivingCount()==3)
BuffyLoverDB.giving=false; cast('l'); assert(ns.GivingCount()==3); BuffyLoverDB.giving=true
aura=nil; cast('m'); now=3; aura={spellId=1459,sourceUnit='player'}
event('UNIT_AURA','target'); assert(ns.GivingCount()==3) -- expired confirmation
ns.GivingCancel(); assert(ns.GivingCount()==3) -- zoning retains session count
''')
print('PASS: giving confirmation, distinct recipients, self/NPC/failed/secret/restricted casts, cancellation and expiry.')

# Re-load the module with the same SavedVariables to simulate a new session.
lua.execute('assert(loadstring(...))("BuffyLover",ns)',(root/'BuffyLover/Giving.lua').read_text(encoding='utf-8'))
lua.execute('''
assert(ns.GivingCount()==3)
ns.GivingFloat=function() end
recipient='one'; cast('reload'); assert(ns.GivingCount()==3)
assert(ns.GivingMilestone(9)==0 and ns.GivingMilestone(10)==1)
assert(ns.GivingMilestone(99)==0 and ns.GivingMilestone(100)==2 and ns.GivingMilestone(200)==2)
widgets={}; sounds=0; ns.InitGivingStyle(BuffyLoverDB); BuffyLoverDB.showGiving=true
local methods={}
function methods:GetStringWidth() return 60 end
function methods:SetText(v) self.text=v end
function methods:SetScript(k,v) self[k]=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:CreateFontString() return CreateFrame() end
function methods:CreateTexture() return CreateFrame() end
function CreateFrame()
 local w=setmetatable({},{__index=function(_,k) return methods[k] or function() end end})
 widgets[#widgets+1]=w; return w
end
function PlaySound(id,channel) assert(id==888 and channel=='SFX'); sounds=sounds+1 end
originalFloat('target','one','one Surname',9)
local f=widgets[1]; assert(f.text.text=='9 toons buffed!'); f:OnUpdate(2); assert(not f.shown and rawget(f,'OnUpdate')==nil)
originalFloat('target','one','one Surname',10); assert(sounds==0 and f.stars[1].shown and not f.stars[11].shown)
f:OnUpdate(2)
originalFloat('target','one','one Surname',100); assert(sounds==1 and f.stars[24].shown)
f:OnUpdate(3)
BuffyLoverDB.givingSound=false
originalFloat('target','one','one Surname',200); assert(sounds==1)
f:OnUpdate(3)
originalFloat('target','one','one Surname',201); assert(not f.stars[1].shown and f.text.text=='201 toons buffed!')
''')
print('PASS: lifetime persistence/deduplication, 10/100 milestones, sparkle reuse/cleanup and optional sound.')

lua.execute('''
local db={giving=false}; ns.InitGivingStyle(db)
assert(db.showGiving==false and db.giving==true and db.givingStyle.text=='{count} toons buffed!')
db.showGiving=true; ns.InitGivingStyle(db); assert(db.showGiving==true)
assert(not ns.ValidGivingText('|Hbad') and not ns.ValidGivingText('{unknown}'))
assert(ns.ValidGivingText('Helped {count}'))
BuffyLoverDB.givingStyle.text='Helped {count}'; BuffyLoverDB.givingStyle.icon='leaf'
local text=ns.GivingAppearance(42); assert(text:find('Helped 42',1,true) and text:find('|T',1,true))
BuffyLoverDB.showGiving=false
local beforeSounds=sounds; local beforeWidgets=#widgets
originalFloat('target','one','one Surname',300)
assert(sounds==beforeSounds and #widgets==beforeWidgets)
-- Visibility does not stop earning credit.
recipient='hidden-new'; cast('hidden'); assert(ns.GivingCount()==4)
''')
print('PASS: hidden default, persistent choice, formatting/icon validation and tracking while hidden.')

lua.execute('''
BuffyLoverDB.givingStyle.icon='buff'; BuffyLoverDB.givingStyle.text='{count}'
C_Spell={GetSpellTexture=function(id) assert(id==1459); return 135932 end}
assert(ns.GivingAppearance(7,1459):find('|T135932:',1,true))
assert(ns.GivingAppearance(7)=='7')
C_Spell.GetSpellTexture=function() return secret end
assert(ns.GivingAppearance(7,1459)=='7')
C_Spell.GetSpellTexture=function() error('unavailable') end
assert(ns.GivingAppearance(7,1459)=='7')
assert(ns.GivingAppearance(7,secret)=='7')
assert(ns.lastGivenSpell==1459)
''')
print('PASS: actual spell icon, missing/secret/error fallback, latest confirmed spell.')
