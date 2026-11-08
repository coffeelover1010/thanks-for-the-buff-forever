from test_buff_back import lua

lua.execute('''
local db=ThanksForTheBuffForeverDB
local key=ThanksForTheBuffForeverBuffBackKey
local function update() backEvents.scripts.OnUpdate(backEvents,.3) end
local function reset()
 backEvents.scripts.OnEvent(backEvents,"PLAYER_LEAVING_WORLD")
 db.enabled=true; db.buffBack=true; db.buffBackPrompt=false
 db.buffBackQueue=true; db.buffBackDuration=30; db.targetBuffBack=false; db.buffBackSkipPvP=true
 units.target={guid="first",class="PRIEST"}; units.focus={guid="second",class="PRIEST"}
 auras.target={}; auras.focus={}; now=1000
end
function UnitIsPVP(unit) return false end
reset()
-- The binding works with no visible prompt and preserves the selected target.
ns.OfferBuffBack("target","first"); ns.OfferBuffBack("focus","second")
assert(not back.shown and key.attrs.type1=="macro")
assert(key.attrs.macrotext1=="/cast [@target,help,nodead] Spell1460(Rank 2)")
key.scripts.PreClick(key,"LeftButton")
assert(key.attrs.unit=="target" and not back.shown)
-- A click without an observed aura must not consume the offer.
update(); assert(key.attrs.unit=="target")
auras.target={{name="Spell1460",spellId=1460}}
backEvents.scripts.OnEvent(backEvents,"UNIT_AURA","target")
assert(key.attrs.unit=="focus" and key.attrs.type1=="macro","queue did not advance after observed buff")
-- Changing the second giver's PvP flag between display and click blocks it.
function UnitIsPVP(unit) return unit=="focus" end
key.scripts.PreClick(key,"LeftButton"); assert(key.attrs.type1==nil)
assert(ns.GetBuffBackStatus():find("PvP"))
function UnitIsPVP(unit) if unit=="focus" then return secret end return false end
update(); assert(key.attrs.type1==nil,"restricted flag was accepted")
function UnitIsPVP(unit) return false end
update(); assert(key.attrs.type1=="macro","held giver did not resume")
-- Disabling while queued disarms both actions immediately.
db.buffBack=false; ns.RefreshBuffBack(true)
assert(not back.shown and key.attrs.type1==nil)
key.scripts.PreClick(key,"LeftButton"); assert(key.attrs.type1==nil)
reset(); ns.OfferBuffBack("target","first"); ns.OfferBuffBack("target","first")
assert(ns.GetBuffBackStatus():find("1 pending"),"same giver duplicated")
ns.OfferBuffBack("focus","second")
db.buffBackQueue=false; ns.RefreshBuffBack(true); ns.DismissBuffBack()
assert(key.attrs.type1==nil,"turning queue off retained hidden recipients")
reset(); ns.OfferBuffBack("target","first"); ns.OfferBuffBack("focus","second")
now=1030; key.scripts.PreClick(key,"LeftButton"); assert(key.attrs.type1==nil,"expired binding cast")
reset(); ns.OfferBuffBack("target","first"); ns.OfferBuffBack("focus","second")
db.buffBackPrompt=true; ns.RefreshBuffBack(true); assert(back.shown)
back.scripts.PreClick(back,"RightButton",true)
back.scripts.PreClick(back,"RightButton",false)
assert(key.attrs.unit=="focus" and key.attrs.type1=="macro","right click skipped more than one giver")
-- A switched token must not cast on its replacement or silently select the next offer.
reset(); ns.OfferBuffBack("target","first"); ns.OfferBuffBack("focus","second")
units.target={guid="replacement",class="PRIEST"}
key.scripts.PreClick(key,"LeftButton"); assert(key.attrs.type1==nil)
units.nameplate5={guid="first",class="PRIEST"}; update()
assert(key.attrs.unit=="nameplate5" and key.attrs.type1=="macro")
-- Combat clears offers with no insecure attribute changes.
combat=true; backEvents.scripts.OnEvent(backEvents,"PLAYER_REGEN_DISABLED")
key.scripts.PreClick(key,"LeftButton")
combat=false; backEvents.scripts.OnEvent(backEvents,"PLAYER_REGEN_ENABLED")
assert(key.attrs.type1==nil and not back.shown)
''')
print('PASS: hidden binding, queue advancement, duplicate/expiry handling, PvP revalidation, opt-outs, target identity and combat cleanup.')
