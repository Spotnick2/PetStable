-- Every widget method PetStable calls exists on that widget type in the pinned build
-- (WowTestKit's Kit.checkMethods). The exercise reaches every window as cheaply as it can:
-- the flat window and the glass one (the real embedded LibGlass), their pages through the
-- existing case files, Settings, the teacher notice and the Target button, every slash command,
-- and a hover over everything shown. The test_*.lua files check behaviour; this one only reads
-- what was called.
dofile("tests/wow_stubs.lua")

-- A method the build lacks reads as nil, so calling it fails where it's made. The addon calls
-- some widget methods inside pcall (GuideModels, GuideUI, UI.lua's history wrapper, the event
-- registrations), which would hide that failure from the check: every error a pcall swallowed
-- during the exercise is kept, and none may be a call of a nil method.
local swallowed = {}
local countingPcall = pcall
local function note(ok, ...)
    if not ok then swallowed[#swallowed + 1] = tostring((...)) end
    return ok, ...
end
function pcall(fn, ...) return note(countingPcall(fn, ...)) end

-- A hunter with a cat out, a stabled bear, and an ability the pet knows.
SlashCmdList = {}
UnitClass = function() return "Hunter", "HUNTER" end
UnitExists = function(unit) return unit == "pet" or unit == "target" end
UnitName = function(unit) return unit == "pet" and "Whiskers" or unit == "player" and "Hunt" or "Prowler" end
UnitLevel = function() return 20 end
UnitCreatureFamily = function() return "Cat", 2 end
UnitGUID = function(unit) return unit == "pet" and "Pet-0-1-1" or "Creature-0-1-2-3-118-1" end
GetRealmName = function() return "Realm" end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 1 2026", 16001 end
function time() return 1700000000 end
Enum.SpellBookSpellBank = { Pet = 1 }
C_SpellBook = { HasPetSpells = function() return 1 end,
    GetSpellBookItemInfo = function() return { name = "Bite", subName = "Rank 1", spellID = 17255 } end }
C_StableInfo = {
    GetActivePetList = function() return { { petNumber = 1, slotID = 1, name = "Whiskers", level = 20, familyName = "Cat" } } end,
    GetStabledPetList = function() return { { petNumber = 2, slotID = 3, name = "Grumpy", level = 8, familyName = "Bear" } } end,
}
-- The Target button's secure state driver (TargetButton.lua reads these through rawget).
function SecureCmdOptionParse() return "0" end
function RegisterStateDriver() end
function UnregisterStateDriver() end
UIParent:SetSize(1920, 1080)

local function Load()
    local ns = {}
    -- Every creature listed, the window opening on the family index.
    PetStableDB = { startOnActivePet = false, filterToLevel = false }
    for line in io.lines("PetStable.toc") do
        line = line:gsub("\r", "")
        if line:match("^[%a]+%.lua$") then assert(loadfile(line))("PetStable", ns) end
    end
    WoW.fire("ADDON_LOADED", "PetStable")
    WoW.fire("PLAYER_LOGIN")
    WoW.fireAllRegistered()
    WoW.step(0.5)
    return ns
end

-- Each pcall'd event registration took: the events are on the build (an unknown one would throw
-- inside the pcall and leave the watcher deaf).
local function Registered(frame, events)
    for _, event in ipairs(events) do check(frame:IsEventRegistered(event), "registered " .. event) end
end

-- Everything shown that takes the mouse: hovered, then clicked, then left, as the player would.
-- Twice over, so what a first click opens (a family's gallery, a look's detail) is crawled too.
-- The window is opened again if a click closed it.
local function Crawl(ns)
    for _ = 1, 2 do
        local shown = {}
        for _, f in ipairs(WoW.frames) do if f:IsVisible() then shown[#shown + 1] = f end end
        for _, f in ipairs(shown) do
            if f:IsVisible() then
                local enter, click, up, wheel, leave = f:GetScript("OnEnter"), f:GetScript("OnClick"),
                    f:GetScript("OnMouseUp"), f:GetScript("OnMouseWheel"), f:GetScript("OnLeave")
                if enter then enter(f) end
                if click then click(f, "LeftButton", false) end
                if up then up(f, "LeftButton") end
                if wheel then wheel(f, -1) end
                if leave then leave(f) end
                WoW.step(0.3)
                if not ns.frame:IsShown() then ns.Toggle() end
            end
        end
    end
end

local function Exercise(ns)
    SlashCmdList.PETSTABLE("")
    for _, key in ipairs({ "guide", "upgrades", "pets" }) do
        ns.SelectPage(key)
        Crawl(ns)
    end
    ns.SelectPage("guide")
    for _, family in ipairs(ns.guide.families) do ns.guide.OpenFamily(family.key) end
    ns.guide.OpenFamily("family-cat")
    local ui = ns.guide.appearances
    ui.OpenAppearance(ui.results[1])
    Crawl(ns)
    ui.Back()
    ns.guide.OpenFamily(nil)
    Crawl(ns)
    ns.settingsButton:GetScript("OnClick")(); ns.settings.Sync()
    ns.settings.scale:SetValue(0.85)
    for _, cmd in ipairs({ "teachers", "teachers on", "teachers check", "levelfilter off", "levelfilter on",
                           "material flat", "material reflective", "material bogus", "scale 1.1", "scale x",
                           "sightings", "sightings on", "sightings off", "reset", "help" }) do
        SlashCmdList.PETSTABLE(cmd)
    end
    -- The teacher notice and its Target button.
    ns.Toast.Show({ title = "PET ABILITY NEARBY", body = "Prowler is listed as teaching Bite rank 2.",
        note = "Listed by references.", target = { id = 118, name = "Prowler" },
        buttons = { { text = "Snooze 15 min" }, { text = "Snooze while I keep this pet" }, { text = "Ignore Bite" } } })
    WoW.step(0.5)
    -- A hover over everything shown, then away.
    for _, f in ipairs(WoW.frames) do
        if f:IsVisible() then
            local enter, leave = f:GetScript("OnEnter"), f:GetScript("OnLeave")
            if enter then enter(f) end
            if leave then leave(f) end
        end
    end
    ns.Toast.Hide()
    ns.Layout()
    WoW.step(0.5)
    SlashCmdList.PETSTABLE("")
end

-- The flat window: no library.
local flat = Load()
Exercise(flat)
Registered(flat.TargetButton.watcher, { "PLAYER_REGEN_ENABLED" })
Registered(flat.TeacherAlert.watcher, { "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" })

-- The glass window: the real embedded LibGlass (r12, the .pkgmeta pin), loaded as the client does.
local embedded = os.getenv("PETSTABLE_LIBGLASS") or "Libs/LibGlass-1.0"
local f = assert(io.open(embedded .. "/LibGlass-1.0.xml", "rb"))
local xml = f:read("*a"):gsub("<!%-%-.-%-%->", ""); f:close()
for path in xml:gmatch('<Script%s+file="([^"]+)"') do
    assert(loadfile(embedded .. "/" .. path:gsub("\\", "/")))("PetStable", {})
end
local glass = Load()
Exercise(glass)
check(glass.Glass ~= nil, "the second window is glass")

local nilCalls = {}
for _, err in ipairs(swallowed) do
    if err:find("attempt to call") then nilCalls[#nilCalls + 1] = err end
end
eq(#nilCalls, 0, "no pcall swallowed a call of a missing method" .. (nilCalls[1] and (": " .. nilCalls[1]) or ""))
io.write("pcalls that failed during the exercise: " .. #swallowed .. "\n")
for _, err in ipairs(swallowed) do io.write("  " .. err .. "\n") end

local recorded = Kit.checkMethods()
io.write("recorded " .. recorded .. " Type:Method pairs\n")
check(recorded >= 200, "the exercise reached the windows (" .. recorded .. " recorded)")
WoW.finish("test_methods")
