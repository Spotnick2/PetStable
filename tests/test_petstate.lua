local frames = {}
function CreateFrame()
    local f = { scripts = {}, events = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(name) self.events[name] = true end
    function f:UnregisterEvent(name) self.events[name] = nil end
    frames[#frames + 1] = f
    return f
end
local now, class, build = 100, "HUNTER", 70450
function time() return now end
function UnitClass() return "Hunter", class end
function UnitName(unit) return unit == "player" and "Hunt" or "Whiskers" end
function GetRealmName() return "Realm" end
function GetBuildInfo() return "1.60.1", build end
local pet = { exists = true, level = 12, family = "Cat", familyID = 2 }
function UnitExists(unit) return unit == "pet" and pet.exists end
function UnitLevel() return pet.level end
function UnitCreatureFamily() return pet.family, pet.familyID end
Enum = { SpellBookSpellBank = { Pet = 1 } }
local spells = {
    { name = "Bite", subName = "Rank 2", spellID = 17255 }, { name = "Claw", subName = "Rank 1", spellID = 16827 },
    { name = "Attack" }, { name = "Dash", spellID = 23099 },
}
C_SpellBook = { HasPetSpells = function() return #spells end, GetSpellBookItemInfo = function(i) return spells[i] end }
local active = { { petNumber = 42, slotID = 1, name = "Whiskers", level = 12, familyName = "Cat", creatureID = 3035, displayID = 1059 } }
local stabled = { { petNumber = 43, slotID = 3, name = "Grumpy", level = 8, familyName = "Bear", creatureID = 251115, displayID = 136606 },
    { petNumber = 44, slotID = 4, name = "Skitter", level = 5, familyName = "Spider" },
    { petNumber = 45, slotID = 5, name = "Minou", level = 3, familyName = "Chat" } }
C_StableInfo = { GetActivePetList = function() return active end, GetStabledPetList = function() return stabled end }

-- The client names the catalog's families in its own language.
C_CreatureInfo = { GetCreatureFamilyInfo = function(id) return ({ [2] = { id = 2, name = "Chat" } })[id] end }
local ns = {
    db = {},
    CatalogData = { facts = { { subject = "family-cat", field = "familyID", value = 2 }, { subject = "family-cat", field = "name", value = "Cat" },
        { subject = "family-bear", field = "name", value = "Bear" }, { subject = "family-spider", field = "name", value = "Spider" } } },
}
assert(loadfile("Util.lua"))("PetStable", ns)
assert(loadfile("PetState.lua"))("PetStable", ns)
local PS = ns.PetState
PS.Initialize()
assert(PS.State() == "unknown" and not PS.Active() and #PS.Stable() == 0, "nothing is known before a scan")

-- Login registers the events once for a hunter and schedules a scan after a short delay.
local watcher = PS.watcher
watcher.scripts.OnEvent(watcher, "PLAYER_LOGIN")
assert(watcher.events.UNIT_PET and watcher.events.PET_STABLE_SHOW and watcher.events.SPELLS_CHANGED)
local calls = 0
local unsubscribe = PS.Subscribe(function() calls = calls + 1 end)
watcher.scripts.OnEvent(watcher, "UNIT_PET"); watcher.scripts.OnEvent(watcher, "SPELLS_CHANGED")
watcher.scripts.OnUpdate(watcher, 0.1); assert(PS.State() == "unknown", "the scan waits for the delay")
watcher.scripts.OnUpdate(watcher, 0.2)
assert(PS.State() == "fresh" and calls == 1 and not watcher.scripts.OnUpdate, "events within the delay collapse into one scan")

local a = PS.Active()
assert(a.present and a.name == "Whiskers" and a.level == 12 and a.family == "Cat" and a.familyKey == "family-cat" and a.observed == 100)
assert(#a.abilities == 3 and a.abilitiesRead, "commands without a spell ID are not abilities")
assert(a.abilities[1].name == "Bite" and a.abilities[1].rank == 2 and a.abilities[3].rank == nil)
assert(PS.ActiveRank("Bite") == 2 and PS.ActiveRank("Claw") == 1 and PS.ActiveRank("Dash") == 1 and PS.ActiveRank("Growl") == 0)
local pets, observed = PS.Stable()
assert(#pets == 4 and observed == 100 and pets[1].active and pets[1].petNumber == 42)
assert(pets[2].name == "Grumpy" and pets[2].familyKey == "family-bear" and pets[3].familyKey == "family-spider")
assert(pets[4].familyKey == "family-cat", "a stabled pet resolves by the client's localized family name")
local owned = PS.Owned()
assert(owned["family-cat"].active and owned["family-bear"].stabled == 1 and owned["family-spider"].stabled == 1)

-- A missing API keeps the last list, a secret value is dropped, a pet that is gone is recorded.
now = 200; C_StableInfo = nil
pet.exists = false
assert(PS.Refresh("test"))
assert(#PS.Stable() == 4 and select(2, PS.Stable()) == 100, "the last stable list is kept with its time")
assert(PS.Active().present == false and PS.Active().observed == 200 and PS.ActiveRank("Bite") == nil)
-- One list unreadable: its last answer and time stay; only the readable list is updated.
now = 250
C_StableInfo = { GetActivePetList = function() return {} end, GetStabledPetList = function() return nil end }
PS.Refresh("test")
local partial, partialTime, complete = PS.Stable()
assert(#partial == 3 and partialTime == 100 and not complete, "stabled pets survive an unreadable stabled list, reported as partial")
for _, pet in ipairs(partial) do assert(not pet.active) end
C_StableInfo = { GetActivePetList = function() return {} end, GetStabledPetList = function() return {} end }
now = 300; PS.Refresh("test")
assert(#PS.Stable() == 0 and select(2, PS.Stable()) == 300, "an empty answer is a real answer")
assert(select(3, PS.Stable()), "a later full scan clears the partial flag")
pet.exists = true
issecretvalue = function(v) return v == "SECRET" end
pet.family = "SECRET"; PS.Refresh("test")
assert(PS.Active().family == nil and PS.Active().familyKey == nil, "a secret answer is dropped whole, never partly trusted")
issecretvalue = nil; pet.family = "Cat"

-- Saved data from an earlier session is stale until the first scan; unsubscribing works.
local saved = ns.db
local fresh = { db = saved, CatalogData = ns.CatalogData }
assert(loadfile("Util.lua"))("PetStable", fresh); assert(loadfile("PetState.lua"))("PetStable", fresh)
fresh.PetState.Initialize(); assert(saved.pets == ns.db.pets)
assert(fresh.PetState.State() == "stale" and fresh.PetState.Active().observed == 300, "earlier data is marked stale")
unsubscribe(); calls = 0; PS.Refresh("test"); assert(calls == 0)

-- Other classes never scan or store anything.
class = "MAGE"; PS.Initialize(); ns.db.pets.characters = {}
local mage = PS.Refresh("test")
assert(mage == false and next(ns.db.pets.characters) == nil and PS.State() == "unknown")
local f2 = { db = { }, CatalogData = ns.CatalogData }
assert(loadfile("Util.lua"))("PetStable", f2); assert(loadfile("PetState.lua"))("PetStable", f2)
f2.PetState.Initialize()
local w2 = f2.PetState.watcher; w2.scripts.OnEvent(w2, "PLAYER_LOGIN")
assert(next(w2.events) == nil, "a mage registers no pet events")

-- The journal of characters is bounded and a corrupt table is replaced.
class = "HUNTER"; ns.db.pets = "bad"; PS.Initialize()
assert(type(ns.db.pets) == "table" and ns.db.pets.version == 1)
io.write("PASS: pet state scans, freshness, missing APIs, secrets, hunters only, subscriptions and saved data\n")
