from test_settings import lua
lua.execute('''
ThanksForTheBuffForeverDB={}; event("ADDON_LOADED","ThanksForTheBuffForever")
local db=ThanksForTheBuffForeverDB
assert(db.buffBack==false and db.buffBackPrompt==false and db.buffBackQueue==false)
assert(db.buffBackSkipPvP==true and db.targetBuffBack==false and db.buffBackDuration==30)
ns.OpenBuffBackSettings()
local count=#widgets
ns.OpenBuffBackSettings(); assert(#widgets==count,"duplicate buff settings page")
local field=ThanksForTheBuffForeverBuffBackDuration
local items=OpenTimingMenu(field)
assert(#items==6)
for _,item in ipairs(items) do item.func(); assert(db.buffBackDuration==item.value) end
ns.SetOption("buffBackDuration",0); assert(db.buffBackDuration==120)
ns.SetOption("buffBackDuration",0/0); assert(db.buffBackDuration==120)
local changed=0
for _,w in ipairs(widgets) do
 if w.kind=="CheckButton" and w.checked==false then
  w:SetChecked(true); w.scripts.OnClick(w); changed=changed+1
 end
end
assert(db.buffBack and db.buffBackPrompt and db.buffBackQueue)
-- Reinitialization preserves explicit choices.
event("ADDON_LOADED","ThanksForTheBuffForever")
assert(db.buffBack and db.buffBackPrompt and db.buffBackQueue and db.buffBackDuration==120)
''')
print('PASS: quiet defaults, separate reusable options page, duration bounds and saved opt-ins.')
