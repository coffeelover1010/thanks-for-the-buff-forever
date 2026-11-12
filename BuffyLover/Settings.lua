local _, addon = ...
local category, refresh
function addon.OpenSettings()
    if category then Settings.OpenToCategory(category:GetID()) end
end
function addon.AddPageDefaults(panel,page)
    local pending
    local note=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    note:SetPoint("BOTTOMLEFT",18,48); note:SetWidth(560); note:SetJustifyH("LEFT")
    local buttons={}
    local function clear()
        pending=nil; note:SetText("")
        buttons.page:SetText("Page defaults"); buttons.all:SetText("All settings defaults")
    end
    for i,mode in ipairs({"page","all"}) do
        local action=mode
        local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        b:SetSize(220,25); b:SetPoint("BOTTOMLEFT",18+(i-1)*232,14); buttons[action]=b
        b:SetScript("OnClick",function()
            if InCombatLockdown() then note:SetText("Leave combat before restoring defaults."); return end
            if pending~=action then
                clear(); pending=action; b:SetText("Confirm "..(action=="page" and "page" or "all settings").." defaults")
                note:SetText(action=="all" and "Resets all settings, replies, rules and addon shortcuts. Count and rank are kept."
                    or (page=="general" and "Resets this page, including saved reply lists and character rules. Count is kept."
                    or page=="rules" and "Clears saved character rules. Default replies and other pages are kept."
                    or page=="target" and "Resets target options, appearance, position and both shortcuts. Other pages are kept."
                    or "Resets this page only. Other pages, lifetime count and rank are kept."))
                return
            end
            if action=="all" then addon.ResetSettings("RESET") else addon.ResetPageSettings(page,"RESET") end
            clear(); note:SetText("Defaults restored.")
        end)
    end
    local cancel=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    cancel:SetSize(90,25); cancel:SetPoint("BOTTOMLEFT",482,14); cancel:SetText("Cancel")
    cancel:SetScript("OnClick",clear)
    panel:HookScript("OnHide",clear)
    clear()
