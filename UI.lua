local _, NS = ...
local W, H = 860, 540
local frame, glass, content, title, description, context
local buttons = {}
local material = { mode="reflective", surfaces={}, panes={} }

local function PaintMaterial()
    local reflective = material.mode == "reflective"
    for _, item in ipairs(material.surfaces) do
        local g, shell = item.glass, item.role == "shell"
        if shell then
            glass.SetSurfaceTint(g, reflective and 0.085 or 0.055,
                reflective and 0.095 or 0.07, reflective and 0.115 or 0.09,
                reflective and 0.78 or 0.86)
            item.backing:SetColorTexture(0.03, 0.03, 0.035, reflective and 0.55 or 0.82)
            for _, layer in ipairs(item.reflections) do layer:SetShown(reflective) end
        else
            glass.SetSurfaceTint(g, 0.095, 0.11, 0.135, 0.90)
        end
        glass.SetWash(g, shell and 0 or 0.025)
        g.rim:SetAlpha(shell and 0.12 or 0.22)
        g.dark:SetAlpha(shell and 0.55 or 0.35)
        g.shadow:SetAlpha(shell and 0.18 or 0.05)
        g.grain:SetAlpha(0)
        if reflective then
            glass.SetEdge(g, shell and 0 or 0.10, shell and 0 or 0.015, shell and 0 or 0.12, 3)
        else
            local edge = glass.STYLE.edge
            glass.SetEdge(g, edge, edge * glass.EDGE.glow, edge * glass.EDGE.bottom, glass.EDGE.glowh)
        end
    end
    for _, pane in ipairs(material.panes) do pane:SetShown(reflective) end
end

function NS.SetMaterial(mode)
    if mode ~= "reflective" and mode ~= "flat" then return false end
    material.mode = mode
    if glass then PaintMaterial() end
    return true
