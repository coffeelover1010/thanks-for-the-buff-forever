from test_behavior import lua

# Reproduces the saved log from 2026-10-11 15:30: on login the first scan sees
# no auras, GetTime() jumps past the quiet window within one real second, and a
# Mark of the Wild carried over from the last session was thanked as new.
lua.execute('''
ns.SetOption("enabled",true); ns.SetOption("group",false)
ns.SetOption("directThanks",true); ns.SetOption("thanksDelay",0)
ns.SetOption("thanksInterval",0); ns.SetOption("playerInterval",0)
local giver="Player-4618-01667CFF"
C_UnitAuras.GetAuraCasterGUID=function() return giver end
GetPlayerInfoByGUID=function() return nil,nil,nil,nil,nil,"Tikiwinki","" end
local wall=105000
GetTimePreciseSec=function() return wall end
local function mark(expires)
 return {name="Mark of the Wild",spellId=1126,auraInstanceID=101,duration=1800,expirationTime=expires}
end
local count=#sent

-- Login: aura data is not loaded at PLAYER_ENTERING_WORLD and GetTime() is stale.
now=101000; auras={}; event("PLAYER_ENTERING_WORLD")
-- One real second later GetTime() has jumped well past now+5.
wall=105001; now=101010
auras={mark(now+1200)}; event("UNIT_AURA","player")
assert(#sent==count,"carried-over login buff thanked inside the quiet window")

-- Even after the quiet window, a buff that has run down is not new.
wall=105100; now=101100
auras={}; event("UNIT_AURA","player")
auras={mark(now+1100)}; event("UNIT_AURA","player")
assert(#sent==count,"partly expired buff thanked as new")

-- A real cast (full duration remaining) is still thanked.
auras={}; event("UNIT_AURA","player")
auras={mark(now+1800)}; event("UNIT_AURA","player")
assert(#sent==count+1 and sent[#sent][2]=="Tikiwinki","fresh buff not thanked")

-- A recast that refreshes the existing aura to full duration is still thanked.
now=101300; wall=105300
auras={mark(now+1800)}; event("UNIT_AURA","player")
assert(#sent==count+2,"refreshed buff not thanked")

-- Wall-clock quiet window also covers a /reload or zone change.
now=102000; wall=106000; auras={}; event("PLAYER_ENTERING_WORLD")
wall=106001; now=102020
auras={mark(now+1800)}; event("UNIT_AURA","player")
assert(#sent==count+2,"buff thanked inside the post-loading quiet window")
GetTimePreciseSec=nil
''')
print('PASS: login carry-over buff, stale GetTime quiet window, partly expired buffs, fresh casts and refreshes.')
