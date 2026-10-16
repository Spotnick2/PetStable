local _, NS = ...
local Guide = {}
NS.GuideData = Guide

local function Sorted(set)
    local values={}; for value in pairs(set) do values[#values+1]=value end
    table.sort(values); return values
end

-- A display projection, not a resolver that promotes one source/build over another.
-- Even cross-build disagreements remain unresolved in this first browser slice.
function Guide.Build(data)
    local errors=NS.Catalog.Validate(data)
    if #errors>0 then return {},{},"Catalog unavailable: invalid data." end
    local evidence,bySubject={},{}
    for _,e in ipairs(data.evidence) do evidence[e.key]=e end
    for _,f in ipairs(data.facts) do
        bySubject[f.subject]=bySubject[f.subject] or {}
        local fields=bySubject[f.subject]
        fields[f.field]=fields[f.field] or {}; table.insert(fields[f.field],f)
    end
    local function Read(key,field)
        local claims=bySubject[key] and bySubject[key][field] or {}
        local value=claims[1] and claims[1].value
        local state=#claims==0 and "unknown" or "known"
        for _,f in ipairs(claims) do
            if f.value~=value then state="conflicting"; break end
        end
        if state~="known" then value=nil end
        return {value=value, state=state, claims=claims}
    end
    local function Value(field,missing)
        if field.state=="conflicting" then return "Unresolved (different claims)" end
        if field.state=="unknown" then return missing or "Unknown" end
        if field.value==false then return "No" end
        if field.value==true then return "Yes" end
        return tostring(field.value)
    end
    local function SameScope(a,b)
        return a.game==b.game and a.build==b.build and a.locale==b.locale
    end
    local entries,families,sourceFamilies={},{},{}
    local plurals={ ["Bird of Prey"]="Birds of Prey", Fox="Foxes", Wolf="Wolves" }
    for _,r in ipairs(data.records) do
        if r.kind=="family" and r.game=="forever" then
            local name,id,icon=Read(r.key,"name"),Read(r.key,"familyID"),Read(r.key,"iconFileID")
            local label=name.value or "Family unresolved"
            local display=name.value and (plurals[label] or label.."s") or label
            families[r.key]={key=r.key,label=label,displayLabel=display,familyID=id.value,
                iconFileID=icon.value,count=0,search=(label.." "..display):lower()}
            for _,field in ipairs({name,id,icon}) do
                for _,claim in ipairs(field.claims) do
                    sourceFamilies[claim.evidence]=sourceFamilies[claim.evidence] or {}
                    sourceFamilies[claim.evidence][display]=true
                end
            end
        end
    end
    for _,r in ipairs(data.records) do
        if r.kind=="creature" and r.game=="forever" then
            local used={}
            local function Field(key,field,label)
                local result=Read(key,field)
                if #result.claims>0 then used[#used+1]={label=label,field=result} end
                return result
            end
            local name=Field(r.key,"name","Name")
            local familyLink=Field(r.key,"family","Family association")
            local family=familyLink.value and Field(familyLink.value,"name","Family") or familyLink
            local familyName=family.state=="known" and family.value or "Family unknown"
            local familyKey=familyLink.state=="known" and familyLink.value or nil
            if familyKey and families[familyKey] then families[familyKey].count=families[familyKey].count+1 end
            local label=name.value or (familyName..(name.state=="conflicting" and " — name unresolved" or " — name unknown"))
            local level=Field(r.key,"observedLevel","Observed level")
            local tameable=Field(r.key,"tameable","Tameability")
            local area=Field(r.key,"observerArea","Observer context")
            local map=Field(r.key,"observerMapID","Observer map")
            local appearance=Field(r.key,"appearance","Appearance association")
            local display,verified
            if appearance.value then
                display=Field(appearance.value,"displayID","Display ID")
                verified=Field(appearance.value,"portraitVerified","Portrait verification")
            end
            local displayID=display and display.state=="known" and display.value or nil
            local builds={}
            if displayID and verified.value==true then
                for _,link in ipairs(appearance.claims) do
                    local scope=evidence[link.evidence]
                    for _,proof in ipairs(verified.claims) do
                        if link.status=="confirmed" and proof.status=="confirmed"
                            and scope.build and SameScope(scope,evidence[proof.evidence]) then
                            for _,id in ipairs(display.claims) do
                                if SameScope(scope,evidence[id.evidence]) then builds[scope.build]=true end
                            end
                        end
                    end
                end
            end
            local buildList=Sorted(builds)
            local appearanceText="Appearance: Unknown"
            if appearance.state=="conflicting" or (display and display.state=="conflicting") then
                appearanceText="Appearance: Unresolved (multiple claims or variants)"
            elseif #buildList>0 then
                appearanceText="Appearance verified on build "..table.concat(buildList,", ")
            elseif displayID then appearanceText="Appearance recorded; verification unresolved" end
            local details={label,"Family: "..Value(family),"Observed level: "..Value(level),
                appearanceText,"Tameability: "..Value(tameable),"Acquisition: Unknown",
                "Spawn location: Unknown"}
            if area.state~="unknown" or map.state~="unknown" then
                details[#details+1]="Observer context: "..Value(area).." (UI map "..Value(map)..")"
                details[#details+1]="Observer context is not a spawn location."
            end
            local sources={label,"Evidence applies to the stated builds; it is not a current-build guarantee."}
            for _,item in ipairs(used) do
                sources[#sources+1]="\n"..item.label..":"
                local lines={}
                for _,f in ipairs(item.field.claims) do
                    local e=evidence[f.evidence]
                    local v=f.value
                    if type(v)=="boolean" then v=v and "Yes" or "No" end
                    local line=tostring(v).." — "..f.status.."; "..e.game.."; build "..(e.build or "unknown")
                        .."; locale "..(e.locale or "unknown").."\nReviewed "..e.date.."\n"..e.locator.."\n"..e.url
                    lines[line]=true
                end
                for _,line in ipairs(Sorted(lines)) do sources[#sources+1]=line end
            end
            entries[#entries+1]={key=r.key,label=label,familyKey=familyKey,family=familyName,displayID=displayID,
                search=((name.value or "").." "..(family.state=="known" and family.value or "")):lower(),
                details=table.concat(details,"\n\n"),evidence=table.concat(sources,"\n")}
        end
    end
    table.sort(entries,function(a,b)
        if a.label:lower()==b.label:lower() then return a.key<b.key end
        return a.label:lower()<b.label:lower()
    end)
    local choices={}
    for _,family in pairs(families) do choices[#choices+1]=family end
    table.sort(choices,function(a,b) if a.label==b.label then return a.key<b.key end; return a.label<b.label end)
    local sources={"Family index sources",
        "Website listings are references, not confirmation of tameability. Client family IDs and icons identify metadata only. Counts describe PetStable's recorded creatures, not all creatures in the game."}
    for _,key in ipairs(Sorted(sourceFamilies)) do
        local e=evidence[key]
        sources[#sources+1]=table.concat({"\n"..e.kind.."; "..e.game.."; reviewed "..e.date,
            "Build: "..(e.build or "not stated").."; locale: "..(e.locale or "not stated"),
            "Families: "..table.concat(Sorted(sourceFamilies[key]),", "),e.locator,e.url},"\n")
    end
    return entries,choices,nil,table.concat(sources,"\n\n")
end

function Guide.Filter(entries,query,familyKey)
    query=(query or ""):match("^%s*(.-)%s*$"):lower()
    local result={}
    for _,entry in ipairs(entries) do
        if (not familyKey or entry.familyKey==familyKey) and entry.search:find(query,1,true) then
            result[#result+1]=entry
        end
    end
    return result
end

function Guide.Select(entries,key)
    for _,entry in ipairs(entries) do if entry.key==key then return entry end end
    return entries[1]
end
