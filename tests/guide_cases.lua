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
    assert(guide.view=="families" and guide.index:IsShown() and not guide.browser:IsShown())
    assert(#guide.cards==19 and #guide.familyResults==19)
    assert(guide.columns==5 and guide.gallery:GetVerticalScrollRange()==0,"default gallery must show all 19 families")
    assert(guide.footer:GetText()=="19 families" and not guide.navigation:IsShown())
    assert(guide.placeholder:GetText()=="Search families..." and guide.placeholder:IsShown())
    guide.search:SetFocus(); assert(guide.placeholder:IsShown(),"empty focused search still has an accurate hint")
    guide.ClearFocus()
    local hovered=guide.cards[1]
    assert(not hovered.count and hovered.icon:GetWidth()==64,"cards use larger portraits without repeated counts")
    hovered:GetScript("OnEnter")(hovered); hovered:GetScript("OnUpdate")(hovered,1)
    assert(hovered.hoverAmount==1 and hovered.arrow:IsShown() and not hovered.active)
    hovered:GetScript("OnLeave")(hovered); hovered:GetScript("OnUpdate")(hovered,1)
    assert(hovered.hoverAmount==0 and not hovered.arrow:IsShown() and not hovered:GetScript("OnUpdate"))
    local originalW,originalH=window:GetWidth(),window:GetHeight()
    window:SetSize(800,560)
    assert(guide.columns<5 and guide.gallery:GetVerticalScrollRange()>0 and guide.galleryBar:IsShown())
    guide.galleryBar:SetValue(guide.gallery:GetVerticalScrollRange())
    local last=guide.cards[19]; local _,_,lastY=unpack(last._points[1])
    assert(-lastY+last:GetHeight()-guide.gallery:GetVerticalScroll()<=guide.gallery:GetHeight(),"bottom row is reachable at minimum size")
    window:SetSize(originalW,originalH)
    assert(guide.columns==5 and guide.gallery:GetVerticalScroll()==0 and not guide.galleryBar:IsShown())
    local familyWidgets=#WoW.widgets
    for _,family in ipairs(guide.families) do
        local card
        for _,candidate in ipairs(guide.cards) do if candidate.family==family then card=candidate end end
        assert(card and card.icon._file==family.iconFileID and not card.placeholder:IsShown())
        Click(card)
        assert(guide.appearances.back:IsShown() and guide.appearances.breadcrumb:GetText():find(family.displayLabel,1,true))
        assert(card.hoverAmount==0 and not card.arrow:IsShown(),"leaving a card must clear hover")
        assert(guide.view=="appearances" and guide.familyKey==family.key and #guide.appearances.results==family.count)
        if family.count==0 then
            assert(guide.appearances.empty:GetText()=="No creatures recorded in PetStable yet.")
            for _,card in ipairs(guide.appearances.cards) do assert(not card:IsShown()) end
        end
        guide.appearances.search:SetText("no match"); Click(guide.appearances.clear)
        assert(guide.familyKey==family.key and #guide.appearances.results==family.count,"Clear must retain the family")
        Click(guide.appearances.back)
    end
    assert(#WoW.widgets==familyWidgets,"family navigation must reuse cards and browser widgets")
    guide.search:SetText("FOXES")
    assert(#guide.familyResults==1 and guide.cards[1].family.key=="family-fox")
    for i=2,#guide.cards do assert(not guide.cards[i]:IsShown()) end
    Click(guide.sources)
    assert(guide.view=="sources" and not guide.search:IsShown() and not guide.evidence:IsShown())
    assert(guide.detail:GetText():find("https://beastmaster.io/forever",1,true))
    assert(guide.detail:GetText():find("https://www.wow-petopia.com/forever/",1,true))
    guide.scrollbar:SetValue(100)
    assert(guide.scroll:GetVerticalScroll()==100)
    Click(guide.navigation)
    assert(guide.search:GetText()=="FOXES" and #guide.familyResults==1,"Back must restore family search")
    local iconID=guide.cards[1].family.iconFileID
    guide.cards[1].family.iconFileID=nil; guide.Refresh(false)
    assert(guide.cards[1].icon._file==nil and guide.cards[1].placeholder:IsShown())
    guide.cards[1].family.iconFileID=iconID
    local setTexture=guide.cards[1].icon.SetTexture
    guide.cards[1].icon.SetTexture=function(self,file) if file then return false end; return setTexture(self,file) end
    guide.Refresh(false); assert(guide.cards[1].placeholder:IsShown())
    guide.cards[1].icon.SetTexture=setTexture
    guide.search:SetText("%")
    assert(#guide.familyResults==0 and guide.indexEmpty:IsShown())
    Click(guide.clear)
    Click(guide.allTab)
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
    guide.OpenFamily("family-bear")
    assert(#guide.appearances.results==1)
    guide.OpenFamily("family-cat"); guide.appearances.search:SetText("bear")
    assert(#guide.appearances.results==0)
    Click(guide.appearances.clear)
    assert(#guide.appearances.results==1 and guide.familyKey=="family-cat")
    guide.OpenFamily(nil)
    assert(guide.search:GetText()=="bear","returning to All Creatures restores its search")
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
    local bar=guide.scrollbar
    local minimum,maximum=bar:GetMinMaxValues()
    assert(minimum==0 and maximum==guide.scroll:GetVerticalScrollRange() and maximum>0)
    assert(bar:IsEnabled() and bar:GetThumbTexture():IsShown())
    guide.search:SetFocus()
    bar:SetValue(maximum/2) -- native Slider dragging reports value changes
    assert(guide.scroll:GetVerticalScroll()==maximum/2 and not guide.HasFocus())
    bar:SetValue(maximum+100)
    assert(guide.scroll:GetVerticalScroll()==maximum,"thumb must stop at the end of the evidence")
    Click(guide.scrollUp)
    assert(bar:GetValue()==guide.scroll:GetVerticalScroll() and bar:GetValue()<maximum)
    Click(guide.scrollDown)
    assert(bar:GetValue()==maximum)
    bar:SetValue(0)
    guide.scroll:GetScript("OnMouseWheel")(guide.scroll,-10)
    assert(guide.scroll:GetVerticalScroll()>0 and bar:GetValue()==guide.scroll:GetVerticalScroll())
    Choose("creature-251707")
    assert(guide.scroll:GetVerticalScroll()==0 and bar:GetValue()==0 and not guide.showEvidence)

    local original=guide.entries
    guide.entries={}
    for i=1,20 do
        guide.entries[i]={key="fixture-"..i,label="Fixture "..i,family="Cat",familyKey="family-cat",
            search="fixture "..i,displayID=i%2==0 and 1059 or nil,details="Fixture "..i,evidence="Test only"}
    end
    local widgets=#WoW.widgets
    guide.selected=nil; guide.Refresh(true)
    assert(not bar:IsEnabled() and not bar:GetThumbTexture():IsShown(),"short details have no draggable thumb")
    assert(bar:GetValue()==0 and select(2,bar:GetMinMaxValues())==0,"short content must clear the old range")
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
