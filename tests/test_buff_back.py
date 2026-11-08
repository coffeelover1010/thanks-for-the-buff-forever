from test_click_buff import lua, root

lua.execute('mine="MAGE"; events.scripts.OnEvent(); units.target={guid="giver",class="PRIEST"}; auras.target={}; now=100; ThanksForTheBuffForeverDB.buffBack=true; ThanksForTheBuffForeverDB.buffBackPrompt=true; ThanksForTheBuffForeverDB.buffBackDuration=10; ThanksForTheBuffForeverDB.targetBuffBack=true')
lua.execute('assert(loadstring(...))("ThanksForTheBuffForever",ns)', (root/'ThanksForTheBuffForever'/'BuffBack.lua').read_text(encoding='utf-8'))
lua.execute('''
backEvents=frames[#frames]; backEvents.scripts.OnEvent(backEvents,"PLAYER_LOGIN")
back=ThanksForTheBuffForeverBuffBack
assert(not back.shown)
ns.OfferBuffBack("target","giver")
assert(back.shown and back.attrs.unit=="target" and back.attrs.spell=="Spell1460(Rank 2)")
assert(back.attrs.type1=="macro" and back.attrs.macrotext1=="/target [@target,help,nodead]\\n/cast [@target,help,nodead] Spell1460(Rank 2)")
units.focus={guid="second",class="PRIEST"}; ns.OfferBuffBack("focus","second")
assert(back.attrs.unit=="target","new buff replaced visible offer")
units.target={guid="wrong",class="PRIEST"}
back.scripts.PreClick(back); assert(not back.shown and back.attrs.type1==nil,"cast on changed target")
units.focus={guid="giver",class="PRIEST"}; backEvents.scripts.OnUpdate(backEvents,.2)
assert(back.shown and back.attrs.unit=="focus","failed to resolve original caster")
assert(back.attrs.macrotext1=="/target [@focus,help,nodead]\\n/cast [@focus,help,nodead] Spell1460(Rank 2)","macro did not follow original caster")
auras.focus={{name="Spell1460",spellId=1460}}
back.scripts.PreClick(back); assert(not back.shown and back.attrs.type1==nil)
auras.focus={}; backEvents.scripts.OnUpdate(backEvents,.2); assert(back.shown)
now=110; back.scripts.PreClick(back); assert(not back.shown and back.attrs.type1==nil,"expired offer cast")
auras.target={{name="Spell1460",spellId=1460}}; ns.OfferBuffBack("target","wrong"); assert(not back.shown)
auras.target={}; ns.OfferBuffBack("target","wrong"); assert(back.shown)
combat=true; backEvents.scripts.OnEvent(backEvents,"PLAYER_REGEN_DISABLED")
back.scripts.PreClick(back); backEvents.scripts.OnUpdate(backEvents,.2)
combat=false; backEvents.scripts.OnUpdate(backEvents,.2); assert(not back.shown,"combat offer replayed")
ns.OfferBuffBack("target","wrong"); assert(back.shown)
backEvents.scripts.OnEvent(backEvents,"PLAYER_LEAVING_WORLD"); assert(not back.shown)
''')
print('PASS: buff-back offer, stable recipient, GUID re-resolution, pre-click identity/buff/expiry checks, ten-second timeout, combat and loading-screen cleanup. Protected casting still needs live testing.')
