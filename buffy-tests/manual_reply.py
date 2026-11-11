from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
ns={}; now=0; sent={}; allowed=true
function GetTime() return now end
local methods={}
function methods:SetText(v) self.text=v end
function methods:SetScript(k,v) self[k]=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:CreateFontString() return CreateFrame() end
function CreateFrame()
 return setmetatable({},{__index=function(_,k) return methods[k] or function() end end})
end
C_ChatInfo={SendChatMessage=function(text,channel)
 assert(clicked,'send must occur in click handler'); sent[#sent+1]={text,channel}
end}
function offer(guid)
 ns.OfferManualReply(guid,guid,'bows to '..guid,function() return allowed end,function() end)
end
""")
lua.execute('assert(loadstring(...))("BuffyLover",ns)',(Path(__file__).resolve().parents[1]/'BuffyLover/ManualReply.lua').read_text(encoding='utf-8'))
lua.execute("""
offer('one'); offer('one'); assert(#sent==0)
local f=ns.manualReplyFrame
assert(f.shown and f.text.text=='bows to one')
clicked=true; f.send:OnClick(); clicked=false
assert(#sent==1 and sent[1][2]=='EMOTE' and not f.shown)
f.send:OnClick(); assert(#sent==1)
offer('two'); allowed=false; f.send:OnClick(); assert(#sent==1)
allowed=true; offer('expired'); now=31; f:OnUpdate(); assert(not f.shown)
offer('dismiss'); f.dismiss:OnClick(); assert(not f.shown and #sent==1)
for i=1,6 do offer('queue'..i) end
assert(f.title.text:find('5 waiting',1,true))
ns.ClearManualReplies(); assert(not f.shown)
""")
print('PASS: click-only RP send, deduplication, revalidation, expiry, dismissal, queue bound and cleanup.')
