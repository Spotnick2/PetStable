return function(ns)
    ns.SelectPage("guide")
    local guide,window=ns.guide,ns.frame
    local function Click(button) button:GetScript("OnClick")(button) end
    local function Choose(key)
        for _,row in ipairs(guide.rows) do
            if row.entry and row.entry.key==key then Click(row); return row end
        end
        error("result not visible: "..key)
    end
    local function Portrait(texture,id)
        assert(texture._file==nil,"clear the reused portrait before requesting an exact display")
        texture:SetTexture("display-"..id)
    end
    rawset(_G,"SetPortraitTextureFromCreatureDisplayID",Portrait)
    Click(guide.clear)
    assert(#guide.results==3 and guide:IsShown())
    local cat=Choose("creature-3035")
    assert(cat.portrait._file=="display-1059" and not cat.placeholder:IsShown())
    assert(guide.detail:GetText():find("Appearance verified on build",1,true))
    Choose("creature-251707")
    assert(guide.detail:GetText():find("Tameability: Unknown",1,true))
    guide.search:SetText("galestrider")
    assert(#guide.results==1 and guide.selected.key=="creature-251707")
    assert(guide.rows[1].portrait._file==nil and guide.rows[1].placeholder:IsShown())
    for i=2,#guide.rows do assert(not guide.rows[i]:IsShown() and guide.rows[i].portrait._file==nil) end
    guide.search:SetText("not present")
    assert(#guide.results==0 and not guide.selected and guide.empty:IsShown())
    assert(not guide.detail:GetText():find("Galestrider",1,true),"no stale details for no results")
    Click(guide.clear)
    for _,mode in ipairs({"missing","error"}) do
        rawset(_G,"SetPortraitTextureFromCreatureDisplayID",mode=="error" and function() error("unavailable") end or nil)
        guide.Refresh(false)
        for _,row in ipairs(guide.rows) do
            assert(row.portrait._file==nil and row.placeholder:IsShown())
        end
    end
    rawset(_G,"SetPortraitTextureFromCreatureDisplayID",Portrait)
    guide.Refresh(false)
    Choose("creature-3035")
    guide.search:SetText("cat")
    assert(guide.selected.key=="creature-3035")
    guide.search:SetText("bear")
    assert(guide.selected.key=="creature-251115","filter must choose first remaining result")
    Click(guide.family) -- first sorted family: Bear
    assert(#guide.results==1)
    Click(guide.family) -- Cat with search Bear
    assert(#guide.results==0)
    Click(guide.clear)

    guide.search:SetFocus()
    assert(guide.HasFocus() and window.propagate==false and guide.search.propagate==false)
    window:GetScript("OnKeyDown")(window,"W")
    assert(window.propagate==false,"typing must not reach gameplay bindings")
    guide.search:GetScript("OnEnterPressed")(guide.search)
    assert(not guide.HasFocus())
    window:GetScript("OnKeyDown")(window,"W")
    assert(window.propagate==true)
    guide.search:SetFocus(); guide.search:GetScript("OnEscapePressed")(guide.search)
    assert(not window:IsShown() and not guide.HasFocus() and window.propagate==false)
    ns.Toggle(); guide.search:SetFocus()
    window:GetScript("OnKeyDown")(window,"ESCAPE")
    assert(not window:IsShown() and not guide.HasFocus() and window.propagate==false)
    ns.Toggle(); guide.search:SetFocus(); ns.SelectPage("pets")
    assert(not guide.HasFocus() and not guide:IsShown())
    ns.SelectPage("guide")
    Click(guide.evidence)
    assert(guide.detail:GetText():find("https://github.com/",1,true))
    guide.scroll:GetScript("OnMouseWheel")(guide.scroll,-10)
    assert(guide.scroll:GetVerticalScroll()>0)
    Choose("creature-251707")
    assert(guide.scroll:GetVerticalScroll()==0 and not guide.showEvidence)

    local original=guide.entries
    guide.entries={}
    for i=1,20 do
        guide.entries[i]={key="fixture-"..i,label="Fixture "..i,family="Cat",familyKey="family-cat",
            search="fixture "..i,displayID=i%2==0 and 1059 or nil,details="Fixture "..i,evidence="Test only"}
    end
    local widgets=#WoW.widgets
    guide.selected=nil; guide.Refresh(true)
    Click(guide.next)
    assert(guide.rows[1].entry.key=="fixture-5" and guide.offset==4)
    guide.rows[1]:GetScript("OnMouseWheel")(guide.rows[1],-1)
    assert(guide.rows[1].entry.key=="fixture-6")
    guide.ScrollRows(100)
    assert(guide.offset==16 and guide.rows[4].entry.key=="fixture-20")
    Click(guide.previous); assert(guide.offset==12)
    assert(#WoW.widgets==widgets,"scrolling and filtering must reuse the row pool")
    guide.entries={}; guide.Refresh(true)
    assert(guide.empty:GetText():find("No creatures",1,true) and not guide.selected)
    guide.entries=original; Click(guide.clear)
    guide.search:SetFocus(); window:Hide()
    assert(not guide.HasFocus()); ns.Toggle()
end
