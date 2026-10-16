-- Exact-display experiment based on AltStable's measured Pets.lua/70124 notes.
-- No NPC identity is inferred from a hunter pet's generic GUID creature field.
local _, NS = ...
local Probe, FP = NS.Probe, ForeverProbe
local CALL_PET = { 883, 83242, 83243, 83244, 83245 }
local viewer, portrait, live, scene, actor, title, status
local activeRender
local WIDTH, HEIGHT, DIST, FOV = 230, 255, 10, 0.6

local function Store()
    local db = NS.GetDB()
    if not db then error("PetStableProbe has not loaded its saved data") end
    db.models = db.models or { captures = {}, records = {}, renders = {} }
    return db.models
end

local function Append(list, row, limit)
    list[#list + 1] = row
    while #list > limit do table.remove(list, 1) end
end

local function Number(v)
    return not FP.IsSecret(v) and type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end
local function ID(v) return Number(v) and v > 0 and v == math.floor(v) end
local function Resolve(system, name)
    local value = rawget(_G, system)
    return name and type(value) == "table" and rawget(value, name) or (not name and value or nil)
end

local function Read(c, label, fn, ...)
    local row = { api = label }
    local r = Probe.Pack(Probe:Try(label, fn, ...))
    if r[1] then
        local tuple = { n = r.n - 1 }
        for i = 2, r.n do tuple[i - 1] = r[i] end
        local copy, why = FP.CopyPlain(tuple)
        row.status, row.values, row.reason = why and "unreadable" or "ok", copy, why
    else
        row.status = type(fn) == "function" and "error" or "missing"
    end
    c.queries[#c.queries + 1] = row
    Probe:Say(label .. " " .. row.status .. " " .. Probe.Describe(row.values, 2))
    if row.values then return unpack(row.values, 1, row.values.n) end
end

local function Unique(rows)
    return #rows == 1 and rows[1] or nil
end
local function Match(slots, guid, spells, petPresent)
    if not petPresent then return nil, "no summoned pet" end
    local byNumber, bySpell = {}, {}
    local tail = type(guid) == "string" and guid:match("%-(%x+)$")
    -- Parse only six hex digits: the complete GUID tail overflows on Forever.
    local number = tail and tonumber(tail:sub(-6), 16)
    for _, info in ipairs(slots) do
        if number and info.petNumber == number then byNumber[#byNumber + 1] = info end
        if spells[info.slotID] then bySpell[#bySpell + 1] = info end
    end
    local a, b = Unique(byNumber), Unique(bySpell)
    if #byNumber > 1 or #bySpell > 1 then return nil, "ambiguous stable match" end
    if a and b and a.petNumber ~= b.petNumber then return nil, "petNumber and Call Pet disagree" end
    if a then return a, "GUID low24 petNumber" end
    if b then return b, "Call Pet spell" end
    return nil, "no unique stable match; select a saved slot manually"
end

local function Capture(label)
    local s = Store()
    local c = { label = label or "manual", run = FP.run, at = FP.Stamp(), queries = {}, slots = {} }
    c.build = Probe.Pack(Read(c, "GetBuildInfo", Resolve("GetBuildInfo")))
    c.locale = Read(c, "GetLocale", Resolve("GetLocale"))
    c.project = rawget(_G, "WOW_PROJECT_ID")
    c.atStableMaster = Read(c, "C_StableInfo.IsAtStableMaster", Resolve("C_StableInfo", "IsAtStableMaster"))
    local exists = Read(c, "UnitExists(pet)", Resolve("UnitExists"), "pet")
    local guid = Read(c, "UnitGUID(pet)", Resolve("UnitGUID"), "pet")
    local slots, seen = {}, {}
    local function Add(info)
        if type(info) ~= "table" then return end
        local copy = FP.CopyPlain(info)
        if not copy then return end
        -- Distinct display IDs of one creature remain separate records.
        local key = tostring(copy.slotID) .. "/" .. tostring(copy.petNumber) .. "/" .. tostring(copy.displayID)
        if not seen[key] then slots[#slots + 1] = copy; seen[key] = true end
    end
    for _, name in ipairs({ "GetNumActivePets", "GetNumStablePets", "GetActivePetList", "GetStabledPetList" }) do
        local value = Read(c, "C_StableInfo." .. name, Resolve("C_StableInfo", name))
        if type(value) == "table" then
            local n = 0
            for _, info in pairs(value) do
                n = n + 1; if n > 100 then c.truncated = true; break end
                Add(info)
            end
        end
    end
    local calls = {}
    for index, spell in ipairs(CALL_PET) do
        Add(Read(c, "C_StableInfo.GetStablePetInfo(" .. index .. ")", Resolve("C_StableInfo", "GetStablePetInfo"), index))
        calls[index] = Read(c, "C_Spell.IsCurrentSpell(" .. spell .. ")", Resolve("C_Spell", "IsCurrentSpell"), spell) == true
    end
    c.slots = slots
    local matched, why = Match(slots, guid, calls, exists == true)
    c.match = why
    for _, info in ipairs(slots) do
        if ID(info.displayID) then
            local key = tostring(info.petNumber) .. "/" .. info.displayID
            local record = { key = key, displayID = info.displayID, creatureID = info.creatureID,
                petNumber = info.petNumber, slotID = info.slotID, family = info.familyName,
                name = info.name, build = c.build, source = "stable displayID" }
            s.records[key] = record
            if info == matched then s.selected = key; c.selected = key end
        end
    end
    Append(s.captures, c, 24)
    Probe:Say("Model capture: " .. why .. "; " .. #slots .. " stable records")
    return c, matched
end

local function Box(tuple)
    local a, b, c, d, e, f = unpack(tuple, 1, tuple.n or #tuple)
    if type(a) == "table" and type(b) == "table" then
        a, b, c, d, e, f = a.x, a.y, a.z, b.x, b.y, b.z
    end
    for _, v in ipairs({ a, b, c, d, e, f }) do if not Number(v) then return nil end end
    if not (Number(a) and Number(b) and Number(c) and Number(d) and Number(e) and Number(f)) then return nil end
    local w, h = math.max(d - a, e - b), f - c
    if w <= 0.001 or h <= 0.001 then return nil end
    local view = 2 * DIST * math.tan(FOV / 2)
    return math.min(0.85 * view / h, 0.85 * view * (WIDTH / HEIGHT) / w)
end

local function Text(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y); fs:SetText(text)
    return fs
end

local function Method(c, object, name, ...)
    return Read(c, name, object and object[name], object, ...)
end
local Show
local function Build()
    if viewer then return end
    viewer = CreateFrame("Frame", nil, UIParent)
    viewer:SetSize(790, 430); viewer:SetPoint("TOP", UIParent, "TOP", 0, -70)
    viewer:SetFrameStrata("DIALOG"); viewer:EnableMouse(true); viewer:SetMovable(true)
    viewer:RegisterForDrag("LeftButton")
    viewer:SetScript("OnDragStart", viewer.StartMoving)
    viewer:SetScript("OnDragStop", viewer.StopMovingOrSizing)
    local bg = viewer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.035, 0.04, 0.055, 0.98)
    title = Text(viewer, "PetStable appearance comparison", 15, -14)
    title:SetWidth(750); title:SetJustifyH("LEFT")
    Text(viewer, "Live pet (blank after dismissal)", 15, -47)
    Text(viewer, "2D portrait: saved display", 275, -47)
    Text(viewer, "3D preview: saved display", 535, -47)
    local liveOK, liveFrame = Probe:Try("CreateFrame(PlayerModel)", CreateFrame, "PlayerModel", nil, viewer)
    live = liveOK and liveFrame or nil
    if live then live:SetSize(WIDTH, HEIGHT); live:SetPoint("TOPLEFT", 15, -75) end
    portrait = viewer:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(200, 200); portrait:SetPoint("TOPLEFT", 290, -96)
    local sceneOK, sceneFrame = Probe:Try("CreateFrame(ModelScene)", CreateFrame, "ModelScene", nil, viewer)
    scene = sceneOK and sceneFrame or nil
    if scene then
        scene:SetSize(WIDTH, HEIGHT); scene:SetPoint("TOPLEFT", 535, -75)
        local ok, result = Probe:Try("ModelScene:CreateActor", scene.CreateActor, scene)
        if ok then actor = result end
    end
    status = Text(viewer, "", 15, -343); status:SetWidth(750); status:SetJustifyH("LEFT")
    local function Button(label, x, fn)
        local b = CreateFrame("Button", nil, viewer, "UIPanelButtonTemplate")
        b:SetPoint("BOTTOMLEFT", x, 14); b:SetSize(115, 24); b:SetText(label); b:SetScript("OnClick", fn)
    end
    local function Cycle(direction)
        local s, keys = Store(), {}
        for key in pairs(s.records) do keys[#keys + 1] = key end
        table.sort(keys)
        if #keys == 0 then return end
        local index = 1
        for i, key in ipairs(keys) do if key == s.selected then index = i end end
        s.selected = keys[((index - 1 + direction) % #keys) + 1]
        Show(s.records[s.selected])
    end
    Button("Previous pet", 15, function() Cycle(-1) end)
    Button("Next pet", 140, function() Cycle(1) end)
    Button("Screenshot", 265, function() Probe:Screenshot("pet appearance comparison") end)
    Button("Close viewer", 650, function() viewer:Hide() end)
    viewer:SetScript("OnHide", function() if scene then scene:SetScript("OnUpdate", nil) end end)
end

Show = function(record)
    Build()
    if scene then scene:SetScript("OnUpdate", nil) end
    local r = { displayID = record and record.displayID, record = record and record.key,
        run = FP.run, at = FP.Stamp(), queries = {}, status = "pending", attempts = 0 }
    activeRender = r
    r.build = Probe.Pack(Read(r, "GetBuildInfo", Resolve("GetBuildInfo")))
    Append(Store().renders, r, 24)
    viewer:Show()
    portrait:SetTexture(nil)
    Method(r, live, "ClearModel")
    Method(r, actor, "ClearModel")
    title:SetText(record and ("Saved pet: " .. tostring(record.family or record.name or "manual")
        .. " | display " .. tostring(record.displayID) .. " | creature " .. tostring(record.creatureID)) or "No saved display selected")
    local pet = Read(r, "UnitExists(pet)", Resolve("UnitExists"), "pet")
    if pet == true then Method(r, live, "SetUnit", "pet"); Method(r, live, "SetPortraitZoom", 0) end
    if not record or not ID(record.displayID) then
        r.status = "missing display"; status:SetText("No display ID: portrait and saved 3D model intentionally cleared.")
        return r
    end
    local fn = Resolve("SetPortraitTextureFromCreatureDisplayID")
    local ok = Probe:Try("SetPortraitTextureFromCreatureDisplayID", fn, portrait, record.displayID)
    r.portrait = ok and "call succeeded; verify picture" or "unavailable/error"
    if not actor then r.status = "actor unavailable"; status:SetText(r.status); return r end
    Method(r, scene, "SetCameraFieldOfView", FOV)
    Method(r, scene, "SetCameraNearClip", 0.1); Method(r, scene, "SetCameraFarClip", 100)
    Method(r, scene, "SetCameraPosition", DIST, 0, 0)
    Method(r, scene, "SetCameraOrientationByYawPitchRoll", math.pi, 0, 0)
    Method(r, actor, "SetScale", 1)
    Method(r, actor, "SetUseCenterForOrigin", true, true, true)
    Method(r, actor, "SetPosition", 0, 0, 0); Method(r, actor, "SetYaw", 0.5)
    local loaded = Method(r, actor, "SetModelByCreatureDisplayID", record.displayID, false)
    if loaded ~= true then
        r.status = "model rejected/unknown"; status:SetText("Model request not confirmed. Saved display " .. record.displayID)
        return r
    end
    local elapsed, since = 0, 0
    status:SetText("Waiting for model bounds. Compare the right-hand preview with your pet's appearance.")
    scene:SetScript("OnUpdate", function(_, delta)
        if activeRender ~= r then return end
        elapsed, since = elapsed + delta, since + delta
        if since < 0.2 then return end
        since = 0; r.attempts = r.attempts + 1
        local tuple = Probe.Pack(Method(r, actor, "GetActiveBoundingBox"))
        local scale = Box(tuple)
        if scale then
            r.box, r.scale, r.status, r.loadSeconds = tuple, scale, "fitted; visually verify", elapsed
            Method(r, actor, "SetScale", scale)
            r.modelFileID = Method(r, actor, "GetModelFileID")
            status:SetText("Saved display " .. record.displayID .. " fitted. Check colour, texture and whole-body framing; the portrait is a head view.")
            scene:SetScript("OnUpdate", nil)
        elseif elapsed >= 4 then
            r.status = "bounds timeout"; r.loadSeconds = elapsed
            status:SetText("Model bounds did not become usable within 4 seconds. Record this in Notes.")
            scene:SetScript("OnUpdate", nil)
        end
    end)
    return r
end

local function Selected()
    local s = Store()
    return s.selected and s.records[s.selected]
end
local function CaptureShow(label)
    local c = Capture(label)
    if not c.selected then error("No unique summoned-pet match. Summon your pet and retry, or inspect /fp ps modelslot <slot>.") end
    Store().comparisonKey = c.selected
    Show(Selected())
    return c.selected
end
local function Restore()
    local r = Selected()
    if not r then error("No saved appearance yet. Capture a summoned pet first.") end
    Show(r)
    return r.key
end

Probe:Command("models", function() if Selected() then Restore() else CaptureShow("manual") end end,
    "Open the saved appearance viewer, or capture the summoned pet")
Probe:Command("modelcapture", function() CaptureShow("manual") end, "Capture stable identity and show the summoned pet")
Probe:Command("modelslot", function(args)
    local slot = tonumber(args)
    if not ID(slot) then Probe:Say("Usage: /fp ps modelslot <slotID>"); return end
    Capture("manual slot selection")
    local s, found = Store(), nil
    for key, r in pairs(s.records) do
        if r.slotID == slot then
            if found then Probe:Say("Slot ambiguous among saved records; use Previous/Next pet"); return end
            found = key
        end
    end
    if not found then Probe:Say("No captured display for slot " .. slot); return end
    s.selected = found; Restore()
end, "Select a stable slot manually when summoned mapping is unknown")
Probe:Command("display", function(args)
    local id = tonumber(args)
    if not ID(id) then Probe:Say("Usage: /fp ps display <positive displayID>"); return end
    Show({ displayID = id, key = "manual/" .. id, source = "manual; tameability unknown" })
end, "Preview a supplied display ID; does not assert tameability")
Probe:Command("modelclear", function() Show(nil) end, "Verify missing-display handling clears previous images")

local function SaveContext(label)
    local s = Store()
    local key = s.comparisonKey or s.selected
    local c = Capture(label)
    s.selected = key
    Restore() -- selection is preserved when the pet has been dismissed.
    return c.match
end
Probe:Steps("models", {
    rev = 1, title = "Pet portraits and exact 3D appearance",
    { text = "Summon your Bear or Cat. Stand away from the stable master and close the stable window. Press Next when ready." },
    { text = "Open the three-view comparison.", button = "Capture and show pet", run = function() return CaptureShow("away from stable") end },
    { text = "Wait for the right-hand model to appear. Does it have the same colour/markings as your live pet? The middle portrait is a head view. Record mismatches in Notes.", ask = true, screenshot = "pet-live-comparison" },
    { text = "Can you see the whole body in the RIGHT-HAND 3D preview, without the head or feet being cut off? Ignore the left live view's camera.", ask = true, screenshot = "pet-framing" },
    { text = "Dismiss your pet normally. Do not abandon it. Press Next when the pet is gone." },
    { text = "Render the saved appearance with no pet summoned.", button = "Show saved appearance", run = function() return SaveContext("dismissed") end },
    { text = "With your pet dismissed, are the MIDDLE portrait and RIGHT 3D preview still textured and showing the same appearance? The left live view should be empty.", ask = true, screenshot = "pet-dismissed" },
    { text = "Reload to test the saved display ID. The procedure will continue afterwards.", reload = true },
    { text = "Restore the saved appearance after reload.", button = "Restore saved appearance", run = function() return SaveContext("after reload") end },
    { text = "Do the middle portrait and right 3D preview still show the same textured appearance after reload?", ask = true, screenshot = "pet-after-reload" },
    { text = "Click Finish measurements below. This closes only the viewer. Then type /reload to save the completed result.", button = "Finish measurements", run = function() if viewer then viewer:Hide() end; return "appearance experiment finished" end },
})
Probe:Steps("modelstable", {
    rev = 1, title = "Compare stable data at and away from a stable master",
    { text = "Visit a stable master and open the stable window. Keep your current pet summoned." },
    { text = "Read stable IDs while at the stable master.", button = "Capture at stable", run = function() Capture("at stable master"); return "captured" end },
    { text = "Close the stable window and walk away. Keep the same pet summoned." },
    { text = "Read the same stable IDs away from the stable master.", button = "Capture away", run = function() return CaptureShow("away comparison") end },
    { text = "Click Finish measurements, then type /reload to save. Pet identity comparisons will be read from the saved results.", button = "Finish measurements", run = function() if viewer then viewer:Hide() end; return "stable experiment finished" end },
})

NS._test.Models = { Capture = Capture, Match = Match, Box = Box, Show = Show,
    ActiveRender = function() return activeRender end, Scene = function() return scene end }
