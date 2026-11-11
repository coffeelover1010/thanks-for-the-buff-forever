local _, addon = ...
local queue, frame = {}, nil
local function update()
    if not frame then return end
    local item=queue[1]
    if not item then frame:Hide(); return end
    frame.title:SetText("Thank "..item.name.." ("..#queue.." waiting)")
    frame.text:SetText(item.text)
    frame:SetHeight(math.max(160,(frame.text:GetStringHeight() or 60)+100))
    frame:Show()
end
function addon.ClearManualReplies()
    queue={}; update()
end
function addon.OfferManualReply(guid,name,text,valid,report)
    if not frame then
        frame=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        addon.manualReplyFrame=frame
        frame:SetSize(420,160); frame:SetPoint("CENTER",UIParent,"CENTER",0,180)
        frame:SetFrameStrata("DIALOG"); frame:EnableMouse(true)
        frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        frame:SetBackdropColor(0.04,0.04,0.06,0.95)
        frame.title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
        frame.title:SetPoint("TOPLEFT",12,-12); frame.title:SetWidth(396)
        frame.text=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        frame.text:SetPoint("TOPLEFT",12,-38); frame.text:SetWidth(396)
        frame.send=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
        frame.send:SetSize(180,25); frame.send:SetPoint("BOTTOMLEFT",12,12); frame.send:SetText("Send RP thanks")
        frame.dismiss=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
        frame.dismiss:SetSize(100,25); frame.dismiss:SetPoint("BOTTOMRIGHT",-12,12); frame.dismiss:SetText("Dismiss")
        frame.dismiss:SetScript("OnClick",function() table.remove(queue,1); update() end)
        frame.send:SetScript("OnClick",function()
            local item=table.remove(queue,1)
            if item then
                local ok,allowed=pcall(item.valid)
                if ok and allowed and GetTime()<item.expires then
                    -- Send directly in this physical click, never from a timer.
                    local sent=pcall(C_ChatInfo.SendChatMessage,item.text,"EMOTE")
                    item.report(sent and "Clicked RP reply; delivery unconfirmed." or "Clicked RP reply rejected by the client.")
                else item.report("RP reply expired or the giver/settings changed; skipped.") end
            end
            update()
        end)
        frame:SetScript("OnUpdate",function()
            local changed=false
            for i=#queue,1,-1 do
                if GetTime()>=queue[i].expires then table.remove(queue,i); changed=true end
            end
            if changed then update() end
        end)
    end
    for _,item in ipairs(queue) do if item.guid==guid then return end end
    if #queue>=5 then report("RP reply queue full; skipped."); return end
    queue[#queue+1]={guid=guid,name=name,text=text,valid=valid,report=report,expires=GetTime()+30}
    update()
end
