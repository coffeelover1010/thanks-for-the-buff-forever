"""Run with Python + lupa installed externally; no addon runtime dependencies."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
ns = {CreateSettings=function() end, OpenSettings=function() end}; now = 0; auras = {}; sent = {}; combat = false; secret = {}; locked = false
function issecretvalue(v) return rawequal(v, secret) end
C_Timer={After=function() end}
function GetTime() return now end
function IsInInstance() return true end
function InCombatLockdown() return combat end
C_Secrets = {ShouldAurasBeSecret = function() return locked end}
C_ChatInfo = {InChatMessagingLockdown = function() return locked end}
C_UnitAuras = {GetAuraDataByIndex = function(_, i) if fail then error('restricted') end return auras[i] end}
function UnitGUID(u) if u == 'player' then return 'own' elseif u == 'npc' then return 'npc' else return u end end
function UnitIsPlayer(u) return u ~= 'npc' end
function UnitInParty(u) return u == 'party1' end
function UnitInRaid(u) if u == 'raid1' then return 1 end end
function UnitClass() return 'Mage', 'MAGE' end
function UnitRace() return 'Human', 'Human' end
function UnitSex() return 2 end
function UnitFullName(u) return u, 'Surname' end
function GetUnitName(u, full)
 assert(full == true)
 if u == 'secretname' then return secret end
 if u == 'missingname' then return nil end
 if u == 'emptyname' then return '' end
 return u .. ' Surname'
end
function C_ChatInfo.PerformEmote(e, name) if reject then error('blocked') end sent[#sent+1] = {e, name}; return true end
DEFAULT_CHAT_FRAME = {AddMessage = function() end}; SlashCmdList = {}
function CreateFrame()
 frame = {RegisterEvent = function() end, RegisterUnitEvent = function() end,
 SetScript = function(self, _, fn) self.handler = fn end}; return frame
end
function event(e, u) frame:handler(e, u) end
function aura(id, unit) return {spellId=id, sourceUnit=unit} end
function clear() auras={}; event('UNIT_AURA','player') end
function check(n) assert(#sent==n, 'expected '..n..' sends, got '..#sent) end
''')
for name in ('Buffs.lua', 'Engine.lua', 'Responses.lua', 'GivingStyle.lua', 'Caster.lua', 'Client.lua'):
    lua.execute('assert(loadstring(...))("BuffyLover", ns)', (root / 'BuffyLover' / name).read_text())
lua.execute('''
event('ADDON_LOADED', 'BuffyLover')
BuffyLoverDB.responseStrategy=nil -- legacy-mode regression cases below
BuffyLoverDB.unknownThanks=false
assert(BuffyLoverDB.cooldown == 60 and not BuffyLoverDB.group)
auras={aura(1459,'friend')}; event('PLAYER_ENTERING_WORLD'); check(0)
event('UNIT_AURA','player'); check(0) -- login and duplicate
now=6; event('UNIT_AURA','player'); check(0) -- loading baseline settled
clear(); auras={aura(1459,'friend'),aura(1243,'friend')}; event('UNIT_AURA','player'); check(1)
assert(sent[1][1]=='THANK' and sent[1][2]=='friend Surname')
now=67; auras[1].expirationTime=999; auras[1].auraInstanceID=123
event('UNIT_AURA','player'); check(1) -- refresh past cooldown
clear(); auras={aura(1459,'friend')}; event('UNIT_AURA','player'); check(2)
clear(); auras={aura(1459,'player'),aura(1243,'npc'),aura(1126,nil)}; event('UNIT_AURA','player'); check(2)
clear(); auras={aura(1459,'party1'),aura(1243,'raid1')}; event('UNIT_AURA','player'); check(2)
SlashCmdList.BUFFYLOVER('group on'); clear()
auras={aura(1459,'party1'),aura(1243,'raid1')}; event('UNIT_AURA','player'); check(4)
combat=true; event('PLAYER_REGEN_DISABLED'); clear()
auras={aura(1459,'other')}; event('UNIT_AURA','player'); check(4)
combat=false; event('PLAYER_REGEN_ENABLED'); check(4)
clear(); fail=true; event('UNIT_AURA','player'); fail=false
auras={aura(1459,'other')}; event('UNIT_AURA','player'); check(4)
clear(); auras={aura(secret,'other')}; event('UNIT_AURA','player'); check(4)
auras={aura(1459,'other')}; event('UNIT_AURA','player'); check(4)
clear(); auras={aura(1459,secret)}; event('UNIT_AURA','player'); check(4)
auras={aura(1459,'other')}; event('UNIT_AURA','player'); check(4) -- late caster is not new
clear(); locked=true; auras={aura(1459,'other')}; event('UNIT_AURA','player'); check(4)
locked=false; event('UNIT_AURA','player'); check(4)
SlashCmdList.BUFFYLOVER('off'); clear(); auras={aura(1459,'disabled')}; event('UNIT_AURA','player'); check(4)
SlashCmdList.BUFFYLOVER('on'); check(4)
clear(); auras={aura(999999,'other')}; event('UNIT_AURA','player'); check(4)
clear(); reject=true; auras={aura(1459,'blocked')}; event('UNIT_AURA','player'); check(4)
reject=false; clear(); auras={aura(1459,'blocked')}; event('UNIT_AURA','player'); check(4)
SlashCmdList.BUFFYLOVER('cooldown 120'); SlashCmdList.BUFFYLOVER('debug')
saved=BuffyLoverDB; event('ADDON_LOADED','BuffyLover'); BuffyLoverDB.responseStrategy=nil
assert(BuffyLoverDB==saved and saved.cooldown==120 and saved.debug and saved.group)
SlashCmdList.BUFFYLOVER('cooldown -1'); assert(saved.cooldown==120)
saved.cooldown=0/0; event('ADDON_LOADED','BuffyLover'); BuffyLoverDB.responseStrategy=nil; assert(saved.cooldown==60)
local e=ns.NewEngine(); local s={enabled=true,group=true,cooldown=60}
e:Accept({},0,s); e:Accept({{spell=1459,guid='x'}},0,s); e:Accept({},60,s)
assert(next(e.thanked)==nil) -- expired records cleared
-- Native Forever names must retain the surname, spaces and Unicode exactly.
clear(); auras={aura(1459,'secretname'),aura(1243,'missingname'),aura(1126,'emptyname')}
event('UNIT_AURA','player'); check(4)
clear(); auras={aura(1459,'ÃƒÆ’Ã¢â‚¬Â°lodie')}; event('UNIT_AURA','player'); check(5)
assert(sent[5][2]=='ÃƒÆ’Ã¢â‚¬Â°lodie Surname')
''')
toc = (root / 'BuffyLover/BuffyLover.toc').read_text()
lua.execute('''
local db={mode='rp',random=false,replies={rp='thanks {name}.'},rules={}}
local traits={class='MAGE',race='Human',gender=2}
assert(ns.SelectResponse(db,traits,'First Surname')=='thanks First Surname.')
db.rules={{mode='rp',class='MAGE',race='ANY',gender='ANY',text='class'},
 {mode='rp',class='MAGE',race='Human',gender=2,text='specific'}}
assert(ns.SelectResponse(db,traits,'Giver')=='specific')
assert(ns.SelectResponse(db,{class='PRIEST'},'Giver')=='thanks Giver.')
db.rules[2].text=''; assert(ns.SelectResponse(db,traits,'Giver')==nil)
db.rules={}; db.random=true; db.replies.rp='one\\ntwo'
assert(ns.SelectResponse(db,traits,'Giver',function() return 2 end)=='two')
assert(ns.ValidateLines('THANK\\nBOW','emote'))
assert(not ns.ValidateLines('FAKE','emote'))
assert(not ns.ValidateLines('|Hlink','rp'))
assert(not ns.ValidateLines('{unsupported}','rp'))
db.replies.rp=string.rep('a',250)..'{name}'
assert(ns.SelectResponse(db,traits,'Long Full Name')==nil)
timers={}; C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
function flush() local old=timers; timers={}; for _,fn in ipairs(old) do fn() end end
chat={}; function C_ChatInfo.SendChatMessage(text,channel,_,recipient)
 chat[#chat+1]={text,channel,recipient}
end
BuffyLoverDB.delay=2; BuffyLoverDB.mode='whisper'; BuffyLoverDB.random=false
clear(); auras={aura(1459,'delayed')}; event('UNIT_AURA','player'); assert(#chat==0)
flush(); assert(#chat==1 and chat[1][2]=='WHISPER' and chat[1][3]=='delayed Surname')
clear(); auras={aura(1459,'cancelcombat')}; event('UNIT_AURA','player')
event('PLAYER_REGEN_DISABLED'); flush(); assert(#chat==1)
clear(); auras={aura(1459,'cancelworld')}; event('UNIT_AURA','player')
event('PLAYER_LEAVING_WORLD'); flush(); assert(#chat==1); event('PLAYER_ENTERING_WORLD'); now=now+6; event('UNIT_AURA','player')
clear(); auras={aura(1459,'cancelsettings')}; event('UNIT_AURA','player')
ns.ConfigurationChanged(); flush(); assert(#chat==1)
clear(); auras={aura(1459,'changed')}; event('UNIT_AURA','player')
local oldGuid=UnitGUID; UnitGUID=function(u) if u=='changed' then return 'different' end return oldGuid(u) end
flush(); assert(#chat==1); UnitGUID=oldGuid
BuffyLoverDB.mode='rp'; clear(); auras={aura(1459,'roleplayer')}; event('UNIT_AURA','player')
flush(); assert(#chat==2 and chat[2][2]=='EMOTE' and chat[2][3]==nil)
assert(chat[2][1]:find('roleplayer Surname',1,true))
''')
lua.execute('''
local originalGUID=UnitGUID
UnitGUID=function(u)
 if u=='nameplate1' then return 'known-giver' end
 return u=='player' and 'own' or nil
end
C_UnitAuras.GetAuraCasterGUID=function() return 'known-giver' end
local unit,general=ns.ResolveCaster({auraInstanceID=1})
assert(unit=='nameplate1' and not general)
C_UnitAuras.GetAuraCasterGUID=function() return 'own' end
assert(ns.ResolveCaster({auraInstanceID=1})=='player')
C_UnitAuras.GetAuraCasterGUID=function() return secret end
unit,general=ns.ResolveCaster({auraInstanceID=1}); assert(unit==nil and general==false)
C_UnitAuras.GetAuraCasterGUID=function() error('restricted') end
unit,general=ns.ResolveCaster({auraInstanceID=1}); assert(unit==nil and general==false)
C_UnitAuras.GetAuraCasterGUID=function() return nil end
unit,general=ns.ResolveCaster({auraInstanceID=1}); assert(unit==nil and general==true)
UnitGUID=originalGUID
BuffyLoverDB.delay=0; BuffyLoverDB.mode='whisper'; BuffyLoverDB.unknownThanks=true
now=500; clear(); local before=#sent; local chatBefore=#chat
-- Multiple unknown buffs produce one untargeted THANK, not whispers.
auras={aura(1459,nil),aura(1243,nil)}; event('UNIT_AURA','player')
assert(#sent==before+1 and sent[#sent][1]=='THANK' and sent[#sent][2]=='none')
assert(#chat==chatBefore)
clear(); auras={aura(1459,nil)}; event('UNIT_AURA','player'); assert(#sent==before+1)
now=700; event('UNIT_AURA','player'); assert(#sent==before+1) -- refresh suppressed
clear(); auras={aura(1459,nil)}; event('UNIT_AURA','player'); assert(#sent==before+2)
BuffyLoverDB.unknownThanks=false; now=900; clear()
auras={aura(1459,nil)}; event('UNIT_AURA','player'); assert(#sent==before+2)
''')
lua.execute('''
local e=ns.NewEngine(); local settings={enabled=true,group=true,cooldown=60}
local function update(expiry,at)
 return e:Accept({{spell=1459,guid='giver',expires=expiry}},at,settings)
end
assert(#update(100,0)==0) -- login baseline
assert(#update(180,10)==1) -- first observed rebuff
assert(#update(180,11)==0) -- duplicate
assert(#update(200,20)==0) -- rebuff within cooldown
assert(#update(200,71)==0) -- cooldown expiry alone is not a rebuff
assert(#update(280,72)==1) -- actual renewal after cooldown
assert(#update(nil,140)==0) -- unavailable expiry
assert(#update(400,141)==0) -- learning expiry is not renewal
assert(#update(401,142)==1)
e:Reset(); assert(#update(500,220)==0) -- recovery baseline
''')
lua.execute('''
SlashCmdList.BUFFYLOVER('cooldown 0'); assert(BuffyLoverDB.cooldown==0)
event('ADDON_LOADED','BuffyLover'); BuffyLoverDB.responseStrategy=nil; assert(BuffyLoverDB.cooldown==0)
local e=ns.NewEngine(); local s={enabled=true,group=true,cooldown=0}
e:Accept({},0,s)
local function renewed(expires)
 return e:Accept({{spell=1459,guid='giver',expires=expires}},0,s)
end
assert(#renewed(100)==1 and #renewed(200)==1)
assert(#renewed(200)==0) -- zero cooldown must not turn duplicate events into replies
''')
lua.execute('''
local db={mode='rp_first',random=false,replies={rp='bows to {name}.',emote='CHEER',whisper='Thanks'},rules={}}
local p=ns.PlanResponses(db,{},'Giver')
assert(#p==1 and p[1].mode=='rp')
db.replies.rp=''; p=ns.PlanResponses(db,{},'Giver'); assert(#p==1 and p[1].mode=='emote')
db.replies.rp='bows'; db.mode='emote_first'
p=ns.PlanResponses(db,{},'Giver'); assert(#p==1 and p[1].mode=='emote')
db.replies.emote=''; p=ns.PlanResponses(db,{},'Giver'); assert(#p==1 and p[1].mode=='rp')
db.replies.emote='CHEER'; db.mode='both'; p=ns.PlanResponses(db,{},'Giver')
assert(#p==2 and p[1].mode=='rp' and p[2].mode=='emote')
ns.InitResponses(db); assert(db.mode=='both')
assert(ns.EditResponseMode('both')=='rp')
-- Both produces exactly one of each, then duplicate notifications produce none.
BuffyLoverDB.mode='both'; BuffyLoverDB.delay=0; BuffyLoverDB.cooldown=60
BuffyLoverDB.rules={}; BuffyLoverDB.replies.rp='bows to {name}.'; BuffyLoverDB.replies.emote='CHEER'
now=1200; clear(); local emotesBefore,chatBefore=#sent,#chat
auras={aura(1459,'bothgiver')}; event('UNIT_AURA','player')
assert(#sent==emotesBefore+1 and #chat==chatBefore+1)
assert(sent[#sent][1]=='CHEER' and chat[#chat][2]=='EMOTE')
event('UNIT_AURA','player'); assert(#sent==emotesBefore+1 and #chat==chatBefore+1)
local sendChat=C_ChatInfo.SendChatMessage
C_ChatInfo.SendChatMessage=function() error('blocked') end
clear(); auras={aura(1459,'otherbothgiver')}; event('UNIT_AURA','player')
assert(#sent==emotesBefore+2) -- independent attempt despite RP error
C_ChatInfo.SendChatMessage=sendChat
BuffyLoverDB.cooldown=0
''')
lua.execute('''
now=2000; BuffyLoverDB.mode='emote'; BuffyLoverDB.cooldown=0; BuffyLoverDB.delay=0
local before=#sent
-- An empty world-entry snapshot followed by staggered restored auras must stay quiet.
event('LOADING_SCREEN_ENABLED'); auras={}; event('PLAYER_ENTERING_WORLD')
now=2001; auras={aura(1459,'loadinggiver')}; event('UNIT_AURA','player')
now=2003; auras[2]=aura(1243,'loadinggiver'); event('UNIT_AURA','player')
assert(#sent==before)
now=2006; flush(); assert(#sent==before)
clear(); auras={aura(1459,'freshgiver')}; event('UNIT_AURA','player'); assert(#sent==before+1)
-- Pending thanks cannot survive the start of a loading screen.
BuffyLoverDB.delay=2; clear(); auras={aura(1459,'queuedgiver')}; event('UNIT_AURA','player')
event('LOADING_SCREEN_ENABLED'); flush(); assert(#sent==before+1)
event('PLAYER_ENTERING_WORLD'); now=2012; flush()
BuffyLoverDB.delay=0
''')
lua.execute('''
local offers={}
ns.OfferBuffBack=function(unit,guid) offers[#offers+1]={unit,guid} end
BuffyLoverDB.buffBack=true; BuffyLoverDB.enabled=false
ns.ConfigurationChanged()
clear(); auras={aura(1459,'returngiver')}; event('UNIT_AURA','player')
assert(#offers==1 and offers[1][1]=='returngiver', 'buff back depended on thanks')
event('UNIT_AURA','player'); assert(#offers==1, 'duplicate return offer')
clear(); auras={aura(1459,'party1')}; event('UNIT_AURA','player'); assert(#offers==2)
BuffyLoverDB.buffBack=false; ns.ConfigurationChanged()
clear(); auras={aura(1459,'disabledreturn')}; event('UNIT_AURA','player'); assert(#offers==2)
BuffyLoverDB.buffBack=true; ns.ConfigurationChanged()
event('LOADING_SCREEN_ENABLED'); event('PLAYER_ENTERING_WORLD')
now=now+6; flush(); assert(#offers==2,'login buffs offered')
clear(); auras={aura(1459,nil)}; event('UNIT_AURA','player'); assert(#offers==2,'unknown giver offered')
ns.OfferBuffBack=nil
''')
# A passing giver can be thanked without a target or visible nameplate.
lua.execute('''
local oldGUID=UnitGUID
UnitGUID=function(unit) return unit=='player' and 'own' or nil end
GetPlayerInfoByGUID=function(guid)
 assert(guid=='Player-passer'); return nil,nil,nil,nil,nil,'Passing Mage','Realm'
end
C_UnitAuras.GetAuraCasterGUID=function() return 'Player-passer' end
local unit,general,guid,name=ns.ResolveCaster({auraInstanceID=22})
assert(unit==nil and general==false and guid=='Player-passer' and name=='Passing Mage')
BuffyLoverDB.enabled=true; BuffyLoverDB.group=false; BuffyLoverDB.mode='emote'; BuffyLoverDB.delay=0
now=5000; clear(); local before=#sent
auras={{spellId=1459,auraInstanceID=22}}; event('UNIT_AURA','player')
assert(#sent==before+1 and sent[#sent][2]=='Passing Mage')
UnitGUID=function(unit) if unit=='party1' then return 'Player-passer' end return unit=='player' and 'own' or nil end
assert(ns.CasterGroupFromGUID('Player-passer')==true)
now=5100; clear(); auras={{spellId=1459,auraInstanceID=22}}; event('UNIT_AURA','player')
assert(#sent==before+1)
GetPlayerInfoByGUID=function() return nil,nil,nil,nil,nil,secret end
assert(ns.CasterNameFromGUID('Player-passer')==nil)
GetPlayerInfoByGUID=function() error('unavailable') end
assert(ns.CasterNameFromGUID('Player-passer')==nil)
UnitGUID=oldGUID; GetPlayerInfoByGUID=nil; C_UnitAuras.GetAuraCasterGUID=nil
''')

# Active chat input no longer delays replies, even with legacy settings.
lua.execute(''' 
BuffyLoverDB.enabled=true; BuffyLoverDB.mode='emote'; BuffyLoverDB.delay=0
BuffyLoverDB.waitWhileTyping=true; BuffyLoverDB.typingWaitSeconds=1
now=6000; clear(); timers={}; local before=#sent
ChatFrameUtil={GetActiveWindow=function() error('Chat input must not be inspected') end}
auras={aura(1459,'typing-giver')}; event('UNIT_AURA','player')
assert(#sent==before+1 and sent[#sent][2]=='typing-giver Surname' and #timers==0)
local config={waitWhileTyping=true,typingWaitSeconds=1}
ns.InitResponses(config); assert(config.waitWhileTyping==nil and config.typingWaitSeconds==nil)
ChatFrameUtil=nil
''')

lua.execute('''
for i=1,35 do frame:handler('ADDON_ACTION_BLOCKED','ExampleAddon','BlockedAction') end
assert(#BuffyLoverDB.activityLog==30)
assert(BuffyLoverDB.activityLog[30]:find('ExampleAddon',1,true))
assert(BuffyLoverDB.activityLog[30]:find('BlockedAction',1,true))
SlashCmdList.BUFFYLOVER('log')
''')

lua.execute('''
local offered
ns.OfferManualReply=function(guid,name,text,valid) offered={guid,name,text,valid} end
IsInInstance=function() return false end
BuffyLoverDB.mode='rp'; BuffyLoverDB.enabled=true; BuffyLoverDB.delay=0
now=7000; clear(); local before=#chat
auras={aura(1459,'click-giver')}; event('UNIT_AURA','player')
assert(#chat==before and offered[2]=='click-giver Surname' and offered[4]())
ns.ConfigurationChanged(); assert(not offered[4]())
IsInInstance=function() return true end
''')

# Smoke-test actual settings construction, registration and editor callbacks.
lua.execute('''
widgets={}
local methods={}
function methods:SetText(v) self.text=v end
function methods:SetShown(v) self.shown=v end
function methods:SetEnabled(v) self.enabled=v end
function methods:GetText() return self.text or '' end
function methods:SetScript(k,v) self[k]=v end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:CreateFontString() return CreateFrame('FontString') end
function CreateFrame(kind)
 local w=setmetatable({kind=kind},{__index=function(_,k) return methods[k] or function() end end})
 widgets[#widgets+1]=w; return w
end
Settings={RegisterCanvasLayoutCategory=function(panel,name)
 assert(name=='BuffyLove'); settingsPanel=panel; return {GetID=function() return 123 end}
end,RegisterCanvasLayoutSubcategory=function(parent,panel,name)
 assert(parent:GetID()==123)
 assert(name=='Buff count' or name=='Buff back' or name=='Saved rules' or name=='Responses')
 subcategories=(subcategories or 0)+1
 return {GetID=function() return 123+subcategories end}
end,RegisterAddOnCategory=function() registered=true end,
OpenToCategory=function(id) assert(id==123); opened=true end}
''')
lua.execute('assert(loadstring(...))("BuffyLover", ns)', (root / 'BuffyLover/Settings.lua').read_text(encoding='utf-8'))
lua.execute('''
ns.CreateSettings(); assert(registered and subcategories==4); settingsPanel:OnShow(); ns.OpenSettings(); assert(opened)
function click(text)
 for _,w in ipairs(widgets) do if w.kind=='Button' and w.text==text then w:OnClick(); return end end
 error('Button missing: '..text)
end
local classFilter, deleteButton
for _,w in ipairs(widgets) do
 if w.kind=='Button' and w.text=='Any class' then classFilter=w end
 if w.kind=='Button' and w.text=='Delete rule' then deleteButton=w end
end
assert(classFilter and classFilter.shown==false and deleteButton.enabled==false)
click('Add character rule')
assert(classFilter.shown==true and deleteButton.enabled==true)
click('Save list'); click('Preview saved response'); click('Delete rule')
assert(classFilter.shown==false and deleteButton.enabled==false)
click('Default replies')
for _,w in ipairs(widgets) do
 if w.kind=='EditBox' and (w.text=='0' or w.text==tostring(BuffyLoverDB.delay)) then w:SetText('0') end
end
click('Apply timing'); assert(BuffyLoverDB.cooldown==0 and BuffyLoverDB.delay==0)
 click('Apply appearance'); click('Preview saved style')
assert(ns.previewWindow.heading.text=='Saved buff-count style')
click('Rank-up sound: Level up'); assert(BuffyLoverDB.givingSoundID==878)
local previewedSound
PlaySound=function(id,channel) previewedSound=id; assert(channel=='SFX') end
click('Preview sound'); assert(previewedSound==878)
ns.InitGivingStyle(BuffyLoverDB); assert(BuffyLoverDB.givingSoundID==878)
local appearanceFields=0
for _,w in ipairs(widgets) do
 if w.kind=='EditBox' and rawget(w,'OnShow') and rawget(w,'OnEditFocusLost') then
  w:OnShow(); local saved=w:GetText(); assert(saved and saved~='')
  w:SetText(''); w:OnEditFocusLost(); assert(w:GetText()==saved)
  w:SetText('draft'); w:OnEnterPressed(); assert(w:GetText()=='draft')
  w:OnEscapePressed(); assert(w:GetText()==saved)
  appearanceFields=appearanceFields+1
 end
end
assert(appearanceFields==2)
local beforeRankPreview=ns.GivingCount and ns.GivingCount() or 0
click('Preview next rank')
assert(ns.previewWindow.heading.text=='Next buff rank preview')
assert(ns.previewWindow.message.text:find('PvPRank01',1,true))
assert((ns.GivingCount and ns.GivingCount() or 0)==beforeRankPreview)
click('Preview saved response')
assert(ns.previewWindow.heading.text=='Saved response for this character')
assert(ns.previewWindow.message.text:find('Kind Traveller',1,true))
local foundRules=false
for _,widget in ipairs(widgets) do
 if type(widget.text)=='string' and widget.text:find('Saved response rules',1,true) then
  assert(widget.text:find('General fallback',1,true) and widget.text:find('winner:',1,true))
  foundRules=true
 end
end
assert(foundRules)
local db={mode='emote',random=false,replies={emote='THANK'},rules={
 {mode='emote',class='MAGE',race='ANY',gender='ANY',text='BOW'},
 {mode='emote',class='MAGE',race='Human',gender='ANY',text=''}}}
local reply,_,winner=ns.SelectResponse(db,{class='MAGE',race='Human'},'Test')
assert(reply==nil and winner==2)
db.rules[2].text='SALUTE'
reply,_,winner=ns.SelectResponse(db,{class='MAGE',race='Human'},'Test')
assert(reply=='SALUTE' and winner==2)

local duration
for _,w in ipairs(widgets) do if w.kind=='EditBox' and w.text=='30' then duration=w end end
assert(duration,'duration setting missing')
duration:SetText('5'); click('Apply duration'); assert(BuffyLoverDB.buffBackDuration==5)
duration:SetText('121'); click('Apply duration'); assert(BuffyLoverDB.buffBackDuration==5)
local moved,reset=0,0
ns.ToggleBuffBackPlacement=function() moved=moved+1 end
ns.ResetBuffBackPosition=function() reset=reset+1 end
click('Move / preview icons'); click('Reset position'); assert(moved==1 and reset==1)
combat=true; click('Move / preview icons'); click('Reset position'); assert(moved==1 and reset==1)
combat=false

local numbers={}
for _,w in ipairs(widgets) do if w.kind=='EditBox' and rawget(w,'OnArrowPressed') then numbers[#numbers+1]=w end end
assert(#numbers==4)
local cooldown,delay,size,duration=numbers[1],numbers[2],numbers[3],numbers[4]
cooldown:SetText('123'); cooldown:OnEnterPressed()
assert(BuffyLoverDB.cooldown==123 and cooldown:GetText()=='123')
delay:SetText('2.5'); delay:OnEditFocusLost()
assert(BuffyLoverDB.delay==2.5 and delay:GetText()=='2.5')
delay:SetText(''); delay:OnEditFocusLost()
assert(BuffyLoverDB.delay==2.5 and delay:GetText()=='2.5')
cooldown:SetText('999'); cooldown:OnEscapePressed()
assert(cooldown:GetText()=='123' and BuffyLoverDB.cooldown==123)
cooldown:SetText('2000'); cooldown:OnArrowPressed('UP')
assert(cooldown:GetText()=='2000' and BuffyLoverDB.cooldown==2000)
delay:SetText('0'); delay:OnArrowPressed('DOWN'); assert(BuffyLoverDB.delay==0)
size:SetText('21.8'); size:OnEnterPressed(); assert(size:GetText()=='21' and BuffyLoverDB.givingStyle.size==21)
duration:SetText('45'); duration:OnHide(); assert(duration:GetText()=='45' and BuffyLoverDB.buffBackDuration==45)
settingsPanel:OnShow(); assert(cooldown:GetText()=='2000' and delay:GetText()=='0')

''')
assert '## Interface: 16001' in toc and '## SavedVariables: BuffyLoverDB' in toc
for line in toc.splitlines():
    if line and not line.startswith('#'):
        assert (root / 'BuffyLover' / line).is_file()
print('PASS: Lua 5.1; detection, RP rules, validation, whispers, delay cancellation, settings UI smoke and TOC.')

lua.execute('''
BuffyLoverDB.givingLifetime={total=233,people={Tester=true}}
BuffyLoverDB.cooldown=123
assert(not ns.ResetSettings('reset') and BuffyLoverDB.cooldown==123)
combat=true; assert(not ns.ResetSettings('RESET'))
combat=false; assert(ns.ResetSettings('RESET'))
assert(BuffyLoverDB.cooldown==60)
assert(BuffyLoverDB.givingLifetime.total==233 and BuffyLoverDB.givingLifetime.people.Tester)
''')
print('PASS: settings reset requires confirmation, blocks combat and preserves lifetime ledger.')

# Wisdom detection uses the same path for every normal/greater rank.
lua.execute('''
local settings={enabled=true,group=true,cooldown=40}
for _,id in ipairs({19742,19850,19852,19853,19854,25290,25894,25918}) do
 assert(ns.buffs[id],"Wisdom rank missing")
 local e=ns.NewEngine(); e:Accept({},0,settings)
 assert(#e:Accept({{spell=id,guid="paladin",expires=3600}},10,settings)==1)
end
local output={}
DEFAULT_CHAT_FRAME.AddMessage=function(_,message) output[#output+1]=message end
combat=false; locked=false; fail=false
auras={{spellId=19850,name="Blessing of Wisdom",sourceUnit="paladin"}}
SlashCmdList.BUFFYLOVER("auras")
assert(output[2]:find("ID=19850; recognised=true; caster=paladin",1,true))
output={}; combat=true; SlashCmdList.BUFFYLOVER("auras")
assert(#output==1 and output[1]:find("paused",1,true))
combat=false
''')
print('PASS: all Wisdom rank IDs, engine eligibility and guarded live aura diagnostic.')

lua.execute('''
combat=false
BuffyLoverDB.givingLifetime={total=999,people={Keep=true}}
local ledger=BuffyLoverDB.givingLifetime
BuffyLoverDB.cooldown=123; BuffyLoverDB.targetShape="circle"
BuffyLoverDB.sendWhisper=true; BuffyLoverDB.responseStrategy="all"
BuffyLoverDB.rules={{mode="rp",text="keep",class="ANY",race="ANY",gender="ANY"}}
local rules=BuffyLoverDB.rules
assert(not ns.ResetPageSettings("responses","no"))
combat=true; assert(not ns.ResetPageSettings("responses","RESET")); combat=false
assert(ns.ResetPageSettings("responses","RESET"))
assert(BuffyLoverDB.sendEmote and not BuffyLoverDB.sendWhisper and BuffyLoverDB.responseStrategy=="priority")
assert(BuffyLoverDB.cooldown==123 and BuffyLoverDB.rules==rules and BuffyLoverDB.targetShape=="circle")
BuffyLoverDB.givingStyle={font="damage",size=40,text="custom",color="FF0000",icon="heart"}
assert(ns.ResetPageSettings("count","RESET"))
assert(BuffyLoverDB.givingStyle.size==20 and BuffyLoverDB.cooldown==123)
assert(BuffyLoverDB.givingLifetime==ledger and ledger.total==999)
assert(ns.ResetPageSettings("rules","RESET") and #BuffyLoverDB.rules==0)
assert(BuffyLoverDB.cooldown==123)
assert(ns.ResetPageSettings("general","RESET") and BuffyLoverDB.cooldown==60)
assert(BuffyLoverDB.targetShape=="circle" and BuffyLoverDB.givingLifetime==ledger)
assert(not ns.ResetPageSettings("typo","RESET"))
local bindings={F8="CLICK BuffyLoverTargetBuff:LeftButton",F9="BUFFYLOVER_TARGET_SOURCES",SPACE="JUMP"}
function GetBindingKey(command) for key,value in pairs(bindings) do if value==command then return key end end end
function SetBinding(key) bindings[key]=nil end
function GetCurrentBindingSet() return 2 end
local saves=0
function SaveBindings(set) assert(set==2); saves=saves+1 end
assert(ns.ResetPageSettings("target","RESET"))
assert(not bindings.F8 and not bindings.F9 and bindings.SPACE=="JUMP" and saves==1)
assert(BuffyLoverDB.givingLifetime==ledger)
''')
print('PASS: page reset isolation, defaults, confirmation/combat guards, lifetime preservation and scoped shortcut clearing.')
