-- Pure Lua: no WoW APIs, LibGlass, SavedVariables or private probe host.
local ns={}
assert(loadfile("Catalog.lua"))("PetStable",ns)
assert(loadfile("CatalogData.lua"))("PetStable",ns)
local C,seed=ns.Catalog,ns.CatalogData
local function Copy(value)
    if type(value)~="table" then return value end
    local copy={}; for k,v in pairs(value) do copy[k]=Copy(v) end; return copy
end
local function Valid(data)
    local errors,conflicts=C.Validate(data)
    assert(#errors==0,table.concat(errors,"\n")); assert(#conflicts==0,"unexpected conflicting claims")
end
local function Invalid(change, expected)
    local data=Copy(seed); change(data)
    local errors=C.Validate(data)
    assert(table.concat(errors,"\n"):find(expected,1,true),"expected validation error: "..expected)
end
local function Claim(data,key,field,value,evidence,status)
    local fact={subject=key,field=field,value=value,evidence=evidence or "galestrider",status=status or "observed"}
    data.facts[#data.facts+1]=fact; return fact
end
local function Value(data,key,field)
    local facts=C.GetFacts(data,key,field)
    assert(#facts==1,key.."."..field.." must have exactly one claim")
    return facts[1].value
end
Valid(seed)
assert(#seed.records==29 and #seed.evidence==7)
assert(Value(seed,"creature-3035","appearance")=="appearance-1059")
assert(Value(seed,"creature-251115","appearance")=="appearance-136606")
assert(Value(seed,"appearance-136606","modelFileID")==7581790)
assert(Value(seed,"creature-251707","observedLevel")==9)
for _,field in ipairs({"tameable","spawn","levelMin","levelMax","appearance"}) do
    assert(#C.GetFacts(seed,"creature-251707",field)==0,"discovery must not invent "..field)
end
assert(Value(seed,"trainer-row-stamina-4","prerequisiteSatisfied")==false)
assert(#C.GetFacts(seed,"trainer-row-stamina-4","rawCost")==0,"unknown is not zero")
assert(Value(seed,"trainer-row-stamina-3","rawCost")==400)
local spells={17255,16827,4188,14916,24549,1263113,1742}
for _,id in ipairs(spells) do
    assert(Value(seed,"spell-"..id,"spellID")==id)
    assert(#C.GetFacts(seed,"spell-"..id,"source")==0,"pet spells do not establish acquisition")
end
assert(#C.GetFacts(seed,"spell-1263113","ordinal")==0,"Roman numeral does not prove rank progression")
for rank=2,4 do
    assert(C.GetRecord(seed,"classic-stamina-"..rank).game=="classic")
    assert(#C.GetFacts(seed,"classic-stamina-"..rank,"spellID")==0,"do not join by name")
end
assert(Value(seed,"classic-stamina-3","petLevel")==18)
assert(Value(seed,"classic-stamina-4","trainingPoints")==25)
for _,fact in ipairs(seed.facts) do
    assert(fact.evidence~="beastmaster-forever","reviewed reference is not a measured seed fact")
end

Invalid(function(d) d.version=2 end,"unsupported catalog version")
Invalid(function(d) d.facts[2]=nil end,"dense array")
Invalid(function(d) d.records[#d.records+1]=Copy(d.records[1]) end,"duplicate record")
Invalid(function(d) d.evidence[#d.evidence+1]=Copy(d.evidence[1]) end,"duplicate evidence")
Invalid(function(d) d.evidence[1].build=nil end,"invalid evidence")
Invalid(function(d) d.evidence[6].build={} end,"invalid evidence")
Invalid(function(d) d.records[1].name="Unattributed name" end,"invalid record")
Invalid(function(d) d.facts[1].spellID=4188 end,"unexpected claim metadata")
Invalid(function(d) d.facts[1].evidence="missing" end,"missing evidence")
Invalid(function(d) d.facts[1].subject="missing" end,"missing subject")
Invalid(function(d) d.facts[1].field="petNumber" end,"unknown field")
Invalid(function(d) Claim(d,"creature-251707","family","missing") end,"invalid family")
Invalid(function(d) Claim(d,"creature-251707","family","appearance-1059") end,"invalid family")
for _,id in ipairs({0,-1,1.5,math.huge,"251707"}) do
    Invalid(function(d) Claim(d,"creature-251707","creatureID",id) end,"invalid creatureID")
end
Invalid(function(d) Claim(d,"creature-251707","creatureID",0/0) end,"invalid creatureID")
Invalid(function(d) Claim(d,"creature-251707","creatureID",3035) end,"duplicate identity")
Invalid(function(d)
    for i=#d.facts,1,-1 do
        if d.facts[i].subject=="appearance-1059" and d.facts[i].field=="displayID" then table.remove(d.facts,i) end
    end
end,"missing displayID")
Invalid(function(d) Claim(d,"spell-4188","source","classic-pet-trainer","pet-switch") end,"invalid source")
Invalid(function(d) Claim(d,"spell-4188","source","trainer-row-stamina-3","trainer") end,"unmapped trainer observation")
Invalid(function(d) Claim(d,"spell-4188","ordinal",2,"petopia-stamina","reference") end,"cross-game evidence")
Invalid(function(d) Claim(d,"classic-stamina-3","ordinal",3,"petopia-stamina","confirmed") end,"evidence/status mismatch")
Invalid(function(d) Claim(d,"creature-251707","levelMin",12); Claim(d,"creature-251707","levelMax",9) end,"inverted level range")
Invalid(function(d) Claim(d,"classic-stamina-2","previous","classic-stamina-4","petopia-stamina","reference") end,"cyclic rank progression")
Invalid(function(d) Claim(d,"spell-4188","previous","spell-17255","pet-switch") end,"previous ability mismatch")

-- Both directions of the many-to-many appearance relation, using synthetic test links only.
local shared=Copy(seed)
Claim(shared,"creature-3035","appearance","appearance-136606","cat-models")
Claim(shared,"creature-251707","appearance","appearance-1059")
Valid(shared)
assert(#C.GetFacts(shared,"creature-3035","appearance")==2)
local users=0
for _,f in ipairs(shared.facts) do
    if f.field=="appearance" and f.value=="appearance-1059" then users=users+1 end
end
assert(users==2,"one appearance can have two creature associations")

-- Contradictions survive inspection; no last-write-wins resolution.
local competing=Copy(seed)
Claim(competing,"creature-251707","tameable",false)
Claim(competing,"creature-251707","tameable",true)
local errors,conflicts=C.Validate(competing)
assert(#errors==0 and #conflicts==1)
local claims=C.GetFacts(competing,"creature-251707","tameable")
assert(#claims==2 and claims[1].value==false and claims[2].value==true)
assert(conflicts[1].first==claims[1] and conflicts[1].second==claims[2])
for _,row in ipairs({{"spell-4188","ordinal",3,"pet-switch"},
    {"classic-pet-trainer","sourceType","tame","petopia-stamina","reference"}}) do
    local d=Copy(seed); Claim(d,unpack(row))
    local e,c=C.Validate(d); assert(#e==0 and #c==1,"contradictory rank/source must be reported")
end

local point={kind="spawn",space="ui-map",mapID=2521,x=0.25,y=0.5}
local positioned=Copy(seed); Claim(positioned,"creature-251707","spawn",point); Valid(positioned)
for _,change in ipairs({function(p) p.kind="observer" end,function(p) p.space="world" end,
    function(p) p.x=2343.9 end,function(p) p.y=-0.1 end,function(p) p.mapID=0 end,
    function(p) p.x=0/0 end,function(p) p.z=1 end}) do
    Invalid(function(d) local p=Copy(point); change(p); Claim(d,"creature-251707","spawn",p) end,"invalid spawn")
end
io.write("PASS: bounded seed, provenance, identities, unknowns, links, conflicts, ranks, and coordinates\n")
