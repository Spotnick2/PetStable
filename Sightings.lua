local _, NS = ...
local S={}; NS.Sightings=S
local LIMIT=10000
local names,seen={},{}
local function ID(v) return type(v)=="number" and v>0 and v<math.huge and v==math.floor(v) end
local Call=NS.Call
local function Locale() return Call(rawget(_G,"GetLocale")) or "unknown" end
local function Index(row)
    if row.familyID then seen[row.familyID..":"..row.displayID]=true end
    if row.name and row.locale==Locale() then
        local old=names[row.creatureID]
        -- `cond and false or x` can never yield false, so spell the conflict out.
        if row.nameConflict or old==false or (old~=nil and old~=row.name) then names[row.creatureID]=false
        else names[row.creatureID]=row.name end
    end
end
function S.Initialize()
    local db=NS.db
    if type(db.sightings)~="table" or db.sightings.version~=1 then db.sightings={version=1,records={}} end
    if type(db.sightings.records)~="table" then db.sightings.records={} end
    if type(db.captureSightings)~="boolean" then db.captureSightings=false end
    -- Capture shipped on before its model binding was measured. Turn it off once
    -- for databases saved by that version; a later deliberate opt-in is kept.
    if db.captureDefaultRev~=2 then db.captureSightings=false; db.captureDefaultRev=2 end
    names,seen={},{}
    S.keys={}; S.count=0
    for key,row in pairs(db.sightings.records) do
        if type(row)=="table" and ID(row.creatureID) and ID(row.displayID) then
            S.keys[key]=true; S.count=S.count+1; Index(row)
        end
    end
end
function S.Name(creatureID) return names[creatureID] or nil end
function S.Seen(familyID,displayID) return seen[tostring(familyID)..":"..tostring(displayID)]==true end
function S.Record(row)
    if not NS.db or not NS.db.captureSightings or not ID(row.creatureID) or not ID(row.displayID)
        or row.kind~="world-creature" or type(row.build)~="string" or type(row.locale)~="string" then return false end
    local key=table.concat({row.build,row.locale,row.creatureID,row.displayID,row.familyID or 0},":")
    local prior=NS.db.sightings.records[key]
    if prior then
        prior.lastSeen=row.lastSeen
        -- A later capture may supply data the first one lacked, or a changed name.
        for _,field in ipairs({"level","classification","modelFileID"}) do
            if prior[field]==nil then prior[field]=row[field] end
        end
        -- Two names for one build/locale/creature/display are conflicting evidence:
        -- keep the first and persist the conflict so it survives re-initialization.
        if row.name then
            if prior.name==nil then prior.name=row.name; Index(prior)
            elseif prior.name~=row.name and not prior.nameConflict then
                prior.nameConflict=true; Index(prior)
            end
        end
        return false
    end
    if S.count>=LIMIT then
        if not S.warned then print("PetStable: sighting journal is full. Save PetStableDB before clearing it."); S.warned=true end
        return false
    end
    NS.db.sightings.records[key]=row; S.keys[key]=true; S.count=S.count+1; Index(row)
    return true
end

-- Only currently addressable world beasts are sampled. No GUIDs/player names,
-- inferred spawn coordinates, pet spellbooks, or tameability flags are persisted.
local watcher=CreateFrame("Frame")
S.watcher=watcher
local model,pending
local function Stop()
    pending=nil; watcher:SetScript("OnUpdate",nil)
    if model then Call(model.ClearModel,model) end
end
local function Eligible(unit,guid)
    if Call(rawget(_G,"UnitGUID"),unit)~=guid or type(guid)~="string" or not guid:match("^Creature%-") then return false end
    if Call(rawget(_G,"UnitIsPlayer"),unit)~=false or Call(rawget(_G,"UnitPlayerControlled"),unit)~=false then return false end
    local _,kind=Call(rawget(_G,"UnitCreatureType"),unit)
    return kind==1
end
local function Sample()
    local p=pending
    if not p or not NS.db.captureSightings or not Eligible(p.unit,p.guid) then Stop(); return end
    local display=Call(model.GetDisplayInfo,model)
    local file=Call(model.GetModelFileID,model)
    if not ID(display) or not ID(file) then return end
    local npc=Call(rawget(_G,"UnitCreatureID"),p.unit)
    if not ID(npc) then return end
    local _,family=Call(rawget(_G,"UnitCreatureFamily"),p.unit)
    local version,build=Call(rawget(_G,"GetBuildInfo"))
    if type(version)~="string" or not build then Stop(); return end
    local timestamp=Call(rawget(_G,"time"))
    local row={kind="world-creature",creatureID=npc,displayID=display,modelFileID=file,
        familyID=ID(family) and family or nil,build=version.."."..tostring(build),locale=Locale(),
        name=Call(rawget(_G,"UnitName"),p.unit),level=Call(rawget(_G,"UnitLevel"),p.unit),
        classification=Call(rawget(_G,"UnitClassification"),p.unit),firstSeen=timestamp,lastSeen=timestamp}
    if not ID(row.level) then row.level=nil end
    if not Eligible(p.unit,p.guid) then Stop(); return end
    S.Record(row); Stop()
end
function S.Capture(unit)
    Stop()
    if not NS.db or not NS.db.captureSightings then return end
    local guid=Call(rawget(_G,"UnitGUID"),unit)
    if not Eligible(unit,guid) then return end
    -- Clear the previous unit before rebinding; every delayed read rechecks the
    -- captured GUID and eligibility before any record is committed.
    if not model then model=CreateFrame("PlayerModel",nil,UIParent); model:Hide() end
    Call(model.ClearModel,model)
    local bound=Call(model.SetUnit,model,unit,false)
    if bound~=true then return end
    pending={unit=unit,guid=guid,elapsed=0,since=0}
    Sample()
    if pending then watcher:SetScript("OnUpdate",function(_,delta)
        if not pending then return end
        pending.elapsed=pending.elapsed+delta; pending.since=pending.since+delta
        if pending.elapsed>=2 then Stop()
        elseif pending.since>=0.1 then pending.since=0; Sample() end
    end) end
end
function S.Command(value)
    if value=="off" then NS.db.captureSightings=false; Stop()
    elseif value=="on" then NS.db.captureSightings=true; S.Capture("target")
    elseif value=="clear" then
        Stop(); NS.db.sightings={version=1,records={}}; S.Initialize(); S.warned=false
    end
    print("PetStable: "..S.count.." local sightings; capture "..(NS.db.captureSightings and "on" or "off")..". /petstable sightings on|off|clear")
    print("Sightings are saved in PetStableDB on logout/reload for manual review. Nothing is uploaded; sightings do not confirm tameability.")
end
watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
watcher:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent",function(_,event) S.Capture(event=="UPDATE_MOUSEOVER_UNIT" and "mouseover" or "target") end)
