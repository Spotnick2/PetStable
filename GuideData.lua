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
    local skins=type(data.displaySkins)=="table" and data.displaySkins.skins or {}
    local looks=type(data.displaySkins)=="table" and data.displaySkins.names or {}
    -- A skin's look name comes from its own family only.
    local function Look(familyKey,id)
        return familyKey and skins[id] and looks[familyKey.."|"..skins[id]] or nil
    end
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
            local same=f.value==value
            if type(value)=="table" and type(f.value)=="table" then
                same=true
                for k,v in pairs(value) do if f.value[k]~=v then same=false end end
                for k,v in pairs(f.value) do if value[k]~=v then same=false end end
            end
            if not same then state="conflicting"; break end
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
    local function VerifiedAppearance(link,display,proof)
        if not (link.value and display and display.value and proof and proof.value==true) then return false end
        for _,a in ipairs(link.claims) do
            local scope=evidence[a.evidence]
            for _,b in ipairs(proof.claims) do
                if a.status=="confirmed" and b.status=="confirmed" and scope.build and SameScope(scope,evidence[b.evidence]) then
                    for _,c in ipairs(display.claims) do
                        if SameScope(scope,evidence[c.evidence]) then return true end
                    end
                end
            end
        end
        return false
    end
    local entries,families,sourceFamilies={},{},{}
    local plurals={ ["Bird of Prey"]="Birds of Prey", Fox="Foxes", Wolf="Wolves" }
    for _,r in ipairs(data.records) do
        if r.kind=="family" and r.game=="forever" then
            local name,id,icon=Read(r.key,"name"),Read(r.key,"familyID"),Read(r.key,"iconFileID")
            local label=name.value or "Family unresolved"
            local display=name.value and (plurals[label] or label.."s") or label
            local api=rawget(_G,"C_CreatureInfo")
            if id.value and api and type(api.GetCreatureFamilyInfo)=="function" then
                local ok,info=pcall(api.GetCreatureFamilyInfo,id.value)
                if ok and type(info)=="table" and type(info.name)=="string" and info.name~="" then
                    label=info.name
                    -- English plurals are not rules for other client languages.
                    display=(type(GetLocale)=="function" and GetLocale()~="enUS" and GetLocale()~="enGB")
                        and label or (plurals[label] or label.."s")
                end
            end
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
            if familyKey and families[familyKey] then familyName=families[familyKey].label end
            if familyKey and families[familyKey] then families[familyKey].count=families[familyKey].count+1 end
            local label=name.value or (familyName..(name.state=="conflicting" and " — name unresolved" or " — name unknown"))
            local creatureID=Field(r.key,"creatureID","NPC ID").value
            local localized=NS.Sightings and NS.Sightings.Name(creatureID)
            if localized then label=localized end
            local level=Field(r.key,"observedLevel","Observed level")
            local tameable=Field(r.key,"tameable","Tameability")
            local area=Field(r.key,"observerArea","Observer context")
            local map=Field(r.key,"observerMapID","Observer map")
            local appearance=Field(r.key,"appearance","Appearance association")
            local variants,variantKeys={},{}
            -- Reference links enumerate exact displays; named-look candidates never enter this list.
            for _,link in ipairs(appearance.claims) do
                if link.status=="reference" and not variantKeys[link.value] then
                    local id=Field(link.value,"displayID","Reference display ID")
                    if id.value then
                        variantKeys[link.value]=true
                        variants[#variants+1]={key=link.value,displayID=id.value,skin=skins[id.value],
                            look=Look(familyKey,id.value),referencePreview=true}
                    end
                end
            end
            local display,verified,modelVerified
            if appearance.value then
                display=Field(appearance.value,"displayID","Display ID")
                verified=Field(appearance.value,"portraitVerified","Portrait verification")
                modelVerified=Field(appearance.value,"modelVerified","Model verification")
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
            local low=Field(r.key,"levelMin","Minimum level")
            local high=Field(r.key,"levelMax","Maximum level")
            local conditions=Field(r.key,"conditions","Conditions")
            local spawn=Field(r.key,"spawn","Spawn location")
            local levelMin,levelMax,location,referenceLevel
            for _,a in ipairs(low.claims) do
                for _,b in ipairs(high.claims) do
                    if low.value and high.value and a.status=="confirmed" and b.status=="confirmed"
                        and SameScope(evidence[a.evidence],evidence[b.evidence]) then levelMin,levelMax=low.value,high.value end
                end
            end
            if not levelMin and low.value and high.value then
                for _,a in ipairs(low.claims) do for _,b in ipairs(high.claims) do
                    if a.status=="reference" and b.status=="reference" and a.evidence==b.evidence then
                        levelMin,levelMax,referenceLevel=low.value,high.value,true
                    end
                end end
            end
            if spawn.state=="known" then
                for _,claim in ipairs(spawn.claims) do if claim.status=="confirmed" then location=spawn.value end end
            end
            if levelMin then details[#details+1]=(referenceLevel and "Reference level range: " or "Verified level range: ")..levelMin.."–"..levelMax end
            local zones,notes={},{}
            for _,claim in ipairs(Field(r.key,"zoneName","Reference zone").claims) do zones[claim.value]=true end
            for _,claim in ipairs(Field(r.key,"referenceNote","Reference acquisition/location note").claims) do notes[claim.value]=true end
            local zoneNames=Sorted(zones)
            if #zoneNames>0 then details[#details+1]="Reference zones: "..table.concat(zoneNames,", ") end
            if next(notes) then details[#details+1]="Reference notes:\n"..table.concat(Sorted(notes),"\n") end
            local rarity=Field(r.key,"rarity","Reference creature classification")
            if rarity.state~="unknown" then details[#details+1]="Reference creature classification: "..Value(rarity) end
            local referenceTame=false
            for _,claim in ipairs(tameable.claims) do if claim.status=="reference" then referenceTame=true end end
            if referenceTame then details[5]="Reference tameability: "..Value(tameable).." (not verified in game)" end
            local taming="Not recorded"
            if tameable.state=="conflicting" then taming="Sources disagree"
            elseif tameable.value==true then taming=referenceTame and "Reported tameable" or "Tameable"
            elseif tameable.value==false then taming=referenceTame and "Reported not tameable" or "Not tameable" end
            if #variants>0 then details[#details+1]="Website appearance references; a working preview does not confirm a wild spawn or tameability." end
            if conditions.state~="unknown" then details[#details+1]="Conditions: "..Value(conditions) end
            if location then
                details[7]=string.format("Recorded spawn: UI map %d (%.1f%%, %.1f%%)",location.mapID,location.x*100,location.y*100)
            end
            if area.state~="unknown" or map.state~="unknown" then
                details[#details+1]="Observer context: "..Value(area).." (UI map "..Value(map)..")"
                details[#details+1]="Observer context is not a spawn location."
            end
            local sources={label,"Evidence applies to the stated builds; it is not a current-build guarantee."}
            local summaries,urls={},{}
            for _,item in ipairs(used) do
                sources[#sources+1]="\n"..item.label..":"
                local lines={}
                for _,f in ipairs(item.field.claims) do
                    local e=evidence[f.evidence]
                    local v=f.value
                    if type(v)=="boolean" then v=v and "Yes" or "No" end
                    if type(v)=="table" then v=string.format("UI map %d (%.1f%%, %.1f%%)",v.mapID,v.x*100,v.y*100) end
                    summaries[#summaries+1]=item.label..": "..tostring(v).." — "..f.status.."; "..e.kind..", reviewed "..e.date
                    urls[e.url]=true
                    local line=tostring(v).." — "..f.status.."; "..e.game.."; build "..(e.build or "unknown")
                        .."; locale "..(e.locale or "unknown").."\nReviewed "..e.date.."\n"..e.locator.."\n"..e.url
                    lines[line]=true
                end
                for _,line in ipairs(Sorted(lines)) do sources[#sources+1]=line end
            end
            entries[#entries+1]={key=r.key,label=label,familyKey=familyKey,family=familyName,displayID=displayID,
                skin=displayID and skins[displayID],look=displayID and Look(familyKey,displayID),taming=taming,
                creatureID=creatureID,familyID=familyKey and families[familyKey] and families[familyKey].familyID,
                variants=variants,zoneNames=zoneNames,referenceLevel=referenceLevel,
                appearanceKey=appearance.value,portraitVerified=VerifiedAppearance(appearance,display,verified),
                modelVerified=VerifiedAppearance(appearance,display,modelVerified),
                observedLevel=level.value,levelMin=levelMin,levelMax=levelMax,spawn=location,
                sourceSummary=table.concat(summaries,"\n"),sourceURLs=Sorted(urls),
                search=(label.." "..(name.value or "").." "..familyName):lower(),
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

-- Exact reference IDs may be previewed, but never acquire a verification flag.
-- One creature can occur beneath several skins. Displays merge only when the
-- datamined client tables give them the same skin (model, textures, effects);
-- they then differ only in scale. Geometry or names alone never merge them.
function Guide.Appearances(entries,familyKey)
    local groups,byKey={},{}
    for _,entry in ipairs(entries) do
        if entry.familyKey==familyKey then
            local verified=entry.displayID and (entry.portraitVerified or entry.modelVerified)
            local variants={}
            for _,v in ipairs(entry.variants or {}) do variants[#variants+1]=v end
            if verified then
                local found=false
                for _,v in ipairs(variants) do if v.displayID==entry.displayID then found=true end end
                if not found then variants[#variants+1]={displayID=entry.displayID,skin=entry.skin,look=entry.look} end
            end
            if #variants==0 then variants[1]={} end
            for _,variant in ipairs(variants) do
            local id=variant.displayID
            local key=id and (variant.skin and (familyKey.."/skin/"..variant.skin) or (familyKey.."/display/"..id))
                or ("unresolved/"..entry.key)
            local group=byKey[key]
            if not group then
                group={key=key,familyKey=familyKey,family=entry.family,displayIDs={},members={},
                    entries={},modelVerified=false,portraitVerified=false}
                if not id then group.label=entry.label.." — appearance unresolved" end
                byKey[key]=group; groups[#groups+1]=group
            end
            if id and not group.members[id] then group.members[id]=true; group.displayIDs[#group.displayIDs+1]=id end
            group.referencePreview=group.referencePreview or variant.referencePreview
            group.look=group.look or variant.look
            group.seen=group.seen or (NS.Sightings and NS.Sightings.Seen(entry.familyID,id))
            if id==entry.displayID and (entry.modelVerified or entry.portraitVerified) then
                -- Proof applies to its own display, which then represents the skin.
                group.verifiedID=math.min(group.verifiedID or id,id)
                group.modelVerified=group.modelVerified or entry.modelVerified or false
                group.portraitVerified=group.portraitVerified or entry.portraitVerified or false
            end
            -- A creature with two displays of one skin is listed once.
            local listed=false
            for _,e in ipairs(group.entries) do if e==entry then listed=true end end
            if not listed then group.entries[#group.entries+1]=entry end
            end
        end
    end
    -- Named looks first, then unnamed displays, then creatures without a display.
    local named={}
    for _,group in ipairs(groups) do
        table.sort(group.displayIDs); group.members=nil
        group.displayID=group.verifiedID or group.displayIDs[1]
        if group.look then named[group.look.name]=(named[group.look.name] or 0)+1 end
    end
    for _,group in ipairs(groups) do
        if group.look then
            group.name=group.look.name..(named[group.look.name]>1 and (" · "..group.displayID) or "")
            group.label=group.name
        elseif group.displayID then group.label=group.family.." appearance · "..group.displayID end
        group.rank=group.look and 1 or group.displayID and 2 or 3
        group.search=(group.label.." "..table.concat(group.displayIDs," ")):lower()
    end
    table.sort(groups,function(a,b)
        if a.rank~=b.rank then return a.rank<b.rank end
        if a.rank==2 then return a.displayID<b.displayID end
        return a.label==b.label and a.key<b.key or a.label<b.label
    end)
    return groups
end

-- Reference zones are English website names. They resolve through the client's
-- own map tree, so a renamed or non-English zone simply finds no map.
local mapIndex
function Guide.ZoneMap(entry)
    local maps=rawget(_G,"C_Map")
    if not (entry and maps and type(maps.GetMapInfo)=="function") then return nil end
    local id=entry.spawn and entry.spawn.mapID
    if not id and entry.zoneNames and entry.zoneNames[1] then
        if not mapIndex then
            mapIndex={}
            for _,root in ipairs({946,947}) do
                local ok,children=false,nil
                if type(maps.GetMapChildrenInfo)=="function" then ok,children=pcall(maps.GetMapChildrenInfo,root,nil,true) end
                for _,info in ipairs(ok and type(children)=="table" and children or {}) do
                    local name=type(info)=="table" and info.name
                    -- Prefer a zone (map type 3) over a dungeon or micro-map of the same name.
                    if type(name)=="string" and (not mapIndex[name] or info.mapType==3) then mapIndex[name]=info.mapID end
                end
                if next(mapIndex) then break end
            end
        end
        id=mapIndex[entry.zoneNames[1]]
    end
    if not id then return nil end
    local ok,info=pcall(maps.GetMapInfo,id)
    if not ok or type(info)~="table" or type(info.name)~="string" then return nil end
    local parent
    if info.parentMapID then
        local found,value=pcall(maps.GetMapInfo,info.parentMapID)
        parent=found and type(value)=="table" and value.name or nil
    end
    return id,info.name,parent
end

function Guide.Zone(entry)
    if not entry.spawn then
        if entry.zoneNames and #entry.zoneNames>0 then return table.concat(entry.zoneNames," (reference), ").." (reference)", "reference:"..entry.zoneNames[1] end
        return "Location unknown", "unknown"
    end
    local id=entry.spawn.mapID
    local maps=rawget(_G,"C_Map")
    if maps and type(maps.GetMapInfo)=="function" then
        local ok,info=pcall(maps.GetMapInfo,id)
        if ok and type(info)=="table" and type(info.name)=="string" then return info.name,tostring(id) end
    end
    return "UI map "..id,tostring(id)
end

function Guide.Level(entry)
    if entry.levelMin and entry.levelMax then
        local label=entry.levelMin==entry.levelMax and ("Level "..entry.levelMin) or ("Levels "..entry.levelMin.."–"..entry.levelMax)
        return label..(entry.referenceLevel and " (reference)" or "")
    end
    return entry.observedLevel and ("Observed level "..entry.observedLevel) or "Level unknown"
end

function Guide.AppearanceSummary(entries)
    local levels,zones={},{}
    for _,entry in ipairs(entries) do
        levels[Guide.Level(entry)]=true
        if not entry.spawn and entry.zoneNames and #entry.zoneNames>0 then
            for _,name in ipairs(entry.zoneNames) do zones[name.." (reference)"]=true end
        else zones[Guide.Zone(entry)]=true end
    end
    local levelList,zoneList=Sorted(levels),Sorted(zones)
    -- Do not collapse observations into a range or hide unknown levels/locations.
    local level=#levelList==1 and levelList[1] or "Levels vary"
    local zone=table.concat(zoneList,", ",1,math.min(2,#zoneList))
    if #zoneList>2 then zone=zone.." +"..(#zoneList-2).." zones" end
    return level,zone
end

function Guide.AppearanceFilters(groups)
    local levels,zones={},{}
    for _,group in ipairs(groups) do for _,entry in ipairs(group.entries) do
        local low,high=entry.levelMin or entry.observedLevel,entry.levelMax or entry.observedLevel
        local label=Guide.Level(entry)
        levels[label]=low and {low=low,high=high} or "unknown"
        if not entry.spawn and entry.zoneNames and #entry.zoneNames>0 then
            for _,name in ipairs(entry.zoneNames) do zones["reference:"..name]=name.." (reference)" end
        else local label,key=Guide.Zone(entry); zones[key]=label end
    end end
    local levelChoices,zoneChoices={{label="All levels"}},{{label="All zones"}}
    for _,level in ipairs(Sorted(levels)) do levelChoices[#levelChoices+1]={label=level,value=levels[level]} end
    local keys=Sorted(zones)
    table.sort(keys,function(a,b) return zones[a]==zones[b] and a<b or zones[a]<zones[b] end)
    for _,key in ipairs(keys) do zoneChoices[#zoneChoices+1]={label=zones[key],value=key} end
    return levelChoices,zoneChoices
end

function Guide.FilterAppearances(groups,query,level,zone)
    query=(query or ""):match("^%s*(.-)%s*$"):lower()
    local results={}
    for _,group in ipairs(groups) do
        local matches={}
        for _,entry in ipairs(group.entries) do
            local _,zoneKey=Guide.Zone(entry)
            local zoneMatch=not zone or zoneKey==zone
            for _,name in ipairs(entry.zoneNames or {}) do if zone=="reference:"..name then zoneMatch=true end end
            local low,high=entry.levelMin or entry.observedLevel,entry.levelMax or entry.observedLevel
            local levelMatch=not level or (level=="unknown" and not low)
                or (type(level)=="table" and low and low<=level.high and high>=level.low)
            if levelMatch and zoneMatch
                and (group.search:find(query,1,true) or entry.label:lower():find(query,1,true)) then
                matches[#matches+1]=entry
            end
        end
        if #matches>0 then results[#results+1]={group=group,matches=matches} end
    end
    return results
end
