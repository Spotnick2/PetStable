local _, NS = ...
local Catalog = {}
NS.Catalog = Catalog

-- Keys are catalog identities, never inferred from names, pet GUIDs or slots.
-- Each field is a claim; references retain the evidence of the relationship.
local fields = {
    creature = { creatureID="id", name="text", family="ref:family", appearance="many:appearance",
        observedLevel="id", levelMin="id", levelMax="id", tameable="boolean",
        observerArea="text", observerMapID="id", spawn="position", conditions="text" },
    appearance = { displayID="id", modelFileID="id", portraitVerified="boolean", modelVerified="boolean" },
    family = { familyID="id", name="text", iconFileID="id" },
    ability = { name="text" },
    rank = { ability="ref:ability", spellID="id", ordinal="id", label="text",
        petLevel="id", trainingPoints="nonnegative", eligibleFamily="many:family",
        allFamilies="boolean", previous="ref:rank", source="many:source" },
    source = { sourceType="sourceType", creature="ref:creature", conditions="text",
        serviceName="text", serviceRank="text", requiredLevel="id", rawCost="nonnegative",
        prerequisiteText="text", prerequisiteSatisfied="boolean", availability="text" },
}
local function Text(v) return type(v)=="string" and v:match("%S") ~= nil end
local function Number(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function ID(v) return Number(v) and v>0 and v==math.floor(v) end
local function Equal(a,b)
    if type(a)~="table" or type(b)~="table" then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Array(t)
    if type(t)~="table" then return false end
    local count=0
    for k in pairs(t) do if not ID(k) then return false end; count=count+1 end
    return count==#t
end
local function Only(t, allowed)
    for key in pairs(t) do if not allowed[key] then return false end end
    return true
end

function Catalog.GetRecord(data, key)
    for _,record in ipairs(data.records) do if record.key==key then return record end end
end

-- An empty list means unknown. False is a real value; no claim is auto-selected.
-- Callers must inspect game/build/status and preserve competing claims.
function Catalog.GetFacts(data, key, field)
    local found={}
    for _,fact in ipairs(data.facts) do
        if fact.subject==key and fact.field==field then found[#found+1]=fact end
    end
    return found
end

function Catalog.Validate(data)
    local errors, conflicts = {}, {}
    local function Error(message) errors[#errors+1]=message end
    if type(data)~="table" or data.version~=1 then
        return {"unsupported catalog version"}, conflicts
    end
    for _,key in ipairs({"records","evidence","facts"}) do
        if not Array(data[key]) then Error(key.." must be a dense array") end
    end
    if #errors>0 then return errors,conflicts end
    local records, evidence = {}, {}
    for i,r in ipairs(data.records) do
        if type(r)~="table" or not Text(r.key) or not fields[r.kind]
            or not Only(r,{key=true,kind=true,game=true})
            or (r.game~="forever" and r.game~="classic") then
            Error("invalid record "..i)
        elseif records[r.key] then Error("duplicate record "..r.key)
        else records[r.key]=r end
    end
    for i,e in ipairs(data.evidence) do
        if type(e)~="table" or not Text(e.key) or not Text(e.url) or not e.url:match("^https://")
            or not Text(e.locator) or not Text(e.date) or not e.date:match("^%d%d%d%d%-%d%d%-%d%d$")
            or (e.game~="forever" and e.game~="classic")
            or (e.kind~="observation" and e.kind~="reference")
            or (e.build~=nil and not Text(e.build)) or (e.locale~=nil and not Text(e.locale))
            or (e.kind=="observation" and (not Text(e.build) or not Text(e.locale))) then
            Error("invalid evidence "..i)
        elseif evidence[e.key] then Error("duplicate evidence "..e.key)
        else evidence[e.key]=e end
    end
    local seen, identities = {}, {}
    for i,f in ipairs(data.facts) do
        local prefix="fact "..i..": "
        if type(f)~="table" then Error(prefix.."expected claim")
        else
            if not Only(f,{subject=true,field=true,value=true,evidence=true,status=true}) then
                Error(prefix.."unexpected claim metadata")
            end
            local r,e=records[f.subject],evidence[f.evidence]
            local spec=r and fields[r.kind][f.field]
            if not r then Error(prefix.."missing subject") end
            if not e then Error(prefix.."missing evidence") end
            if not spec then Error(prefix.."unknown field") end
            if f.status~="observed" and f.status~="reference" and f.status~="confirmed" then
                Error(prefix.."invalid status")
            end
            if r and e then
                if r.game~=e.game then Error(prefix.."cross-game evidence") end
                if (e.kind=="reference") ~= (f.status=="reference") then Error(prefix.."evidence/status mismatch") end
            end
            if spec then
                local v,valid=f.value,false
                local target=spec:match("^ref:(.+)$") or spec:match("^many:(.+)$")
                if target then
                    local linked=records[v]
                    valid=linked and linked.kind==target and linked.game==r.game
                elseif spec=="id" then valid=ID(v)
                elseif spec=="text" then valid=Text(v)
                elseif spec=="boolean" then valid=type(v)=="boolean"
                elseif spec=="nonnegative" then valid=Number(v) and v>=0
                elseif spec=="sourceType" then valid=v=="trainer" or v=="tame" or v=="trainer-observation"
                elseif spec=="position" then
                    valid=type(v)=="table" and v.kind=="spawn" and v.space=="ui-map"
                        and ID(v.mapID) and Number(v.x) and Number(v.y)
                        and v.x>=0 and v.x<=1 and v.y>=0 and v.y<=1
                    if valid then
                        for k in pairs(v) do
                            if k~="kind" and k~="space" and k~="mapID" and k~="x" and k~="y" then valid=false end
                        end
                    end
                end
                if not valid then Error(prefix.."invalid "..f.field) end
                if valid and e then
                    -- Build-scoped contradictions are reported separately, never overwritten.
                    local scope=r.key..":"..f.field..":"..(e.build or "unknown")..":"..(e.locale or "unknown")
                    if not spec:match("^many:") then
                        for _,prior in ipairs(seen[scope] or {}) do
                            if not Equal(prior.value,v) then conflicts[#conflicts+1]={first=prior,second=f} end
                        end
                        seen[scope]=seen[scope] or {}; table.insert(seen[scope],f)
                    end
                    if f.field=="creatureID" or f.field=="displayID" or f.field=="spellID" or f.field=="familyID" then
                        local identity=r.game..":"..f.field..":"..v
                        if identities[identity] and identities[identity]~=r.key then Error(prefix.."duplicate identity") end
                        identities[identity]=r.key
                    end
                end
            end
        end
    end
    -- Corroborating claims are unambiguous within their evidence scope.
    -- Keep all original claims, including conflicts, available to reviewers.
    if #errors==0 then
        local function Agreed(key,field,context)
            local first
            for _,fact in ipairs(Catalog.GetFacts(data,key,field)) do
                local e=evidence[fact.evidence]
                if e.game==context.game and e.build==context.build and e.locale==context.locale then
                    if first and not Equal(first.value,fact.value) then return nil end
                    first=first or fact
                end
            end
            if first then return first.value end
        end
        for key,r in pairs(records) do
            if r.kind=="creature" or r.kind=="appearance" then
                local field=r.kind=="creature" and "creatureID" or "displayID"
                if #Catalog.GetFacts(data,key,field)==0 then Error(key..": missing "..field) end
            end
            if r.kind=="creature" then
                for _,fact in ipairs(Catalog.GetFacts(data,key,"levelMin")) do
                    local context=evidence[fact.evidence]
                    local low,high=Agreed(key,"levelMin",context),Agreed(key,"levelMax",context)
                    if low and high and low>high then Error(key..": inverted level range") end
                end
            elseif r.kind=="rank" then
                for _,link in ipairs(Catalog.GetFacts(data,key,"previous")) do
                    local prior=link.value
                    local context=evidence[link.evidence]
                    local ability,priorAbility=Agreed(key,"ability",context),Agreed(prior,"ability",context)
                    local rank,priorRank=Agreed(key,"ordinal",context),Agreed(prior,"ordinal",context)
                    if ability and priorAbility and ability~=priorAbility then Error(key..": previous ability mismatch") end
                    if rank and priorRank and priorRank>=rank then Error(key..": invalid rank progression") end
                end
                for _,link in ipairs(Catalog.GetFacts(data,key,"source")) do
                    if Agreed(link.value,"sourceType",evidence[link.evidence])=="trainer-observation" then
                        Error(key..": unmapped trainer observation cannot be an acquisition source")
                    end
                end
            end
        end
        local visiting,done={},{}
        local function Visit(key)
            if visiting[key] then Error(key..": cyclic rank progression"); return end
            if done[key] then return end
            visiting[key]=true
            for _,f in ipairs(Catalog.GetFacts(data,key,"previous")) do Visit(f.value) end
            visiting[key]=nil; done[key]=true
        end
        for key,r in pairs(records) do if r.kind=="rank" then Visit(key) end end
    end
    return errors,conflicts
end
