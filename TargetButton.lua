local _, NS = ...
local TB = {}
NS.TargetButton = TB

-- One secure Target button for a notice (#39). The design was reviewed with Codex to consensus; it is
-- on issue #39:
-- * The button is parented and anchored to UIParent only. The notice (Toast.lua) is never its parent
--   or anchor, so the notice stays unprotected and can show, change and hide in combat.
-- * It sits in a fixed band under the notice's title. The notice's top and width never move, and the
--   notice is no longer clamped to the screen, so the band and the button always line up.
-- * Insecure code changes it only out of combat (Reconcile). Desired state is the notice that is up
--   now; at combat end it is applied again unconditionally.
-- * A one-way combat latch: a secure state driver clears its action and hides it when combat starts
--   (on the secure manager's next update), and does nothing when combat ends. Only Reconcile, out of
--   combat, shows it again, so a button for a notice that is gone never comes back by itself.
-- * The macro is Stakeout's, measured on Forever: /cleartarget, /targetexact <name>, /cleartarget [dead].
--   The player clicks; nothing targets automatically.

local Call = NS.Call
local NAME_MAX = 100
-- The notice is TOP-anchored at UIParent TOP (0, -150) and 400 wide. The band is the notice's
-- x 14..386, y 30..56, so the button's TOPLEFT is UIParent TOP (-186, -180), 372 x 26.
TB.NOTICE_TOP, TB.NOTICE_WIDTH = -150, 400
TB.BAND = { x = -186, y = -180, width = 372, height = 26, top = 30, bottom = 56 }
TB.LEVEL = 30 -- above the notice, which pins its own level at 20
TB.STATE = "petstablecombat"
TB.LATCH = [[
if newstate == 1 then
    self:SetAttribute("type", nil)
    self:Hide()
end
]]

local button, desired, pendingBuild

local function Locked()
    local fn = rawget(_G, "InCombatLockdown")
    return type(fn) == "function" and fn() and true or false
end
TB.Locked = Locked

-- Without the secure state driver there is no latch, so no button at all.
function TB.Available()
    return type(rawget(_G, "RegisterStateDriver")) == "function" and type(rawget(_G, "UnregisterStateDriver")) == "function"
end

-- A name that can go into a /targetexact line as it is (Stakeout's MacroSafeName): a plain string, not
-- secret, not empty, at most 100 bytes, no control character. Nothing is cleaned into another name.
function TB.SafeName(name)
    local secret = rawget(_G, "issecretvalue")
    if secret and secret(name) then return false end
    return type(name) == "string" and name ~= "" and #name <= NAME_MAX and not name:find("%c") and true or false
end

function TB.Macro(name) return "/cleartarget\n/targetexact " .. name .. "\n/cleartarget [dead]" end

local function IsHunter()
    local _, class = Call(rawget(_G, "UnitClass"), "player")
    return class == "HUNTER"
end

-- Builds the button once, out of combat. Returns whether it exists.
function TB.Build()
    if button then return true end
    if Locked() then pendingBuild = true; return false end
    pendingBuild = false
    -- The notice is built at the same time, so both levels are pinned now.
    if NS.Toast and NS.Toast.Frame then NS.Toast.Frame() end
    button = CreateFrame("Button", "PetStableTargetButton", UIParent,
        "SecureActionButtonTemplate,SecureHandlerStateTemplate,BackdropTemplate")
    button:SetSize(TB.BAND.width, TB.BAND.height)
    button:SetPoint("TOPLEFT", UIParent, "TOP", TB.BAND.x, TB.BAND.y)
    button:SetFrameStrata("DIALOG"); button:SetFrameLevel(TB.LEVEL)
    -- Both edges: the client acts on the one ActionButtonUseKeyDown names. Never "typerelease".
    button:RegisterForClicks("AnyUp", "AnyDown")
    -- The template's secure OnClick is kept: no script is set on this button.
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    button:SetBackdropColor(0.09, 0.16, 0.11, 0.97); button:SetBackdropBorderColor(0.55, 0.78, 0.5, 1)
    local glow = button:CreateTexture(nil, "HIGHLIGHT"); glow:SetAllPoints(button); glow:SetColorTexture(1, 1, 1, 0.08)
    button.label = button:CreateFontString(nil, "OVERLAY")
    button.label:SetFont("Fonts\\FRIZQT__.TTF", 13, ""); button.label:SetTextColor(0.92, 0.97, 0.9, 1)
    button.label:SetPoint("CENTER")
    button:SetAttribute("_onstate-" .. TB.STATE, TB.LATCH) -- installed before any driver is registered
    button:Hide()
    TB.button = button
    return true
end

local function Disarm()
    if not button then return end
    if TB.Available() then UnregisterStateDriver(button, TB.STATE) end
    button:SetAttribute("type", nil); button:SetAttribute("macrotext", nil)
    button:Hide()
end

local function Arm(spec)
    button:SetAttribute("type", "macro"); button:SetAttribute("macrotext", TB.Macro(spec.name))
    button.label:SetText("Target " .. spec.name:gsub("|", "||"))
    button:Show()
    -- Re-registering evaluates at once: out of combat that is 0, so an old 1 never lingers.
    UnregisterStateDriver(button, TB.STATE)
    RegisterStateDriver(button, TB.STATE, "[combat] 1; 0")
end

-- Applies the desired state when insecure code may: out of combat, unconditionally (the latch may have
-- cleared the button without us knowing). Returns whether it applied.
function TB.Reconcile()
    if Locked() then return false end
    if not TB.Build() then return false end
    if desired and TB.SafeName(desired.name) and TB.Available() then Arm(desired) else Disarm() end
    return true
end

-- What the notice that is up now wants: { id, name }, or nil for no button.
function TB.Want(spec)
    desired = type(spec) == "table" and TB.SafeName(spec.name) and { id = spec.id, name = spec.name } or nil
    TB.Reconcile()
end

function TB.Desired() return desired end
-- True when a notice may offer the button: a safe name and the secure driver present.
function TB.Offered(spec) return type(spec) == "table" and TB.SafeName(spec.name) and TB.Available() end

local watcher = CreateFrame("Frame")
TB.watcher = watcher
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not IsHunter() then return end -- other classes build nothing
        pcall(self.RegisterEvent, self, "PLAYER_REGEN_ENABLED")
        TB.Build()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingBuild then TB.Build() end
        TB.Reconcile()
    end
end)
