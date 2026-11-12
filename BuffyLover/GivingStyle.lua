local _, addon = ...
addon.givingFonts = {{"default","Default"},{"damage","Combat text"},{"name","Nameplate"}}
addon.givingIcons = {{"none","No icon"},{"buff","Buff being given"},{"spark","Magic"},{"heart","Fortitude"},{"leaf","Mark of the Wild"}}
local icons={spark="Interface\\Icons\\Spell_Holy_MagicalSentry",heart="Interface\\Icons\\Spell_Holy_WordFortitude",leaf="Interface\\Icons\\Spell_Nature_Regeneration"}
addon.givingSounds={{888,"Level up"},{878,"Quest complete"},{8960,"Ready check"}}
addon.givingRankThresholds={32,128,512,1204,1337,2048,10001,32768,100001}
function addon.PlayGivingSound()
    if PlaySound then pcall(PlaySound,BuffyLoverDB.givingSoundID or 888,"SFX") end
end
function addon.InitGivingStyle(db)
    if type(db.rankEmote)~="boolean" then db.rankEmote=true end
    local validSound=false
    for _,entry in ipairs(addon.givingSounds) do if db.givingSoundID==entry[1] then validSound=true end end
    if not validSound then db.givingSoundID=888 end
    if type(db.showGivingRank)~="boolean" then db.showGivingRank=true end
    if type(db.showGiving)~="boolean" then db.showGiving=false; db.giving=true end
    -- Old 'giving' remains the tracking switch, separate from presentation.
    if type(db.givingStyle)~="table" then db.givingStyle={} end
    local s=db.givingStyle
    if s.font~="default" and s.font~="damage" and s.font~="name" then s.font="name" end
    if s.icon~="none" and s.icon~="buff" and not icons[s.icon] then s.icon="buff" end
    if type(s.size)~="number" or s.size~=s.size or s.size<10 or s.size>48 then s.size=20 end
    if type(s.color)~="string" or not s.color:match("^%x%x%x%x%x%x$") then s.color="FFFFFF" end
    if not addon.ValidGivingText(s.text) then s.text="{count} toons buffed!" end
end
function addon.GivingRank(total)
    if type(total)~="number" or total~=total or total==math.huge or total<0 then total=0 end
    total=math.floor(total)
    local rank=0
    for i,threshold in ipairs(addon.givingRankThresholds) do if total>=threshold then rank=i else break end end
    local icon=rank>0 and string.format("Interface\\PvPRankBadges\\PvPRank%02d",math.min(rank,14)) or nil
    local nextTotal=addon.givingRankThresholds[rank+1]
    return rank,icon,nextTotal and nextTotal-total or nil
end
function addon.GivingRankSummary(total)
    local rank,icon,remaining=addon.GivingRank(total)
    local badge=icon and ("|T"..icon..":24:24:0:0|t ") or ""
    return badge.."Buff rank "..rank..(rank==0 and " (Unranked)" or "").."\n"..(remaining and (remaining.." more unique players to rank "..(rank+1)..".") or "Highest rank reached.")
end
function addon.ValidGivingText(text)
    if type(text)~="string" or #text==0 or #text>80 or text:find("[%c|]") then return false end
    local rest=text:gsub("{count}","")
    return not rest:find("[{}]")
end
function addon.GivingAppearance(total, spellID)
    addon.InitGivingStyle(BuffyLoverDB)
    local s=BuffyLoverDB.givingStyle
    local text=s.text:gsub("{count}",function() return tostring(total) end)
    local icon=icons[s.icon]
    if s.icon=="buff" and (not issecretvalue or not issecretvalue(spellID)) and type(spellID)=="number"
        and C_Spell and C_Spell.GetSpellTexture then
        local ok,value=pcall(C_Spell.GetSpellTexture,spellID)
        if ok and (not issecretvalue or not issecretvalue(value)) and type(value)=="number" and value>0 then icon=value end
    end
    if icon then text="|T"..icon..":"..s.size..":"..s.size..":0:0|t "..text end
    local rank,rankIcon=addon.GivingRank(total)
    if BuffyLoverDB.showGivingRank and rankIcon then
        text=text.." |T"..rankIcon..":"..s.size..":"..s.size..":0:0|t"
    end
    local font=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if s.font=="damage" then font=DAMAGE_TEXT_FONT or font elseif s.font=="name" then font=UNIT_NAME_FONT or font end
    return text,font,s.size,tonumber(s.color:sub(1,2),16)/255,tonumber(s.color:sub(3,4),16)/255,tonumber(s.color:sub(5,6),16)/255
end
