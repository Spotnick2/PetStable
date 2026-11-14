-- Ability Upgrades page: reference list, family filter, details and creature links.
return function(ns)
    local up=ns.upgrades
    ns.SelectPage("upgrades")
    assert(ns.db.page=="upgrades" and up:IsShown() and not ns.guide:IsShown(),"upgrades page replaces the guide")
    assert(#up.visible==31 and up.state.selected==up.visible[1].key,"every listed ability, first selected")
    local function Shown(test)
        local found={}
        for _,f in ipairs(WoW.frames) do if f:IsShown() and test(f) then found[#found+1]=f end end
        return found
    end
    local rows=Shown(function(f) return f.ability~=nil end)
    assert(#rows==31,"one visible row per ability")
    local bite
    for _,row in ipairs(rows) do if row.ability.name=="Bite" then bite=row end end
    bite:GetScript("OnClick")(bite)
    assert(up.state.selected=="ability-bite")
    for _,row in ipairs(rows) do
        assert(row.icon:IsShown() and type(row.icon._file)=="number" and row.icon._file==row.ability.icon,"each row shows its ability's icon")
    end
    assert(bite.icon._file==132278 and up.titleIcon:IsShown() and up.titleIcon._file==132278,"the selected ability's icon beside its name")
    local teachers=Shown(function(f) return f.teacher~=nil end)
    assert(#teachers>0,"teaching creatures are listed under each rank")
    assert(teachers[1].label:GetText():find(" · ",1,true) and teachers[1].label:GetText():find("(reference)",1,true),
        "creature rows keep the reference qualifier")
    -- A long family list wraps at the minimum width; ranks start below it.
    local wide=up.firstRankY
    up.Layout(800-48,560-180); up.Select("ability-bite")
    assert(up.summary:GetStringHeight()>16*2 and up.firstRankY>=34+up.summary:GetStringHeight(),
        "the first rank starts below the wrapped family summary")
    assert(up.firstRankY>=wide,"a narrower column never packs the summary tighter")
    up.Layout(1040-48,700-180); up.Select("ability-bite")
    -- The family filter narrows the list and the teachers, and cycles back to all.
    local seen={}
    for _=1,#up.abilities do
        up.CycleFamily()
        if not up.state.familyKey then break end
        seen[up.state.familyKey]=true
        assert(#up.visible>0 and #up.visible<=31)
        for _,f in ipairs(Shown(function(f) return f.teacher~=nil end)) do
            assert(f.teacher.familyKey==up.state.familyKey,"only beasts of the chosen family")
        end
    end
    assert(up.state.familyKey==nil and #up.visible==31 and next(seen),"the filter cycles through families and back")
    -- A creature opens its family in the Pet Guide.
    up.Select("ability-bite")
    local target=Shown(function(f) return f.teacher~=nil end)[1]
    target:GetScript("OnClick")(target)
    assert(ns.db.page=="guide" and ns.guide:IsShown() and not up:IsShown(),"a creature opens the Pet Guide")
    ns.SelectPage("upgrades"); assert(up:IsShown())
    -- Markers for the active pet (#10). PetState is replaced by a read-this-session wolf that knows Bite 2.
    local PS=ns.PetState
    local active,state=PS.Active,PS.State
    local pet={present=true,abilitiesRead=true,level=20,name="Fang",family="Wolf",familyKey="family-wolf",locale="enUS",
        abilities={{spellID=17255,name="Bite",rank=2}}}
    PS.Active=function() return pet end; PS.State=function() return "fresh" end
    up.Refresh(); up.Select("ability-bite")
    assert(up.note:GetText():find("Fang",1,true) and up.note:GetText():find("level 20 Wolf",1,true),"the note names the pet")
    local byName={}
    for _,row in ipairs(Shown(function(f) return f.ability~=nil end)) do byName[row.ability.name]=row end
    assert(byName.Bite.count:GetText()=="2/8 · Can learn" and byName.Bite.mine.ready,"learned rank and a rank its level allows")
    assert(byName.Growl.count:GetText()=="Can learn","not learned, level 1 rank")
    assert(byName["Scorpid Poison"].count:GetText()=="4 ranks","another family's ability keeps its plain count")
    local statuses={}
    for _,h in ipairs(up.headings) do if h:IsShown() and h.rank then statuses[h.rank.ordinal]=h.status end end
    assert(statuses[1]=="learned" and statuses[2]=="learned" and statuses[3]=="ready" and statuses[4]=="level","rank markers")
    local third
    for _,h in ipairs(up.headings) do if h:IsShown() and h.rank and h.rank.ordinal==3 then third=h end end
    assert(third:GetText():find("Can learn now",1,true) and third:GetText():find("|cff",1,true),"the marker ends the rank's line, coloured")
    -- Nothing is marked when the pet is unknown: no pet, an unread spellbook, or another session's data.
    for _,case in ipairs({{nil,"fresh","Summon a pet"},{{present=true,abilitiesRead=false},"fresh","could not be read"},
        {pet,"stale","not been read this session"}}) do
        PS.Active=function() return case[1] end; PS.State=function() return case[2] end
        up.Refresh(); up.Select("ability-bite")
        assert(up.note:GetText():find(case[3],1,true),case[3])
        for _,h in ipairs(up.headings) do if h:IsShown() then assert(h.status==nil,"no marker when the pet is unknown") end end
        for _,row in ipairs(Shown(function(f) return f.ability~=nil end)) do assert(row.mine==nil) end
    end
    PS.Active,PS.State=active,state; up.Refresh()
    ns.SelectPage("guide")
end
