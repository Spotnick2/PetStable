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
-- Learned markers for the active pet (#10): spell IDs match in any locale.
local wolf={present=true,abilitiesRead=true,level=20,familyKey="family-wolf",locale="deDE",
    abilities={{spellID=17255,name="Biss",rank=2}}}
assert(U.KnownRank(bite,wolf)==2,"rank found by spell ID, whatever the language")
assert(U.RankStatus(bite.ranks[1],2,wolf)=="learned" and U.RankStatus(bite.ranks[2],2,wolf)=="learned")
assert(bite.ranks[3].petLevel==16 and U.RankStatus(bite.ranks[3],2,wolf)=="ready","pet level reached: can learn now")
assert(bite.ranks[4].petLevel==24 and U.RankStatus(bite.ranks[4],2,wolf)=="level","pet level too low")
local s=U.PetSummary(bite,wolf); assert(s.known==2 and s.total==8 and s.ready)
assert(U.PetSummary(by["Scorpid Poison"],wolf)==nil,"another family's ability gets no marker")
assert(U.RankStatus(by["Scorpid Poison"].ranks[1],0,wolf)==nil)
local growl=by["Growl"]
assert(U.KnownRank(growl,wolf)==0 and U.RankStatus(growl.ranks[1],0,wolf)=="ready","unlearned rank 1 at level 1")
-- Unknown stays unknown: no spellbook, no family, no level.
assert(U.KnownRank(bite,{present=true,abilitiesRead=false,abilities={}})==nil)
assert(U.KnownRank(bite,{present=false})==nil and U.KnownRank(bite,nil)==nil)
assert(U.RankStatus(bite.ranks[3],nil,wolf)==nil,"unknown knowledge is never 'not learned'")
assert(U.RankStatus(bite.ranks[3],2,{familyKey=nil,level=20})==nil,"unknown family: no marker")
assert(U.RankStatus(bite.ranks[3],2,{familyKey="family-wolf"})==nil,"unknown pet level: no marker")
-- English name and rank text are the fallback when the spell ID does not match.
local english={present=true,abilitiesRead=true,level=20,familyKey="family-wolf",locale="enUS",
    abilities={{spellID=999999,name="Bite",rank=3}}}
assert(U.KnownRank(bite,english)==3)
english.locale="frFR"; assert(U.KnownRank(bite,english)==0,"no English fallback outside enUS")
-- Without client spell IDs, only an English client can say anything.
local plain
for _,a in ipairs(U.Build({records=data.records,facts=data.facts,evidence=data.evidence},entries,families)) do
    if a.name=="Bite" then plain=a end
end
assert(U.KnownRank(plain,wolf)==nil,"no spell IDs and no English names: unknown")
english.locale="enUS"; assert(U.KnownRank(plain,english)==3)
io.write("PASS: ability projection, rank order, family filters and teacher resolution, icons, rank spell IDs and active-pet markers\n")
