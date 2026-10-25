local _, NS = ...
local PS = {}
NS.PetState = PS

-- Observed hunter and pet state, owned in one place. Each part carries when it
-- was observed. It never claims what the hunter has learned: the client exposes
-- the active pet's spellbook and the stable lists, nothing about the hunter's
-- own knowledge, and stabled pets' spellbooks cannot be read.
local Call, Plain = NS.Call, NS.Plain
local MAX_PETS, MAX_SPELLS, MAX_CHARACTERS, DEBOUNCE = 30, 200, 20, 0.25
local EVENTS = { "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED", "PET_STABLE_SHOW", "PET_STABLE_UPDATE", "PLAYER_ENTERING_WORLD" }

local listeners, session = {}, { scanned = false }
local familyByID, familyByName, localized

local function Number(v) v = Plain(v); return type(v) == "number" and v or nil end
local function Text(v) v = Plain(v); return type(v) == "string" and v:match("%S") and v:sub(1, 80) or nil end
local function Time() return Number(Call(rawget(_G, "time"))) end

-- Client family name or ID to catalog family key. The ID is locale independent;
-- the English name is a fallback and finds nothing on other locales.
local function FamilyKey(name, id)
    if not familyByID then
        familyByID, familyByName = {}, {}
        local data = NS.CatalogData
        for _, fact in ipairs(data and data.facts or {}) do
            if fact.field == "familyID" then familyByID[fact.value] = fact.subject
            elseif fact.field == "name" and fact.subject:match("^family%-") then
                familyByName[fact.value:lower()] = fact.subject
            end
        end
    end
    -- The client's own names for the catalog's family IDs make the name fallback work in any locale.
    if not localized then
        local info = rawget(_G, "C_CreatureInfo")
        if type(info) == "table" then
            localized = true
            for familyID, key in pairs(familyByID) do
                local family = Call(info.GetCreatureFamilyInfo, familyID)
                local text = type(family) == "table" and Text(family.name)
                if text then familyByName[text:lower()] = key end
            end
        end
    end
    return (id and familyByID[id]) or (name and familyByName[name:lower()]) or nil
end
PS.FamilyKey = FamilyKey

local function CharacterKey()
    local name = Text(Call(rawget(_G, "UnitName"), "player"))
    local realm = Text(Call(rawget(_G, "GetRealmName")))
    if not name then return nil end
    return name .. "-" .. (realm or "?")
end

local function IsHunter()
    local _, class = Call(rawget(_G, "UnitClass"), "player")
    return class == "HUNTER"
end

function PS.Initialize()
    local db = NS.db
    if type(db.pets) ~= "table" or db.pets.version ~= 1 then db.pets = { version = 1, characters = {} } end
    if type(db.pets.characters) ~= "table" then db.pets.characters = {} end
    session.scanned = false
end

local function Record(create)
    local db, key = NS.db, CharacterKey()
    if not (db and db.pets and key) then return nil end
    local chars = db.pets.characters
    if not chars[key] and create then
        local count = 0
        for _ in pairs(chars) do count = count + 1 end
        if count >= MAX_CHARACTERS then return nil end
        chars[key] = {}
    end
    return chars[key]
end

local function Build()
    local version, build = Call(rawget(_G, "GetBuildInfo"))
    version, build = Text(version), Number(build) or Text(build)
    return version and build and (version .. "." .. tostring(build)) or nil
end

