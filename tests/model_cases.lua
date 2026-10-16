return function(ns)
    local M = ns._test.Models
    local slots = {
        { slotID = 1, petNumber = 42, displayID = 1001, creatureID = 555, familyName = "Bear", name = "Same name" },
        { slotID = 2, petNumber = 43, displayID = 1002, creatureID = 555, familyName = "Cat", name = "Same name" },
    }
    local petPresent, guid = true, "Pet-0-1-1-1-165189-7FFB00002A"
    rawset(_G, "C_StableInfo", {
        GetStablePetInfo = function(i) return slots[i] end,
        GetActivePetList = function() return slots end,
        GetStabledPetList = function() return {} end,
        GetNumActivePets = function() return 2 end,
        GetNumStablePets = function() return 0 end,
        IsAtStableMaster = function() return false end,
    })
    rawset(_G, "UnitExists", function() return petPresent end)
    rawset(_G, "UnitGUID", function() return guid end)
    rawset(_G, "C_Spell", { IsCurrentSpell = function(spell) return petPresent and spell == 883 end })
    local same, reason = M.Match(slots, guid, { [1] = true }, true)
    assert(same == slots[1] and reason == "GUID low24 petNumber")
    assert(M.Match(slots, nil, { [2] = true }, true) == slots[2], "Call Pet mapping must work without GUID")
    assert(not M.Match(slots, guid, { [2] = true }, true), "conflicting evidence must not guess")
    assert(not M.Match(slots, nil, {}, true), "duplicate names cannot be a fallback")
    assert(not M.Match(slots, guid, {}, false), "dismissed pet cannot match stale GUID data")
    local dup = { slots[1], { slotID = 3, petNumber = 42 } }
    assert(not M.Match(dup, guid, {}, true), "duplicate pet numbers must stay ambiguous")
    local c = M.Capture("test stable")
    assert(c.build.n == 6 and c.build[2] == "70374", "capture must retain the full build tuple")
    assert(#c.slots == 2, "list and indexed stable results must be deduplicated")
    local store = PetStableProbeDB.models
    assert(store.records['42/1001'] and store.records['43/1002'], "same creature's skins stay distinct")
    assert(store.records['42/1001'].creatureID == 555, "generic GUID NPC must not overwrite stable creature ID")
    assert(c.atStableMaster == false and c.selected == '42/1001')
    -- Rendering stubs are added to the single existing host environment.
    local create = CreateFrame
    local modelID, clearCalls, portraitIDs = nil, 0, {}
    local accept = true
    local box = { 0, 0, 0, 0, 0, 0, n = 6 }
    local actor = {
        ClearModel = function() clearCalls = clearCalls + 1; modelID = nil end,
        SetScale = function(self, scale) self.scale = scale end,
        SetUseCenterForOrigin = function() end, SetPosition = function() end, SetYaw = function() end,
        SetModelByCreatureDisplayID = function(_, id, customization)
            assert(customization == false); modelID = id; return accept
        end,
        GetActiveBoundingBox = function() return unpack(box, 1, box.n) end,
        GetModelFileID = function() return 1234 end,
    }
    rawset(_G, "SetPortraitTextureFromCreatureDisplayID", function(texture, id)
        portraitIDs[#portraitIDs + 1] = id; texture.display = id
    end)
    rawset(_G, "CreateFrame", function(kind, ...)
        local frame = create(kind, ...)
        if kind == "ModelScene" then frame.CreateActor = function() return actor end end
        if kind == "PlayerModel" then
            frame.SetCreature = function() error("must never render a random creature skin") end
        end
        return frame
    end)
    local record = store.records['42/1001']
    local r = M.Show(record)
    assert(r.status == "pending" and modelID == 1001 and portraitIDs[1] == 1001)
    local scene = M.Scene()
    local update = scene._scripts.OnUpdate
    update(scene, 0.21)
    assert(r.status == "pending" and r.attempts == 1, "empty bounds must wait for model loading")
    box = { -1, -2, -1, 1, 2, 2, n = 6 }
    update(scene, 0.21)
    assert(r.status == "fitted; visually verify" and r.modelFileID == 1234 and r.scale > 0)
    assert(r.box.n == 6 and scene._scripts.OnUpdate == nil)
    local small = M.Box({ 0, 0, 0, 1, 1, 1, n = 6 })
    local big = M.Box({ 0, 0, 0, 10, 10, 10, n = 6 })
    assert(math.abs(small / big - 10) < 0.001, "framing must scale inversely with model bounds")
    assert(M.Box({ { x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 }, n = 2 }) == small)
    assert(not M.Box({ 0, nil, 0, 1, 1, 1, n = 6 }))
    assert(not M.Box({ 0, 0, 0, 0, 0, 0, n = 6 }))
    assert(not M.Box({ WoW.Secret("bound"), 0, 0, 1, 1, 1, n = 6 }))
    -- Missing/rejected models must clear previous images, with no stale updates.
    local count = #portraitIDs
    local missing = M.Show({ displayID = 0 })
    assert(missing.status == "missing display" and modelID == nil and #portraitIDs == count)
    local attempts = r.attempts
    update(scene, 1)
    assert(r.attempts == attempts, "old render callbacks cannot affect a new selection")
    accept = false
    assert(M.Show(record).status == "model rejected/unknown")
    accept = true
    box = { 0, 0, 0, 0, 0, 0, n = 6 }
    local timeout = M.Show(record)
    local tick = scene._scripts.OnUpdate
    for _ = 1, 21 do tick(scene, 0.21) end
    assert(timeout.status == "bounds timeout" and scene._scripts.OnUpdate == nil)
    -- Saved display restoration does not require a live unit or stable API.
    petPresent = false
    rawset(_G, "C_StableInfo", nil)
    local noStable = M.Capture("dismissed")
    assert(noStable.match == "no summoned pet" and store.selected == '42/1001')
    assert(loadfile('Tools/PetStableProbe/Models.lua'))('PetStableProbe', ns)
    box = { 0, 0, 0, 1, 1, 1, n = 6 }
    SlashCmdList.FOREVERPROBE("ps models")
    assert(modelID == 1001, "saved display must render across module reload without a pet")
    local latest = ns._test.Models.ActiveRender()
    assert(latest.build[2] == '70374')
    local copy, why = ForeverProbe.CopyPlain(store)
    assert(copy and not why, "no widgets or secrets may enter SavedVariables")
    assert(clearCalls >= 5 and #WoW.chat == 0 and #WoW.errors == 0)
    rawset(_G, "CreateFrame", create)
    io.write("PASS: model identity, exact skin IDs, delayed fitting, stale callbacks, missing displays, and saved restoration\n")
end
