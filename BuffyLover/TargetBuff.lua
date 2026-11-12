local _, ns = ...
local cast, viewer, text, content
local elapsed = 0
local loading = false
local action = "CLICK BuffyLoverTargetBuff:LeftButton"
BINDING_HEADER_BUFFYLOVER = "BuffyLove"
_G["BINDING_NAME_"..action] = "Buff current target (out of combat)"
BINDING_NAME_BUFFYLOVER_TARGET_SOURCES = "Show target buff sources"
local function Public(v) return not issecretvalue or not issecretvalue(v) end
local function InitAppearance(db)
    if db.targetShape~="rounded" and db.targetShape~="circle" then db.targetShape="square" end
    for key,default in pairs({targetBorderWidth=0,targetOpacity=100}) do
        local v=db[key]
        local low,high=key=="targetOpacity" and 20 or 0,key=="targetOpacity" and 100 or 6
        if type(v)~="number" or v~=v or v<low or v>high then db[key]=default end
    end
    if type(db.targetBorderColor)~="string" or not db.targetBorderColor:match("^%x%x%x%x%x%x$") then db.targetBorderColor="FFD700" end
end
local function StyleIcon(button,db,size)
    local path="Interface\\AddOns\\BuffyLover\\IconMask-"..db.targetShape..".tga"
    button.shapeMask:SetTexture(path,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    button.borderMask:SetTexture(path,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    local width=db.targetBorderWidth
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT",button,"TOPLEFT",width,-width)
    button.icon:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-width,width)
    local hex=db.targetBorderColor
    button.border:SetVertexColor(tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255)
    button.border:SetAlpha(width>0 and 1 or 0)
end
local function CreateIconStyle(button)
    button.border=button:CreateTexture(nil,"BACKGROUND")
    button.border:SetAllPoints(); button.border:SetColorTexture(1,1,1,1)
    button.borderMask=button:CreateMaskTexture()
    button.borderMask:SetAllPoints(button); button.border:AddMaskTexture(button.borderMask)
    button.shapeMask=button:CreateMaskTexture()
    button.shapeMask:SetAllPoints(button.icon); button.icon:AddMaskTexture(button.shapeMask)
end
local function SelectBuff()
    if loading then return nil,"Loading." end
    if not BuffyLoverDB or not BuffyLoverDB.targetBuff then return nil,"Target buffing is disabled." end
    if InCombatLockdown() then return nil,"Paused in combat." end
    local mine, theirs = UnitIsPVP("player"), UnitIsPVP("target")
    if not Public(mine) or not Public(theirs) or (mine ~= true and theirs ~= false) then return nil,"Blocked by PvP flag check." end
    if mine ~= true and mine ~= false then return nil,"Your PvP flag is unavailable." end
    if UnitIsPVPFreeForAll then
        local flag = UnitIsPVPFreeForAll("target")
        if not Public(flag) or (flag ~= false and mine ~= true) then return nil,"Blocked by free-for-all PvP check." end
    end
    local missing,reason = ns.GetMissingBuffs("target", BuffyLoverDB.targetNPCs)
    if #missing==0 then return nil,reason end
    for _,spell in ipairs(missing) do
        local usable,range=true,true
        if C_Spell and C_Spell.IsSpellUsable then usable=C_Spell.IsSpellUsable(spell.id)
        elseif IsUsableSpell then usable=IsUsableSpell(spell.castName) end
        if C_Spell and C_Spell.IsSpellInRange then range=C_Spell.IsSpellInRange(spell.id,"target")
        elseif IsSpellInRange then range=IsSpellInRange(spell.castName,"target") end
        -- Some Classic rank/target combinations have no range result by ID.
        -- Retry by ranked name; nil is unknown, not an explicit rejection.
        if Public(range) and range==nil and C_Spell and C_Spell.IsSpellInRange then
            range=C_Spell.IsSpellInRange(spell.castName,"target")
        end
        if Public(usable) and Public(range) and (usable==true or usable==1) and (range==nil or range==true or range==1) then return spell end
        reason=(not Public(usable) or not Public(range)) and "Spell information is restricted." or "Spell is unusable or target is out of range."
    end
    return nil,type(reason)=="string" and reason or "Spell information is restricted."
end
function ns.TargetBuffDiagnostic()
    local ok,spell,reason=pcall(SelectBuff)
    if not ok then return "Target check failed: "..tostring(spell) end
    if not spell then return reason or "No eligible buff." end
    return "Ready: "..spell.castName..(BuffyLoverDB.targetCursor and ". Cursor icon enabled." or ". Cursor icon disabled; shortcut remains available.")
end
local function Arm()
    if not cast or InCombatLockdown() then return end
    cast:SetAttribute("type1", nil)
    local ok, spell = pcall(SelectBuff)
    cast.available=ok and spell~=nil
    if ok and spell then
        cast:SetAttribute("macrotext1", "/cast [@target,help,nodead] "..spell.castName)
        cast:SetAttribute("type1", "macro")
        cast.lastIcon=spell.icon
        cast.icon:SetTexture(spell.icon)
        cast.icon:SetDesaturated(false)
        cast.icon:SetVertexColor(1,1,1)
    else
        cast.icon:SetTexture(cast.lastIcon or "Interface\\Icons\\INV_Misc_Book_09")
        cast.icon:SetDesaturated(true)
        cast.icon:SetVertexColor(.55,.55,.55)
    end
end
function ns.TargetBuffSourceText()
    local title = UnitName("target")
    if not Public(title) or type(title) ~= "string" then return "Select someone to view their buffs." end
    local lines = {title.." - buff sources", ""}
    for i=1,255 do
        local name, source
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL")
            if not Public(aura) then lines[#lines+1]="Buff information unavailable."; break end
            if not aura then break end
            name, source = aura.name, aura.sourceUnit
        elseif UnitBuff then
            name, _, _, _, _, _, source = UnitBuff("target", i)
        else
            lines[#lines+1]="Buff information unavailable."; break
        end
        if not Public(name) then lines[#lines+1]="Buff information unavailable."; break end
        if not name then break end
        local giver = "Unknown / unavailable"
        if Public(source) and type(source)=="string" then
            local n, realm = UnitName(source)
            if Public(n) and type(n)=="string" then
                giver=n
                if Public(realm) and type(realm)=="string" and realm~="" then giver=giver.."-"..realm end
            end
        end
        lines[#lines+1]=name.."  -  "..giver
    end
    if #lines==2 then lines[#lines+1]="No visible buffs." end
    return table.concat(lines,"\n")
end
local function RefreshSources()
    if not viewer or not viewer:IsShown() then return end
    local ok, result=pcall(ns.TargetBuffSourceText)
    text:SetText(ok and result or "Buff information unavailable.")
    content:SetHeight(math.max(260,text:GetStringHeight()+20))
end
function ns.ToggleTargetSources()
    if not viewer then
        viewer=CreateFrame("Frame","BuffyLoverTargetSources",UIParent,"BasicFrameTemplateWithInset")
        viewer:SetSize(440,360); viewer:SetPoint("CENTER"); viewer:SetFrameStrata("DIALOG")
        viewer:SetClampedToScreen(true); viewer:SetMovable(true); viewer:EnableMouse(true)
        viewer:RegisterForDrag("LeftButton")
        viewer:SetScript("OnDragStart",viewer.StartMoving)
        viewer:SetScript("OnDragStop",viewer.StopMovingOrSizing)
        viewer.TitleText:SetText("BuffyLove - Target buffs")
        local scroll=CreateFrame("ScrollFrame",nil,viewer,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-38); scroll:SetPoint("BOTTOMRIGHT",-34,16)
        content=CreateFrame("Frame",nil,scroll); content:SetSize(370,260); scroll:SetScrollChild(content)
        text=content:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        text:SetPoint("TOPLEFT"); text:SetWidth(370); text:SetJustifyH("LEFT"); text:SetSpacing(5)
        viewer:Hide()
        UISpecialFrames[#UISpecialFrames+1]="BuffyLoverTargetSources"
    end
    if viewer:IsShown() then viewer:Hide() else viewer:Show(); RefreshSources() end
end
_G.BuffyLoverToggleTargetSources=ns.ToggleTargetSources
function ns.RefreshTargetBuff(move)
    if not cast or InCombatLockdown() then return end
    Arm()
    local guid=UnitGUID("target")
    local visible=not loading and BuffyLoverDB.targetCursor and Public(guid) and type(guid)=="string"
        and (not BuffyLoverDB.targetHideUnavailable or cast.available)
    cast:SetAlpha(visible and BuffyLoverDB.targetOpacity/100 or 0); cast:EnableMouse(visible and true or false)
    if not visible and GameTooltip:IsOwned(cast) then GameTooltip:Hide() end
    cast:SetSize(BuffyLoverDB.targetIconSize,BuffyLoverDB.targetIconSize)
    StyleIcon(cast,BuffyLoverDB,BuffyLoverDB.targetIconSize)
    if move then
        local mode=BuffyLoverDB.targetPosition or "cursor"
        cast:ClearAllPoints()
        if mode=="screen" then
            cast:SetPoint("CENTER",UIParent,"CENTER",BuffyLoverDB.targetOffsetX,BuffyLoverDB.targetOffsetY)
        elseif mode=="target" and TargetFrame then
            cast:SetPoint("TOP",TargetFrame,"BOTTOM",BuffyLoverDB.targetOffsetX,BuffyLoverDB.targetOffsetY)
        else
        local x,y=GetCursorPosition()
        local scale=UIParent:GetEffectiveScale()
        cast:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x/scale-BuffyLoverDB.targetIconSize/2+BuffyLoverDB.targetOffsetX,y/scale+BuffyLoverDB.targetOffsetY)
        end
    end
    RefreshSources()
end
function ns.InitTargetBuff(db)
    InitAppearance(db)
    if db.targetPosition~="screen" and db.targetPosition~="target" then db.targetPosition="cursor" end
    if type(db.targetNPCs)~="boolean" then db.targetNPCs=true end
    if type(db.targetHideUnavailable)~="boolean" then db.targetHideUnavailable=true end
    for key,default in pairs({targetIconSize=32,targetOffsetX=0,targetOffsetY=-18}) do
        local value=db[key]
        local low,high=key=="targetIconSize" and 16 or -3000,key=="targetIconSize" and 80 or 3000
        if type(value)~="number" or value~=value or value<low or value>high then db[key]=default end
    end
    for _,key in ipairs({"targetBuff","targetCursor","targetSourcesAuto"}) do
        if type(db[key])~="boolean" then db[key]=false end
    end
    if cast then ns.RefreshTargetBuff(true); return end
    local holder=CreateFrame("Frame",nil,UIParent,"SecureHandlerStateTemplate")
    holder:SetAllPoints(UIParent)
    RegisterStateDriver(holder,"visibility","[combat] hide; show")
    cast=CreateFrame("Button","BuffyLoverTargetBuff",holder,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
    cast:SetSize(32,32); cast:SetPoint("CENTER"); cast:SetClampedToScreen(true); cast:SetFrameStrata("DIALOG")
    cast.icon=cast:CreateTexture(nil,"ARTWORK")
    cast.icon:SetAllPoints(); cast.icon:SetTexCoord(.08,.92,.08,.92)
    CreateIconStyle(cast)
    local highlight=cast:CreateTexture(nil,"HIGHLIGHT")
    highlight:SetAllPoints(cast.icon); highlight:SetColorTexture(1,1,1,.18); highlight:AddMaskTexture(cast.shapeMask)
    cast:RegisterForClicks("AnyDown","AnyUp")
    cast:SetAttribute("_onstate-combat",[[if newstate == "yes" then self:SetAttribute("type1",nil) end]])
    RegisterStateDriver(cast,"combat","[combat] yes; no")
    cast:SetScript("PreClick",Arm)
    cast:SetScript("PostClick",function(_,button,down)
        if button=="RightButton" and not down then ns.ToggleTargetSources() end
    end)
    cast:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Left-click: Buff target",1,1,1)
        GameTooltip:AddLine("Right-click: Show buff sources",1,1,1); GameTooltip:Show()
    end)
    cast:SetScript("OnLeave",function() GameTooltip:Hide() end)
    ns.RefreshTargetBuff(true)
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_TARGET_CHANGED","UNIT_AURA","PLAYER_REGEN_ENABLED","SPELLS_CHANGED","PLAYER_LOGIN","PLAYER_LEAVING_WORLD","PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
    if not cast then return end
    if event=="UNIT_AURA" and unit~="target" then return end
    if event=="PLAYER_LEAVING_WORLD" then
        loading=true
        if viewer then viewer:Hide() end
        if not InCombatLockdown() then cast:SetAttribute("type1",nil); cast:SetAlpha(0); cast:EnableMouse(false) end
        return
    end
    if event=="PLAYER_ENTERING_WORLD" then loading=false end
    if event=="SPELLS_CHANGED" or event=="PLAYER_LOGIN" then ns.RebuildReturnSpells() end
    if event=="PLAYER_TARGET_CHANGED" and BuffyLoverDB.targetSourcesAuto then
        if not viewer or not viewer:IsShown() then ns.ToggleTargetSources() end
    end
    ns.RefreshTargetBuff(event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_REGEN_ENABLED")
    RefreshSources()
end)
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<.25 then return end
    elapsed=0; ns.RefreshTargetBuff(false)
end)

function ns.CreateTargetSettings(category)
    local outer=CreateFrame("Frame")
    local scroll=CreateFrame("ScrollFrame",nil,outer,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",8,-8); scroll:SetPoint("BOTTOMRIGHT",-30,86)
    local panel=CreateFrame("Frame",nil,scroll)
    panel:SetSize(620,1030); scroll:SetScrollChild(panel)
    local function Label(value,y)
        local label=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        label:SetPoint("TOPLEFT",18,y); label:SetWidth(540); label:SetJustifyH("LEFT"); label:SetText(value)
        return label
    end
    Label("Target buffs",-20)
    local checks={}
    for i,entry in ipairs({{"targetBuff","Enable buffing the current target"},{"targetCursor","Show target buff button"},{"targetSourcesAuto","Automatically show buff sources when I select someone"},{"targetNPCs","Allow buffing NPCs"}}) do
        local key=entry[1]
        local box=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
        box:SetSize(26,26); box:SetPoint("TOPLEFT",14,-45-(i-1)*35)
        local label=box:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        label:SetPoint("LEFT",box,"RIGHT",4,0); label:SetText(entry[2])
        box:SetScript("OnClick",function(self) BuffyLoverDB[key]=self:GetChecked() and true or false; ns.RefreshTargetBuff(true) end)
        checks[key]=box
    end
    Label("Click once per buff. The shortcut works with the cursor buttons hidden.\nCasting pauses in combat. Existing PvP and missing-buff checks apply.\nSources show Unknown when the game does not expose the caster.",-195)
    local feedback=Label("Shortcuts also appear in Options > Keybindings > BuffyLove",-260)
    local function Binding(label,command,y)
        local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        b:SetSize(370,28); b:SetPoint("TOPLEFT",18,y)
        local function Refresh() b:SetText(label..": "..(GetBindingKey(command) or "Not bound")) end
        b:SetScript("OnClick",function(self) self:EnableKeyboard(true); self:SetPropagateKeyboardInput(false); self:SetText("Press a key (Escape cancels)") end)
        b:SetScript("OnKeyDown",function(self,key)
            if key=="LSHIFT" or key=="RSHIFT" or key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" then return end
            self:EnableKeyboard(false); self:SetPropagateKeyboardInput(true)
            if key=="ESCAPE" then Refresh(); return end
            if InCombatLockdown() then feedback:SetText("Leave combat before changing shortcuts."); Refresh(); return end
            key=(IsControlKeyDown() and "CTRL-" or "")..(IsAltKeyDown() and "ALT-" or "")..(IsShiftKeyDown() and "SHIFT-" or "")..key
            local existing=GetBindingAction(key)
            if existing and existing~="" and existing~=command then feedback:SetText(key.." is already bound. Choose another key or use Keybindings."); Refresh(); return end
            local previous={GetBindingKey(command)}
            if SetBinding(key,command) then
                for _,old in ipairs(previous) do if old~=key then SetBinding(old) end end
                SaveBindings(GetCurrentBindingSet()); feedback:SetText("Shortcut saved.")
            end
            Refresh()
        end)
        b:SetScript("OnHide",function(self) self:EnableKeyboard(false); self:SetPropagateKeyboardInput(true); Refresh() end)
        local clear=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        clear:SetSize(100,28); clear:SetPoint("LEFT",b,"RIGHT",8,0); clear:SetText("Clear")
        clear:SetScript("OnClick",function()
            if InCombatLockdown() then feedback:SetText("Leave combat before changing shortcuts."); return end
            local keys={GetBindingKey(command)}
            for _,key in ipairs(keys) do SetBinding(key) end
            SaveBindings(GetCurrentBindingSet()); Refresh()
        end)
        return Refresh
    end
    local refreshCast=Binding("Buff target",action,-300)
    local refreshSources=Binding("Show buff sources","BUFFYLOVER_TARGET_SOURCES",-345)
    local hideUnavailable=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    hideUnavailable:SetSize(26,26); hideUnavailable:SetPoint("TOPLEFT",14,-385)
    local hideLabel=hideUnavailable:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    hideLabel:SetPoint("LEFT",hideUnavailable,"RIGHT",4,0); hideLabel:SetText("Hide icon when no buff is possible")
    hideUnavailable:SetScript("OnClick",function(self)
        BuffyLoverDB.targetHideUnavailable=self:GetChecked() and true or false; ns.RefreshTargetBuff(false)
    end)
    checks.targetHideUnavailable=hideUnavailable
    local fields={}
    for i,entry in ipairs({{"targetIconSize","Icon size (16-80)",16,80},{"targetOffsetX","Horizontal offset (-3000 to 3000)",-3000,3000},{"targetOffsetY","Vertical offset (-3000 to 3000)",-3000,3000}}) do
        local key,title,low,high=unpack(entry)
        Label(title,-430-(i-1)*40)
        local field=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
        field:SetSize(80,25); field:SetPoint("TOPLEFT",340,-425-(i-1)*40); field:SetAutoFocus(false)
        local function save(self)
            local value=tonumber(self:GetText())
            if value and value==value and value>=low and value<=high then
                BuffyLoverDB[key]=math.floor(value); ns.RefreshTargetBuff(true)
            end
            self:SetText(tostring(BuffyLoverDB[key]))
        end
        field:SetScript("OnEnterPressed",function(self) save(self); self:ClearFocus() end)
        field:SetScript("OnEditFocusLost",save)
        field:SetScript("OnEscapePressed",function(self) self:SetText(tostring(BuffyLoverDB[key])); self:ClearFocus() end)
        fields[key]=field
    end
    Label("Enter or click away to save. Positive offsets move right / up.\nThe source shortcut works even when the icon is hidden.",-550)
    local modes={{"cursor","Cursor when selecting target"},{"screen","Fixed screen position"},{"target","Below target frame"}}
    local placement=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    placement:SetSize(370,28); placement:SetPoint("TOPLEFT",18,-600)
    local function refreshPlacement()
        for _,entry in ipairs(modes) do if entry[1]==BuffyLoverDB.targetPosition then placement:SetText("Position: "..entry[2]) end end
        for key,field in pairs(fields) do field:SetText(tostring(BuffyLoverDB[key])) end
    end
    placement:SetScript("OnClick",function()
        if InCombatLockdown() then feedback:SetText("Leave combat before positioning the button."); return end
        local index=1
        for i,entry in ipairs(modes) do if entry[1]==BuffyLoverDB.targetPosition then index=i end end
        BuffyLoverDB.targetPosition=modes[index % #modes+1][1]
        ns.RefreshTargetBuff(true); refreshPlacement()
    end)
    local move=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    move:SetSize(240,28); move:SetPoint("TOPLEFT",18,-640); move:SetText("Drag to set screen position")
    local marker
    move:SetScript("OnClick",function()
        if InCombatLockdown() then feedback:SetText("Leave combat before positioning the button."); return end
        if not marker then
            marker=CreateFrame("Button",nil,UIParent,"UIPanelButtonTemplate")
            marker:SetSize(200,48); marker:SetText("Drag buff button here\nRight-click to finish")
            marker:SetFrameStrata("DIALOG"); marker:SetClampedToScreen(true); marker:SetMovable(true)
            marker:RegisterForDrag("LeftButton"); marker:RegisterForClicks("RightButtonUp")
            marker:SetScript("OnDragStart",function(self) self:StartMoving() end)
            marker:SetScript("OnDragStop",function(self)
                self:StopMovingOrSizing()
                local x,y=self:GetCenter(); local px,py=UIParent:GetCenter()
                BuffyLoverDB.targetPosition="screen"; BuffyLoverDB.targetOffsetX=math.floor(x-px); BuffyLoverDB.targetOffsetY=math.floor(y-py)
                ns.RefreshTargetBuff(true); refreshPlacement()
            end)
            marker:SetScript("OnClick",function(self) self:Hide() end)
        end
        marker:ClearAllPoints(); marker:SetPoint("CENTER",UIParent,"CENTER",BuffyLoverDB.targetOffsetX,BuffyLoverDB.targetOffsetY); marker:Show()
    end)
    Label("Icon appearance",-700)
    local preview=CreateFrame("Frame",nil,panel)
    preview:SetSize(48,48); preview:SetPoint("TOPLEFT",460,-735)
    preview.icon=preview:CreateTexture(nil,"ARTWORK")
    preview.icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
    preview.icon:SetTexCoord(.08,.92,.08,.92); CreateIconStyle(preview)
    local function refreshPreview()
        StyleIcon(preview,BuffyLoverDB,48); preview:SetAlpha(BuffyLoverDB.targetOpacity/100)
    end
    local shape=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    shape:SetSize(300,28); shape:SetPoint("TOPLEFT",18,-735)
    local shapes={{"square","Square"},{"rounded","Rounded square"},{"circle","Circle"}}
    local function refreshShape()
        for _,entry in ipairs(shapes) do if entry[1]==BuffyLoverDB.targetShape then shape:SetText("Shape: "..entry[2]) end end
        refreshPreview()
    end
    shape:SetScript("OnClick",function()
        local index=1
        for i,entry in ipairs(shapes) do if entry[1]==BuffyLoverDB.targetShape then index=i end end
        BuffyLoverDB.targetShape=shapes[index % #shapes+1][1]
        ns.RefreshTargetBuff(false); refreshShape()
    end)
    for i,entry in ipairs({{"targetBorderWidth","Border width (0-6; 0 hides border)",0,6},{"targetOpacity","Opacity (20-100%)",20,100}}) do
        local key,title,low,high=unpack(entry)
        Label(title,-785-(i-1)*40)
        local field=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
        field:SetSize(80,25); field:SetPoint("TOPLEFT",340,-780-(i-1)*40); field:SetAutoFocus(false)
        local function save(self)
            local value=tonumber(self:GetText())
            if value and value==value and value>=low and value<=high then BuffyLoverDB[key]=math.floor(value) end
            self:SetText(tostring(BuffyLoverDB[key])); ns.RefreshTargetBuff(false); refreshPreview()
        end
        field:SetScript("OnEnterPressed",function(self) save(self); self:ClearFocus() end)
        field:SetScript("OnEditFocusLost",save)
        field:SetScript("OnEscapePressed",function(self) self:SetText(tostring(BuffyLoverDB[key])); self:ClearFocus() end)
        fields[key]=field
    end
    Label("Border colour (hex, e.g. FFD700 = gold)",-865)
    local colour=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
    colour:SetSize(100,25); colour:SetPoint("TOPLEFT",340,-860); colour:SetAutoFocus(false); colour:SetMaxLetters(6)
    local function saveColour(self)
        local value=self:GetText()
        if value:match("^%x%x%x%x%x%x$") then BuffyLoverDB.targetBorderColor=value:upper() end
        self:SetText(BuffyLoverDB.targetBorderColor); ns.RefreshTargetBuff(false); refreshPreview()
    end
    colour:SetScript("OnEnterPressed",function(self) saveColour(self); self:ClearFocus() end)
    colour:SetScript("OnEditFocusLost",saveColour)
    colour:SetScript("OnEscapePressed",function(self) self:SetText(BuffyLoverDB.targetBorderColor); self:ClearFocus() end)
    Label("Enter or click away to save. Appearance changes apply after combat.\nPreview shows the chosen shape, border and opacity.",-915)
    local function refreshPage()
        for key,box in pairs(checks) do box:SetChecked(BuffyLoverDB[key]) end
        for key,field in pairs(fields) do field:SetText(tostring(BuffyLoverDB[key])) end
        refreshCast(); refreshSources()
        refreshPlacement(); refreshShape(); colour:SetText(BuffyLoverDB.targetBorderColor)
    end
    outer:SetScript("OnShow",refreshPage)
    ns.RefreshTargetSettings=refreshPage
    outer:SetScript("OnHide",function() if marker then marker:StopMovingOrSizing(); marker:Hide() end end)
    if ns.AddPageDefaults then ns.AddPageDefaults(outer,"target") end
    Settings.RegisterCanvasLayoutSubcategory(category,outer,"Target buffs")
end
