from test_behavior import lua, root

lua.execute('assert(loadstring(...))("ThanksForTheBuffForever",ns)',
            (root/'ThanksForTheBuffForever/Messages.lua').read_text())
lua.execute('''
function UnitRace(u) assert(u=="player"); return "Dwarf","Dwarf" end
function UnitFullName(u) return "Friend","OtherRealm" end
local db=ThanksForTheBuffForeverDB
assert(ns.SaveMessages("WHISPER","ANY","Thank you!"))
assert(ns.SaveMessages("WHISPER","Dwarf","Cheers!\\nA fine blessing!"))
local seen={}
for i=1,100 do
 local mode,text,name=ns.PrepareMessage("target")
 assert(mode=="WHISPER" and name=="Friend-OtherRealm")
 assert(text=="Cheers!" or text=="A fine blessing!"); seen[text]=true
end
assert(seen["Cheers!"] and seen["A fine blessing!"])
assert(ns.SaveMessages("WHISPER","Dwarf","  "))
local mode,text,name=ns.PrepareMessage(nil,"Faraway-Realm")
assert(text=="Thank you!" and name=="Faraway-Realm")
assert(select(2,ns.PrepareMessage(nil))==nil)
assert(not ns.SaveMessages("WHISPER","ANY",string.rep("x",256)))
assert(not ns.SaveMessages("WHISPER","ANY","bad|code"))
assert(db.messages.WHISPER.ANY=="Thank you!")
assert(ns.SaveMessages("EMOTE","ANY","raises a mug in thanks."))
mode,text,name=ns.PrepareMessage("target")
assert(mode=="EMOTE" and text=="raises a mug in thanks." and name==nil)
assert(ns.SaveMessages("BUILTIN","ANY","")); assert(ns.PrepareMessage("target")==nil)
assert(ns.SaveMessages("WHISPER","ANY","Thank you!"))
ns.SetOption("enabled",true); ns.SetOption("group",true)
ns.SetOption("thanksDelay",0); ns.SetOption("thanksInterval",5); ns.SetOption("playerInterval",5)
local calls={}
function SendChatMessage(text,mode,language,recipient)
 calls[#calls+1]={text,mode,recipient}
end
now=10000; auras={}; event("PLAYER_ENTERING_WORLD"); now=10006
local before=#sent
auras={buff("target")}; event("UNIT_AURA","player")
assert(#calls==1 and #sent==before)
assert(calls[1][1]=="Thank you!" and calls[1][2]=="WHISPER" and calls[1][3]=="Friend-OtherRealm")
auras={}; event("UNIT_AURA","player"); auras={buff("target")}; event("UNIT_AURA","player")
assert(#calls==1,"whisper ignored cooldown")
now=10020
function SendChatMessage() error("blocked") end
auras={}; event("UNIT_AURA","player"); auras={buff("target")}; event("UNIT_AURA","player")
function SendChatMessage() calls[#calls+1]={} end
auras={}; event("UNIT_AURA","player"); auras={buff("target")}; event("UNIT_AURA","player")
assert(#calls==1,"blocked message retried within cooldown")
''')
print('PASS: message pools, player race, random choices, fallback, validation, recipient realm, delivery and cooldowns.')