local function ReadPets(list, active, out)
    if type(list) ~= "table" then return false end
    for i = 1, math.min(#list, MAX_PETS) do
        local info = list[i]
        if type(info) == "table" and #out < MAX_PETS then
            local familyName = Text(info.familyName)
            out[#out + 1] = { petNumber = Number(info.petNumber), slotID = Number(info.slotID), name = Text(info.name),
                level = Number(info.level), family = familyName, creatureID = Number(info.creatureID),
                displayID = Number(info.displayID), active = active or nil,
                familyKey = FamilyKey(familyName, Number(info.familyID)) }
        end
    end
    return true
end

local function ScanStable(record, now)
    local stable = rawget(_G, "C_StableInfo")
    if type(stable) ~= "table" then return end
    local activeList = Call(stable.GetActivePetList)
    local stabledList = Call(stable.GetStabledPetList)
    local pets = {}
    local stable = record.stable
    if type(stable) ~= "table" or stable.version ~= 2 then stable = { version = 2 }; record.stable = stable end
    -- Each list is its own section: one that cannot be read keeps its last answer and time.
    for _, section in ipairs({ { "active", activeList, true }, { "stabled", stabledList, false } }) do
        local pets = {}
        local ok = ReadPets(section[2], section[3], pets)
        if ok then stable[section[1]] = { observed = now, build = Build(), pets = pets } end
        stable[section[1] .. "Read"] = ok -- whether the latest scan read this list
    end
end

local function ScanActive(record, now)
    if not Call(rawget(_G, "UnitExists"), "pet") then
        record.active = { observed = now, present = false }
        return
    end
    local familyName, familyID = Call(rawget(_G, "UnitCreatureFamily"), "pet")
    local active = { observed = now, present = true, build = Build(), name = Text(Call(rawget(_G, "UnitName"), "pet")),
        level = Number(Call(rawget(_G, "UnitLevel"), "pet")), family = Text(familyName), abilities = {} }
    active.familyKey = FamilyKey(active.family, Number(familyID))
    local book = rawget(_G, "C_SpellBook")
    local count = type(book) == "table" and Number(Call(book.HasPetSpells)) or nil
    local bank = rawget(_G, "Enum") and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    if count and bank then
        for i = 1, math.min(count, MAX_SPELLS) do
            local info = Call(book.GetSpellBookItemInfo, i, bank)
            local spellID = type(info) == "table" and Number(info.spellID)
            -- Commands and stances have no spell ID; only abilities are kept.
            if spellID and Text(info.name) then
                local sub = Text(info.subName)
                active.abilities[#active.abilities + 1] = { name = Text(info.name), spellID = spellID,
                    rank = sub and tonumber(sub:match("(%d+)")) or nil }
            end
        end
        active.abilitiesRead = true
    end
    record.active = active
end

local function Notify(reason)
    for _, fn in ipairs(listeners) do pcall(fn, reason) end
end

function PS.Refresh(reason)
    if not NS.db or not IsHunter() then return false end
    local record, now = Record(true), Time()
    if not record then return false end
    ScanStable(record, now); ScanActive(record, now)
    record.class = "HUNTER"; session.scanned = true
    Notify(reason or "refresh")
    return true
end

-- "fresh": scanned this session. "stale": only an earlier session's data. "unknown": none.
function PS.State()
    if session.scanned then return "fresh" end
    local record = Record(false)
    return record and (record.stable or record.active) and "stale" or "unknown"
end

function PS.Active()
    local record = Record(false)
    return record and record.active or nil
end

-- All stable entries, when the older list was read, and whether the latest scan read both lists.
function PS.Stable()
    local record = Record(false)
    local stable = record and record.stable
    local pets, observed = {}, nil
    for _, name in ipairs({ "active", "stabled" }) do
        local section = type(stable) == "table" and stable[name]
        if section then
            for _, pet in ipairs(section.pets) do pets[#pets + 1] = pet end
            observed = observed and math.min(observed, section.observed or observed) or section.observed
        end
    end
    return pets, observed, type(stable) == "table" and stable.activeRead == true and stable.stabledRead == true
end

-- Pets of one catalog family. "active" and "stabled" are current: read by this
-- session's latest scan. "earlier" counts stabled pets from saved data or from a
-- list the latest scan could not read, so callers can say they may be out of date.
function PS.Owned()
    local owned = {}
    local active = PS.Active()
    if session.scanned and active and active.present and active.familyKey then
        owned[active.familyKey] = { active = true, stabled = 0, earlier = 0 }
    end
    local record = Record(false)
    local stable = record and type(record.stable) == "table" and record.stable or nil
    local section = stable and stable.stabled
    local current = session.scanned and stable ~= nil and stable.stabledRead == true
    for _, pet in ipairs(section and section.pets or {}) do
        if pet.familyKey and not pet.active then
            local row = owned[pet.familyKey]
            if not row then row = { active = false, stabled = 0, earlier = 0 }; owned[pet.familyKey] = row end
            if current then row.stabled = row.stabled + 1 else row.earlier = row.earlier + 1 end
        end
    end
    return owned
end

-- Observed rank of an ability on the active pet; nil when unknown or absent.
function PS.ActiveRank(abilityName)
    local active = PS.Active()
    if not (active and active.present and active.abilitiesRead) then return nil end
    for _, ability in ipairs(active.abilities) do
        if ability.name == abilityName then return ability.rank or 1 end
    end
    return 0
end

function PS.Subscribe(fn)
    listeners[#listeners + 1] = fn
    return function()
        for i, other in ipairs(listeners) do if other == fn then table.remove(listeners, i); break end end
    end
end

local watcher = CreateFrame("Frame")
PS.watcher = watcher
local pending
local function Tick(_, delta)
    pending = pending - delta
    if pending > 0 then return end
    watcher:SetScript("OnUpdate", nil); pending = nil
    PS.Refresh("event")
end
local function Schedule()
    if pending then return end
    pending = DEBOUNCE; watcher:SetScript("OnUpdate", Tick)
end
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not IsHunter() then return end -- other classes never register or store anything
        for _, name in ipairs(EVENTS) do pcall(self.RegisterEvent, self, name) end
        Schedule()
    else Schedule() end
end)