end
local pages = {
    { key="guide", label="Pet Guide", title="Discover your next companion",
      text="The pet guide is coming soon.\n\nBrowseable families, appearances, and locations will appear here as the Forever catalog is added." },
    { key="upgrades", label="Ability Upgrades", title="Plan your pet's next ability",
      text="Ability recommendations are coming soon.\n\nThis page will help you find new ranks and the creatures or trainers that teach them." },
    { key="pets", label="My Pets", title="Your companions, together",
      text="Your pet collection is coming soon.\n\nOwned pets and their known abilities will appear here once collection tracking is available." },
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
            -- Static layers from References/LIBGLASS-WINDOW-STYLING.md.
            -- Alpha belongs in gradient endpoints on Forever.
            local S = glass.SIZES[surface.size]
            local rim = surface.top:CreateTexture(nil, "OVERLAY", nil, 6)
            rim:SetAllPoints(host)
            rim:SetTexture(glass.MEDIA .. S.rim)
            rim:SetTextureSliceMargins(S.rimMargin, S.rimMargin, S.rimMargin, S.rimMargin)
            rim:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            rim:SetGradient("VERTICAL", CreateColor(0.55,0.65,0.75,0.035), CreateColor(0.84,0.88,0.91,0.52))
            local top = surface.top:CreateTexture(nil, "OVERLAY", nil, 7)
            top:SetColorTexture(1,1,1,1)
            top:SetPoint("TOPLEFT", host, "TOPLEFT", S.maskMargin,-1)
            top:SetPoint("TOPRIGHT", host, "TOPRIGHT", -S.maskMargin,-1)
            top:SetHeight(1)
            top:SetGradient("HORIZONTAL", CreateColor(0.88,0.91,0.93,0.58), CreateColor(0.65,0.73,0.8,0.035))
            local reflection = host:CreateTexture(nil, "BACKGROUND", nil, -3)
            reflection:SetColorTexture(1,1,1,1)
            reflection:AddMaskTexture(surface.mask)
            reflection:SetPoint("TOPLEFT",host,"TOPLEFT",0,0)
            reflection:SetPoint("TOPRIGHT",host,"TOPRIGHT",0,0)
            reflection:SetHeight(70) -- fade before the reading region at y=82
            reflection:SetGradient("VERTICAL", CreateColor(0.77,0.81,0.85,0), CreateColor(0.77,0.81,0.85,0.105))
            item.reflections = { rim, top, reflection }
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
        fs:SetFont("Fonts\\FRIZQT__.TTF", size)
        fs:SetJustifyH("LEFT")
    end
    fs:SetTextColor(unpack(color or {0.9, 0.93, 0.95, 1}))
    return fs
end

function NS.Layout()
    if not frame then return end
    local fit = math.min(1.3, (UIParent:GetWidth()-32)/W, (UIParent:GetHeight()-32)/H)
    frame:SetScale(math.max(0.1, math.min(NS.db.scale, fit)))
    local p = NS.db.position
    frame:ClearAllPoints()
    frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
end

function NS.SelectPage(key)
    for _, page in ipairs(pages) do
        local selected = page.key == key
        local b = buttons[page.key]
        b.label:SetTextColor(selected and 0.78 or 0.8, selected and 0.94 or 0.83, selected and 0.65 or 0.86, 1)
        b.marker:SetShown(selected)
        if selected then
            NS.db.page = key
            title:SetText(page.title)
            description:SetText(page.text)
        end
    end
    local _, class = UnitClass("player")
    context:SetText(class == "HUNTER" and "PetStable • Forever" or "The pet guide is open to everyone. Ability advice and pet tracking are for hunters.")
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
    frame:SetSize(W,H)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(self, key)
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then self:Hide() end
    end)
    Surface(frame, "large", "shell")
    content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    content:SetFrameLevel(glass and glass.ContentLevel(frame) or frame:GetFrameLevel()+2)
    if glass then
        -- One continuous reading area follows PetStable's navigation, page,
        -- help and footer; no extra input frames or per-paragraph cards.
        local pane = content:CreateTexture(nil, "BACKGROUND", nil, -7)
        pane:SetPoint("TOPLEFT",content,"TOPLEFT",12,-82)
        pane:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",-12,12)
        pane:SetColorTexture(0.072,0.082,0.10,0.94)
        local S = glass.SIZES.thin_small
        pane:AddMaskTexture(glass.Mask(content,S.mask,S.maskMargin,0,pane))
        material.panes[#material.panes+1] = pane
    end
    local heading = Text(content, 24, {0.78,0.94,0.65,1})
    heading:SetPoint("TOPLEFT", 24, -22); heading:SetText("PetStable")
    local subtitle = Text(content, 12, {0.68,0.74,0.79,1})
    subtitle:SetPoint("TOPLEFT", 25, -53); subtitle:SetText("A hunter's field guide to Forever")
    local drag = CreateFrame("Frame", nil, content)
    drag:SetPoint("TOPLEFT"); drag:SetPoint("TOPRIGHT", -52, 0); drag:SetHeight(78)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    local function StopDrag()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        NS.db.position = {point=point,relativePoint=relativePoint,x=x,y=y}
    end
    drag:SetScript("OnDragStop", StopDrag)
    frame:SetScript("OnHide", StopDrag)
    local close = CreateFrame("Button", nil, content, "BackdropTemplate")
    close:SetSize(30,28); close:SetPoint("TOPRIGHT", -14,-14)
    Surface(close,"small","control")
    local x = Text(close, 18); x:SetPoint("CENTER"); x:SetText("×")
    close:SetScript("OnClick", function() frame:Hide() end)
    for i,page in ipairs(pages) do
        local b = CreateFrame("Button",nil,content,"BackdropTemplate")
        b:SetSize(180,44); b:SetPoint("TOPLEFT",20,-94-(i-1)*54)
        Surface(b,"small","control")
        b.label=Text(b,14); b.label:SetPoint("LEFT",18,0); b.label:SetText(page.label)
        b.marker=b:CreateTexture(nil,"OVERLAY")
        b.marker:SetColorTexture(0.6,0.85,0.4,1); b.marker:SetSize(3,24); b.marker:SetPoint("LEFT",6,0)
        local key = page.key
        b:SetScript("OnClick", function() NS.SelectPage(key) end)
        buttons[key]=b
    end
    title=Text(content,22); title:SetPoint("TOPLEFT",232,-108); title:SetWidth(590)
    description=Text(content,16); description:SetPoint("TOPLEFT",232,-158)
    description:SetSize(580,220); description:SetWordWrap(true)
    description:SetJustifyV("TOP"); description:SetSpacing(5)
    context=Text(content,12,{0.72,0.78,0.82,1}); context:SetPoint("BOTTOMLEFT",24,24); context:SetWidth(810)
    local hint=Text(content,12,{0.64,0.70,0.75,1})
    hint:SetPoint("BOTTOMLEFT",232,82); hint:SetText("Drag the title bar to move • /petstable scale 0.9 to resize")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:SetScript("OnEvent", NS.Layout)
    NS.Layout()
    NS.SelectPage(NS.db.page)
    NS.buttons=buttons
    if glass then PaintMaterial() end
end

function NS.Toggle()
    if not frame then Build(); frame:Show()
    elseif frame:IsShown() then frame:Hide()
    else NS.SelectPage(NS.db.page); frame:Show() end
end
