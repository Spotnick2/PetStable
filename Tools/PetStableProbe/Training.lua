-- Read-only experiments. Spell presence, pet knowledge, and hunter training
-- knowledge are separate observations until the live comparisons establish them.
local _, NS = ...
local Probe, FP = NS.Probe, ForeverProbe
local MAX_CAPTURES, MAX_EVENTS, MAX_ROWS = 24, 200, 200

local function Resolve(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = rawget(value, part)
    end
    return value
end

local function Store()
    local db = NS.GetDB()
    if not db then error("PetStableProbe SavedVariables are not ready") end
    if type(db.training) ~= "table" then db.training = {} end
    local t = db.training
    t.captures, t.events, t.tracked = t.captures or {}, t.events or {}, t.tracked or {}
    return t
end

local function Append(list, value, limit)
    list[#list + 1] = value
    while #list > limit do table.remove(list, 1) end
end

local function ID(value)
    return not FP.IsSecret(value) and type(value) == "number" and value > 0
        and value < math.huge and value == math.floor(value)
end

-- Save complete plain tuples with arity and explicit unavailable/error states.
-- The host guards secrets, deep copies tables, and preserves nil positions.
local function Query(capture, path, ...)
    local row = { api = path, args = Probe.Pack(...) }
    local fn = Resolve(path)
    if type(fn) ~= "function" then
        row.status = "missing"
    else
        local result = Probe.Pack(Probe:Try(path, fn, ...))
        if not result[1] then
            row.status = "error"
        else
            local tuple = { n = result.n - 1 }
            for i = 2, result.n do tuple[i - 1] = result[i] end
            local copy, why = FP.CopyPlain(tuple)
            if why then
                row.status, row.reason = "unreadable", why
            else
                row.status, row.values = "ok", copy
            end
        end
    end
    capture.queries[#capture.queries + 1] = row
    Probe:Say(path .. " " .. row.status .. " " .. Probe.Describe(row.values, 2))
    return row.values
end

local function Count(tuple, capture, label)
    local n = tuple and tuple[1]
    if type(n) ~= "number" or n < 0 or n ~= math.floor(n) or n == math.huge then
        Probe:Say(label .. " count unavailable; enumeration unknown")
        return nil
    end
    if n > MAX_ROWS then
        capture.truncated = true
        Probe:Say(label .. " truncated to " .. MAX_ROWS .. " of " .. n)
    end
    return math.min(n, MAX_ROWS)
end

local eventNames = { "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE", "UNIT_PET_TRAINING_POINTS",
    "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED" }
local events = CreateFrame("Frame")
local watching = false
local function Watch(on)
    if on == watching then return end
    watching = on
    if on then
        Probe:RegisterEvents(events, eventNames)
    else
        for _, event in ipairs(eventNames) do events:UnregisterEvent(event) end
    end
    Probe:Say("training event watch " .. (on and "on" or "off"))
end
events:SetScript("OnEvent", function(_, event, ...)
    local t = Store()
    -- Only unit tokens and numeric learning-event arguments; no chat payloads.
    local args, why = FP.CopyPlain(Probe.Pack(...))
    Append(t.events, { event = event, run = FP.run, at = FP.Stamp(),
        args = args, unreadable = why }, MAX_EVENTS)
    Probe:Say("training event " .. event .. " " .. Probe.Describe(args, 1))
end)

local function Knowledge(c, spellID, banks)
    c.spellIDs[spellID] = true
    Query(c, "C_Spell.GetSpellInfo", spellID)
    Query(c, "C_Spell.GetSpellSubtext", spellID) -- raw localized text; never parse 'Rank'.
    Query(c, "C_SpellBook.FindBaseSpellByID", spellID)
    Query(c, "C_SpellBook.FindSpellOverrideByID", spellID)
    for _, name in ipairs({ "Player", "Pet" }) do
        local bank = Resolve("Enum.SpellBookSpellBank." .. name)
        if not FP.IsSecret(bank) and type(bank) == "number" then
            banks[name] = bank
            Query(c, "C_SpellBook.IsSpellKnown", spellID, bank)
            Query(c, "C_SpellBook.IsSpellInSpellBook", spellID, bank, false)
        end
    end
    Query(c, "IsSpellKnown", spellID, false)
    Query(c, "IsSpellKnown", spellID, true)
end

local capabilityNames = {
    "C_SpellBook.HasPetSpells", "C_SpellBook.GetSpellBookItemInfo",
    "C_SpellBook.GetSpellBookItemName", "C_SpellBook.IsSpellKnown",
    "C_SpellBook.IsSpellInSpellBook", "C_PetInfo.GetPetTrainingPoints",
    "C_Trainer.GetTrainerType", "GetNumTrainerServices", "GetTrainerServiceInfo",
    "GetTrainerServiceItemLink", "GetNumCrafts", "GetCraftInfo", "GetCraftTrainingPoints",
}

local function Capture(label)
    local t = Store()
    Watch(true)
    t.serial = (t.serial or 0) + 1
    local c = { id = t.serial, label = label, run = FP.run, at = FP.Stamp(),
        queries = {}, petSpellIDs = {}, spellIDs = {}, banks = {}, capabilities = {},
        hunterTrainingKnowledge = "unknown; raw knowledge checks require live validation" }
    Probe:Say("CAPTURE " .. c.id .. " " .. label)
    for _, name in ipairs(capabilityNames) do c.capabilities[name] = type(Resolve(name)) == "function" end
    local frame = rawget(_G, "ClassTrainerFrame")
    if frame then
        local ok, shown = Probe:Try("ClassTrainerFrame:IsShown", frame.IsShown, frame)
        if ok and not FP.IsSecret(shown) and type(shown) == "boolean" then c.trainerWindowShown = shown end
    end
    c.build = Query(c, "GetBuildInfo")
    c.locale = Query(c, "GetLocale")
    c.class = Query(c, "UnitClass", "player")
    c.petExists = Query(c, "UnitExists", "pet")
    Query(c, "UnitGUID", "pet")
    Query(c, "UnitLevel", "player")
    Query(c, "UnitLevel", "pet")
    Query(c, "UnitCreatureFamily", "pet")
    Query(c, "C_PetInfo.GetPetTrainingPoints")
    Query(c, "C_PetInfo.GetPetLoyalty")
    local petBank = Resolve("Enum.SpellBookSpellBank.Pet")
    if FP.IsSecret(petBank) or type(petBank) ~= "number" then
        Probe:Say("Pet spell bank enum unavailable; no guessed numeric bank")
    else
        c.banks.Pet = petBank
        local n = Count(Query(c, "C_SpellBook.HasPetSpells"), c, "pet spells")
        if n then
            c.petEnumeration = "ok"
            for index = 1, n do
                local info = Query(c, "C_SpellBook.GetSpellBookItemInfo", index, petBank)
                Query(c, "C_SpellBook.GetSpellBookItemName", index, petBank)
                local kind = Query(c, "C_SpellBook.GetSpellBookItemType", index, petBank)
                local spellID = info and type(info[1]) == "table" and info[1].spellID
                if not ID(spellID) then spellID = kind and kind[3] end
                if ID(spellID) then
                    c.petSpellIDs[spellID] = true
                else
                    c.petEnumeration = "partial"
                end
            end
        end
    end
    c.petEnumeration = c.petEnumeration or "unknown"
    Query(c, "C_Trainer.GetTrainerType")
    for _, filter in ipairs({ "available", "unavailable", "used" }) do
        Query(c, "GetTrainerServiceTypeFilter", filter)
    end
    local services = Count(Query(c, "GetNumTrainerServices"), c, "trainer services")
    if services then
        for index = 1, services do
            Query(c, "GetTrainerServiceInfo", index)
            local link = Query(c, "GetTrainerServiceItemLink", index)
            Query(c, "GetTrainerServiceCost", index)
            Query(c, "GetTrainerServiceLevelReq", index)
            Query(c, "GetTrainerServiceSkillReq", index)
            Query(c, "GetTrainerServiceDescription", index)
            local requirements = Count(Query(c, "GetTrainerServiceNumAbilityReq", index), c, "ability requirements")
            if requirements then
                for r = 1, requirements do Query(c, "GetTrainerServiceAbilityReq", index, r) end
            end
            local spellID = link and type(link[1]) == "string" and tonumber(link[1]:match("|Hspell:(%d+)"))
            if ID(spellID) then c.spellIDs[spellID] = true end
        end
    end
    -- These legacy calls are absent in the 70425 dump: record rather than assume.
    local crafts = Count(Query(c, "GetNumCrafts"), c, "legacy training crafts")
    if crafts then
        for index = 1, crafts do
            Query(c, "GetCraftInfo", index)
            Query(c, "GetCraftSpellFocus", index)
            Query(c, "GetCraftTrainingPoints", index)
        end
    end
    for spellID in pairs(c.petSpellIDs) do c.spellIDs[spellID] = true end
    -- Query the same IDs after switching/dismissing and after reload, even when
    -- an ability is no longer in the current pet's spellbook or trainer list.
    for spellID in pairs(t.tracked) do if ID(spellID) then c.spellIDs[spellID] = true end end
    local ids = {}
    for spellID in pairs(c.spellIDs) do ids[#ids + 1] = spellID end
    table.sort(ids)
    for _, spellID in ipairs(ids) do
        Knowledge(c, spellID, c.banks)
        t.tracked[spellID] = true
    end
    Append(t.captures, c, MAX_CAPTURES)
    Probe:Say("Saved capture " .. c.id .. "; hunter training knowledge remains unknown until compared")
    return c.id, label, c.petEnumeration
end

Probe:Command("capture", function(args)
    Capture(args ~= "" and args:sub(1, 60) or "manual")
end, "Save pet spells, training UI, and raw knowledge checks; starts event watch")
Probe:Command("track", function(args)
    local spellID = tonumber(args)
    if not ID(spellID) then Probe:Say("Usage: /fp ps track <positive spell ID>"); return end
    Store().tracked[spellID] = true
    Probe:Say("Tracking spell " .. spellID .. " across captures and reloads; capture again to query it")
end, "Include a specific spell ID in subsequent knowledge captures")
Probe:Command("watch", function(args)
    if args ~= "on" and args ~= "off" then Probe:Say("Usage: /fp ps watch on|off"); return end
    Watch(args == "on")
end, "Watch relevant pet, learning, and trainer events for this session")
Probe:Command("compare", function()
    local list = Store().captures
    if #list < 2 then Probe:Say("Need two captures to compare"); return end
    local before, after = list[#list - 1], list[#list]
    Probe:Say("COMPARE " .. before.id .. " " .. before.label .. " -> " .. after.id .. " " .. after.label)
    local old = {}
    for _, row in ipairs(before.queries) do
        old[row.api .. Probe.Describe(row.args, 1)] = row
    end
    for _, row in ipairs(after.queries) do
        if row.api == "C_SpellBook.IsSpellKnown" or row.api == "C_SpellBook.IsSpellInSpellBook"
            or row.api == "IsSpellKnown" or row.api == "C_PetInfo.GetPetTrainingPoints" then
            local previous = old[row.api .. Probe.Describe(row.args, 1)]
            if previous and (previous.status ~= row.status
                or Probe.Describe(previous.values, 2) ~= Probe.Describe(row.values, 2)) then
                Probe:Say("query changed " .. row.api .. " " .. Probe.Describe(row.args, 1)
                    .. " " .. previous.status .. " " .. Probe.Describe(previous.values, 2)
                    .. " -> " .. row.status .. " " .. Probe.Describe(row.values, 2))
            end
        end
    end
    if before.petEnumeration ~= "ok" or after.petEnumeration ~= "ok" or before.truncated or after.truncated then
        Probe:Say("Pet spell comparison unknown: missing, partial, or truncated enumeration")
        return
    end
    for id in pairs(after.petSpellIDs) do if not before.petSpellIDs[id] then Probe:Say("pet spell ID added " .. id) end end
    for id in pairs(before.petSpellIDs) do if not after.petSpellIDs[id] then Probe:Say("pet spell ID removed " .. id) end end
    Probe:Say("Raw query tuples and knowledge checks are saved in both captures; no rank progression inferred")
end, "Compare the last two pet spell ID sets; retain raw tuples for analysis")

local function RunCapture(label) return function() return Capture(label) end end
local function Procedure(name, title, setup, action, confirmation)
    Probe:Steps(name, {
        rev = 2, title = title,
        { text = setup .. " Use the Note box for pet family, ability/rank, and visible training filters. If unavailable, Skip and note why." },
        { text = "Capture before the change.", button = "Capture before", run = RunCapture(name .. "-before") },
        { text = action .. " Use the Note box to name the ability/rank and what you actually did; then press Next. Skip if unavailable." },
        { text = "Capture after the change, keeping the same training UI open if possible.", button = "Capture after", run = RunCapture(name .. "-after") },
        { text = confirmation or "Did the intended change happen? Answer No if you skipped it; record what the game showed in Notes.", ask = true },
        { text = "Reload to save the before/after evidence.", reload = true },
        { text = "Reopen the same training UI with the same filters, if it was open. Then press Next." },
        { text = "Capture again after reload.", button = "Capture saved state", run = RunCapture(name .. "-reload") },
        { text = "Click Finish measurements below to complete this procedure. Afterwards type /reload to save the results.",
          button = "Finish measurements", run = function() Watch(false); return "saved captures ready; reload to flush" end },
    })
end
Procedure("switch", "Pet abilities across a pet switch",
    "On a hunter, summon pet A and open its spellbook. Have a different existing pet B available.",
    "Manually switch to pet B. Do not abandon either pet.")
Procedure("learn", "Acquire a hunter training rank",
    "On a hunter, prepare a pet with an ability rank you have not learned. Record its spell ID with /fp ps track if known; open the training UI if available.",
    "Use normal gameplay until the game reports learning that rank. Do not abandon a pet for this experiment.")
Procedure("teach", "Teach an existing rank to a pet",
    "On a hunter, open the pet training UI with a pet eligible for a rank the hunter already knows.",
    "Manually teach one rank through the game's UI. The probe will not cast or purchase anything.")
Procedure("trainer", "Inspect trainer acquisition and UI data",
    "On a hunter, stand at an appropriate trainer with a pet summoned, with the trainer window closed.",
    "Open the trainer window manually. Note its type and filters. Optionally learn one desired ability through the game UI, recording that choice.",
    "Did the trainer window open and show its service list? Opening it is the change being tested; you do not need to buy or learn anything.")

NS._test.Training = { Capture = Capture, Watch = Watch }
