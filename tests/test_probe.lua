-- Use the sibling host's single stub environment and actual TOC load order.
local root = (os.getenv("FOREVERPROBE") or "../ForeverProbe"):gsub("\\", "/"):gsub("/$", "")
local toc = io.open(root .. "/ForeverProbe.toc", "rb")
if not toc then
    if os.getenv("FOREVERPROBE_OPTIONAL") == "1" then
        io.write("SKIPPED: ForeverProbe missing; probe integration tests run locally\n")
        os.exit(0)
    end
    error("ForeverProbe missing at " .. root .. "; set FOREVERPROBE or restore the sibling checkout")
end
local files = {}
for line in toc:lines() do
    line = line:gsub("\r", "")
    if line:match("%.lua$") and not line:match("^#") then files[#files + 1] = line end
end
toc:close()
dofile(root .. "/tests/wow_stubs.lua")
for _, file in ipairs(files) do assert(loadfile(root .. "/" .. file))("ForeverProbe", {}) end
WoW.fire("ADDON_LOADED", "ForeverProbe")
local ns = {}
assert(loadfile("Tools/PetStableProbe/PetStableProbe.lua"))("PetStableProbe", ns)
assert(loadfile("Tools/PetStableProbe/Training.lua"))("PetStableProbe", ns)
assert(loadfile("Tools/PetStableProbe/Models.lua"))("PetStableProbe", ns)
assert(loadfile("Tools/PetStableProbe/Discovery.lua"))("PetStableProbe", ns)
assert(loadfile("Tools/PetStableProbe/Binding.lua"))("PetStableProbe", ns)
assert(rawget(_G, "PetStableProbeDB") == nil, "must not initialize saved data at file scope")
local log = { "previous session" }
PetStableProbeDB = { log = log, loads = 7 }
WoW.fire("ADDON_LOADED", "OtherAddon")
assert(PetStableProbeDB.loads == 7, "unrelated event must not initialize the module")
WoW.fire("ADDON_LOADED", "PetStableProbe")
assert(PetStableProbeDB.loads == 8 and PetStableProbeDB.log == log)
assert(log[1] == "previous session", "previous log must survive loading")
WoW.fire("ADDON_LOADED", "PetStableProbe")
assert(PetStableProbeDB.loads == 8, "initialization must only run once")
WoW.fire("PLAYER_LOGIN")
SlashCmdList.FOREVERPROBE("ps state")
assert(table.concat(log, "\n"):find("70374", 1, true), "state must record build")
assert(#WoW.chat == 0, "normal diagnostics must not go to chat")
SlashCmdList.FOREVERPROBE("ps clear")
assert(PetStableProbeDB.log == log and #log == 1, "clear must preserve log identity")
ns._test.Probe:Say("after clear")
assert(log[2]:find("after clear", 1, true))
assert(ForeverProbe.lines[#ForeverProbe.lines].text == log[2], "console and saved log must both receive new lines")
local original = GetBuildInfo
GetBuildInfo = nil
SlashCmdList.FOREVERPROBE("ps state")
assert(table.concat(log, "\n"):find("ABSENT", 1, true), "missing API must be reported")
GetBuildInfo = original
SlashCmdList.FOREVERPROBE("steps ps check")
assert(ForeverProbeDB.steps.active == "PetStableProbe/check")
ForeverProbe.Steps.Click("primary")
local record = ForeverProbeDB.steps.records["PetStableProbe/check"]
assert(record.results[1].status == "done", "guided state measurement must record its result")
assert(#WoW.chat == 0 and #WoW.errors == 0, "guided checks must be quiet and error-free")
dofile("tests/training_cases.lua")(ns)
dofile("tests/model_cases.lua")(ns)
dofile("tests/discovery_cases.lua")(ns)
dofile("tests/binding_cases.lua")(ns)
io.write("PASS: probe lifecycle, dispatch, log identity, missing API, and guided procedure\n")
