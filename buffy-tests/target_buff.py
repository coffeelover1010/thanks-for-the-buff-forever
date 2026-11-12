"""Target casting and source attribution using the shared buff-back API harness."""
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
lua = runpy.run_path(str(Path(__file__).resolve().parent / 'buff_back.py'))['lua']
lua.execute('''
combat=false; mine="MAGE"; auras={}; BuffyLoverDB={}; UISpecialFrames={}
units.target={guid="target-one",class="PRIEST"}
function GetCursorPosition() return 300,400 end
function UnitIsPVP() return false end
function UnitIsPVPFreeForAll() return false end
''')
lua.execute('assert(loadstring(...))("BuffyLover",ns)', (root/'BuffyLover/TargetBuff.lua').read_text())
lua.execute('''
ns.RebuildReturnSpells(); ns.InitTargetBuff(BuffyLoverDB)
local b=BuffyLoverTargetBuff
assert(not b.attrs.type1, "feature defaults off")
BuffyLoverDB.targetBuff=true; BuffyLoverDB.targetCursor=true
ns.RefreshTargetBuff(true)
assert(b.attrs.type1=="macro" and b.attrs.macrotext1:find("@target,help,nodead",1,true))
assert(b.point[4]==284 and b.point[5]==382)
assert(BuffyLoverDB.targetNPCs==true)
units.target.npc=true
b.scripts.PreClick(); assert(b.attrs.type1=="macro","friendly NPC must be offered a buff by default")
assert(#ns.GetMissingBuffs("target")==0,"buff-back remains player-only")
BuffyLoverDB.targetNPCs=false
b.scripts.PreClick(); assert(not b.attrs.type1,"NPC toggle must disable casting")
BuffyLoverDB.targetNPCs=true
units.target.enemy=true
b.scripts.PreClick(); assert(not b.attrs.type1,"hostile NPC must not cast")
units.target.enemy=false; units.target.dead=true
b.scripts.PreClick(); assert(not b.attrs.type1,"dead NPC must not cast")
units.target.dead=false
auras.target={{name="Spell1460",spellId=1460}}
b.scripts.PreClick(); assert(not b.attrs.type1,"already buffed NPC must not cast")
units.target.npc=false
auras.target={{name="Spell1460",spellId=1460,sourceUnit="player"}}
b.scripts.PreClick(); assert(not b.attrs.type1,"already buffed target must not cast")
auras.target={}; units.target.enemy=true
b.scripts.PreClick(); assert(not b.attrs.type1,"hostile target must not cast")
units.target.enemy=false; units.target.dead=true
b.scripts.PreClick(); assert(not b.attrs.type1,"dead target must not cast")
units.target.dead=false
function UnitIsPVP(u) return u=="target" end
b.scripts.PreClick(); assert(not b.attrs.type1,"PvP target must not flag player")
function UnitIsPVP() return false end
b.scripts.PreClick(); assert(b.attrs.type1=="macro")
BuffyLoverDB.targetCursor=false; ns.RefreshTargetBuff(false)
assert(b.attrs.type1=="macro","shortcut works independently of cursor display")
combat=true; ns.RefreshTargetBuff(true); b.scripts.PreClick()
combat=false; BuffyLoverDB.targetBuff=false; b.scripts.PreClick(); assert(not b.attrs.type1)
auras.target={{name="Intellect",sourceUnit="player"},{name="Fortitude"}}
local result=ns.TargetBuffSourceText()
assert(result:find("Intellect  -  me",1,true))
assert(result:find("Fortitude  -  Unknown / unavailable",1,true))
auras.target={{name=secret}}
assert(ns.TargetBuffSourceText():find("unavailable",1,true))
units.target=nil
assert(ns.TargetBuffSourceText():find("Select someone",1,true))
''')
print('PASS: target selection, missing buffs, PvP, combat writes, hidden-button shortcut and source attribution.')
lua.execute('''
local make=CreateFrame
function CreateFrame(...)
 local f=make(...)
 f.GetStringHeight=function() return 200 end
 f.TitleText={SetText=function() end}
 return f
end
bindings={}; saves=0
function GetBindingKey(command) for key,value in pairs(bindings) do if value==command then return key end end end
function GetBindingAction(key) return bindings[key] or "" end
function SetBinding(key,command) bindings[key]=command; return true end
function SaveBindings() saves=saves+1 end
function GetCurrentBindingSet() return 2 end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function IsShiftKeyDown() return false end
Settings={RegisterCanvasLayoutSubcategory=function(_,panel) targetPanel=panel end}
ns.CreateTargetSettings({}); targetPanel.scripts.OnShow()
local binder
for _,frame in ipairs(frames) do
 if type(frame.text)=="string" and frame.text:find("Buff target:",1,true) then binder=frame end
end
assert(binder)
binder.scripts.OnClick(binder); binder.scripts.OnKeyDown(binder,"F8")
assert(bindings.F8=="CLICK BuffyLoverTargetBuff:LeftButton" and saves==1)
bindings.F9="JUMP"; binder.scripts.OnKeyDown(binder,"F9")
assert(bindings.F9=="JUMP" and saves==1)
binder.scripts.OnKeyDown(binder,"F10")
assert(not bindings.F8 and bindings.F10 and saves==2)
combat=true; binder.scripts.OnKeyDown(binder,"F11"); assert(not bindings.F11)
combat=false
ns.ToggleTargetSources(); assert(BuffyLoverTargetSources:IsShown())
ns.ToggleTargetSources(); assert(not BuffyLoverTargetSources:IsShown())
local b=BuffyLoverTargetBuff
b.scripts.PostClick(b,"LeftButton",false); assert(not BuffyLoverTargetSources:IsShown())
b.scripts.PostClick(b,"RightButton",true); assert(not BuffyLoverTargetSources:IsShown())
b.scripts.PostClick(b,"RightButton",false); assert(BuffyLoverTargetSources:IsShown())
assert(not b.attrs.type2,"right-click must not cast")
''')
print('PASS: settings construction, shortcut conflicts/replacement/combat guard and source-window toggle.')

