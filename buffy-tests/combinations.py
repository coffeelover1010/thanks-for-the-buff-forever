from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('ns={}')
lua.execute('assert(loadstring(...))("BuffyLover",ns)',(Path(__file__).resolve().parents[1]/'BuffyLover/Responses.lua').read_text(encoding='utf-8'))
lua.execute("""
for _,mode in ipairs({'emote','rp','whisper','both','rp_first','emote_first'}) do
 local db={mode=mode}; ns.InitResponses(db)
 local p=ns.PlanResponses(db,{},'Giver')
 assert(#p==(mode=='both' and 2 or 1))
 assert(p[1].mode==((mode=='both' or mode=='rp_first') and 'rp' or mode=='emote_first' and 'emote' or mode))
end
local db={mode='whisper'}; ns.InitResponses(db)
db.sendEmote=true; db.sendRP=true; db.sendWhisper=true; db.responseStrategy='all'
assert(#ns.PlanResponses(db,{},'Giver')==3)
db.responseOrder='whisper,rp,emote'; db.responseStrategy='priority'
assert(ns.PlanResponses(db,{},'Giver')[1].mode=='whisper')
db.replies.whisper=''; assert(ns.PlanResponses(db,{},'Giver')[1].mode=='rp')
db.responseStrategy='random'
assert(ns.PlanResponses(db,{},'Giver',function(n) return n end)[1].mode=='emote')
db.sendEmote=false; db.sendRP=false; assert(#ns.PlanResponses(db,{},'Giver')==0)
ns.InitResponses(db); assert(not db.sendEmote and not db.sendRP and db.responseStrategy=='random')
""")
print('PASS: legacy migration, all three channels, priority, empty lists, random choice, disabled types and persistence.')
