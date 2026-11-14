-- The Target button on the teacher notice (#39): checks it in game on the current build.
-- The design (issue #39, reviewed to consensus) leans on things only the client can confirm: the
-- combat latch (a secure state driver hiding the button and clearing its action), the regen re-arm,
-- the click edges, and the band lining up with the notice. Each capture reads the live button and
-- notice; the steps make the owner do the transitions.
local _, NS = ...
local Probe, FP = NS.Probe, ForeverProbe

local function Store()
    local db = NS.GetDB()
    if not db then error("PetStableProbe SavedVariables are not ready") end
    db.target = db.target or { captures = {} }
    return db.target
end

local function Plain(...)
    local copy = FP.CopyPlain(Probe.Pack(...))
    return copy
end

local function Read(frame, method, ...)
    if type(frame) ~= "table" or type(frame[method]) ~= "function" then return nil end
    return Plain(Probe:Try(method, frame[method], frame, ...))
end

local function Capture(label)
    local button, notice = rawget(_G, "PetStableTargetButton"), rawget(_G, "PetStableToast")
    local row = { label = label,
        lockdown = Plain(Probe:Try("InCombatLockdown", rawget(_G, "InCombatLockdown"))),
        keyDown = Plain(Probe:Try("GetCVar", rawget(_G, "GetCVar"), "ActionButtonUseKeyDown")),
        target = Plain(Probe:Try("UnitName", rawget(_G, "UnitName"), "target")),
        targetDead = Plain(Probe:Try("UnitIsDead", rawget(_G, "UnitIsDead"), "target")),
        buttonExists = button ~= nil, noticeExists = notice ~= nil }
    if button then
        row.shown = Read(button, "IsShown")
        row.type = Read(button, "GetAttribute", "type")
        row.macrotext = Read(button, "GetAttribute", "macrotext")
        row.latchState = Read(button, "GetAttribute", "state-petstablecombat")
        row.protected = Read(button, "IsProtected")
        row.rect = { left = Read(button, "GetLeft"), top = Read(button, "GetTop"), width = Read(button, "GetWidth"), height = Read(button, "GetHeight") }
        row.buttonText = button.label and Read(button.label, "GetText")
    end
    if notice then
        row.noticeShown = Read(notice, "IsShown")
        row.noticeProtected = Read(notice, "IsProtected")
        row.noticeRect = { left = Read(notice, "GetLeft"), top = Read(notice, "GetTop"), height = Read(notice, "GetHeight") }
    end
    local store = Store()
    store.captures[#store.captures + 1] = row
    if #store.captures > 40 then table.remove(store.captures, 1) end
    local function V(entry) return Probe.Show(type(entry) == "table" and entry[2]) end
    Probe:Say(string.format("target %s: shown %s, type %s, latch %s, lockdown %s, target %s", label,
        V(row.shown), V(row.type), V(row.latchState), V(row.lockdown), V(row.target)))
    return #store.captures
end

-- Combat end, measured passively (#39): run #320 found a button armed at PLAYER_REGEN_ENABLED latched
-- off at once. Each combat end records the lockdown, what the latch's [combat] condition reads, the
-- player's and pet's combat flags and the button, at the event and shortly after.
local function RegenSample(when)
    local ok, store = pcall(Store)
    if not ok then return end
    local button = rawget(_G, "PetStableTargetButton")
    store.regen = store.regen or {}
    store.regen[#store.regen + 1] = { when = when, time = Plain(Probe:Try("GetTime", rawget(_G, "GetTime"))),
        lockdown = Plain(Probe:Try("InCombatLockdown", rawget(_G, "InCombatLockdown"))),
        condition = Plain(Probe:Try("SecureCmdOptionParse", rawget(_G, "SecureCmdOptionParse"), "[combat] 1; 0")),
        player = Plain(Probe:Try("UnitAffectingCombat", rawget(_G, "UnitAffectingCombat"), "player")),
        pet = Plain(Probe:Try("UnitAffectingCombat", rawget(_G, "UnitAffectingCombat"), "pet")),
        shown = button and Read(button, "IsShown"), type = button and Read(button, "GetAttribute", "type"),
        latch = button and Read(button, "GetAttribute", "state-petstablecombat") }
    if #store.regen > 80 then table.remove(store.regen, 1) end
end
local regen = CreateFrame("Frame")
regen:RegisterEvent("PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
    RegenSample("event")
    local timer = rawget(_G, "C_Timer")
    if type(timer) == "table" and type(timer.After) == "function" then
        for _, delay in ipairs({ 0, 0.1, 0.3, 1 }) do timer.After(delay, function() RegenSample("+" .. delay) end) end
    end
end)

Probe:Command("target", function(args) return Capture(args ~= "" and args:sub(1, 40) or "target") end,
    "Record the Target button and the teacher notice as they are now")

local function Step(label) return function() return Capture(label) end end

-- Brings the notice back on demand: /petstable teachers check looks at the current target past the
-- per-beast cooldown and the snoozes, so a step never waits fifteen minutes. The notice still closes
-- itself after 45 seconds, so each step that needs it starts with this.
local function Show(label)
    return function()
        local slash = rawget(_G, "SlashCmdList")
        local handler = type(slash) == "table" and slash.PETSTABLE
        if type(handler) ~= "function" then error("PetStable is not loaded") end
        handler("teachers check")
        return Capture(label)
    end
end

local SHOW = "Target a Deepmoss Creeper (or any beast the alert names) and press Show notice. "
    .. "The notice closes itself after 45 seconds: if it goes before you finish a step, press Back and show it again. "

Probe:Steps("target", {
    rev = 4, title = "Target button on the teacher notice (#39)",
    { text = "Turn the teacher alert on (/petstable teachers on) and summon your pet. Stay out of combat. " .. SHOW
        .. "If no notice comes, chat says why.", button = "Show notice", run = Show("armed"), screenshot = "armed" },
    { text = "Does the Target button sit in the band under the notice's title, clear of the close button and the notice's other buttons?", ask = true },
    { text = "Clear your target (Escape), then click the Target button. Is the beast your target again?", ask = true },
    { text = "Record after the click.", button = "Record", run = Step("clicked") },
    { text = "Close the notice with its close button. The Target button should go with it. Record.", button = "Record", run = Step("closed"), screenshot = "closed" },
    { text = "Out of combat: " .. SHOW, button = "Show notice", run = Show("before-combat") },
    { text = "Now start a fight with the notice still up (send your pet or attack). Record while in combat: the button should be gone (the latch).",
      button = "Record", run = Step("combat-latched"), screenshot = "combat" },
    { text = "Did the Target button disappear as combat started?", ask = true },
    { text = "End the fight with the notice still up. Record after combat: the button should be back. (If the notice closed by itself first, say so in Notes.)",
      button = "Record", run = Step("regen-rearmed"), screenshot = "regen" },
    { text = "Out of combat: " .. SHOW, button = "Show notice", run = Show("before-close-in-combat") },
    { text = "Start a fight. During the fight, close the notice with its close button. Did it close?", ask = true },
    { text = "End the fight. Record after combat: no notice and no button should come back.",
      button = "Record", run = Step("closed-in-combat") },
    { text = "Start a fight. While in combat, target a beast the alert names and press Show notice. The notice should show with the band saying \"Target button after combat\" and no button.",
      button = "Show notice", run = Show("shown-in-combat"), screenshot = "shown-in-combat" },
    { text = "Did the band say \"Target button after combat\", with no button?", ask = true },
    { text = "End the fight with that notice still up. Within a second of combat ending the button should appear over the band. Record.",
      button = "Record", run = Step("armed-after-combat"), screenshot = "armed-after-combat" },
    { text = "Did the button appear when the fight ended?", ask = true },
    { text = "If you can: show the notice, then let that beast die or wander off (or several of the same name stand nearby), clear your target and click the button. Say in Notes what got targeted.", ask = true },
    { text = "Show the notice (/petstable teachers check with a beast targeted). Press and hold the Target button, start a fight while holding (a pet attack works), then let go. Did anything get targeted, and did any error show? Notes.", ask = true },
    { text = "Show the notice, then click its button at the very moment combat starts (the latch window). Was the beast targeted? Notes.", ask = true },
    { text = "Optional: with two different beasts the alert names in view (not two of the same kind), close the first notice when the second one is waiting. Record: the button should say the second beast's name.",
      button = "Record", run = Step("queued-next") },
    { text = "Type /console ActionButtonUseKeyDown 0 now, before the next step." },
    { text = SHOW, button = "Show notice", run = Show("keyup-shown") },
    { text = "Clear your target and click the Target button. Record (it notes the setting).", button = "Record", run = Step("keyup-clicked") },
    { text = "Did it target the beast? Then set the setting back with /console ActionButtonUseKeyDown 1.", ask = true },
    { text = "Press Finish, then type /reload to save the results." },
})

NS._test.Target = { Capture = Capture, Show = Show, RegenSample = RegenSample }
