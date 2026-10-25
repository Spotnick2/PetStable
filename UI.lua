local _, NS = ...
local frame, glass, content, title, description, context
local buttons, controls = {}, {}
local material = { mode="reflective", surfaces={}, panes={} }

local function PaintMaterial()
    local reflective = material.mode == "reflective"
    for _, item in ipairs(material.surfaces) do
        local g, shell = item.glass, item.role == "shell"
        if shell then
            glass.SetSurfaceTint(g, reflective and 0.075 or 0.055,
                reflective and 0.095 or 0.07, reflective and 0.09 or 0.08,
                reflective and 0.78 or 0.86)
            item.backing:SetColorTexture(0.03, 0.03, 0.035, reflective and 0.55 or 0.82)
            for _, layer in ipairs(item.reflections) do layer:SetShown(reflective) end
        else
            glass.SetSurfaceTint(g, 0.095, 0.11, 0.135, 0.90)
        end
        glass.SetWash(g, shell and 0 or 0.025)
        glass.SetSurfaceAlpha(g, "rim", shell and 0.12 or 0.22)
        glass.SetSurfaceAlpha(g, "dark", shell and 0.55 or 0.35)
        glass.SetSurfaceAlpha(g, "shadow", shell and 0.18 or 0.05)
        glass.SetSurfaceAlpha(g, "grain", 0)
        if reflective then
            glass.SetEdge(g, shell and 0 or 0.10, shell and 0 or 0.015, shell and 0 or 0.12, 3)
        else
            local edge = glass.STYLE.edge
            glass.SetEdge(g, edge, edge * glass.EDGE.glow, edge * glass.EDGE.bottom, glass.EDGE.glowh)
        end
    end
    for _, pane in ipairs(material.panes) do pane:SetShown(reflective) end
    for _,control in ipairs(controls) do control.Paint() end
end

function NS.SetMaterial(mode)
    if mode ~= "reflective" and mode ~= "flat" then return false end
    material.mode = mode
    if glass then PaintMaterial() end
    return true
end
local pages = {
    { key="guide", label="Pet Guide", title="Find your next companion",
      text="" },
    { key="upgrades", label="Ability Upgrades", title="Pet ability ranks and who teaches them",
      text="" },
    { key="pets", label="My Pets", title="Your pet and stable",
      text="" },
}

local function Surface(host, size, role)
    if glass then
        local surface = glass.Apply(host, size)
        local item = { glass=surface, role=role }
        if role == "shell" then
            local backing = host:CreateTexture(nil, "BACKGROUND", nil, -7)
            backing:SetAllPoints(host)
            backing:AddMaskTexture(surface.mask)
            item.backing = backing
            local reflection = glass.Reflect(surface, host, { header=70 })
            item.reflections = { reflection.rim, reflection.top, reflection.header }
        end
        material.surfaces[#material.surfaces+1] = item
        return surface
    end
    host:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    host:SetBackdropColor(0.055, 0.07, 0.09, 0.97)
    host:SetBackdropBorderColor(0.25, 0.30, 0.34, 1)
end

local function Text(parent, size, color)
    local fs
    if glass then fs = glass.Font(parent, size, "LEFT")
    else
        fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, "")
        fs:SetJustifyH("LEFT")
    end
    fs:SetTextColor(unpack(color or {0.9, 0.93, 0.95, 1}))
    return fs
end

