local ns={}
for _,file in ipairs({"Catalog.lua","CatalogData.lua","GuideData.lua"}) do assert(loadfile(file))("PetStable",ns) end
local G,seed=ns.GuideData,ns.CatalogData
local function Copy(v)
    if type(v)~="table" then return v end
    local result={}; for k,value in pairs(v) do result[k]=Copy(value) end; return result
end
local function Claim(data,key,field,value,evidence,status)
    data.facts[#data.facts+1]={subject=key,field=field,value=value,evidence=evidence or "galestrider",status=status or "observed"}
end
local function Entry(entries,key)
    for _,entry in ipairs(entries) do if entry.key==key then return entry end end
    error("missing entry "..key)
end
local entries,families,problem=G.Build(seed)
assert(not problem and #entries==3 and #families==19)
local familyCount,emptyFamilies=0,0
for _,family in ipairs(families) do
    familyCount=familyCount+family.count
    if family.count==0 then emptyFamilies=emptyFamilies+1 end
    assert(family.familyID and family.iconFileID)
end
assert(familyCount==3 and emptyFamilies==16)
assert(Entry(families,"family-bird-of-prey").displayLabel=="Birds of Prey")
assert(#G.Filter(families,"  FOXES  ")==1 and #G.Filter(families,"wolves")==1)
assert(#G.Filter(families,"core hound")==1 and #G.Filter(families,"%") ==0)
local _,_,_,familySources=G.Build(seed)
assert(familySources:find("https://beastmaster.io/forever",1,true)
    and familySources:find("https://www.wow-petopia.com/forever/",1,true))
assert(familySources:find("Core Hound absent",1,true) and familySources:find("2026-10-16",1,true))
local noCreatures=Copy(seed)
for i=#noCreatures.facts,1,-1 do
    if noCreatures.facts[i].subject:match("^creature%-") then table.remove(noCreatures.facts,i) end
end
for i=#noCreatures.records,1,-1 do
    if noCreatures.records[i].kind=="creature" then table.remove(noCreatures.records,i) end
end
local noEntries,allFamilies=G.Build(noCreatures)
assert(#noEntries==0 and #allFamilies==19,"family index must not depend on creature coverage")
for _,family in ipairs(allFamilies) do assert(family.count==0) end
local cat,bear,bird=Entry(entries,"creature-3035"),Entry(entries,"creature-251115"),Entry(entries,"creature-251707")
assert(cat.label=="Cat — name unknown" and cat.displayID==1059)
assert(bear.label=="Bear — name unknown" and bear.displayID==136606)
assert(bird.label=="Ornery Galestrider" and not bird.displayID)
assert(cat.details:find("Appearance verified on build 1.60.1.70425",1,true))
assert(bird.details:find("Observed level: 9",1,true))
assert(bird.details:find("Observer context: Zephras Isle / Gustberry Lowlands (UI map 2521)",1,true))
assert(bird.details:find("Spawn location: Unknown",1,true) and bird.details:find("Tameability: Unknown",1,true))
assert(bird.evidence:find("captures 1-3",1,true) and bird.evidence:find("https://github.com/",1,true))
for _,entry in ipairs(entries) do
    assert(not entry.details:find("Bite",1,true) and not entry.details:find("Great Stamina",1,true))
    assert(entry.details:find("Acquisition: Unknown",1,true))
end
assert(#G.Filter(entries,"  cAt  ")==1)
assert(#G.Filter(entries,"galestrider","family-tallstrider")==1)
assert(#G.Filter(entries,"galestrider","family-cat")==0)
assert(#G.Filter(entries,"","family-bear")==1)
for _,query in ipairs({"%",".","[",".*","stamina","Zephras"}) do assert(#G.Filter(entries,query)==0) end
assert(G.Select(entries,cat.key)==cat)
assert(G.Select({bird},cat.key)==bird and G.Select({},cat.key)==nil)

local reordered=Copy(seed)
local reversed={}; for i=#reordered.facts,1,-1 do reversed[#reversed+1]=reordered.facts[i] end
reordered.facts=reversed
local again,reorderedFamilies,_,reorderedSources=G.Build(reordered)
assert(reorderedSources==familySources)
for i,family in ipairs(families) do assert(reorderedFamilies[i].key==family.key) end
for i,entry in ipairs(entries) do
    assert(again[i].key==entry.key and again[i].details==entry.details and again[i].evidence==entry.evidence)
end
local conflict=Copy(seed)
Claim(conflict,"creature-251707","name","Other name")
Claim(conflict,"creature-3035","appearance","appearance-136606","cat-models","confirmed")
Claim(conflict,"creature-251707","observedLevel",10)
local disputed=G.Build(conflict)
assert(Entry(disputed,bird.key).label=="Tallstrider — name unresolved")
assert(not Entry(disputed,cat.key).displayID)
assert(Entry(disputed,bird.key).details:find("Unresolved (different claims)",1,true))
assert(Entry(disputed,bird.key).evidence:find("Other name",1,true))
assert(Entry(select(2,G.Build(conflict)),"family-cat").count==1)
local familyConflict=Copy(seed)
Claim(familyConflict,"family-cat","iconFileID",999,"cat-models")
Claim(familyConflict,"family-cat","name","Other family","cat-models")
local _,uncertainFamilies=G.Build(familyConflict)
local uncertain=Entry(uncertainFamilies,"family-cat")
assert(not uncertain.iconFileID and uncertain.label=="Family unresolved")
local negative=Copy(seed); Claim(negative,bird.key,"tameable",false)
assert(Entry(G.Build(negative),bird.key).details:find("Tameability: No",1,true))
local duplicate=Copy(seed)
Claim(duplicate,"creature-3035","appearance","appearance-1059","cat-models","confirmed")
assert(Entry(G.Build(duplicate),cat.key).displayID==1059)

-- A matching value without matching scope/confirmation must not get the verified label.
for _,mode in ipairs({"status","build","locale"}) do
    local changed=Copy(seed)
    for _,fact in ipairs(changed.facts) do
        if fact.subject=="appearance-1059" and fact.field=="portraitVerified" then
            if mode=="status" then fact.status="observed"
            else
                local e=Copy(changed.evidence[1]); e.key="different-scope"
                e[mode]=mode=="build" and "1.60.1.99999" or "frFR"
                changed.evidence[#changed.evidence+1]=e; fact.evidence=e.key
            end
        end
    end
    local result=Entry(G.Build(changed),cat.key)
    assert(result.displayID==1059 and not result.details:find("Appearance verified",1,true))
end
local empty,choices=G.Build({version=1,records={},evidence={},facts={}})
assert(#empty==0 and #choices==0)
local broken=Copy(seed); broken.facts[1].evidence="missing"
local unavailable,_,reason=G.Build(broken)
assert(#unavailable==0 and reason)
io.write("PASS: guide projection, literal/combined filters, selection, provenance, and unknown/conflicting data\n")
