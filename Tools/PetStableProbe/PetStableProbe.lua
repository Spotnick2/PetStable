local ADDON, NS = ...
local Probe = ForeverProbe:Module("PetStableProbe", { api = 1, cmd = "ps" })
local MAX_LOG = 3000
local db

local function State()
    Probe:Call("GetBuildInfo", rawget(_G, "GetBuildInfo"))
    Probe:Call("GetLocale", rawget(_G, "GetLocale"))
    Probe:Say("project " .. Probe.Show(rawget(_G, "WOW_PROJECT_ID")))
    Probe:Say("module loads " .. Probe.Show(db and db.loads))
    return db and db.loads
end

Probe:Command("state", State, "Record client context and module load count")
Probe:Command("clear", function()
    Probe:ClearLog()
    Probe:Say("log cleared")
end, "Clear this module's log in place")

Probe:Steps("check", {
    rev = 1,
    title = "PetStableProbe smoke check",
    { text = "Record the client context.", button = "Record state", run = State },
    { text = "With /fp mirror off, did the state command stay out of chat?", ask = true },
    { text = "Reload to check that this procedure resumes.", reload = true },
    { text = "Record state after reload. The module load count should have increased.",
      button = "Record state", run = State },
    { text = "Did the procedure resume after reload and the load count increase?", ask = true },
    { text = "Exit the game fully, then relaunch to test saved results surviving a new process.", reload = "exit" },
    { text = "Record state after relaunch.", button = "Record state", run = State },
    { text = "Did the procedure resume with its earlier results and an increased load count?", ask = true },
    { text = "Finish, then type /reload to flush the completed results to disk." },
})

local boot = CreateFrame("Frame")
Probe:RegisterEvents(boot, { "ADDON_LOADED" })
boot:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    Probe:Ready()
    local saved = rawget(_G, "PetStableProbeDB")
    if type(saved) ~= "table" then saved = {}; PetStableProbeDB = saved end
    db = saved
    if type(db.log) ~= "table" then db.log = {} end
    db.loads = (type(db.loads) == "number" and db.loads or 0) + 1
    Probe:UseLog(db.log, MAX_LOG)
    Probe:Say("loaded; /fp ps state or /fp steps ps check")
    boot:UnregisterEvent("ADDON_LOADED")
end)

NS.Probe = Probe
NS.GetDB = function() return db end
NS._test = { Probe = Probe }