-- Per-addon material and short hover fades. Active, hover and pressed are separate.
function NS.StyleButton(b,tab)
    local g=glass and not tab and glass.Apply(b,"small")
    if g then
        glass.SetSurfaceAlpha(g,"dark",0.25); glass.SetSurfaceAlpha(g,"shadow",0.04)
        glass.SetSurfaceAlpha(g,"grain",0); glass.SetEdge(g,0.045,0,0)
    elseif not tab then
        b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    end
    b.hoverAmount=0; b.hoverTarget=0
    function b.Paint()
        local amount=b.hoverAmount or 0
        local accent=math.max(amount,b.active and 0.65 or 0)
        local dim=b.disabled and 0.45 or 1
        local shade=b.pressed and -0.025 or 0
        if g then
            glass.SetSurfaceTint(g,0.075+accent*0.04+shade,0.09+accent*0.065+shade,0.09+accent*0.025+shade,0.96)
            glass.SetSurfaceRim(g,0.48+accent*0.25,0.55+accent*0.3,0.54+accent*0.12,((b.familyCard and 0.17 or 0.22)+accent*0.42)*dim)
            glass.SetWash(g,(b.familyCard and 0.055 or 0.025)+amount*0.035)
            if b.familyCard then glass.SetEdge(g,0.09+amount*0.02,0,0.012) end
        elseif not tab then
            b:SetBackdropColor((0.075+accent*0.04+shade)*dim,(0.09+accent*0.065+shade)*dim,(0.09+accent*0.025+shade)*dim,0.96)
            b:SetBackdropBorderColor(0.28+accent*0.3,0.33+accent*0.43,0.32+accent*0.23,dim)
        end
        if b.label then
            local bright=b.familyCard and 0.06 or 0
            b.label:SetTextColor((0.84+bright+accent*0.08)*dim,(0.88+bright+accent*0.06)*dim,(0.86+bright-accent*0.08)*dim,1)
        end
        if b.arrow then b.arrow:SetShown(not b.disabled and b.hoverTarget==1) end
    end
    function b.ResetHover()
        b.hoverAmount=0; b.hoverTarget=0; b.pressed=false; b:SetScript("OnUpdate",nil); b.Paint()
    end
    local function Animate(self,elapsed)
        self.hoverAmount=self.hoverAmount+(self.hoverTarget-self.hoverAmount)*math.min(1,elapsed*16)
        if math.abs(self.hoverTarget-self.hoverAmount)<0.01 then self.hoverAmount=self.hoverTarget; self:SetScript("OnUpdate",nil) end
        self.Paint()
    end
    b:SetScript("OnEnter",function(self)
        if self.disabled then return end
        self.hoverTarget=1; self:SetScript("OnUpdate",Animate); self.Paint()
    end)
    b:SetScript("OnLeave",function(self) self.hoverTarget=0; self.pressed=false; self:SetScript("OnUpdate",Animate); self.Paint() end)
    b:SetScript("OnMouseDown",function(self) self.pressed=true; self.Paint() end)
    b:SetScript("OnMouseUp",function(self) self.pressed=false; self.Paint() end)
    b:SetScript("OnHide",b.ResetHover)
    controls[#controls+1]=b; b.Paint()
    if NS.history then NS.BindHistoryMouse(b) end
end

local function Contents()
    if not NS.guide then return end
    local w,h=frame:GetWidth(),frame:GetHeight()
    title:SetWidth(w-310); description:SetSize(w-48,h-220); context:SetWidth(w-70)
    NS.guide.Layout(w-48,h-180)
    if NS.upgrades then NS.upgrades.Layout(w-48,h-180) end
    if NS.pets then NS.pets.Layout(w-48,h-180) end
end

-- The level filter or the hunter's level changed: repaint what depends on it.
function NS.RefreshFilters()
    if NS.settings then NS.settings.Sync() end
    if NS.guide then NS.guide.Refresh(false) end
    if NS.upgrades and NS.upgrades:IsShown() then NS.upgrades.Refresh() end
end

function NS.Layout()
    if not frame then return end
    local availableW,availableH=UIParent:GetWidth()-32,UIParent:GetHeight()-32
    local scale=math.max(0.1,math.min(NS.db.scale,availableW/800,availableH/560))
    local maxW,maxH=math.max(800,math.min(1440,availableW/scale)),math.max(560,math.min(1000,availableH/scale))
    frame:SetScale(scale); frame:SetResizeBounds(800,560,maxW,maxH)
    frame:SetSize(math.min(NS.db.width,maxW),math.min(NS.db.height,maxH))
    local p = NS.db.position
    frame:ClearAllPoints()
    frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    Contents()
    if NS.settings then NS.settings.Sync() end
end

function NS.SelectPage(key)
    if NS.guide then NS.guide.ClearFocus(); NS.guide.ResetHover() end
    if NS.settings then NS.settings:Hide() end
    for _, page in ipairs(pages) do
        local selected = page.key == key
        local b = buttons[page.key]
        b.active=selected; b.ResetHover()
        b.marker:SetShown(selected)
        if selected then
            NS.db.page = key
            title:Show()
            title:SetText(page.title)
            description:SetText(page.text)
        end
    end
    if NS.guide then
        NS.guide:SetShown(key=="guide")
        description:SetShown(key~="guide" and key~="upgrades" and key~="pets")
        if NS.pets then
            NS.pets.ResetHover(); NS.pets:SetShown(key=="pets")
            if key=="pets" then NS.pets.Refresh() end
        end
        if NS.upgrades then
            NS.upgrades.ResetHover(); NS.upgrades:SetShown(key=="upgrades")
            if key=="upgrades" then NS.upgrades.Refresh() end
        end
        if key=="guide" then NS.guide.Refresh(false) end
    end
    local _, class = UnitClass("player")
    context:SetText(class == "HUNTER" and "PetStable • Forever" or "The pet guide is open to everyone. Ability advice and pet tracking are for hunters.")
end

-- Local input hooks only: never change the player's global mouse bindings.
function NS.BindHistoryMouse(host)
    -- Adding a mouse script can enable hit testing. In particular LibGlass's
    -- full-size rim frames sit above controls and must remain click-through.
    if host.petStableHistoryHooked or not host:IsMouseClickEnabled() or not host:HasScript("OnMouseUp") then return end
    host.petStableHistoryHooked=true
    host:HookScript("OnMouseUp",function(_,button)
        if not frame:IsShown() then return end
        if button=="Button4" then NS.history.Move(-1)
        elseif button=="Button5" then NS.history.Move(1) end
    end)
end

local function CreateHistory()
    local history={entries={},index=1}; NS.history=history
    local busy=false
    local function Capture() return {page=NS.db.page,guide=NS.guide.Capture()} end
    local function Route(saved)
        if saved.page~="guide" then return saved.page end
        local g=saved.guide
        local result=g.view=="appearance" and g.appearance.result
        return table.concat({saved.page,g.view,g.familyKey or "",g.sourceFamily or "",result and result.group.key or ""},"/")
    end
    history.entries[1]=Capture()
    function history.Move(delta)
        local target=history.index+delta
        if busy or target<1 or target>#history.entries then return false end
        history.entries[history.index]=Capture()
        history.index=target; local saved=history.entries[target]
        busy=true
        NS.SelectPage(saved.page)
        if saved.page=="guide" then NS.guide.Restore(saved.guide) end
        busy=false
        return true
    end
    local function Wrap(host,key)
        local original=host[key]
        host[key]=function(...)
            if busy then return original(...) end
            local before=Capture(); busy=true
            local ok,result=pcall(original,...)
            busy=false
            if not ok then error(result,0) end
            local after=Capture()
            if Route(before)~=Route(after) then
                history.entries[history.index]=before
                for i=#history.entries,history.index+1,-1 do history.entries[i]=nil end
                history.entries[#history.entries+1]=after
                if #history.entries>50 then table.remove(history.entries,1) end
                history.index=#history.entries
            else history.entries[history.index]=after end
            return result
        end
    end
    Wrap(NS,"SelectPage")
    for _,name in ipairs({"ShowFamilies","OpenFamily","OpenSources"}) do Wrap(NS.guide,name) end
    for _,name in ipairs({"OpenAppearance","Back"}) do Wrap(NS.guide.appearances,name) end
    local function BindTree(host)
        NS.BindHistoryMouse(host)
        for _,child in ipairs({host:GetChildren()}) do BindTree(child) end
    end
    BindTree(frame)
end

local function Build()
    if frame then return end
    local stub = rawget(_G, "LibStub")
    local lib = stub and stub("LibGlass-1.0", true)
    if lib and type(lib.New) == "function" then
        glass = lib:New({ preset="clean", bodyAlpha=0.88, style={ rimAlpha=1 } })
    end
    NS.Glass = glass
    frame = CreateFrame("Frame", "PetStableFrame", UIParent, "BackdropTemplate")
    NS.frame = frame
    frame:SetSize(NS.db.width,NS.db.height)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else self:SetPropagateKeyboardInput(not (NS.guide and NS.guide.HasFocus())) end
    end)
    Surface(frame, "large", "shell")
    content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    content:SetFrameLevel(glass and glass.ContentLevel(frame) or frame:GetFrameLevel()+2)
    if glass then
        -- One continuous reading area follows PetStable's navigation, page,
        -- help and footer; no extra input frames or per-paragraph cards.
        local pane = content:CreateTexture(nil, "BACKGROUND", nil, -7)
        pane:SetPoint("TOPLEFT",content,"TOPLEFT",12,-52)
        pane:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",-12,12)
        pane:SetColorTexture(0.045,0.06,0.055,0.96)
        local S = glass.SIZES.thin_small
        pane:AddMaskTexture(glass.Mask(content,S.mask,S.maskMargin,0,pane))
        material.panes[#material.panes+1] = pane
    end
    local heading = Text(content, 24, {0.78,0.94,0.65,1})
    heading:SetPoint("TOPLEFT", 24, -16); heading:SetText("PetStable")
    -- One compact header line leaves the space to the guide.
    local subtitle = Text(content, 12, {0.68,0.74,0.79,1})
    subtitle:SetPoint("BOTTOMLEFT", heading, "BOTTOMRIGHT", 14, 3); subtitle:SetText("A hunter's field guide to Forever")
    local drag = CreateFrame("Frame", nil, content)
    drag:SetPoint("TOPLEFT"); drag:SetPoint("TOPRIGHT", -160, 0); drag:SetHeight(50)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() NS.guide.ClearFocus(); frame:StartMoving() end)
    local resizing=false
    local function StopDrag()
        frame:StopMovingOrSizing()
        if resizing then NS.db.width,NS.db.height=frame:GetWidth(),frame:GetHeight(); resizing=false end
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        NS.db.position = {point=point,relativePoint=relativePoint,x=x,y=y}
    end
    drag:SetScript("OnDragStop", StopDrag)
    NS.drag=drag
    frame:SetScript("OnHide", function()
        if NS.guide then NS.guide.ClearFocus(); NS.guide.ResetHover() end
        if NS.settings then NS.settings:Hide() end
        StopDrag()
    end)
    local close = CreateFrame("Button", nil, content, "BackdropTemplate")
    close:SetSize(30,28); close:SetPoint("TOPRIGHT", -16,-18)
    NS.StyleButton(close)
    local x = Text(close, 18); x:SetPoint("CENTER"); x:SetText("×")
    close:SetScript("OnClick", function() frame:Hide() end)
    NS.close=close
    for i,page in ipairs(pages) do
        local b = CreateFrame("Button",nil,content,"BackdropTemplate")
        b:SetSize(152,34); b:SetPoint("TOPLEFT",24+(i-1)*160,-52)
        b.label=Text(b,14); b.label:SetPoint("CENTER"); b.label:SetText(page.label)
        b.marker=b:CreateTexture(nil,"OVERLAY")
        b.marker:SetColorTexture(0.62,0.8,0.5,1); b.marker:SetHeight(2)
        b.marker:SetPoint("BOTTOMLEFT",8,0); b.marker:SetPoint("BOTTOMRIGHT",-8,0)
        NS.StyleButton(b,true)
        local key = page.key
        b:SetScript("OnClick", function() NS.SelectPage(key) end)
        buttons[key]=b
    end
    local rule=content:CreateTexture(nil,"BACKGROUND"); rule:SetColorTexture(0.35,0.43,0.39,0.4)
    rule:SetPoint("TOPLEFT",16,-87); rule:SetPoint("TOPRIGHT",-16,-87); rule:SetHeight(1)
    title=Text(content,23); title:SetPoint("TOPLEFT",24,-98); title:SetWidth(700)
    NS.guideTitle=title
    description=Text(content,16); description:SetPoint("TOPLEFT",24,-152)
    description:SetSize(580,220); description:SetWordWrap(true)
    description:SetJustifyV("TOP"); description:SetSpacing(5)
    NS.guide=NS.CreateGuide(content,frame,Text)
    NS.upgrades=NS.CreateUpgrades(content,frame,Text)
    NS.pets=NS.CreatePets(content,frame,Text)
    context=Text(content,11,{0.6,0.68,0.64,1}); context:SetPoint("BOTTOMLEFT",24,16); context:SetWidth(810)
    local function Button(host,label,w,h,click)
        local b=CreateFrame("Button",nil,host,"BackdropTemplate"); b:SetSize(w,h)
        b.label=Text(b,13); b.label:SetPoint("CENTER"); b.label:SetText(label)
        NS.StyleButton(b); b:SetScript("OnClick",click); return b
    end
    local settings=CreateFrame("Frame",nil,content,"BackdropTemplate"); NS.settings=settings
    settings:SetSize(320,342); settings:SetPoint("TOPRIGHT",-16,-58); settings:SetFrameLevel(content:GetFrameLevel()+50); settings:EnableMouse(true)
    settings:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    settings:SetBackdropColor(0.045,0.065,0.055,1); settings:SetBackdropBorderColor(0.4,0.5,0.42,1)
    local help=Text(settings,13); help:SetPoint("TOPLEFT",16,-14); help:SetWidth(288)
    help:SetText("Window settings\n\nDrag the header to move.\nDrag the lower-right grip to resize.")
    local scaleLabel=Text(settings,13); scaleLabel:SetPoint("TOPLEFT",16,-100)
    local scale=CreateFrame("Slider",nil,settings,"BackdropTemplate"); settings.scale=scale
    scale:SetPoint("TOPLEFT",16,-124); scale:SetSize(288,20); scale:SetOrientation("HORIZONTAL")
    scale:SetMinMaxValues(0.65,1.3); scale:SetValueStep(0.05); scale:SetObeyStepOnDrag(true)
    scale:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); scale:SetBackdropColor(0.1,0.14,0.12,1)
    scale:SetThumbTexture("Interface\\Buttons\\WHITE8X8"); scale:GetThumbTexture():SetSize(12,20); scale:GetThumbTexture():SetVertexColor(0.65,0.8,0.55,1)
    local syncing=false
    function settings.Sync()
        syncing=true; scale:SetValue(NS.db.scale); scaleLabel:SetText(string.format("UI scale: %.0f%%",NS.db.scale*100)); syncing=false
    end
    scale:SetScript("OnValueChanged",function(_,value) if not syncing then NS.db.scale=value; NS.Layout() end end)
    local reset=Button(settings,"Reset window",136,28,function() SlashCmdList.PETSTABLE("reset") end); reset:SetPoint("TOPLEFT",16,-170); settings.reset=reset
    local done=Button(settings,"Done",136,28,function() settings:Hide() end); done:SetPoint("TOPRIGHT",-16,-170)
    if NS.Sightings then
        local capture
        capture=Button(settings,"",288,28,function()
            NS.Sightings.Command(NS.db.captureSightings and "off" or "on")
            capture.label:SetText("Record beast sightings: "..(NS.db.captureSightings and "On" or "Off"))
        end)
        capture:SetPoint("TOPLEFT",16,-208)
        local sync=settings.Sync
        settings.Sync=function()
            sync(); capture.label:SetText("Record beast sightings: "..(NS.db.captureSightings and "On" or "Off"))
        end
    end
    local levelFilter
    levelFilter=Button(settings,"",288,28,function()
        NS.db.filterToLevel=not NS.db.filterToLevel
        levelFilter.label:SetText("Filter to your level: "..(NS.db.filterToLevel and "On" or "Off"))
        NS.RefreshFilters()
    end)
    levelFilter:SetPoint("TOPLEFT",16,-284)
    local syncLevel=settings.Sync
    settings.Sync=function()
        syncLevel(); levelFilter.label:SetText("Filter to your level: "..(NS.db.filterToLevel and "On" or "Off"))
    end
    local start
    start=Button(settings,"",288,28,function()
        NS.db.startOnActivePet=not NS.db.startOnActivePet
        start.label:SetText("Open on your pet's family: "..(NS.db.startOnActivePet and "On" or "Off"))
    end)
    start:SetPoint("TOPLEFT",16,-246)
    local syncStart=settings.Sync
    settings.Sync=function()
        syncStart(); start.label:SetText("Open on your pet's family: "..(NS.db.startOnActivePet and "On" or "Off"))
    end
    settings:Hide()
    local settingsButton=Button(content,"Settings",80,28,function() NS.guide.ClearFocus(); settings:SetShown(not settings:IsShown()); settings.Sync() end)
    settingsButton:SetPoint("TOPRIGHT",-54,-18); NS.settingsButton=settingsButton
    local grip=Button(content,"",24,24,function() end); grip:SetPoint("BOTTOMRIGHT",-6,6); grip:SetFrameLevel(content:GetFrameLevel()+60); NS.resize=grip
    -- Draw the corner affordance: the bundled text font has no resize-arrow glyph.
    for i=1,3 do
        local span=i*4
        local line=grip:CreateTexture(nil,"OVERLAY")
        line:SetColorTexture(0.62,0.72,0.66,0.9); line:SetSize(span*math.sqrt(2),1)
        line:SetPoint("CENTER",grip,"BOTTOMRIGHT",-5-span/2,5+span/2); line:SetRotation(math.pi/4)
    end
    grip:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" then return end
        NS.guide.ClearFocus(); settings:Hide(); resizing=true; frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp",function(_,button) if button=="LeftButton" then StopDrag() end end)
    frame:SetScript("OnSizeChanged",Contents)
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:SetScript("OnEvent", function(_,event,level)
        if event=="PLAYER_LEVEL_UP" then NS.levelHint=tonumber(level); NS.RefreshFilters() else NS.Layout() end
    end)
    NS.Layout()
    NS.SelectPage(NS.db.page)
    NS.buttons=buttons
    -- First open of the session only, and only from fresh data: restored history is never replaced.
    local pet=NS.PetState and NS.PetState.Active()
    if NS.db.startOnActivePet and NS.db.page=="guide" and NS.PetState.State()=="fresh" and pet and pet.present and pet.familyKey then
        for _,family in ipairs(NS.guide.families) do
            if family.key==pet.familyKey then NS.guide.OpenFamily(pet.familyKey); break end
        end
    end
    CreateHistory()
    if glass then PaintMaterial() end
end

function NS.Toggle()
    if not frame then Build(); frame:Show()
    elseif frame:IsShown() then frame:Hide()
    else NS.SelectPage(NS.db.page); frame:Show() end
end
