-- Family and creature facts the client may expose: attack speed and the foods a pet eats.
-- docs/FAMILY-FACTS.md says why: attack speed and stat modifiers are not in any client table, and
-- the food names decoded from the family table's mask should be confirmed against the client.
local _, NS = ...
local Probe, FP = NS.Probe, ForeverProbe

local function Store()
    local db = NS.GetDB()
    if not db then error("PetStableProbe SavedVariables are not ready") end
    db.facts = db.facts or { captures = {} }
    return db.facts
end

local function Resolve(...)
    local value = _G
    for _, part in ipairs({ ... }) do
        if type(value) ~= "table" then return nil end
        value = rawget(value, part)
    end
    return value
end

local function Plain(...)
    local copy, why = FP.CopyPlain(Probe.Pack(...))
    return copy, why
end

-- One reading: what the unit is, and the numbers the client gives for it.
local function Unit(unit)
    local row = { unit = unit }
    local called, exists = Probe:Try("UnitExists", rawget(_G, "UnitExists"), unit)
    if not (called and exists) then row.absent = true; return row end
    local _, guid = Probe:Try("UnitGUID", rawget(_G, "UnitGUID"), unit)
    row.kind = type(guid) == "string" and not FP.IsSecret(guid) and guid:match("^(%a+)%-") or nil
    row.name = Plain(Probe:Try("UnitName", rawget(_G, "UnitName"), unit))
    row.level = Plain(Probe:Try("UnitLevel", rawget(_G, "UnitLevel"), unit))
    row.family = Plain(Probe:Try("UnitCreatureFamily", rawget(_G, "UnitCreatureFamily"), unit))
    row.attackSpeed = Plain(Probe:Try("UnitAttackSpeed", rawget(_G, "UnitAttackSpeed"), unit))
    return row
end

local function Foods()
    local rows = {}
    local active = Resolve("C_PetInfo", "GetPetFoodTypes")
    if active then rows.active = Plain(Probe:Try("C_PetInfo.GetPetFoodTypes", active)) end
    local stable = Resolve("C_StableInfo", "GetStablePetFoodTypes")
    local info = Resolve("C_StableInfo", "GetStablePetInfo")
    rows.stabled = {}
    for slot = 1, 5 do
        local _, pet = Probe:Try("GetStablePetInfo", info, slot)
        if type(pet) == "table" and not FP.IsSecret(pet) then
            rows.stabled[#rows.stabled + 1] = { slot = slot, family = Plain(pet.familyName),
                foods = stable and Plain(Probe:Try("GetStablePetFoodTypes", stable, slot)) or nil }
        end
    end
    return rows
end

local function Capture(label)
    local _, build = Probe:Try("GetBuildInfo", rawget(_G, "GetBuildInfo"))
    local capture = { label = label, build = build, locale = Plain(Probe:Try("GetLocale", rawget(_G, "GetLocale"))),
        target = Unit("target"), pet = Unit("pet"), foods = Foods() }
    local store = Store()
    store.captures[#store.captures + 1] = capture
    if #store.captures > 24 then table.remove(store.captures, 1) end
    Probe:Say(string.format("facts %s: target speed %s, pet speed %s, active foods %s", label,
        Probe.Show(capture.target.attackSpeed and capture.target.attackSpeed[2]),
        Probe.Show(capture.pet.attackSpeed and capture.pet.attackSpeed[2]),
        Probe.Show(capture.foods.active ~= nil)))
    return #store.captures
end

Probe:Command("facts", function(args) return Capture(args ~= "" and args:sub(1, 40) or "facts") end,
    "Record attack speed of the target and the pet, and the foods the client lists for pets")

Probe:Steps("facts", {
    rev = 1, title = "Attack speed and pet foods",
    { text = "Summon a hunter pet and target a wild beast. Note the beast's name and family in Notes." },
    { text = "Record the readings.", button = "Record facts", run = function() return Capture("facts-1") end },
    { text = "Target a different wild beast of another family (or the same family with a different speed, such as a fast rare), then record again.",
      button = "Record facts", run = function() return Capture("facts-2") end },
    { text = "Does the pet's own tooltip or the stable window list the same foods for this family as the readings? Put any difference in Notes.", ask = true },
    { text = "Press Finish, then type /reload to save the results." },
})

NS._test.Facts = { Capture = Capture }
