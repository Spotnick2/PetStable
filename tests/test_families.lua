-- Family facts from the client's CreatureFamily table: diet decoding and its place in the guide.
local ns={}
for _,file in ipairs({"Catalog.lua","CatalogData.lua","CatalogReference.lua","CatalogTeachers.lua","CatalogFamilies.lua","GuideData.lua"}) do
    assert(loadfile(file))("PetStable",ns)
end
local data,G=ns.CatalogData,ns.GuideData
local traits=data.familyTraits
assert(traits and traits.build:match("^1%.60%.1%.%d+$") and traits.url:match("^https://") and #traits.revision==64)
local count=0
for _ in pairs(traits.families) do count=count+1 end
assert(count==19,"the nineteen hunter pet families")

-- The mask decodes bit by bit, and unusable values give no diet.
local function Join(mask) return table.concat(G.Diet(mask),",") end
assert(Join(1)=="Meat" and Join(3)=="Meat,Fish" and Join(48)=="Fungus,Fruit")
assert(Join(63)=="Meat,Fish,Cheese,Bread,Fungus,Fruit" and Join(178)=="Fish,Fungus,Fruit,Raw Fish")
assert(Join(0)=="" and Join(-1)=="" and Join(1.5)=="" and Join(nil)=="" and Join("3")=="")

-- It agrees with an independent diet listing for every family that the guide knows.
local expected={Bat="Fungus,Fruit",Bear="Meat,Fish,Cheese,Bread,Fungus,Fruit",["Bird of Prey"]="Meat",Boar="Meat,Fish,Cheese,Bread,Fungus,Fruit",
    ["Carrion Bird"]="Meat,Fish",Cat="Meat,Fish",["Core Hound"]="Meat",Crab="Fish,Bread,Fungus,Fruit",Crocolisk="Meat,Fish",Fox="Meat",
    Gorilla="Fungus,Fruit",Hyena="Meat,Fruit",Raptor="Meat",Scorpid="Meat",Spider="Meat",Tallstrider="Cheese,Fungus,Fruit",
    Turtle="Fish,Fungus,Fruit,Raw Fish",["Wind Serpent"]="Fish,Cheese,Bread",Wolf="Meat"}
local entries,families=G.Build(data)
local seen=0
for _,family in ipairs(families) do
    local want=expected[family.label]
    assert(want,"unexpected family "..family.label)
    assert(table.concat(family.diet or {},",")==want,family.label.." diet "..table.concat(family.diet or {},","))
    assert(family.traitBuild==traits.build)
    seen=seen+1
end
assert(seen==19)

-- A catalog without the table, or with an unknown family, simply has no diet.
local copy={version=data.version,records=data.records,evidence=data.evidence,facts=data.facts}
local _,bare=G.Build(copy)
for _,family in ipairs(bare) do assert(family.diet==nil) end
io.write("PASS: client family table: mask decoding, 19 families, agreement with the diet listing and graceful absence\n")