lua.execute('''
local b=BuffyLoverTargetBuff
units.target={guid="pet-one",class="MAGE",npc=true}; auras.target={}
BuffyLoverDB.targetBuff=true; BuffyLoverDB.targetCursor=true; BuffyLoverDB.targetNPCs=true
function UnitPlayerControlled(u) return u=="target" end
ns.RefreshTargetBuff(false); assert(not b.available and not b.attrs.type1)
units.partypet1=units.target
ns.RefreshTargetBuff(false); assert(not b.available and not b.attrs.type1,"group pets must not be offered buffs")
units.partypet1=nil; units.pet=units.target
ns.RefreshTargetBuff(false); assert(not b.available and not b.attrs.type1,"own pets must not be offered buffs")
units.pet=nil
function UnitPlayerControlled() return false end
units.target.guid="Pet-0-123"
ns.RefreshTargetBuff(false); assert(not b.available and not b.attrs.type1,"pet GUID must also be rejected")
units.target.guid="friendly-npc"
C_Spell.IsSpellInRange=function() return false end
ns.RefreshTargetBuff(false); assert(not b.available and not b.attrs.type1)
C_Spell.IsSpellInRange=function() return true end
C_Spell.IsSpellUsable=function() return false end
ns.RefreshTargetBuff(false); assert(not b.available)
C_Spell.IsSpellUsable=function() return true end
ns.RefreshTargetBuff(false); assert(b.available)
assert(BuffyLoverDB.targetHideUnavailable==true)
local alpha,mouse
b.SetAlpha=function(_,v) alpha=v end
b.EnableMouse=function(_,v) mouse=v end
C_Spell.IsSpellInRange=function() return false end
ns.RefreshTargetBuff(false); assert(alpha==0 and mouse==false)
BuffyLoverDB.targetHideUnavailable=false
ns.RefreshTargetBuff(false); assert(alpha==1 and mouse==true and not b.attrs.type1)
BuffyLoverDB.targetIconSize=48; BuffyLoverDB.targetOffsetX=20; BuffyLoverDB.targetOffsetY=-40
ns.RefreshTargetBuff(true); assert(b.width==48 and b.point[4]==296 and b.point[5]==360)
''')
print('PASS: own/group/ungrouped pets, range, usability, default hiding, optional disabled icon and size/offsets.')

lua.execute('''
C_Spell.IsSpellInRange=function() return nil end
local b=BuffyLoverTargetBuff
ns.RefreshTargetBuff(false); assert(b.available and b.attrs.type1=="macro")
assert(ns.TargetBuffDiagnostic():find("Ready:",1,true))
C_Spell.IsSpellInRange=function(id) if type(id)=="number" then return nil end return false end
ns.RefreshTargetBuff(false); assert(not b.available)
assert(ns.TargetBuffDiagnostic():find("out of range",1,true))
''')
print('PASS: unknown NPC range remains eligible; explicit ranked-name range rejection still blocks.')

lua.execute('''
local b=BuffyLoverTargetBuff
BuffyLoverDB.targetPosition="screen"; ns.RefreshTargetBuff(true)
assert(b.point[1]=="CENTER" and b.point[2]==UIParent and b.point[4]==20 and b.point[5]==-40)
BuffyLoverDB.targetPosition="target"; ns.RefreshTargetBuff(true)
assert(b.point[1]=="TOP" and b.point[2]==TargetFrame and b.point[3]=="BOTTOM")
BuffyLoverDB.targetPosition="cursor"; ns.RefreshTargetBuff(true)
assert(b.point[1]=="TOPLEFT" and b.point[4]==296 and b.point[5]==360)
''')
print('PASS: screen, target-frame and cursor positioning with saved offsets.')

