-- The facts probe records attack speed and pet foods, and survives missing APIs.
return function(ns)
    local saved={}
    for _,name in ipairs({"UnitExists","UnitGUID","UnitName","UnitLevel","UnitCreatureFamily","UnitAttackSpeed","C_PetInfo","C_StableInfo"}) do saved[name]=rawget(_G,name) end
    UnitExists=function() return true end
    UnitGUID=function(unit) return unit=="pet" and "Pet-0-1" or "Creature-0-1-2-3-100-1" end
    UnitName=function(unit) return unit=="pet" and "Whiskers" or "Prowler" end
    UnitLevel=function() return 10 end
    UnitCreatureFamily=function() return "Wolf",1 end
    UnitAttackSpeed=function(unit) return unit=="pet" and 2 or 1.3 end
    C_PetInfo={GetPetFoodTypes=function() return {"Meat"} end}
    C_StableInfo={GetStablePetInfo=function(i) if i==1 then return {familyName="Cat"} end end,
        GetStablePetFoodTypes=function(i) return {"Meat","Fish"} end}
    local db=ns.GetDB()
    local before=db.facts and #db.facts.captures or 0
    local index=ns._test.Facts.Capture("test")
    local capture=db.facts.captures[index]
    assert(#db.facts.captures==before+1 and capture.target.kind=="Creature" and capture.pet.kind=="Pet")
    assert(type(capture.build)=="string" and capture.build:match("^%d+%.%d+%.%d+%.%d+$"),"the full version.build is saved, got "..tostring(capture.build))
    assert(capture.target.attackSpeed[2]==1.3 and capture.pet.attackSpeed[2]==2,"speeds are recorded as the client gives them")
    assert(capture.foods.active[2][1]=="Meat" and capture.foods.stabled[1].family[1]=="Cat")
    -- Missing APIs and no unit are recorded, not errors.
    UnitExists=function() return false end; UnitAttackSpeed=nil; C_PetInfo=nil; C_StableInfo=nil
    local bare=db.facts.captures[ns._test.Facts.Capture("bare")]
    assert(bare.target.absent and bare.pet.absent and #bare.foods.stabled==0)
    for name,value in pairs(saved) do rawset(_G,name,value) end
end
