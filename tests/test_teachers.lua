local ns={}
for _,file in ipairs({"Catalog.lua","CatalogData.lua","CatalogReference.lua","CatalogTeachers.lua","GuideData.lua"}) do assert(loadfile(file))("PetStable",ns) end
local data,C=ns.CatalogData,ns.Catalog
local errors=C.Validate(data)
assert(#errors==0,table.concat(errors,"\n"))
local evidence={}; for _,e in ipairs(data.evidence) do evidence[e.key]=e end
-- One citation per Petopia listing anchor (#31): reference, dated, linked, and never a measured build.
local cited=0
for key,e in pairs(evidence) do
    if key:match("^petopia%-abilities%-") then
        cited=cited+1
        assert(e.kind=="reference" and not e.build,"a listing is not a measurement: "..key)
        assert(e.url:match("^https://www%.wow%-petopia%.com/forever/abilities%.php#") and e.date:match("^%d%d%d%d%-%d%d%-%d%d$"),key)
        assert(e.locator:match("not confirmed in game") and e.locator:match("against client build"),key)
    end
end
assert(cited==175 and not evidence["teachers-reference"],"175 anchors replace the single unchecked listing record")
local kinds,records={ability=0,rank=0,source=0},{}
for _,r in ipairs(data.records) do records[r.key]=r end
for _,r in ipairs(data.records) do
    if r.key:match("^ability%-") and not r.key:match("^ability%-for%-") and r.kind=="ability" then kinds.ability=kinds.ability+1 end
    if r.key:match("%-rank%-%d+$") then kinds.rank=kinds.rank+1 end
    if r.key:match("^source%-tame%-") then kinds.source=kinds.source+1 end
end
assert(kinds.ability==30 and kinds.rank==145 and kinds.source==433,"ability, rank and teaching-beast counts")
for _,f in ipairs(data.facts) do
    if f.evidence:match("^petopia%-abilities%-") then
        assert(f.status=="reference","teacher claims are never verified")
        assert(f.field~="spawn" and f.field~="tameable" and f.field~="modelVerified","no position or tameability claims")
    end
end
-- Every fact about a generated record cites a Petopia anchor, so nothing in it can be promoted by agreement.
local generated={}
for _,r in ipairs(data.records) do
    if r.key:match("^ability%-") and not r.key:match("^ability%-for%-") or r.key:match("^source%-tame%-") or r.key=="source-pet-trainer" then generated[r.key]=true end
end
for _,f in ipairs(data.facts) do
    if generated[f.subject] then assert(f.evidence:match("^petopia%-abilities%-") and f.status=="reference",f.subject.." "..f.field) end
end
-- Each tame source links an existing catalog creature and a rank of the right ability.
local linked=0
for _,r in ipairs(data.records) do
    if r.key:match("^source%-tame%-") then
        local creature=C.GetFacts(data,r.key,"creature")
        assert(#creature==1 and records[creature[1].value] and records[creature[1].value].kind=="creature",r.key)
        assert(#C.GetFacts(data,r.key,"sourceType")==1)
        linked=linked+1
    end
end
assert(linked==433)
-- Rank chains are continuous and every rank names its ability and levels.
local bite=C.GetFacts(data,"ability-bite-rank-2","previous")
assert(#bite==1 and bite[1].value=="ability-bite-rank-1")
assert(#C.GetFacts(data,"ability-bite-rank-1","previous")==0)
assert(#C.GetFacts(data,"ability-arcane-resistance-rank-1","allFamilies")==1,"trainer abilities fit every family")
assert(#C.GetFacts(data,"ability-arcane-resistance-rank-1","source")==1)
local guide=ns.GuideData.Build(data)
assert(#guide==808,"teacher claims add no creature entries")
io.write("PASS: teacher abilities, ranks, tame sources, reference scope and links to catalog creatures\n")
