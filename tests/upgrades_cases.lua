-- Ability Upgrades page: reference list, family filter, details and creature links.
return function(ns)
    local up=ns.upgrades
    ns.SelectPage("upgrades")
    assert(ns.db.page=="upgrades" and up:IsShown() and not ns.guide:IsShown(),"upgrades page replaces the guide")
    assert(#up.visible==33 and up.state.selected==up.visible[1].key,"every listed ability, first selected")
    local function Shown(test)
        local found={}
        for _,f in ipairs(WoW.frames) do if f:IsShown() and test(f) then found[#found+1]=f end end
        return found
    end
    local rows=Shown(function(f) return f.ability~=nil end)
    assert(#rows==33,"one visible row per ability")
    local bite
    for _,row in ipairs(rows) do if row.ability.name=="Bite" then bite=row end end
    bite:GetScript("OnClick")(bite)
    assert(up.state.selected=="ability-bite")
    local teachers=Shown(function(f) return f.teacher~=nil end)
    assert(#teachers>0,"teaching creatures are listed under each rank")
    assert(teachers[1].label:GetText():find(" · ",1,true) and teachers[1].label:GetText():find("(reference)",1,true),
        "creature rows keep the reference qualifier")
    -- The family filter narrows the list and the teachers, and cycles back to all.
    local seen={}
    for _=1,#up.abilities do
        up.CycleFamily()
        if not up.state.familyKey then break end
        seen[up.state.familyKey]=true
        assert(#up.visible>0 and #up.visible<=33)
        for _,f in ipairs(Shown(function(f) return f.teacher~=nil end)) do
            assert(f.teacher.familyKey==up.state.familyKey,"only beasts of the chosen family")
        end
    end
    assert(up.state.familyKey==nil and #up.visible==33 and next(seen),"the filter cycles through families and back")
    -- A creature opens its family in the Pet Guide.
    up.Select("ability-bite")
    local target=Shown(function(f) return f.teacher~=nil end)[1]
    target:GetScript("OnClick")(target)
    assert(ns.db.page=="guide" and ns.guide:IsShown() and not up:IsShown(),"a creature opens the Pet Guide")
    ns.SelectPage("upgrades"); assert(up:IsShown()); ns.SelectPage("guide")
end
