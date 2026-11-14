local ns={}
for _,file in ipairs({"Catalog.lua","CatalogData.lua","CatalogReference.lua","CatalogTeachers.lua","CatalogSpells.lua","GuideData.lua","UpgradesData.lua"}) do assert(loadfile(file))("PetStable",ns) end
local data,U=ns.CatalogData,ns.UpgradesData
local entries,families=ns.GuideData.Build(data)
local abilities=U.Build(data,entries,families)
assert(#abilities==31,"the 31 listed abilities; measured spell records are not duplicated")
local by={}
for _,a in ipairs(abilities) do assert(not by[a.name],a.name); by[a.name]=a end
for i=2,#abilities do assert(abilities[i-1].name<=abilities[i].name,"sorted by name") end
local bite=by["Bite"]
assert(#bite.ranks>=2 and bite.ranks[1].ordinal==1 and bite.ranks[2].ordinal==2,"ranks in order")
assert(bite.ranks[1].petLevel==1 and bite.ranks[2].petLevel==8 and bite.ranks[2].trainingPoints==4)
assert(bite.teachers>0 and not bite.trainer and not bite.allFamilies)
local arcane=by["Arcane Resistance"]
assert(arcane.trainer and arcane.allFamilies and arcane.familyLabel=="All families" and arcane.teachers==0)
assert(U.RankLabel(bite.ranks[2])=="Rank 2 · pet level 8 · 4 training points")
-- Family filter: a family-specific ability is hidden for other families; universal ones stay.
local function Has(list,name) for _,a in ipairs(list) do if a.name==name then return true end end return false end
local wolf=U.Filter(abilities,"family-wolf")
assert(Has(wolf,"Arcane Resistance") and Has(wolf,"Bite") and #wolf<#abilities)
local scorpid=U.Filter(abilities,"family-scorpid")
assert(Has(scorpid,"Scorpid Poison") and not Has(wolf,"Scorpid Poison"))
assert(#U.Filter(abilities,nil)==#abilities)
-- Teachers resolve to guide entries and can be narrowed to one family.
local rank=bite.ranks[2]
assert(#rank.teachers>0)
for _,entry in ipairs(rank.teachers) do assert(entry.key:match("^creature%-") and entry.familyKey) end
local wolves=U.Teachers(rank,"family-wolf")
for _,entry in ipairs(wolves) do assert(entry.familyKey=="family-wolf") end
assert(#wolves<=#rank.teachers and #U.Teachers(rank,nil)==#rank.teachers)
-- Only reference-backed ranks: a missing guide entry drops that teacher, not the rank.
local partial=U.Build(data,{},families)
assert(#partial==31 and partial[1].teachers==0)
-- Client spell data: every ability has its icon and every rank its spell ID (CatalogSpells.lua).
for _,a in ipairs(abilities) do
    assert(type(a.icon)=="number" and a.icon>0,a.name.." icon")
    for _,r in ipairs(a.ranks) do
        assert(type(r.spellID)=="number",a.name.." rank "..r.ordinal.." spell ID")
        assert(not r.clientLevel or r.clientLevel==r.petLevel,a.name.." rank "..r.ordinal..": client level agrees")
    end
end
assert(bite.icon==132278 and bite.ranks[1].clientLevel==1 and not arcane.ranks[1].clientLevel,"trainer ranks have no client level")
-- The spell IDs measured on an active pet (CatalogData.lua, build 70425) land on the same ranks.
for _,m in ipairs({{"Bite",2,17255},{"Claw",1,16827},{"Great Stamina",2,4188},{"Growl",2,14916},
    {"Natural Armor",2,24549},{"Cower",1,1742}}) do
    assert(by[m[1]].ranks[m[2]].spellID==m[3],m[1].." rank "..m[2].." is the measured spell "..m[3])
end
-- Without the client file, or when the rank counts differ, nothing is attached.
local bare={records=data.records,facts=data.facts,evidence=data.evidence}
for _,a in ipairs(U.Build(bare,entries,families)) do assert(not a.icon and not a.ranks[1].spellID) end
local saved=data.abilitySpells.abilities["ability-bite"]
data.abilitySpells.abilities["ability-bite"]={name="Bite",icon=132278,ranks={{17253,1}}}
for _,a in ipairs(U.Build(data,entries,families)) do
    if a.name=="Bite" then assert(a.icon==132278 and not a.ranks[1].spellID,"rank count mismatch: icon only") end
end
data.abilitySpells.abilities["ability-bite"]=saved
io.write("PASS: ability projection, rank order, family filters and teacher resolution, icons and rank spell IDs\n")
