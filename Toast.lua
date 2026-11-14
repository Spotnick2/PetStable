local _, NS = ...
local Toast = {}
NS.Toast = Toast

-- A small dismissible notice. One shows at a time; a new one replaces it. It contains no secure
-- or protected frames, so it can be shown, replaced and hidden at any time, including in combat.
-- A notice may offer a Target button (#39): that button is a separate secure frame (TargetButton.lua)
-- placed over a fixed band under the title. The notice never parents or anchors it.
local WIDTH, LIFETIME, MAX_HEIGHT, LEVEL = 400, 45, 300, 20
local BODY_TOP, BAND_BODY_TOP = 30, 64 -- the body starts lower when the band is reserved
local frame, widgets

local function Clean(text)
    return (tostring(text or ""):gsub("[%c|]", ""):sub(1, 60))
end

local function Label(button, text)
    button.label = button:CreateFontString(nil, "OVERLAY")
    button.label:SetFont("Fonts\\FRIZQT__.TTF", 12, ""); button.label:SetTextColor(0.9, 0.93, 0.95, 1)
    button.label:SetPoint("CENTER"); button.label:SetText(text or "")
end

local function Build()
    frame = CreateFrame("Frame", "PetStableToast", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 170); frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    -- Not clamped: clamping could move the notice away from the Target button's fixed band. Its height
    -- is capped instead, so it always fits (150 + 300 is inside UIParent at the largest UI scale).
    frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(LEVEL); frame:SetClampedToScreen(false); frame:EnableMouse(true)
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
    widgets.body = Font(13, 0.92, 0.95, 0.93); widgets.body:SetWidth(WIDTH - 28)
    widgets.note = Font(11, 0.68, 0.74, 0.79); widgets.note:SetWidth(WIDTH - 28)
    -- What the band says while the Target button can't be armed (in combat); the button covers it otherwise.
    widgets.band = Font(12, 0.72, 0.8, 0.74); widgets.band:SetPoint("TOPLEFT", 14, -36); widgets.band:SetWidth(WIDTH - 28)
    local close = CreateFrame("Button", nil, frame, "BackdropTemplate"); close:SetSize(24, 22); close:SetPoint("TOPRIGHT", -6, -6)
    Label(close, "×")
    if NS.StyleButton then NS.StyleButton(close) end
    close:SetScript("OnClick", function() Toast.Hide() end)
    widgets.close = close
    frame:Hide()
end

-- The notice's frame, built if needed (the Target button builds it early to pin both levels).
function Toast.Frame()
    if not frame then Build() end
    return frame
end

local function Slot(i)
    local button = widgets.buttons[i]
    if button then return button end
    button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetHeight(24); Label(button, "")
    if NS.StyleButton then NS.StyleButton(button) end
    widgets.buttons[i] = button
    return button
end

-- Callers may set Toast.onHide to learn when a notice that was up has gone, to show the next one.
-- The Target button is let go first: onHide may show the next notice, which then sets its own.
function Toast.Hide()
    local wasShown = frame ~= nil and frame:IsShown()
    if frame then frame:Hide(); frame:SetScript("OnUpdate", nil) end
    if NS.TargetButton then NS.TargetButton.Want(nil) end
    if wasShown and Toast.onHide then Toast.onHide() end
end

function Toast.IsShown() return frame ~= nil and frame:IsShown() end

-- Cuts text until the font string is no taller than the budget.
local function Fit(fs, text, budget)
    fs:SetText(text)
    if fs:GetStringHeight() <= budget then return end
    local keep = #text
    while keep > 0 and fs:GetStringHeight() > budget do
        keep = math.floor(keep * 0.85)
        fs:SetText(text:sub(1, keep) .. "...")
    end
end

-- opts: title, body, note, buttons {{text, onClick}}, target {id, name}. Returns true when the notice is up.
function Toast.Show(opts)
    if not frame then Build() end
    for _, button in pairs(widgets.buttons) do button:Hide() end
    local TB = NS.TargetButton
    local target = TB and TB.Offered(opts.target) and opts.target or nil
    widgets.title:SetText(Clean(opts.title))
    -- The buttons' rows first: the body is cut to fit what remains under the height cap.
    local specs, rows, x = opts.buttons or {}, 0, 14
    local placed = {}
    for i, spec in ipairs(specs) do
        local width = math.max(70, #spec.text * 7 + 20)
        if x + width > WIDTH - 14 then x, rows = 14, rows + 1 end
        placed[i] = { x = x, row = rows, width = width }; x = x + width + 6
    end
    local rowCount = #specs > 0 and rows + 1 or 0
    local top = target and BAND_BODY_TOP or BODY_TOP
    widgets.note:SetText(opts.note or "")
    local note = opts.note and math.max(14, widgets.note:GetStringHeight()) or 0
    local budget = MAX_HEIGHT - (top + 8 + note + 8 + rowCount * 28 + 10)
    widgets.body:ClearAllPoints(); widgets.body:SetPoint("TOPLEFT", 14, -top)
    Fit(widgets.body, (tostring(opts.body or ""):gsub("|", "||")), math.max(16, budget))
    local y = top + math.max(16, widgets.body:GetStringHeight()) + 8
    widgets.note:ClearAllPoints(); widgets.note:SetPoint("TOPLEFT", 14, -y)
    y = y + note + 8
    for i, spec in ipairs(specs) do
        local button, at = Slot(i), placed[i]
        button:SetScript("OnClick", function() if spec.onClick then spec.onClick() end; Toast.Hide() end)
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", at.x, -(y + at.row * 28)); button:SetWidth(at.width)
        button.label:SetText(spec.text); button:Show()
    end
    frame:SetHeight(math.min(MAX_HEIGHT, y + rowCount * 28 + 10))
    widgets.band:SetText(target and TB.Locked() and "Target button after combat" or "")
    widgets.band:SetShown(target ~= nil)
    local age = 0
    frame:SetScript("OnUpdate", function(_, delta) age = age + delta; if age >= LIFETIME then Toast.Hide() end end)
    frame:Show()
    if TB then TB.Want(target) end
    return true
end

Toast._test = { widgets = function() return widgets end, MAX_HEIGHT = MAX_HEIGHT, BAND_BODY_TOP = BAND_BODY_TOP }
