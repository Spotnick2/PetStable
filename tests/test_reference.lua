local ns={}
for _,file in ipairs({"Catalog.lua","CatalogData.lua","CatalogReference.lua","GuideData.lua"}) do assert(loadfile(file))("PetStable",ns) end
local data,G=ns.CatalogData,ns.GuideData
local errors,conflicts=ns.Catalog.Validate(data)
assert(#errors==0,table.concat(errors,"\n")); assert(#conflicts>0,"research disagreements must survive import")
local evidence={}; for _,e in ipairs(data.evidence) do evidence[e.key]=e end
local sourceOnly=0
for _,r in ipairs(data.records) do
    if r.kind=="creature" and #ns.Catalog.GetFacts(data,r.key,"creatureID")==0 then sourceOnly=sourceOnly+1 end
end
assert(sourceOnly==4,"unresolved Fox identities must remain accessible")
for _,f in ipairs(data.facts) do
    if f.evidence:match("^research%-") then
        assert(f.status=="reference" and evidence[f.evidence].kind=="reference")
        assert(not evidence[f.evidence].build,"target build is not verification")
        assert(f.field~="modelVerified" and f.field~="portraitVerified" and f.field~="spawn")
    end
end
local entries,families,problem=G.Build(data)
assert(not problem and #entries==810 and #families==19)
local byKey={}; for _,entry in ipairs(entries) do byKey[entry.key]=entry end
assert(byKey['creature-3035'].label=='Flatland Cougar' and byKey['creature-3035'].modelVerified)
assert(byKey['creature-251115'].label:find('name unresolved',1,true),"do not silently normalize a disputed name")
assert(byKey['creature-251707'].observedLevel==9 and byKey['creature-251707'].referenceLevel)
assert(byKey['creature-2031'].levelMin==1 and not byKey['creature-2031'].modelVerified)
local cats=G.Appearances(entries,'family-cat')
local displays={}; for _,g in ipairs(cats) do if g.displayID then displays[g.displayID]=g end end
assert(displays[143625] and displays[143626],"Prideclaw variants must stay separate")
local function Contains(group,key) for _,e in ipairs(group.entries) do if e.key==key then return true end end end
assert(Contains(displays[143625],'creature-251245') and Contains(displays[143626],'creature-251245'))
assert(displays[11454].referencePreview and not displays[11454].modelVerified)
assert(displays[1059].modelVerified,"existing observed model evidence remains intact")
assert(#G.Appearances(entries,'family-core-hound')==0,"no invented Core Hound NPCs/displays")
for _,family in ipairs(families) do
    if family.key~='family-core-hound' then assert(#G.Appearances(entries,family.key)>0,family.key) end
end
local synthetic={{key='one',label='A',familyKey='cat',family='Cat',variants={{displayID=1,referencePreview=true}},
    levelMin=2,levelMax=4,referenceLevel=true,zoneNames={'Zone A','Zone B'}}}
local groups=G.Appearances(synthetic,'cat')
assert(#G.FilterAppearances(groups,'A',{low=3,high=3},'reference:Zone B')==1)
assert(#G.FilterAppearances(groups,'A',{low=8,high=8},'reference:Zone B')==0)
assert(G.Level(synthetic[1]):find('reference',1,true))
local _,zones=G.AppearanceFilters(groups); assert(#zones==3)
-- Native family localization changes labels, never catalog identities or evidence.
C_CreatureInfo={GetCreatureFamilyInfo=function(id) return {name='Famille '..id} end}
GetLocale=function() return 'frFR' end
local localized,choices=G.Build(data)
assert(choices[1].displayLabel:find('Famille ',1,true))
for _,e in ipairs(localized) do if e.key=='creature-3035' then assert(e.family=='Famille 2') end end
io.write('PASS: full reference import, source-only records, conflicts, exact variants, filters, localization and proof separation\n')