end
function addon.CreateSettings()
    if category then return end
    local function page(height)
        local panel=CreateFrame("Frame")
        local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",8,-8); scroll:SetPoint("BOTTOMRIGHT",-30,86)
        local body=CreateFrame("Frame",nil,scroll)
        body:SetSize(620,height); scroll:SetScrollChild(body)
        return panel,body
    end
    local panel,body=page(1050)
    local totalsPanel,totalsBody=page(1080)
    local returnPanel,returnBody=page(260)
    local responsePanel,responseBody=page(600)
    local responseCategory
    local rulesPanel,rulesBody=page(600)
    local rulesText=rulesBody:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    rulesText:SetPoint("TOPLEFT",12,-12); rulesText:SetWidth(580); rulesText:SetJustifyH("LEFT")
    local function showPreview(heading,text,font,size,r,g,b)
        if not addon.previewWindow then
            local window=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
            window:SetSize(620,330); window:SetPoint("CENTER")
            window:SetFrameStrata("FULLSCREEN_DIALOG"); window:EnableMouse(true)
            window:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
            window:SetBackdropColor(0.04,0.04,0.06,1); window:SetBackdropBorderColor(0.7,0.6,0.2,1)
            window.heading=window:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
            window.heading:SetPoint("TOP",0,-20)
            local scroll=CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT",24,-65); scroll:SetPoint("BOTTOMRIGHT",-44,85)
            window.content=CreateFrame("Frame",nil,scroll); window.content:SetSize(550,180)
            scroll:SetScrollChild(window.content); window.scroll=scroll
            window.message=window.content:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            window.message:SetPoint("TOPLEFT",0,0); window.message:SetWidth(550); window.message:SetJustifyH("LEFT")
            local note=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            note:SetPoint("BOTTOM",0,55); note:SetText("Preview only. No message sent, buff cast or count added.")
            local close=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
            close:SetSize(120,25); close:SetPoint("BOTTOM",0,18); close:SetText("Close preview")
            close:SetScript("OnClick",function() window:Hide() end)
            addon.previewWindow=window
        end
        local window=addon.previewWindow
        window.heading:SetText(heading)
        window.message:SetFont(font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size or 18,"OUTLINE")
        window.message:SetTextColor(r or 1,g or 1,b or 1); window.message:SetText(text)
        window.content:SetHeight(math.max(180,(window.message:GetStringHeight() or 180)+15))
        window.scroll:SetVerticalScroll(0)
        window:Show(); window:Raise()
    end
    local function section(y)
        if y<=-2000 then return responseBody,y+1980 end
        if y<=-1470 then return returnBody,y+1450 end
        if y==-1060 then return body,-950 end
        if y==-1095 then return body,-985 end
        if y<=-930 then
            return totalsBody,y+900+(y<=-1145 and 90 or 0)
        end
        return body,y
    end
    local function label(text, y)
        local parent; parent,y=section(y)
        local font = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        font:SetPoint("TOPLEFT", 12, y); font:SetWidth(580); font:SetJustifyH("LEFT"); font:SetText(text)
        return font
    end
    local function button(text, x, y, width, action)
        local parent; parent,y=section(y)
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetSize(width, 25); b:SetPoint("TOPLEFT", x, y); b:SetText(text); b:SetScript("OnClick", action)
        return b
    end
    local updates = {}
    local function check(text, key, y)
        local parent; parent,y=section(y)
        local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", 12, y); box:SetSize(26,26)
        local caption = box:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        caption:SetPoint("LEFT",box,"RIGHT",4,0); caption:SetText(text)
        box:SetScript("OnClick", function(self)
            BuffyLoverDB[key] = self:GetChecked() and true or false
            addon.ConfigurationChanged()
            if addon.RefreshResponseSummary then addon.RefreshResponseSummary() end
        end)
        updates[#updates+1] = function() box:SetChecked(BuffyLoverDB[key]) end
    end
    local function edit(x,y,width)
        local parent; parent,y=section(y)
        local field=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
        field:SetSize(width,24); field:SetPoint("TOPLEFT",x,y); field:SetAutoFocus(false)
        field:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        return field
    end
    local function numberField(field,minimum,maximum,integer,get,set,feedback)
        field:SetSize(72,24)
        field:SetJustifyH("CENTER")
        field:SetMaxLetters(8)
        local function restore() field:SetText(tostring(get())); field:SetCursorPosition(0) end
        local function save()
            local value=tonumber(field:GetText())
            if not value or value~=value or value<minimum or value>maximum then
                restore()
                feedback:SetText("Enter a number from "..minimum.." to "..maximum..". Previous value kept.")
                return
            end
            if integer then value=math.floor(value) end
            if value~=get() then
                set(value); addon.ConfigurationChanged()
                feedback:SetText("Saved. Enter/click away saves; Escape cancels; Up/Down adjusts.")
            end
            restore()
        end
        -- Override InputBoxTemplate's Enter handler, which clears its text.
        field:SetScript("OnEnterPressed",function(self) save(); self:ClearFocus() end)
        field:SetScript("OnEscapePressed",function(self) restore(); self:ClearFocus() end)
        field:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
        field:SetScript("OnEditFocusLost",function(self) save(); self:HighlightText(0,0) end)
        field:SetScript("OnHide",function(self) save(); self:ClearFocus() end)
        field:SetScript("OnArrowPressed",function(self,key)
            if key~="UP" and key~="DOWN" then return end
            local value=tonumber(self:GetText()) or get()
            self:SetText(tostring(math.max(minimum,math.min(maximum,value+(key=="UP" and 1 or -1)))))
            save(); self:HighlightText()
        end)
        restore()
    end
    label("BuffyLove", -10)
    local totalLabel=body:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    totalLabel:SetPoint("TOPRIGHT",body,"TOPRIGHT",-24,-10)
    local rankLabel=totalsBody:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    rankLabel:SetPoint("TOPLEFT",12,-520); rankLabel:SetWidth(580); rankLabel:SetJustifyH("LEFT")
    local rankToggle=CreateFrame("CheckButton",nil,totalsBody,"UICheckButtonTemplate")
    rankToggle:SetPoint("TOPLEFT",12,-580); rankToggle:SetSize(26,26)
    local rankCaption=rankToggle:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    rankCaption:SetPoint("LEFT",rankToggle,"RIGHT",4,0); rankCaption:SetText("Show rank badge beside the floating buff graphic")
    rankToggle:SetScript("OnClick",function(self)
        BuffyLoverDB.showGivingRank=self:GetChecked() and true or false
        addon.ConfigurationChanged()
        if refresh then refresh() end
    end)
    local rankHelp=totalsBody:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    rankHelp:SetPoint("TOPLEFT",12,-620); rankHelp:SetWidth(580); rankHelp:SetJustifyH("LEFT")
    rankHelp:SetText("Ranks: 32, 128, 512, 1,204, 1,337, 2,048, 10,001, 32,768, 100,001.\nLifetime unique players only. NPCs and repeat buffs do not count.")
    local rankPreview=CreateFrame("Button",nil,totalsBody,"UIPanelButtonTemplate")
    rankPreview:SetSize(220,25); rankPreview:SetPoint("TOPLEFT",18,-675); rankPreview:SetText("Preview next rank")
    rankPreview:SetScript("OnClick",function()
        local total=addon.GivingCount and addon.GivingCount() or 0
        local rank=addon.GivingRank(total)
        local nextTotal=addon.givingRankThresholds[rank+1] or addon.givingRankThresholds[#addon.givingRankThresholds]
        local text,font,size,r,g,b=addon.GivingAppearance(nextTotal,addon.lastGivenSpell or 1459)
        showPreview("Next buff rank preview",text.."\n\n"..addon.GivingRankSummary(nextTotal).."\n\nSample only. Your lifetime count is unchanged.\nFloating badge follows the rank badge toggle.",font,size,r,g,b)
    end)
    local soundSelect=CreateFrame("Button",nil,totalsBody,"UIPanelButtonTemplate")
    soundSelect:SetSize(270,25); soundSelect:SetPoint("TOPLEFT",18,-720)
    local function refreshSound()
        for _,entry in ipairs(addon.givingSounds) do
            if entry[1]==BuffyLoverDB.givingSoundID then soundSelect:SetText("Rank-up sound: "..entry[2]); return end
        end
    end
    soundSelect:SetScript("OnClick",function()
        local selected=1
        for i,entry in ipairs(addon.givingSounds) do if entry[1]==BuffyLoverDB.givingSoundID then selected=i end end
        BuffyLoverDB.givingSoundID=addon.givingSounds[selected % #addon.givingSounds+1][1]
        refreshSound()
    end)
    local soundPreview=CreateFrame("Button",nil,totalsBody,"UIPanelButtonTemplate")
    soundPreview:SetSize(160,25); soundPreview:SetPoint("LEFT",soundSelect,"RIGHT",12,0); soundPreview:SetText("Preview sound")
    soundPreview:SetScript("OnClick",function() addon.PlayGivingSound() end)
    local emote=CreateFrame("CheckButton",nil,totalsBody,"UICheckButtonTemplate")
    emote:SetSize(26,26); emote:SetPoint("TOPLEFT",12,-770)
    local emoteLabel=emote:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    emoteLabel:SetPoint("LEFT",emote,"RIGHT",4,0); emoteLabel:SetText("Offer a custom emote when I earn a rank")
    emote:SetScript("OnClick",function(self) BuffyLoverDB.rankEmote=self:GetChecked() and true or false; addon.ConfigurationChanged() end)
    local resetMode
    local confirm=CreateFrame("Frame",nil,totalsBody)
    confirm:SetSize(580,160); confirm:SetPoint("TOPLEFT",12,-865)
    local warning=confirm:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    warning:SetPoint("TOPLEFT"); warning:SetWidth(560); warning:SetJustifyH("LEFT")
    local phrase=CreateFrame("EditBox",nil,confirm,"InputBoxTemplate")
    phrase:SetSize(140,25); phrase:SetPoint("TOPLEFT",8,-75); phrase:SetAutoFocus(false); phrase:SetFontObject(GameFontHighlight)
    local commit=CreateFrame("Button",nil,confirm,"UIPanelButtonTemplate")
    commit:SetSize(160,25); commit:SetPoint("LEFT",phrase,"RIGHT",12,0); commit:SetText("Confirm reset")
    local cancel=CreateFrame("Button",nil,confirm,"UIPanelButtonTemplate")
    cancel:SetSize(100,25); cancel:SetPoint("LEFT",commit,"RIGHT",12,0); cancel:SetText("Cancel")
    cancel:SetScript("OnClick",function() confirm:Hide() end)
    phrase:SetScript("OnTextChanged",function(self) commit:SetEnabled(self:GetText()=="RESET") end)
    phrase:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    phrase:SetScript("OnEscapePressed",function() confirm:Hide() end)
    confirm:SetScript("OnHide",function() resetMode=nil; phrase:SetText(""); phrase:ClearFocus(); commit:Disable() end)
    commit:SetScript("OnClick",function()
        if phrase:GetText()~="RESET" then return end
        if InCombatLockdown() then warning:SetText("Leave combat before resetting. Type RESET, then click Confirm reset."); return end
        local ok
        if resetMode=="count" then ok=addon.ResetGivingCount("RESET")
        elseif resetMode=="settings" then ok=addon.ResetSettings("RESET") end
        if ok then confirm:Hide() end
    end)
    for i,entry in ipairs({{"count","Reset count"}}) do
        local mode=entry[1]
        local b=CreateFrame("Button",nil,totalsBody,"UIPanelButtonTemplate")
        b:SetSize(240,25); b:SetPoint("TOPLEFT",18+(i-1)*252,-820); b:SetText(entry[2])
        b:SetScript("OnClick",function()
            resetMode=mode; phrase:SetText(""); commit:Disable()
            warning:SetText(mode=="count" and "Reset the account-wide lifetime count, credited players and rank to zero?\nYour settings are kept. This cannot be undone.\nType RESET, then click Confirm reset."
                or "Restore addon settings, appearance, positions and saved replies to defaults?\nYour lifetime count and rank are kept. Addon shortcuts are reset.\nType RESET, then click Confirm reset.")
            confirm:Show(); phrase:SetFocus()
        end)
    end
    confirm:Hide()
    function addon.UpdateGivingTotal()
        local total=addon.GivingCount and addon.GivingCount() or 0
        totalLabel:SetText("Lifetime players buffed: "..total)
        rankLabel:SetText(addon.GivingRankSummary(total))
        rankToggle:SetChecked(BuffyLoverDB.showGivingRank)
        refreshSound()
        emote:SetChecked(BuffyLoverDB.rankEmote)
    end
    check("Enable automatic thanks", "enabled", -40)
    check("Thank party and raid members", "group", -70)
    check("Random saved line within each type (off uses first line)", "random", -100)
    check("Debug messages", "debug", -130)
    check("Thank everyone when the buff giver cannot be identified", "unknownThanks", -1060)
    label("Unknown givers share one cooldown. This sends a general THANK, even in\nwhisper/RP mode. Unknown self or group sources cannot be excluded.", -1095)
    check("Show floating buff total", "showGiving", -930)
    check("Play sound when earning a rank", "givingSound", -1020)
    label("Lifetime total: one credit per full player name, saved across reloads.\nEvery 10 sparkles; rank milestones celebrate. /buffy giving shows the total.", -966)
    label("Cooldown per player (0–2000 seconds)       Response delay (0–40 seconds)", -168)
    local cooldown, delay = edit(18,-193,130), edit(330,-193,130)
    local feedback = label("", -905)
    local timingFeedback=label("",-222)
    numberField(cooldown,0,2000,true,function() return BuffyLoverDB.cooldown end,function(v) BuffyLoverDB.cooldown=v end,timingFeedback)
    numberField(delay,0,40,false,function() return BuffyLoverDB.delay end,function(v) BuffyLoverDB.delay=v end,timingFeedback)
    cooldown:SetScript("OnTabPressed",function(self) self:ClearFocus(); delay:SetFocus() end)
    delay:SetScript("OnTabPressed",function(self) self:ClearFocus(); cooldown:SetFocus() end)
    button("Apply timing",475,-193,120,function()
        local c,d=tonumber(cooldown:GetText()),tonumber(delay:GetText())
        if not c or not d or c~=c or d~=d or c<0 or c>2000 or d<0 or d>40 then
            timingFeedback:SetText("Use a cooldown of 0–2000 and a delay of 0–40 seconds."); return
        end
        BuffyLoverDB.cooldown, BuffyLoverDB.delay=math.floor(c),d
        cooldown:SetText(tostring(BuffyLoverDB.cooldown)); delay:SetText(tostring(d))
        addon.ConfigurationChanged(); timingFeedback:SetText("Saved: cooldown "..BuffyLoverDB.cooldown.."s; delay "..BuffyLoverDB.delay.."s.")
    end)
    local modes={{"emote","Built-in emote"},{"rp","RP custom emote"},{"whisper","Whisper"}}
    local function cycle(options,x,y,width,get,set)
        local b
        local function update()
            for _,v in ipairs(options) do if get()==v[1] then b:SetText(v[2]); return end end
            b:SetText("Unknown")
        end
        b=button("",x,y,width,function()
            local index=0
            for i,v in ipairs(options) do if get()==v[1] then index=i end end
            set(options[index % #options + 1][1]); update()
            if addon.RefreshResponseSummary then addon.RefreshResponseSummary() end
        end)
        updates[#updates+1]=update
        return update,b
    end
    label("Floating total appearance",-1145)
    cycle(addon.givingFonts,18,-1172,180,function() return BuffyLoverDB.givingStyle.font end,function(v)
        BuffyLoverDB.givingStyle.font=v; addon.ConfigurationChanged()
    end)
    cycle(addon.givingIcons,208,-1172,180,function() return BuffyLoverDB.givingStyle.icon end,function(v)
        BuffyLoverDB.givingStyle.icon=v; addon.ConfigurationChanged()
    end)
    label("Text ({count} inserts your total)                 Font size (10-48)      Colour (hex)",-1210)
    local rewardText,rewardSize,rewardColor=edit(18,-1236,285),edit(330,-1236,95),edit(465,-1236,100)
    local function restoreAppearanceField(field,key)
        field:SetText(BuffyLoverDB.givingStyle[key])
        field:SetCursorPosition(0)
    end
    for _,entry in ipairs({{rewardText,"text"},{rewardColor,"color"}}) do
        local field,key=entry[1],entry[2]
        field:SetFontObject(GameFontHighlight)
        field:SetTextColor(1,1,1)
        field:SetScript("OnShow",function(self) restoreAppearanceField(self,key) end)
        field:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
        field:SetScript("OnEscapePressed",function(self) restoreAppearanceField(self,key); self:ClearFocus() end)
        field:SetScript("OnEditFocusLost",function(self)
            if self:GetText()=="" then restoreAppearanceField(self,key) end
            self:HighlightText(0,0); self:SetCursorPosition(0)
        end)
    end
    local rewardPreview=label("",-1320)
    local rewardFeedback=label("",-1360)
    numberField(rewardSize,10,48,true,function() return BuffyLoverDB.givingStyle.size end,function(v) BuffyLoverDB.givingStyle.size=v end,rewardFeedback)
    local function previewReward()
        local text,font,size,r,g,b=addon.GivingAppearance(addon.GivingCount and addon.GivingCount() or 0,addon.lastGivenSpell)
        rewardPreview:SetFont(font,size,"OUTLINE"); rewardPreview:SetTextColor(r,g,b); rewardPreview:SetText(text)
    end
    button("Apply appearance",18,-1275,180,function()
        local text,size,color=rewardText:GetText(),tonumber(rewardSize:GetText()),rewardColor:GetText()
        if not addon.ValidGivingText(text) or not size or size~=size or size<10 or size>48 or not color:match("^%x%x%x%x%x%x$") then
            rewardFeedback:SetText("Use plain text (max 80 bytes), {count}, size 10-48 and a six-digit hex colour."); return
        end
        local s=BuffyLoverDB.givingStyle
        s.text,s.size,s.color=text,math.floor(size),color:upper()
        restoreAppearanceField(rewardText,"text"); restoreAppearanceField(rewardColor,"color")
        addon.ConfigurationChanged(); previewReward(); rewardFeedback:SetText("Appearance saved. Preview is local only.")
    end)
    button("Preview saved style",208,-1275,180,function()
        previewReward()
        -- Provide a sample spell before the first credited buff of this session.
        local text,font,size,r,g,b=addon.GivingAppearance(addon.GivingCount and addon.GivingCount() or 0,addon.lastGivenSpell or 1459)
        showPreview("Saved buff-count style",text,font,size,r,g,b)
    end)
    label("Tracking continues while hidden. Hidden rewards make no sparkle or sound.\nFont size saves on Enter/click away; text and colour use Apply appearance.\nText example: {count} toons buffed!\nColour examples: FFFFFF = white, FFD700 = gold, 00FF00 = green.",-1400)
    label("Buff back (out of combat)",-1470)
    check("Offer clickable buffs for players who buff me","buffBack",-1495)
    label("Show icons for (5-120 seconds)",-1530)
    local returnDuration=edit(18,-1555,130)
    updates[#updates+1]=function() returnDuration:SetText(tostring(BuffyLoverDB.buffBackDuration or 30)) end
    local returnFeedback=label("One click per buff. Right-click an icon to dismiss that giver.",-1640)
    numberField(returnDuration,5,120,true,function() return BuffyLoverDB.buffBackDuration or 30 end,function(v) BuffyLoverDB.buffBackDuration=v end,returnFeedback)
    button("Apply duration",165,-1555,150,function()
        local value=tonumber(returnDuration:GetText())
        if not value or value~=value or value<5 or value>120 then
            returnFeedback:SetText("Choose a duration from 5 to 120 seconds."); return
        end
        BuffyLoverDB.buffBackDuration=math.floor(value)
        returnDuration:SetText(tostring(BuffyLoverDB.buffBackDuration))
        returnFeedback:SetText("Saved. New offers last "..BuffyLoverDB.buffBackDuration.." seconds.")
    end)
    button("Move / preview icons",18,-1595,200,function()
        if InCombatLockdown() then returnFeedback:SetText("Leave combat before positioning the icons."); return end
        addon.ToggleBuffBackPlacement()
    end)
    button("Reset position",230,-1595,150,function()
        if InCombatLockdown() then returnFeedback:SetText("Leave combat before resetting the position."); return end
        addon.ResetBuffBackPosition()
    end)
    label("1. Choose what BuffyLove sends",-245)
    button("Enable / combine responses...",18,-268,240,function()
        if responseCategory then Settings.OpenToCategory(responseCategory:GetID()) end
    end)
    label("Response types (enable any combination)",-2000)
    check("Built-in emote: automatic THANK, BOW, CHEER, etc.","sendEmote",-2040)
    check("Custom RP: click to send outdoors","sendRP",-2075)
    check("Whisper: automatic private reply","sendWhisper",-2110)
    label("How to combine enabled types",-2160)
    cycle({{"all","Send all selected"},{"random","Choose one type randomly"},{"priority","First available in priority order"}},18,-2190,380,
        function() return BuffyLoverDB.responseStrategy end,function(v) BuffyLoverDB.responseStrategy=v; addon.ConfigurationChanged() end)
    label("Priority order (disabled types are skipped)",-2235)
    cycle({{"emote,rp,whisper","Built-in > RP > Whisper"},{"emote,whisper,rp","Built-in > Whisper > RP"},
        {"rp,emote,whisper","RP > Built-in > Whisper"},{"rp,whisper,emote","RP > Whisper > Built-in"},
        {"whisper,emote,rp","Whisper > Built-in > RP"},{"whisper,rp,emote","Whisper > RP > Built-in"}},18,-2265,380,
        function() return BuffyLoverDB.responseOrder end,function(v) BuffyLoverDB.responseOrder=v; addon.ConfigurationChanged() end)
    local responseSummary=label("",-2320)
    local function refreshResponseSummary() responseSummary:SetText(addon.ResponseSummary(BuffyLoverDB)) end
    updates[#updates+1]=refreshResponseSummary
    responsePanel:SetScript("OnShow",function() for _,fn in ipairs(updates) do fn() end end)
    addon.RefreshResponseSummary=refreshResponseSummary
    label("Each type uses its own saved fallback and matching character rules.\nEmpty matching lists are skipped. Priority does not retry rejected sends.\nRandom type selection is separate from choosing a random saved line.\nAll selected types share one cooldown; RP may wait for your click.",-2400)
    label("2. Write your replies\nStart with default replies. Character rules are optional overrides.",-300)
    local function updateRuleList()
        local db,traits=BuffyLoverDB,addon.CharacterTraits()
        local lines={"Saved response rules", "", addon.ResponseSummary(db),
            "Automatic thanks: "..(db.enabled and "on" or "off"),
            "Selection: "..(db.random and "random saved line" or "first saved line"),
            "", "Rules match YOUR character. Most specific wins; ties use the earlier rule.",
            "An empty winning list suppresses that response type.", ""}
        for _,item in ipairs(modes) do
            local _,_,winner=addon.SelectResponse(db,traits,"Kind Traveller",function() return 1 end,item[1])
            lines[#lines+1]=item[2].." winner: "..(winner and winner>0 and ("Rule "..winner) or "General fallback")
        end
        lines[#lines+1]="Winners above are per type; enabled response types and combination control what sends."
        for _,item in ipairs(modes) do
            lines[#lines+1]="\nGeneral fallback - "..item[2]
            lines[#lines+1]=(db.replies[item[1]]~="" and db.replies[item[1]] or "(empty - no reply)")
        end
        local genders={[1]="Other / unknown",[2]="Male",[3]="Female",ANY="Any gender"}
        for index,rule in ipairs(db.rules) do
            lines[#lines+1]="\nRule "..index.." - "..rule.mode
            lines[#lines+1]="Class: "..rule.class.." | Race: "..rule.race.." | Gender: "..(genders[rule.gender] or tostring(rule.gender))
            lines[#lines+1]=rule.text~="" and rule.text or "(empty - no reply)"
        end
        if #db.rules==0 then lines[#lines+1]="\nNo character rules saved. The general fallbacks are used." end
        lines[#lines+1]="\nTo edit: open the main BuffyLove page, use Default replies / Previous / Next, then Save list. Unsaved edits are not shown here."
        rulesText:SetText(table.concat(lines,"\n"))
        rulesBody:SetHeight(math.max(600,(rulesText:GetStringHeight() or 600)+40))
    end
    local selected, draft = 0, {}
    local filterControls = {}
    local filterHeading, replyHelp, deleteRule
    local title=label("",-350)
    local editorScroll=CreateFrame("ScrollFrame",nil,body,"UIPanelScrollFrameTemplate")
    editorScroll:SetPoint("TOPLEFT",20,-585); editorScroll:SetSize(550,170)
    local editor=CreateFrame("EditBox",nil,editorScroll)
    editor:SetMultiLine(true); editor:SetFontObject(ChatFontNormal); editor:SetSize(540,170)
    editor:SetAutoFocus(false); editor:SetMaxLetters(8000); editorScroll:SetScrollChild(editor)
    editor:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    local function redraw()
        for _,fn in ipairs(updates) do fn() end
        updateRuleList()
        title:SetText(selected==0 and "Default replies — used when no character rule matches" or ("Character rule "..selected.." of "..#BuffyLoverDB.rules))
        for _,control in ipairs(filterControls) do control:SetShown(selected>0) end
        if filterHeading then
            filterHeading:SetText(selected==0 and "Defaults apply to all your characters unless a rule overrides them." or "Use this rule when MY character matches:")
        end
        if deleteRule then deleteRule:SetEnabled(selected>0) end
        if replyHelp then
            replyHelp:SetText(draft.mode=="emote" and "One emote per line: THANK, BOW, SALUTE, CHEER, WAVE, NOD, APPLAUD." or
                "One reply per line. Use {name} for the buff giver's full name.")
        end
    end
    local function load()
        local source=BuffyLoverDB.rules[selected]
        draft={mode=source and source.mode or addon.EditResponseMode(BuffyLoverDB.mode), class="ANY",race="ANY",gender="ANY"}
        if source then for k,v in pairs(source) do draft[k]=v end end
        editor:SetText(source and source.text or BuffyLoverDB.replies[draft.mode] or "")
        editor:SetCursorPosition(0); redraw()
    end
    button("Default replies",18,-378,120,function() selected=0; load() end)
    button("Previous",145,-378,80,function() selected=math.max(0,selected-1); load() end)
    button("Next",232,-378,70,function() selected=math.min(#BuffyLoverDB.rules,selected+1); load() end)
    button("Add character rule",309,-378,145,function()
        if #BuffyLoverDB.rules>=50 then feedback:SetText("Maximum 50 rules."); return end
        table.insert(BuffyLoverDB.rules,{mode=addon.EditResponseMode(BuffyLoverDB.mode),class="ANY",race="ANY",gender="ANY",text=BuffyLoverDB.replies[addon.EditResponseMode(BuffyLoverDB.mode)]})
        selected=#BuffyLoverDB.rules; load(); addon.ConfigurationChanged()
    end)
    deleteRule=button("Delete rule",461,-378,115,function()
        if selected>0 then table.remove(BuffyLoverDB.rules,selected); selected=0; load(); addon.ConfigurationChanged() end
    end)
    label("Reply text to edit (click to switch type)", -420)
    cycle(modes,18,-442,240,function() return draft.mode end,function(v)
        draft.mode=v
        if selected==0 then editor:SetText(BuffyLoverDB.replies[v] or "") end
        redraw()
    end)
    local classes={{"ANY","Any class"}}
    for _,v in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}) do classes[#classes+1]={v,v} end
    local races={{"ANY","Any race"},{"Human","Human"},{"Dwarf","Dwarf"},{"NightElf","Night elf"},{"Gnome","Gnome"},{"Orc","Orc"},{"Troll","Troll"},{"Tauren","Tauren"},{"Scourge","Undead"}}
    filterHeading=label("", -480)
    filterControls[1]=select(2,cycle(classes,18,-503,180,function() return draft.class end,function(v) draft.class=v end))
    filterControls[2]=select(2,cycle(races,208,-503,180,function() return draft.race end,function(v) draft.race=v end))
    filterControls[3]=select(2,cycle({{"ANY","Any gender"},{2,"Male"},{3,"Female"},{1,"Other / unknown"}},398,-503,180,function() return draft.gender end,function(v) draft.gender=v end))
    replyHelp=label("",-543)
    button("Save list",18,-775,120,function()
        local text=editor:GetText()
        local lines,issue=addon.ValidateLines(text,draft.mode)
        if not lines then feedback:SetText(issue); return end
        if selected==0 then BuffyLoverDB.replies[draft.mode]=text
        else draft.text=text; BuffyLoverDB.rules[selected]={mode=draft.mode,class=draft.class,race=draft.race,gender=draft.gender,text=text} end
        addon.ConfigurationChanged(); updateRuleList(); feedback:SetText("List saved. Empty matching lists suppress responses.")
    end)
    button("Preview saved response",150,-775,220,function()
        local ok,replies=pcall(addon.PlanResponses,BuffyLoverDB,addon.CharacterTraits(),"Kind Traveller")
        local lines={}
        if ok then for _,reply in ipairs(replies) do lines[#lines+1]=reply.mode..": "..reply.text end end
        local result=#lines>0 and table.concat(lines,"\n\n") or "No response: check saved lists and matching rules."
        feedback:SetText(result)
        showPreview("Saved response for this character",result.."\n\nSample giver: Kind Traveller. Uses saved settings, not unsaved editor text.")
    end)
    label("Save list before switching types or rules; unsaved edits are discarded.\nAn empty list sends nothing. Preview checks saved replies for this character.\nRules match YOUR character: most specific wins; ties use the earlier rule.\nCustom RP outdoors needs a click. Combat/loading/settings cancel pending replies.",-819)
    refresh=function()
        addon.UpdateGivingTotal()
        restoreAppearanceField(rewardText,"text")
        rewardSize:SetText(tostring(BuffyLoverDB.givingStyle.size))
        restoreAppearanceField(rewardColor,"color")
        previewReward()
        cooldown:SetText(tostring(BuffyLoverDB.cooldown)); delay:SetText(tostring(BuffyLoverDB.delay)); load()
    end
    addon.RefreshSettings=function()
        selected=0
        if refresh then refresh() end
        for _,fn in ipairs(updates) do fn() end
        updateRuleList()
    end
    panel:SetScript("OnShow",refresh)
    category=Settings.RegisterCanvasLayoutCategory(panel,"BuffyLove")
    responseCategory=Settings.RegisterCanvasLayoutSubcategory(category,responsePanel,"Responses")
    Settings.RegisterCanvasLayoutSubcategory(category,totalsPanel,"Buff count")
    Settings.RegisterCanvasLayoutSubcategory(category,returnPanel,"Buff back")
    Settings.RegisterCanvasLayoutSubcategory(category,rulesPanel,"Saved rules")
    rulesPanel:SetScript("OnShow",updateRuleList)
    totalsPanel:SetScript("OnShow",refresh)
    returnPanel:SetScript("OnShow",refresh)
    for _,entry in ipairs({{panel,"general"},{responsePanel,"responses"},{totalsPanel,"count"},{returnPanel,"back"},{rulesPanel,"rules"}}) do
        addon.AddPageDefaults(entry[1],entry[2])
    end
    Settings.RegisterAddOnCategory(category)
    if addon.CreateTargetSettings then addon.CreateTargetSettings(category) end
    refresh()
end
