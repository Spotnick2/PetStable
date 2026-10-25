local _, NS = ...
local Toast = {}
NS.Toast = Toast

-- A small dismissible notice. One shows at a time; a new one replaces it. The optional
-- Target button is a secure macro the player clicks, so nothing is targeted automatically.
local WIDTH, LIFETIME = 400, 45
local frame, widgets

local function Clean(text)
    return (tostring(text or ""):gsub("[%c|]", ""):sub(1, 60))
end

local function Build()
    frame = CreateFrame("Frame", "PetStableToast", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 170); frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true); frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.045, 0.065, 0.055, 0.97); frame:SetBackdropBorderColor(0.4, 0.5, 0.42, 1)
    widgets = { buttons = {} }
    local function Font(size, r, g, b)
        local fs = frame:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, ""); fs:SetTextColor(r, g, b, 1)
        fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetWordWrap(true)
        return fs
    end
    widgets.title = Font(11, 0.78, 0.94, 0.65); widgets.title:SetPoint("TOPLEFT", 14, -10)
    widgets.body = Font(13, 0.92, 0.95, 0.93); widgets.body:SetPoint("TOPLEFT", 14, -30); widgets.body:SetWidth(WIDTH - 28)
    widgets.note = Font(11, 0.68, 0.74, 0.79); widgets.note:SetWidth(WIDTH - 28)
    local close = CreateFrame("Button", nil, frame, "BackdropTemplate"); close:SetSize(24, 22); close:SetPoint("TOPRIGHT", -6, -6)
    close.label = Font(14, 0.9, 0.93, 0.95); close.label:SetParent(close); close.label:SetPoint("CENTER"); close.label:SetText("×")
    if NS.StyleButton then NS.StyleButton(close) end
    close:SetScript("OnClick", function() Toast.Hide() end)
    widgets.close = close
    frame:Hide()
end

local function Slot(i, secure)
    local key = (secure and "s" or "b") .. i
    local button = widgets.buttons[key]
    if button then return button end
    button = CreateFrame("Button", nil, frame, (secure and "SecureActionButtonTemplate," or "") .. "BackdropTemplate")
    button:SetHeight(24)
    button.label = frame:CreateFontString(nil, "OVERLAY")
    button.label:SetFont("Fonts\\FRIZQT__.TTF", 12, ""); button.label:SetTextColor(0.9, 0.93, 0.95, 1)
    button.label:SetParent(button); button.label:SetPoint("CENTER")
    if NS.StyleButton then NS.StyleButton(button) end
    widgets.buttons[key] = button
    return button
end

function Toast.Hide()
    if frame then frame:Hide(); frame:SetScript("OnUpdate", nil) end
end

function Toast.IsShown() return frame ~= nil and frame:IsShown() end

-- opts: title, body, note, target (a creature name for the Target button), buttons {{text, onClick}}.
function Toast.Show(opts)
    if not frame then Build() end
    for _, button in pairs(widgets.buttons) do button:Hide() end
    widgets.title:SetText(Clean(opts.title))
    widgets.body:SetText((tostring(opts.body or ""):gsub("|", "||")))
    local y = 30 + math.max(16, widgets.body:GetStringHeight()) + 8
    widgets.note:ClearAllPoints(); widgets.note:SetPoint("TOPLEFT", 14, -y)
    widgets.note:SetText(opts.note or "")
    y = y + (opts.note and math.max(14, widgets.note:GetStringHeight()) or 0) + 8
    local x, row = 14, 0
    local function Place(button, label)
        local width = math.max(70, #label * 7 + 20)
        if x + width > WIDTH - 14 then x, row = 14, row + 1 end
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, -(y + row * 28)); button:SetWidth(width)
        button.label:SetText(label); button:Show(); x = x + width + 6
    end
    -- Secure attributes cannot change in combat, so the Target button is simply left out then.
    local name = opts.target and Clean(opts.target)
    local inCombat = rawget(_G, "InCombatLockdown") and InCombatLockdown()
    if name and name ~= "" and not inCombat then
        local button = Slot(1, true)
        button:SetAttribute("type", "macro"); button:SetAttribute("macrotext", "/targetexact " .. name)
        button:SetScript("PostClick", nil)
        Place(button, "Target")
    end
    for i, spec in ipairs(opts.buttons or {}) do
        local button = Slot(i, false)
        button:SetScript("OnClick", function() if spec.onClick then spec.onClick() end; Toast.Hide() end)
        Place(button, spec.text)
    end
    frame:SetHeight(y + (row + 1) * 28 + 10)
    local age = 0
    frame:SetScript("OnUpdate", function(_, delta) age = age + delta; if age >= LIFETIME then Toast.Hide() end end)
    frame:Show()
end