# Forever-specific pet spell filtering, separate from general NPC eligibility.
lua.execute('''
combat=false; mine="MAGE"; auras.target={}
BuffyLoverDB.targetBuff=true; BuffyLoverDB.targetNPCs=true
units.target={guid="Pet-0-1",class="WARRIOR",npc=true,level=60}
units.pet=units.target
local oldLevel=C_Spell.GetSpellLevelLearned
C_Spell.GetSpellLevelLearned=function(id)
 if id==604 then return 12 elseif id==8450 then return 24 elseif id==467 or id==1126 then return 1 end
 return oldLevel(id)
end
known[604]=true; known[8450]=true
ns.RebuildReturnSpells()
local buffs=ns.GetMissingBuffs("target",true)
assert(#buffs==1 and buffs[1].id==8450,"pet gets Dampen, never Intellect")
units.target.level=2
buffs=ns.GetMissingBuffs("target",true)
assert(#buffs==1 and buffs[1].id==604,"pet gets level-appropriate Dampen rank")
units.target.level=60
auras.target={{name="Dampen",spellId=604}}
assert(#ns.GetMissingBuffs("target",true)==0,"existing Dampen rank is respected")
auras.target={{name="Amplify",spellId=1008}}
assert(#ns.GetMissingBuffs("target",true)==0,"Amplify must not be overwritten")
auras.target={}; units.pet=nil
assert(#ns.GetMissingBuffs("target",true)==0,"Dampen not offered outside own/group pets")
units.raidpet3=units.target
assert(#ns.GetMissingBuffs("target",true)==1,"raid pet accepts Dampen")
assert(#ns.GetMissingBuffs("target")==0,"buff-back remains player-only")
BuffyLoverDB.targetNPCs=false
BuffyLoverTargetBuff.scripts.PreClick(); assert(not BuffyLoverTargetBuff.attrs.type1)
BuffyLoverDB.targetNPCs=true
mine="DRUID"; known[467]=true; known[1126]=true; ns.RebuildReturnSpells()
buffs=ns.GetMissingBuffs("target",true)
assert(#buffs==1 and buffs[1].id==467,"pet gets Thorns, never Mark")
units.raidpet3=nil
assert(#ns.GetMissingBuffs("target",true)==1,"Thorns allowed for ungrouped friendly pet")
mine="PRIEST"; ns.RebuildReturnSpells()
assert(#ns.GetMissingBuffs("target",true)==0,"unverified priest pet spells excluded")
mine="PALADIN"; ns.RebuildReturnSpells()
assert(#ns.GetMissingBuffs("target",true)==0,"stat blessings excluded for pets")
mine="MAGE"; units.target={guid="Player-1",class="PRIEST"}; ns.RebuildReturnSpells()
buffs=ns.GetMissingBuffs("target",true)
assert(#buffs==1 and buffs[1].id==1460,"player still gets Intellect, not Dampen")
''')
print('PASS: Forever pet spell allowlist, Dampen rank/group restrictions, existing magic buffs, stat exclusions and player regression.')

lua.execute('''
local b=BuffyLoverTargetBuff
BuffyLoverDB.targetShape="bad"; BuffyLoverDB.targetBorderWidth=99
BuffyLoverDB.targetOpacity=0/0; BuffyLoverDB.targetBorderColor="oops"
ns.InitTargetBuff(BuffyLoverDB)
assert(BuffyLoverDB.targetShape=="square" and BuffyLoverDB.targetBorderWidth==0)
assert(BuffyLoverDB.targetOpacity==100 and BuffyLoverDB.targetBorderColor=="FFD700")
local texture,opacity,colour
b.shapeMask.SetTexture=function(_,v) texture=v end
b.SetAlpha=function(_,v) opacity=v end
b.border.SetVertexColor=function(_,r,g,blue) colour={r,g,blue} end
BuffyLoverDB.targetCursor=true; BuffyLoverDB.targetHideUnavailable=false
BuffyLoverDB.targetShape="rounded"; BuffyLoverDB.targetBorderWidth=3
BuffyLoverDB.targetOpacity=60; BuffyLoverDB.targetBorderColor="00FF00"
ns.RefreshTargetBuff(false)
assert(texture:find("IconMask-rounded.tga",1,true) and opacity==.6)
assert(colour[1]==0 and colour[2]==1 and colour[3]==0)
assert(b.icon.point[4]==-3 and b.icon.point[5]==3)
combat=true; BuffyLoverDB.targetShape="circle"; ns.RefreshTargetBuff(false)
assert(texture:find("rounded",1,true),"appearance writes must wait until out of combat")
combat=false; ns.RefreshTargetBuff(false)
assert(texture:find("circle",1,true))
targetPanel.scripts.OnShow()
local shapeButton
for _,f in ipairs(frames) do if f.text=="Shape: Circle" then shapeButton=f end end
assert(shapeButton); shapeButton.scripts.OnClick()
assert(BuffyLoverDB.targetShape=="square")
''')
print('PASS: appearance defaults, masks, border colour/inset, opacity, saved shape control and combat deferral.')
