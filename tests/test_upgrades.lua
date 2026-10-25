local ns={}
for _,file in ipairs({"Catalog.lua","CatalogData.lua","CatalogReference.lua","CatalogTeachers.lua","GuideData.lua","UpgradesData.lua"}) do assert(loadfile(file))("PetStable",ns) end
local data,U=ns.CatalogData,ns.UpgradesData
local entries,families=ns.GuideData.Build(data)
local abilities=U.Build(data,entries,families)
assert(#abilities==33,"the 33 listed abilities; measured spell records are not duplicated")
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
assert(#partial==33 and partial[1].teachers==0)
io.write("PASS: ability projection, rank order, family filters and teacher resolution\n")
