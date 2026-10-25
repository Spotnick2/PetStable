local _, NS = ...
local Upgrades = {}
NS.UpgradesData = Upgrades

-- Ability ranks and who teaches them, projected from the catalog for display.
-- Everything here is reference data: it says what a listing reports, never what
-- a character has learned or what the game confirms.
local function Sorted(set)
    local list = {}
    for key in pairs(set) do list[#list + 1] = key end
    table.sort(list)
    return list
end

function Upgrades.Build(data, entries, families)
    local facts, records = {}, {}
    for _, record in ipairs(data.records) do records[record.key] = record end
    for _, fact in ipairs(data.facts) do
        local fields = facts[fact.subject]
        if not fields then fields = {}; facts[fact.subject] = fields end
        local list = fields[fact.field]
        if not list then list = {}; fields[fact.field] = list end
        list[#list + 1] = fact
    end
    local function Values(key, field)
        local out = {}
        for _, fact in ipairs(facts[key] and facts[key][field] or {}) do out[#out + 1] = fact.value end
        return out
    end
    local function One(key, field) return Values(key, field)[1] end
    local byCreature, familyLabel = {}, {}
    for _, entry in ipairs(entries) do byCreature[entry.key] = entry end
    for _, family in ipairs(families) do familyLabel[family.key] = family.label end

    local abilities, byAbility = {}, {}
    for _, record in ipairs(data.records) do
        if record.kind == "ability" and record.game == "forever" and One(record.key, "name") and #Values(record.key, "ability") == 0 then
            local ability = { key = record.key, name = One(record.key, "name"), ranks = {}, familyKeys = {}, teachers = 0 }
            abilities[#abilities + 1] = ability; byAbility[record.key] = ability
        end
    end
    for _, record in ipairs(data.records) do
        local abilityKey = record.kind == "rank" and One(record.key, "ability")
        local ability = abilityKey and byAbility[abilityKey]
        if ability then
            local rank = { key = record.key, ordinal = One(record.key, "ordinal"), petLevel = One(record.key, "petLevel"),
                trainingPoints = One(record.key, "trainingPoints"), allFamilies = One(record.key, "allFamilies") == true,
                familyKeys = {}, teachers = {}, trainer = false }
            for _, family in ipairs(Values(record.key, "eligibleFamily")) do rank.familyKeys[#rank.familyKeys + 1] = family end
            table.sort(rank.familyKeys)
            for _, sourceKey in ipairs(Values(record.key, "source")) do
                local type = One(sourceKey, "sourceType")
                if type == "trainer" then rank.trainer = true
                elseif type == "tame" then
                    local entry = byCreature[One(sourceKey, "creature")]
                    if entry then rank.teachers[#rank.teachers + 1] = entry end
                end
            end
            table.sort(rank.teachers, function(a, b)
                local la, lb = a.levelMin or a.observedLevel or 0, b.levelMin or b.observedLevel or 0
                if la ~= lb then return la < lb end
                return a.label == b.label and a.key < b.key or a.label < b.label
            end)
            ability.ranks[#ability.ranks + 1] = rank
        end
    end
    -- The measured spell-ID ability records carry no pet level; they are another view.
    local listed = {}
    for _, ability in ipairs(abilities) do
        for _, rank in ipairs(ability.ranks) do
            if rank.petLevel then listed[#listed + 1] = ability; break end
        end
    end
    abilities = listed
    for _, ability in ipairs(abilities) do
        table.sort(ability.ranks, function(a, b) return (a.ordinal or 0) < (b.ordinal or 0) end)
        local fam, trainer, count = {}, false, 0
        for _, rank in ipairs(ability.ranks) do
            trainer = trainer or rank.trainer
            ability.allFamilies = ability.allFamilies or rank.allFamilies
            for _, key in ipairs(rank.familyKeys) do fam[key] = true end
            count = count + #rank.teachers
        end
        ability.trainer, ability.teachers = trainer, count
        ability.familyKeys = Sorted(fam)
        local names = {}
        for _, key in ipairs(ability.familyKeys) do names[#names + 1] = familyLabel[key] or key end
        ability.familyLabel = ability.allFamilies and "All families" or table.concat(names, ", ")
    end
    table.sort(abilities, function(a, b) return a.name == b.name and a.key < b.key or a.name < b.name end)
    return abilities
end

-- A rank fits a family when the listing says every family can learn it or names it.
function Upgrades.Fits(rank, familyKey)
    if not familyKey or rank.allFamilies then return true end
    for _, key in ipairs(rank.familyKeys) do if key == familyKey then return true end end
    return false
end

-- A pet cannot be above its hunter's level, so a rank whose pet level is higher is hidden by the level filter.
function Upgrades.Visible(rank, cap)
    return not cap or not rank.petLevel or rank.petLevel <= cap
end

function Upgrades.Filter(abilities, familyKey, cap)
    local out = {}
    for _, ability in ipairs(abilities) do
        for _, rank in ipairs(ability.ranks) do
            if Upgrades.Fits(rank, familyKey) and Upgrades.Visible(rank, cap) then out[#out + 1] = ability; break end
        end
    end
    return out
end

-- Teachers of one rank, optionally only the beasts of the chosen family.
function Upgrades.Teachers(rank, familyKey, cap)
    local out, above = {}, NS.GuideData and NS.GuideData.AboveLevel
    for _, entry in ipairs(rank.teachers) do
        if (not familyKey or entry.familyKey == familyKey) and not (cap and above and above(entry, cap)) then out[#out + 1] = entry end
    end
    return out
end

function Upgrades.RankLabel(rank)
    local parts = { "Rank " .. tostring(rank.ordinal or "?") }
    if rank.petLevel then parts[#parts + 1] = "pet level " .. rank.petLevel end
    if rank.trainingPoints then parts[#parts + 1] = rank.trainingPoints .. " training points" end
    return table.concat(parts, " · ")
end
