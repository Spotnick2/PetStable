local ns={db={}}; local frames={}; local unit={guid='Creature-0-1-2-3-100-1',id=100,display=200,file=300,family=2,name='Cat'}
UIParent={}; local pendingLoad=false; local now=10
function CreateFrame(kind)
    local f={scripts={}}; frames[#frames+1]=f
    function f:SetScript(event,fn) self.scripts[event]=fn end
    function f:RegisterEvent() end
    function f:Hide() end
    function f:ClearModel() self.display=nil; self.file=nil end
    function f:SetUnit() if not pendingLoad then self.display=unit.display; self.file=unit.file end; return true end
    function f:GetDisplayInfo() return self.display end
    function f:GetModelFileID() return self.file end
    return f
end
function UnitGUID() return unit.guid end
function UnitIsPlayer() return false end
function UnitPlayerControlled() return unit.controlled==true end
function UnitCreatureType() return 'Beast',1 end
function UnitCreatureID() return unit.id end
function UnitCreatureFamily() return 'Cat',unit.family end
function UnitName() return unit.name end
function UnitLevel() return 7 end
function UnitClassification() return 'normal' end
function GetBuildInfo() return '1.60.1','70450' end
function GetLocale() return 'enUS' end
function time() return now end
assert(loadfile('Sightings.lua'))('PetStable',ns)
local S=ns.Sightings; S.Initialize(); assert(ns.db.captureSightings==false,'capture stays off until the binding path is measured'); ns.db.captureSightings=true
S.Capture('target'); assert(S.count==1 and S.Seen(2,200) and S.Name(100)=='Cat')
now=11; S.Capture('target'); assert(S.count==1)
for _,row in pairs(ns.db.sightings.records) do
    assert(row.firstSeen==10 and row.lastSeen==11 and row.build=='1.60.1.70450')
    assert(not row.guid and not row.tameable and not row.spawn and not row.modelVerified)
end
unit.display=201; S.Capture('target'); assert(S.count==2,'same geometry, different skin')
unit.controlled=true; unit.display=202; S.Capture('target'); assert(S.count==2)
unit.controlled=false; unit.guid='Pet-0-1-2-3-100-1'; S.Capture('target'); assert(S.count==2)
unit.guid='Creature-0-1-2-3-100-1'; pendingLoad=true; S.Capture('target')
assert(S.watcher.scripts.OnUpdate)
frames[2].display=202; frames[2].file=300
unit.guid='Creature-0-1-2-3-101-2'
S.watcher.scripts.OnUpdate(nil,0.2); assert(S.count==2 and not S.watcher.scripts.OnUpdate,'stale target rejected')
S.Capture('target'); frames[2].display=202; frames[2].file=300
S.watcher.scripts.OnUpdate(nil,0.2); assert(S.count==3,'delayed model accepted for unchanged target')
S.Capture('target'); S.watcher.scripts.OnUpdate(nil,2.1)
assert(not S.watcher.scripts.OnUpdate and S.count==3,'missing models time out')
S.Initialize(); assert(S.count==3 and S.Seen(2,201),'journal persists across initialization')
do
    local function Row(name) return {kind='world-creature',creatureID=500,displayID=600,modelFileID=700,familyID=2,
        build='1.60.1.70450',locale='enUS',name=name,firstSeen=1,lastSeen=1} end
    local before=S.count
    assert(S.Record(Row(nil)) and S.Name(500)==nil)
    assert(not S.Record(Row('Late Name')) and S.Name(500)=='Late Name','a later capture supplies the missing name')
    S.Initialize(); assert(S.Name(500)=='Late Name','the merged name survives re-initialization')
    assert(not S.Record(Row('Renamed')) and S.Name(500)==nil,'a different name is conflicting evidence, not a replacement')
    S.Initialize(); assert(S.Name(500)==nil,'the conflict survives re-initialization')
    assert(S.count==before+1,'duplicates do not add rows')
    S.Initialize()
end
ns.db.captureSightings=false; pendingLoad=false; unit.display=203; S.Capture('target'); assert(S.count==4)
ns.db.captureSightings=true; S.count=10000; S.Capture('target'); assert(S.count==10000,'bounded journal')
io.write('PASS: sightings identity, deduplication, delayed loads, stale targets, player control, persistence and limits\n')
