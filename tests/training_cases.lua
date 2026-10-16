return function(ns)
    -- Exercise the real module through /fp with the host already loaded.
    local function command(text) SlashCmdList.FOREVERPROBE("ps " .. text) end
    local function last()
        local captures = PetStableProbeDB.training.captures
        return captures[#captures]
    end
    local function query(c, api, arg1, arg2)
        for _, row in ipairs(c.queries) do
            if row.api == api and (arg1 == nil or row.args[1] == arg1)
                and (arg2 == nil or row.args[2] == arg2) then return row end
        end
        error("Missing query: " .. api)
    end
    local function has(text)
        return table.concat(PetStableProbeDB.log, "\n"):find(text, 1, true)
    end
    local eventNames = { "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED",
        "LEARNED_SPELL_IN_SKILL_LINE", "UNIT_PET_TRAINING_POINTS",
        "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED" }
    for _, name in ipairs(eventNames) do WoW.KNOWN_EVENTS[name] = true end
    -- Capabilities absent on a class/no-pet environment remain unknown, not false.
    command("capture missing")
    local missing = last()
    assert(query(missing, "C_PetInfo.GetPetTrainingPoints").status == "missing")
    assert(missing.petEnumeration == "unknown")
    assert(missing.hunterTrainingKnowledge:find("unknown", 1, true))

    rawset(_G, "Enum", { SpellBookSpellBank = { Player = 0, Pet = 1 } })
    local petSpells, serviceCount = { 17253, 16827 }, 1
    rawset(_G, "UnitExists", function(unit) return unit == "pet" and #petSpells > 0 end)
    rawset(_G, "UnitClass", function() return "Hunter", "HUNTER", 3 end)
    rawset(_G, "UnitLevel", function(unit) return unit == "pet" and 20 or 25 end)
    rawset(_G, "UnitCreatureFamily", function() return "Cat" end)
    rawset(_G, "UnitGUID", function() return "Pet-0-test" end)
    rawset(_G, "C_PetInfo", { GetPetTrainingPoints = function() return 50, 10 end })
    local calls = 0
    rawset(_G, "C_SpellBook", {
        HasPetSpells = function() return #petSpells, "PET" end,
        GetSpellBookItemInfo = function(i, bank)
            assert(bank == 1)
            return { spellID = petSpells[i], actionID = 999999, name = "Griffe", subName = "Rang 2" }
        end,
        GetSpellBookItemName = function() return "Griffe", "Rang 2" end,
        GetSpellBookItemType = function(i) return 1, 999999, petSpells[i] end,
        FindBaseSpellByID = function() return 12345 end,
        FindSpellOverrideByID = function() return 67890 end,
        IsSpellKnown = function(id, bank)
            calls = calls + 1
            if bank ~= 1 then return false end
            for _, known in ipairs(petSpells) do if known == id then return true end end
            return false
        end,
        IsSpellInSpellBook = function(id, bank, overrides) assert(overrides == false); return bank == 1 end,
    })
    rawset(_G, "C_Spell", { GetSpellSubtext = function() return "Rang 2" end })
    rawset(_G, "GetNumTrainerServices", function() return serviceCount end)
    rawset(_G, "GetTrainerServiceInfo", function() return "Griffe", "available", 1, 20, "Rang 2" end)
    rawset(_G, "GetTrainerServiceItemLink", function() return "|Hspell:999|h[Test]|h" end)
    rawset(_G, "GetTrainerServiceNumAbilityReq", function() return 1 end)
    rawset(_G, "GetTrainerServiceAbilityReq", function(i, r) return "Bite", false, nil end)
    command("track 111")
    command("capture before")
    local before = last()
    assert(before.build[2] == "70374" and before.build.n == 6)
    assert(before.petSpellIDs[17253] and before.petSpellIDs[16827])
    assert(not before.petSpellIDs[999999], "action ID is not the spell ID")
    assert(before.spellIDs[999] and before.spellIDs[111], "trainer link and explicit tracked ID must be queried")
    assert(query(before, "C_Spell.GetSpellSubtext", 17253).values[1] == "Rang 2", "localized rank stays raw")
    assert(query(before, "C_SpellBook.FindBaseSpellByID", 17253).values[1] == 12345)
    assert(query(before, "C_SpellBook.FindSpellOverrideByID", 17253).values[1] == 67890)
    assert(not before.petSpellIDs[67890], "override is not inferred as another learned rank")
    assert(query(before, "C_SpellBook.IsSpellKnown", 17253, 0).values[1] == false)
    assert(query(before, "C_SpellBook.IsSpellKnown", 17253, 1).values[1] == true)
    assert(before.hunterTrainingKnowledge:find("unknown", 1, true), "false Player-bank result is not a training conclusion")
    local req = query(before, "GetTrainerServiceAbilityReq").values
    assert(req.n == 3 and req[2] == false and req[3] == nil, "tuple arity, false and trailing nil must survive")
    assert(query(before, "C_PetInfo.GetPetTrainingPoints").values[2] == 10)

    petSpells, serviceCount = { 17253, 999 }, 0
    command("capture after")
    local after = last()
    assert(after.spellIDs[16827] and after.spellIDs[111], "removed and manually tracked IDs must still be queried")
    command("compare")
    assert(has("pet spell ID added 999") and has("pet spell ID removed 16827"))
    assert(has("query changed C_SpellBook.IsSpellKnown"), "raw knowledge changes must be reported separately")
    WoW.fire("LEARNED_SPELL_IN_SKILL_LINE", 999, 1, false)
    local training = PetStableProbeDB.training
    assert(training.events[#training.events].args[1] == 999)
    local count = #training.events
    command("watch off")
    WoW.fire("SPELLS_CHANGED")
    assert(#training.events == count, "watch off stops collecting")

    -- Secret/error/nil calls must stay explicit and safe to save.
    C_PetInfo.GetPetTrainingPoints = function() return WoW.Secret("training"), nil end
    C_SpellBook.HasPetSpells = function() error("unavailable in this state") end
    command("capture secret-error")
    local bad = last()
    assert(query(bad, "C_PetInfo.GetPetTrainingPoints").status == "unreadable")
    assert(query(bad, "C_SpellBook.HasPetSpells").status == "error")
    assert(bad.petEnumeration == "unknown")
    local _, why = ForeverProbe.CopyPlain(bad)
    assert(not why, "capture must not retain a secret or unpersistable value")
    command("compare")
    assert(has("Pet spell comparison unknown"), "failed enumeration must not produce false removals")
    C_SpellBook.HasPetSpells = function() return nil end
    command("capture nil-count")
    assert(last().petEnumeration == "unknown")

    C_PetInfo.GetPetTrainingPoints = function() return 50, 10 end
    C_SpellBook.HasPetSpells = function() return 1 end
    C_SpellBook.GetSpellBookItemInfo = function() return {} end
    C_SpellBook.GetSpellBookItemType = function() return 1, 123456, nil end
    command("capture no-spell-id")
    assert(last().petEnumeration == "partial", "no spell ID must not be treated as a complete enumeration")

    C_SpellBook.HasPetSpells = function() return 0 end
    command("capture dismissed")
    assert(last().petEnumeration == "ok" and next(last().petSpellIDs) == nil)
    C_SpellBook.HasPetSpells = function() return 201 end
    command("capture oversized-list")
    assert(last().truncated and last().petEnumeration == "partial", "bounded enumeration must flag incomplete evidence")
    Enum.SpellBookSpellBank.Pet = WoW.Secret("bank")
    command("capture secret-enum")
    local _, bankError = ForeverProbe.CopyPlain(last())
    assert(not bankError and last().petEnumeration == "unknown", "secret enum must never be stored or used")
    Enum.SpellBookSpellBank.Pet = nil
    calls = 0
    command("capture no-enum")
    assert(last().petEnumeration == "unknown")
    -- All snapshots are persisted, including captures across module reloads.
    local previousCaptures = training.captures
    assert(loadfile("Tools/PetStableProbe/Training.lua"))("PetStableProbe", ns)
    command("capture after-module-reload")
    assert(PetStableProbeDB.training.captures == previousCaptures)
    assert(last().spellIDs[111], "tracked IDs survive a module reload")

    local captureCount = #training.captures
    SlashCmdList.FOREVERPROBE("steps ps switch")
    ForeverProbe.Steps.Click("primary") -- setup
    ForeverProbe.Steps.Click("primary") -- before
    assert(#training.captures == captureCount + 1 and last().label == "switch-before")
    ForeverProbe.Steps.Click("primary") -- manual switch
    ForeverProbe.Steps.Click("primary") -- after
    assert(last().label == "switch-after")
    local record = ForeverProbeDB.steps.records["PetStableProbe/switch"]
    assert(record.results[2].detail:find("switch-before", 1, true))
    assert(record.results[4].detail:find("switch-after", 1, true))
    ns._test.Training.Watch(false)
    assert(#WoW.chat == 0 and #WoW.errors == 0, "training measurements must stay quiet")
    io.write("PASS: training captures, spell IDs/banks, localized ranks, errors/secrets, event watch, and guided pairs\n")
end
