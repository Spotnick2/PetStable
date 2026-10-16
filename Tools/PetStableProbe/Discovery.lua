-- Observations are evidence, not an automatically confirmed pet catalog.
local _, NS = ...
local Probe, FP = NS.Probe, ForeverProbe
local LIMIT = 200

local function Store()
    local db = NS.GetDB()
    if not db then error("PetStableProbe SavedVariables are not ready") end
    db.discovery = db.discovery or { captures = {}, serial = 0 }
    return db.discovery
end

local function Resolve(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = rawget(value, part)
    end
    return value
end

local function Read(c, path, fn, ...)
    local args, argsWhy = FP.CopyPlain(Probe.Pack(...))
    local row = { api = path, args = args, argsUnreadable = argsWhy }
    if type(fn) ~= "function" then row.status = "missing"
    else
        local result = Probe.Pack(Probe:Try(path, fn, ...))
        if not result[1] then row.status = "error"
        else
            local tuple = { n = result.n - 1 }
            for i = 2, result.n do tuple[i - 1] = result[i] end
            local copy, why = FP.CopyPlain(tuple)
            row.status, row.values, row.reason = why and "unreadable" or "ok", copy, why
            -- Live TooltipData contains mixin methods. Keep the raw-copy failure
            -- explicit, but salvage only selected plain fields, never methods.
            if path == "C_TooltipInfo.GetUnit" and why and not FP.IsSecret(tuple[1])
                and type(tuple[1]) == "table" then
                local lines = rawget(tuple[1], "lines")
                if not FP.IsSecret(lines) and type(lines) == "table" then
                    row.tooltipLines, row.tooltipFieldErrors = {}, {}
                    for i = 1, math.min(#lines, 100) do
                        local line = rawget(lines, i)
                        local saved = {}
                        row.tooltipLines[i] = saved
                        if not FP.IsSecret(line) and type(line) == "table" then
                            for _, key in ipairs({ "type", "leftText", "rightText", "id", "spellID" }) do
                                local value, reason = FP.CopyPlain(rawget(line, key))
                                if reason then row.tooltipFieldErrors[#row.tooltipFieldErrors + 1] = { line = i, field = key, reason = reason }
                                else saved[key] = value end
                            end
                        else row.tooltipFieldErrors[#row.tooltipFieldErrors + 1] = { line = i, reason = "unreadable line" } end
                    end
                    row.tooltipLinesTruncated = #lines > 100
                end
            end
        end
    end
    c.queries[#c.queries + 1] = row
    Probe:Say(path .. " " .. row.status .. " " .. Probe.Describe(row.values, 1))
    if row.status == "ok" then return unpack(row.values, 1, row.values.n) end
end

local function Query(c, path, ...) return Read(c, path, Resolve(path), ...) end
local function ID(v)
    return not FP.IsSecret(v) and type(v) == "number" and v > 0
        and v < math.huge and v == math.floor(v)
end

local function New(label)
    local t = Store()
    t.serial = t.serial + 1
    local c = { id = t.serial, label = label, run = FP.run, at = FP.Stamp(), queries = {},
        evidence = { clientData = "unknown", world = "unknown", tameable = "unknown",
            abilityAcquisition = "unknown" } }
    c.build = Probe.Pack(Query(c, "GetBuildInfo"))
    c.locale = Query(c, "GetLocale")
    c.project = rawget(_G, "WOW_PROJECT_ID")
    t.captures[#t.captures + 1] = c
    while #t.captures > 24 do table.remove(t.captures, 1) end
    return c
end

local function Families()
    local c = New("client family enumeration")
    local ids = Query(c, "C_CreatureInfo.GetCreatureFamilyIDs")
    if type(ids) == "table" then
        c.evidence.clientData = "family IDs returned; not a tameable creature list"
        local count = 0
        for _, id in ipairs(ids) do
            count = count + 1
            if count > LIMIT then c.truncated = true; break end
            if ID(id) then Query(c, "C_CreatureInfo.GetCreatureFamilyInfo", id) end
        end
    end
    return c
end

local function Spell(c, id)
    if not ID(id) then return end
    Query(c, "C_Spell.GetSpellInfo", id)
    Query(c, "C_Spell.GetSpellSubtext", id)
    Query(c, "C_Spell.GetSpellDescription", id)
end

local model
local function Appearance(c, unit)
    -- Clear before binding so a missing target cannot inherit an earlier skin.
    if not model then Read(c, "CreateFrame(PlayerModel)", function()
        local frame = CreateFrame("PlayerModel", nil, UIParent)
        frame:Hide()
        model = frame -- retain locally; do not serialize the widget
    end) end
    if not model then return end
    Read(c, "PlayerModel:ClearModel", model.ClearModel, model)
    Read(c, "PlayerModel:SetUnit", model.SetUnit, model, unit)
    c.displayID = Read(c, "PlayerModel:GetDisplayInfo", model.GetDisplayInfo, model)
    c.modelFileID = Read(c, "PlayerModel:GetModelFileID", model.GetModelFileID, model)
    c.appearance = "immediate unit-model query; nil/zero or asynchronous loading is inconclusive"
end

local function Capture(label)
    local c = New(label)
    local exists = Query(c, "UnitExists", "target")
    local guid = Query(c, "UnitGUID", "target")
    c.targetGUID = guid
    -- Never turn a Player/Pet/Vehicle GUID into an observed wild NPC identity.
    if exists == true and type(guid) == "string" and guid:match("^Creature%-") then
        c.evidence.world = "observed creature target; wild/tameable status unconfirmed"
        c.creatureID = Query(c, "UnitCreatureID", "target")
        Query(c, "C_CreatureInfo.GetCreatureID", guid)
        for _, api in ipairs({ "UnitName", "UnitLevel", "UnitCreatureFamily", "UnitCreatureType",
            "UnitClassification", "UnitIsDead", "UnitIsPlayer", "UnitPlayerControlled" }) do
            Query(c, api, "target")
        end
        c.creaturePosition = Probe.Pack(Query(c, "UnitPosition", "target"))
        Query(c, "C_TooltipInfo.GetUnit", "target") -- raw localized lines; no English parsing
        local cast = Probe.Pack(Query(c, "UnitCastingInfo", "target"))
        local channel = Probe.Pack(Query(c, "UnitChannelInfo", "target"))
        Spell(c, cast[9]); Spell(c, channel[8])
        for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
            for index = 1, 40 do
                local aura = Query(c, "C_UnitAuras.GetAuraDataByIndex", "target", index, filter)
                if type(aura) ~= "table" then break end
                -- Aura presence is not evidence that the creature can teach it.
                if index == 40 then c.aurasMayBeTruncated = true end
            end
        end
        Appearance(c, "target")
        if Query(c, "UnitGUID", "target") ~= guid then
            c.targetChanged = true
            c.evidence.world = "target changed during capture; identity association invalid"
            c.creatureID, c.displayID, c.modelFileID = nil, nil, nil
        end
    else c.targetStatus = "no Creature GUID target; select an NPC creature" end
    c.observerPosition = Probe.Pack(Query(c, "UnitPosition", "player"))
    c.positionMeaning = "separate raw world positions, not spawn points or normalized map coordinates"
    c.observerMapID = Query(c, "C_Map.GetBestMapForUnit", "player")
    if ID(c.observerMapID) then Query(c, "C_Map.GetMapInfo", c.observerMapID) end
    Query(c, "GetZoneText"); Query(c, "GetSubZoneText")
    Query(c, "UnitGUID", "pet")
    Query(c, "UnitCreatureFamily", "pet")
    Query(c, "C_StableInfo.GetActivePetList")
    Query(c, "C_StableInfo.GetStabledPetList")
    local count = Query(c, "C_SpellBook.HasPetSpells")
    local bank = Resolve("Enum.SpellBookSpellBank.Pet")
    if ID(count) and type(bank) == "number" and not FP.IsSecret(bank) then
        if count > LIMIT then c.truncated = true end
        for i = 1, math.min(count, LIMIT) do Query(c, "C_SpellBook.GetSpellBookItemInfo", i, bank) end
    end
    return c
end

Probe:Command("families", function() return Families().id end, "Record client family IDs and metadata")
Probe:Command("discover", function(args) return Capture(args ~= "" and args:sub(1,60) or "target observation").id end,
    "Record a creature target, tooltip, appearance, and separate observer/target positions")
Probe:Command("discoveryspell", function(args)
    local id = tonumber(args)
    if not ID(id) then Probe:Say("Usage: /fp ps discoveryspell <positive spell ID>"); return end
    local c = New("explicit client spell query")
    Spell(c, id)
    c.evidence.clientData = "query only; inspect returned spell data"
end, "Query a supplied spell ID without claiming a creature knows or teaches it")

Probe:Steps("discover", {
    rev = 1, title = "Observe a wild creature",
    { text = "Target a nearby wild beast. Prefer a Forever-specific creature if one is conveniently available; otherwise note that coverage as pending. No taming is needed. Put the creature name and any special context in Notes." },
    { text = "Record the client's family list.", button = "Capture families", run = function() return Families().id end },
    { text = "Keep the creature targeted and record its current data.", button = "Capture target", run = function() return Capture("discovery-before-lore").id end },
    { text = "If Beast Lore is available, cast it manually on the same creature and hover it to show the resulting tooltip. Otherwise note that it is unavailable. Record visible abilities or taming restrictions in Notes; do not guess." },
    { text = "Keep the same creature targeted. Capture its tooltip and unit data again.", button = "Capture tooltip", run = function() return Capture("discovery-after-lore").id end },
    { text = "Does the visible creature tooltip show ability or tameability information? Hover the creature for the screenshot; use Notes for the exact text. No or Not sure is a useful result.", ask = true, screenshot = true },
    { text = "Click Finish measurements, then /reload to save the results.", button = "Finish measurements", run = function() return "discovery recorded; reload to save" end },
})

Probe:Steps("tame", {
    rev = 1, title = "Optional tame before/after evidence",
    { text = "Only run this when you already intend to tame a beast and have room for it. Keep existing pets safely stabled; do not abandon a pet for this test. Target the intended wild beast. If no suitable tame is available, stop here and leave this experiment pending." },
    { text = "Capture the intended wild target before taming.", button = "Capture before", run = function()
        local c = Capture("tame-before")
        Store().tameBefore = { id = c.id, run = c.run, guid = c.targetGUID, creatureID = c.creatureID }
        return c.id
    end },
    { text = "Manually attempt your planned tame. Note whether it succeeded, failed, or was skipped, and any game error. The probe will not cast anything." },
    { text = "Capture the resulting pet/stable/spellbook state, even if the tame failed.", button = "Capture after", run = function()
        local c = Capture("tame-after")
        c.before = FP.CopyPlain(Store().tameBefore)
        c.association = "manual before/after candidate only; verify successful tame and stable identity"
        return c.id
    end },
    { text = "Did the tame succeed and produce the intended new pet? No means failed or skipped, not proof the species is untameable. Describe the result in Notes.", ask = true, screenshot = true },
    { text = "Click Finish measurements, then /reload to save. Learning an ability for hunter training is a separate /fp steps ps learn experiment.", button = "Finish measurements", run = function() return "taming evidence recorded; reload to save" end },
})

NS._test.Discovery = { Capture = Capture, Families = Families }
