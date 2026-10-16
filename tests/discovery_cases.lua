return function(ns)
    local D = ns._test.Discovery
    local guid = "Creature-0-1-2-3-251115-ABC"
    rawset(_G, "UnitExists", function() return true end)
    rawset(_G, "UnitGUID", function(unit) return unit == "target" and guid or "Pet-0-1-2-3-165189-ABC" end)
    rawset(_G, "UnitCreatureID", function() return 251115 end)
    rawset(_G, "UnitPosition", function(unit)
        if unit == "target" then return 10, 20, 30, 1 end
        return 100, 200, 300, 1
    end)
    rawset(_G, "C_Map", { GetBestMapForUnit = function() return 7 end,
        GetMapInfo = function() return { name = "Test zone" } end })
    rawset(_G, "C_CreatureInfo", {
        GetCreatureFamilyIDs = function() return { 1, 2 } end,
        GetCreatureFamilyInfo = function(id) return { id = id, name = "Family" } end,
        GetCreatureID = function() return 251115 end,
    })
    rawset(_G, "C_TooltipInfo", { GetUnit = function() return { lines = { { leftText = "Localized evidence" } } } end })
    rawset(_G, "C_UnitAuras", { GetAuraDataByIndex = function() return nil end })
    rawset(_G, "UnitCastingInfo", function() return "Ability", nil, nil, nil, nil, nil, nil, nil, 123 end)
    rawset(_G, "UnitChannelInfo", function() return nil end)
    rawset(_G, "C_Spell", { GetSpellInfo = function(id) return { spellID = id } end })
    local c = D.Capture("wild")
    assert(c.build.n == 6 and c.creatureID == 251115)
    assert(c.creaturePosition[1] == 10 and c.observerPosition[1] == 100)
    assert(c.creaturePosition.n == 4 and c.observerMapID == 7)
    assert(c.evidence.tameable == "unknown" and c.evidence.abilityAcquisition == "unknown")
    local found = false
    for _,q in ipairs(c.queries) do
        if q.api == "C_Spell.GetSpellInfo" and q.args[1] == 123 then found = true end
    end
    assert(found, "observed cast spell must be queried without claiming acquisition")
    rawset(_G, "C_TooltipInfo", { GetUnit = function()
        return { GetType = function() end, lines = { { leftText = "Localized evidence", rightText = "Rank text", method = function() end } } }
    end })
    local tooltipCapture = D.Capture("tooltip mixin")
    local salvaged = false
    for _,q in ipairs(tooltipCapture.queries) do
        if q.api == "C_TooltipInfo.GetUnit" then
            salvaged = q.status == "unreadable" and q.tooltipLines[1].leftText == "Localized evidence"
                and q.tooltipLines[1].rightText == "Rank text" and not q.tooltipLines[1].method
        end
    end
    assert(salvaged, "tooltip methods must not discard readable text or enter saved data")
    assert(D.Families().evidence.clientData:find("family IDs", 1, true))
    guid = "Pet-0-1-2-3-165189-ABC"
    c = D.Capture("owned pet target")
    assert(not c.creatureID and c.evidence.world == "unknown", "pet GUID must not become wild identity")
    guid = "Creature-0-1-2-3-251115-ABC"
    local calls = 0
    rawset(_G, "UnitGUID", function(unit)
        if unit ~= "target" then return nil end
        calls = calls + 1
        return calls == 1 and guid or "Creature-0-1-2-3-999-XYZ"
    end)
    c = D.Capture("changed target")
    assert(c.targetChanged and not c.creatureID and not c.displayID)
    rawset(_G, "UnitGUID", function(unit) return unit == "target" and guid or nil end)
    rawset(_G, "UnitPosition", function() error("unavailable position") end)
    rawset(_G, "C_TooltipInfo", nil)
    c = D.Capture("unavailable")
    assert(c.creaturePosition.n == 0 and c.observerPosition.n == 0)
    local missing, failed = false, false
    for _,q in ipairs(c.queries) do
        if q.api == "C_TooltipInfo.GetUnit" then missing = q.status == "missing" end
        if q.api == "UnitPosition" then failed = q.status == "error" end
    end
    assert(missing and failed, "missing and failed APIs must stay explicit")
    for i = 1, 26 do D.Families() end
    assert(#PetStableProbeDB.discovery.captures == 24)
    local copy, why = ForeverProbe.CopyPlain(PetStableProbeDB.discovery)
    assert(copy and not why, "saved discovery data must contain no widgets")
    SlashCmdList.FOREVERPROBE("steps stop")
    SlashCmdList.FOREVERPROBE("steps ps discover")
    assert(ForeverProbeDB.steps.active == "PetStableProbe/discover")
    ForeverProbe.Steps.Click("primary")
    ForeverProbe.Steps.Click("primary")
    local record = ForeverProbeDB.steps.records['PetStableProbe/discover']
    assert(record.results[2].status == "done", "guided family capture must execute")
    assert(#WoW.chat == 0, "discovery diagnostics must stay quiet")
    io.write("PASS: discovery identity, positions, evidence separation, missing APIs, bounded storage, and guide\n")
end
