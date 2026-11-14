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
        row.label = button.label and Read(button.label, "GetText")
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

Probe:Command("target", function(args) return Capture(args ~= "" and args:sub(1, 40) or "target") end,
    "Record the Target button and the teacher notice as they are now")

local function Step(label) return function() return Capture(label) end end

Probe:Steps("target", {
    rev = 1, title = "Target button on the teacher notice (#39)",
    { text = "Turn the teacher alert on (/petstable teachers on), summon your pet, and find a beast the alert names (a listed teacher of your pet's next rank). Stay out of combat. When the notice is up with its Target button, record.",
      button = "Record", run = Step("armed"), screenshot = "armed" },
    { text = "Does the Target button sit in the band under the notice's title, clear of the close button and the notice's other buttons?", ask = true },
    { text = "Click the Target button. Is the beast now your target?", ask = true },
    { text = "Record after the click.", button = "Record", run = Step("clicked") },
    { text = "Close the notice with its close button. The Target button should go. Record.", button = "Record", run = Step("closed"), screenshot = "closed" },
    { text = "Bring the notice up again, out of combat. Then start a fight (attack anything) with the notice still up. Record while in combat: the button should be gone (the latch).",
      button = "Record", run = Step("combat-latched"), screenshot = "combat" },
    { text = "Still in combat, did the Target button disappear as combat started?", ask = true },
    { text = "End the fight with the notice still up. Record after combat: the button should be back.", button = "Record", run = Step("regen-rearmed"), screenshot = "regen" },
    { text = "Bring a notice up, start a fight, close the notice during the fight, then end the fight. Record after combat: no button should come back.",
      button = "Record", run = Step("closed-in-combat") },
    { text = "Start a fight first, then let a teacher come into view so the notice shows during combat. Does the band say \"Target button after combat\", with no button?", ask = true, screenshot = "shown-in-combat" },
    { text = "End the fight with that notice still up. Record: the button should appear.", button = "Record", run = Step("armed-after-combat") },
    { text = "If you can: a notice for a beast that died or left, or with several beasts of the same name nearby. Click the button and say in Notes what got targeted.", ask = true },
    { text = "Press Finish, then type /reload to save the results." },
})

NS._test.Target = { Capture = Capture }
