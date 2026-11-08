from test_behavior import lua
lua.execute('''
ns.SetOption("enabled",true); ns.SetOption("group",true)
ns.SetOption("thanksInterval",0); ns.SetOption("playerInterval",0); ns.SetOption("thanksDelay",0)
now=10000; auras={}; event("PLAYER_ENTERING_WORLD"); now=10006
local function aura(id, source)
 return {name="Shared buff name",spellId=1459,auraInstanceID=id,sourceUnit=source,expirationTime=0}
end
local count=#sent
auras={aura(101,"target")}; event("UNIT_AURA","player"); assert(#sent==count+1)
auras={aura(101,"target"),aura(102,"focus")}; event("UNIT_AURA","player")
assert(#sent==count+2,"distinct same-name aura was missed")
event("UNIT_AURA","player"); assert(#sent==count+2,"unchanged instances were thanked")
auras[1].auraInstanceID=secret; event("UNIT_AURA","player")
assert(#sent==count+2,"withheld identity was thanked under a fallback name")
auras={secret}; event("UNIT_AURA","player")
auras={aura(101,"target"),aura(102,"focus")}; event("UNIT_AURA","player")
assert(#sent==count+2,"restricted scan forgot existing auras")
-- Complete absence must still allow a later fresh application.
auras={}; event("UNIT_AURA","player")
auras={aura(103,"target")}; event("UNIT_AURA","player"); assert(#sent==count+3)
''')
print('PASS: same-name aura identities, duplicates, restricted-scan baseline preservation and reapplications.')
