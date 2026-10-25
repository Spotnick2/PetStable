-- My Pets page: honest freshness, the active pet, stabled pets and links into the Pet Guide.
return function(ns)
    local pets,PS=ns.pets,ns.PetState
    local function Shown(test)
        local found={}
        for _,f in ipairs(WoW.frames) do if f:IsShown() and test(f) then found[#found+1]=f end end
        return found
    end
    local function Texts() return pets.Lines() end
    ns.SelectPage("pets")
    assert(ns.db.page=="pets" and pets:IsShown() and not ns.upgrades:IsShown() and not ns.guide:IsShown())
    assert(PS.State()=="unknown" and Texts():find("Nothing observed yet",1,true),"no data is said plainly")
    -- A scan with an active Cat, a stabled Bear and an unreadable stabled pet.
    UnitExists=function(unit) return unit=="pet" end
    UnitName=function(unit) return unit=="pet" and "Whiskers" or "Hunt" end
    UnitLevel=function() return 12 end
    UnitCreatureFamily=function() return "Cat",2 end
    Enum=Enum or {}; Enum.SpellBookSpellBank={Pet=1}
    C_SpellBook={HasPetSpells=function() return 2 end,GetSpellBookItemInfo=function(i)
        return ({{name="Bite",subName="Rank 2",spellID=17255},{name="Attack"}})[i] end}
    C_StableInfo={GetActivePetList=function() return {{petNumber=1,slotID=1,name="Whiskers",level=12,familyName="Cat"}} end,
        GetStabledPetList=function() return {{petNumber=2,slotID=3,name="Grumpy",level=8,familyName="Bear"}} end}
    PS.Refresh("test")
    local text=Texts()
    assert(text:find("Checked this session",1,true) and text:find("Whiskers · Level 12 · Cat",1,true))
    assert(text:find("Bite  ·  Rank 2",1,true) and not text:find("Attack",1,true),"only abilities are listed")
    assert(text:find("Grumpy · Level 8 · Bear  ·  slot 3",1,true))
    assert(not text:find("learned",1,true) or text:find("not tracked yet",1,true),"no learned claims")
    -- A stabled pet opens its family in the Pet Guide.
    local rows=Shown(function(f) return f.pet~=nil and f.GetScript and f:GetScript("OnClick") end)
    assert(#rows==1 and rows[1].pet.familyKey=="family-bear")
    rows[1]:GetScript("OnClick")(rows[1])
    assert(ns.db.page=="guide" and ns.guide:IsShown() and not pets:IsShown())
    -- Dismissing the pet is recorded as a check, not as data loss.
    UnitExists=function() return false end
    PS.Refresh("test"); ns.SelectPage("pets")
    assert(Texts():find("No pet was summoned at the last check",1,true))
    ns.SelectPage("guide")
end
