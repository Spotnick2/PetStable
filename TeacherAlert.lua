local _, NS = ...
local TA = {}
NS.TeacherAlert = TA

-- Tells a hunter that a creature in view is listed as teaching the next rank of an ability the
-- active pet lacks. It only reads the active pet: what the hunter has learned is not known, so
-- the wording is about the pet, and nothing is said when the pet's abilities could not be read.
local Call, Plain = NS.Call, NS.Plain
local COOLDOWN, SNOOZE, PET_LEVEL = 900, 900, 10
local DEFAULT_IGNORE = { Cower = true } -- rarely worth a trip
local EVENTS = { "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }

local index
local alerted, snoozedUntil, snoozedPet, deferred, waiting = {}, 0, nil, {}, {}
local watcher = CreateFrame("Frame")
TA.watcher = watcher

-- creature ID -> the ability ranks it is listed as teaching, built once from the catalog.
function TA.Index()
    if index then return index end
    index = {}
    local entries, families = NS.GuideData.Build(NS.CatalogData)
    for _, ability in ipairs(NS.UpgradesData.Build(NS.CatalogData, entries, families)) do
        if not ability.trainer then
            for _, rank in ipairs(ability.ranks) do
                for _, creature in ipairs(rank.teachers) do
                    if creature.creatureID then
                        local list = index[creature.creatureID]
                        if not list then list = {}; index[creature.creatureID] = list end
                        list[#list + 1] = { ability = ability, rank = rank, creature = creature }
                    end
                end
            end
        end
    end
    return index
end

function TA.Enabled() return NS.db and NS.db.teacherAlerts == true end
function TA.SetEnabled(on) if NS.db then NS.db.teacherAlerts = on and true or false end end

function TA.Ignored(name)
    local saved = NS.db and NS.db.teacherIgnore
    if saved and saved[name] ~= nil then return saved[name] == true end
    return DEFAULT_IGNORE[name] == true
end
function TA.Ignore(name, ignored)
    if not NS.db then return end
    NS.db.teacherIgnore = NS.db.teacherIgnore or {}
    NS.db.teacherIgnore[name] = ignored and true or false
end
function TA.Snooze(now) snoozedUntil = (now or 0) + SNOOZE end

-- A hunter with a pet out may need to stable it before taming another, so alerts can be held for
-- as long as this same pet stays active. Summoning or swapping to another pet ends the hold.
-- The identity is the live pet's GUID, never saved. Name and family are not an identity (two pets can
-- share both). If the client gives no GUID there is nothing to hold on, so no hold is set.
local function PetIdentity()
    local guid = Call(rawget(_G, "UnitGUID"), "pet")
    return type(guid) == "string" and guid or nil
end
function TA.SnoozeForPet() snoozedPet = PetIdentity() end
function TA.ResetSnoozes() snoozedUntil, snoozedPet = 0, nil; alerted = {} end

-- ctx: playerLevel, creatureLevel, active (PetState.Active()), now. Returns a candidate or nil, reason.
function TA.Find(creatureID, ctx)
    local listed = TA.Index()[creatureID]
    if not listed then return nil, "not a listed teacher" end
    if not ctx.playerLevel or ctx.playerLevel < PET_LEVEL then return nil, "no pet at this level" end
    if ctx.creatureLevel and ctx.creatureLevel > ctx.playerLevel then return nil, "above your level" end
    local pet = ctx.active
    if not (pet and pet.present) then return nil, "no active pet" end
    -- Catalog ability names are English; matching them against a localized spellbook would misreport ranks.
    if pet.locale ~= "enUS" then return nil, "rank matching needs English ability names" end
    -- A temporary quest pet knows nothing yet; an unreadable spellbook is unknown, not empty.
    if not (pet.abilitiesRead and #pet.abilities > 0) then return nil, "pet abilities unknown" end
    if not pet.familyKey then return nil, "pet family unknown" end
    local best
    for _, row in ipairs(listed) do
        local name, rank = row.ability.name, row.rank
        local current = 0
        for _, ability in ipairs(pet.abilities) do if ability.name == name then current = ability.rank or 1 end end
        local fits = rank.allFamilies
        for _, key in ipairs(rank.familyKeys) do if key == pet.familyKey then fits = true end end
        -- Only the next rank, within the pet's level, for an ability that is not ignored.
        if fits and not TA.Ignored(name) and (rank.ordinal or 0) == current + 1
            and (not rank.petLevel or not pet.level or rank.petLevel <= pet.level) then
            if not best or (rank.petLevel or 0) < (best.rank.petLevel or 0) then
                best = { ability = row.ability, rank = rank, creature = row.creature, current = current, pet = pet }
            end
        end
    end
    if not best then return nil, "nothing new for the active pet" end
    return best
end

local function Eligible(unit)
    if not Call(rawget(_G, "UnitExists"), unit) or Call(rawget(_G, "UnitIsDead"), unit) then return nil end
    local guid = Call(rawget(_G, "UnitGUID"), unit)
    if type(guid) ~= "string" or not guid:match("^Creature%-") then return nil end
    if Call(rawget(_G, "UnitIsPlayer"), unit) ~= false or Call(rawget(_G, "UnitPlayerControlled"), unit) ~= false then return nil end
    return Plain(Call(rawget(_G, "UnitCreatureID"), unit))
end

local MAX_WAITING = 20
local function Push(list, unit)
    for _, other in ipairs(list) do if other == unit then return end end
    if #list < MAX_WAITING then list[#list + 1] = unit end
end

-- Evaluate one unit; shows the toast when it qualifies. Returns the candidate.
function TA.Consider(unit)
    if not TA.Enabled() or not NS.PetState or not NS.Toast then return nil end
    local now = Plain(Call(rawget(_G, "GetTime"))) or 0
    if now < snoozedUntil then return nil end
    local creatureID = Eligible(unit)
    if not creatureID or not TA.Index()[creatureID] then return nil end
    if alerted[creatureID] and now - alerted[creatureID] < COOLDOWN then return nil end
    -- A notice already up is never replaced: this unit waits its turn and is checked again when it goes.
    if NS.Toast.IsShown() then Push(waiting, unit); return nil end
    -- Pet data from before this session's scan, or about to be replaced by a pending one, is not
    -- current: wait for the refresh and look at this unit again then.
    if NS.PetState.State() ~= "fresh" or NS.PetState.Pending() then
        -- Every unit seen meanwhile is kept, not just the last: nameplates arrive in bursts.
        Push(deferred, unit)
        return nil
    end
    local active = NS.PetState.Active()
    if snoozedPet then
        if PetIdentity() == snoozedPet then return nil end
        snoozedPet = nil -- a different pet is out now
    end
    local found = TA.Find(creatureID, { playerLevel = NS.PlayerLevel(), now = now,
        creatureLevel = Plain(Call(rawget(_G, "UnitLevel"), unit)), active = active })
    if not found then return nil end
    local name = Plain(Call(rawget(_G, "UnitName"), unit)) or found.creature.label
    local shown = NS.Toast.Show({
        title = "PET ABILITY NEARBY",
        body = string.format("%s is listed as teaching %s rank %d.\n%s (%s) has %s.",
            name, found.ability.name, found.rank.ordinal, found.pet.name or "Your pet", found.pet.family or "pet",
            found.current > 0 and ("rank " .. found.current) or "none"),
        note = "Listed by references, not confirmed in game. Your hunter's learned ranks are not tracked.",
        buttons = {
            { text = "Snooze 15 min", onClick = function() TA.Snooze(now) end },
            { text = "Snooze while I keep this pet", onClick = function() TA.SnoozeForPet() end },
            { text = "Ignore " .. found.ability.name, onClick = function() TA.Ignore(found.ability.name, true) end },
        },
    })
    -- The cooldown starts only when a notice really appeared.
    if not shown then return nil end
    alerted[creatureID] = now
    return found
end

-- One notice at a time. The first unit that qualifies shows; the units after it wait, and are looked at
-- again (their level, family, cooldown and the pet may have changed) when that notice is dismissed or expires.
function TA.ShowNext(units)
    for i, unit in ipairs(units) do
        if TA.Consider(unit) then
            for j = i + 1, #units do Push(waiting, units[j]) end
            return true
        end
    end
    return false
end

if NS.Toast then
    NS.Toast.onHide = function()
        local units = waiting
        waiting = {}
        TA.ShowNext(units)
    end
end

if NS.PetState then
    NS.PetState.Subscribe(function()
        local units = deferred
        deferred = {}
        if NS.Toast and NS.Toast.IsShown() then
            -- Earlier candidates may still be waiting; these join the end of the queue.
            for _, unit in ipairs(units) do Push(waiting, unit) end
        else TA.ShowNext(units) end
    end)
end

watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        local _, class = Call(rawget(_G, "UnitClass"), "player")
        if class ~= "HUNTER" then return end -- other classes register nothing
        for _, name in ipairs(EVENTS) do pcall(self.RegisterEvent, self, name) end
    elseif event == "PLAYER_TARGET_CHANGED" then TA.Consider("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then TA.Consider("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" and type(unit) == "string" then TA.Consider(unit) end
end)
