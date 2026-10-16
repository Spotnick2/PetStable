local _, NS = ...
local ROWS, ROW_HEIGHT = 4, 51
local function Plain(text) return (text or ""):gsub("|","||") end

function NS.CreateGuide(parent, window, Text)
    local panel=CreateFrame("Frame",nil,parent)
    panel:SetPoint("TOPLEFT",232,-150); panel:SetSize(600,300)
    panel.entries,panel.families,panel.problem,panel.familySources=NS.GuideData.Build(NS.CatalogData)
    panel.rows={}; panel.offset=0; panel.showEvidence=false; panel.view="families"; panel.familyQuery=""
    local browser=CreateFrame("Frame",nil,panel); browser:SetAllPoints(panel)
    local index=CreateFrame("Frame",nil,panel); index:SetAllPoints(panel)
    panel.browser=browser; panel.index=index; panel.cards={}
    local function Button(host,label,x,y,width,click)
        local b=CreateFrame("Button",nil,host,"BackdropTemplate")
        b:SetPoint("TOPLEFT",x,-y); b:SetSize(width,26)
        b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        b:SetBackdropColor(0.08,0.11,0.13,0.95); b:SetBackdropBorderColor(0.3,0.39,0.34,1)
        b.label=Text(b,12); b.label:SetPoint("CENTER"); b.label:SetWidth(width-8); b.label:SetJustifyH("CENTER")
        b.label:SetText(label); b:SetScript("OnClick",click)
        return b
    end
    panel.search=CreateFrame("EditBox",nil,panel,"BackdropTemplate")
    local search=panel.search
    search:SetPoint("TOPLEFT"); search:SetSize(342,28)
    search:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    search:SetBackdropColor(0.03,0.045,0.055,1); search:SetBackdropBorderColor(0.35,0.45,0.38,1)
    search:SetFont("Fonts\\FRIZQT__.TTF",14,""); search:SetTextColor(0.95,0.97,0.95,1)
    search:SetTextInsets(8,8,0,0); search:SetAutoFocus(false); search:SetMultiLine(false); search:SetMaxLetters(120)
    search:SetPropagateKeyboardInput(false)
    local placeholder=Text(search,13,{0.65,0.72,0.75,1})
    placeholder:SetPoint("LEFT",8,0); placeholder:SetText("Search names or families")
    function panel.ClearFocus() search:ClearFocus() end
    function panel.HasFocus() return search:HasFocus()==true end
    local function Focus()
        placeholder:SetShown(search:GetText()=="" and not panel.HasFocus())
        window:SetPropagateKeyboardInput(not panel.HasFocus())
    end
    search:SetScript("OnEditFocusGained",Focus); search:SetScript("OnEditFocusLost",Focus)
    search:SetScript("OnEnterPressed",panel.ClearFocus)
    search:SetScript("OnEscapePressed",function()
        panel.ClearFocus(); window:Hide(); window:SetPropagateKeyboardInput(false)
    end)
    panel.clear=Button(panel,"Clear",350,0,68,function()
        panel.ClearFocus(); search:SetText(""); panel.Refresh(true)
    end)
    function panel.ShowFamilies()
        panel.ClearFocus(); panel.view="families"; panel.familyKey=nil; panel.selected=nil; panel.showEvidence=false
        search:SetText(panel.familyQuery); panel.Refresh(true)
    end
    function panel.OpenFamily(key)
        panel.ClearFocus(); panel.view="creatures"; panel.familyKey=key; panel.selected=nil; panel.showEvidence=false
        search:SetText(""); panel.Refresh(true)
    end
    panel.navigation=Button(panel,"Browse all creatures",426,0,174,function()
        if panel.view=="families" then panel.OpenFamily(nil) else panel.ShowFamilies() end
    end)
    panel.sources=Button(index,"Family sources",0,36,140,function()
        panel.ClearFocus(); panel.view="sources"; panel.Refresh(true)
    end)
    local coverage=Text(index,11,{0.65,0.72,0.75,1}); coverage:SetPoint("TOPLEFT",150,-43); coverage:SetWidth(450)
    coverage:SetText("Counts are creatures recorded in PetStable.")
    local indexEmpty=Text(index,14); indexEmpty:SetPoint("TOPLEFT",0,-90); indexEmpty:SetWidth(580)
    panel.indexEmpty=indexEmpty
    for i=1,#panel.families do
        local card=Button(index,"",((i-1)%4)*152,70+math.floor((i-1)/4)*45,144,function(self)
            if self.family then panel.OpenFamily(self.family.key) end
        end)
        card:SetHeight(40); card.label:ClearAllPoints(); card.label:SetPoint("TOPLEFT",42,-5)
        card.label:SetWidth(98); card.label:SetJustifyH("LEFT")
        card.icon=card:CreateTexture(nil,"ARTWORK"); card.icon:SetPoint("LEFT",4,0); card.icon:SetSize(32,32)
        card.placeholder=Text(card,18,{0.65,0.72,0.75,1}); card.placeholder:SetPoint("LEFT",14,0); card.placeholder:SetText("?")
        card.count=Text(card,10,{0.65,0.72,0.75,1}); card.count:SetPoint("TOPLEFT",42,-23); card.count:SetWidth(98)
        panel.cards[i]=card
    end
    local familyHeading=Text(browser,12,{0.65,0.72,0.75,1}); familyHeading:SetPoint("TOPLEFT",0,-34); familyHeading:SetWidth(228)
    local empty=Text(browser,14); empty:SetPoint("TOPLEFT",4,-62); empty:SetSize(222,160); empty:SetJustifyV("TOP")
    panel.empty=empty
    local count=Text(browser,12); count:SetPoint("TOPLEFT",54,-266); count:SetWidth(120); count:SetJustifyH("CENTER")
    panel.count=count
    local detailLabel=Text(browser,14,{0.78,0.94,0.65,1})
    detailLabel:SetPoint("TOPLEFT",244,-42); detailLabel:SetText("Details")
    local scroll=CreateFrame("ScrollFrame",nil,browser)
    scroll:SetPoint("TOPLEFT",244,-74); scroll:SetSize(330,216); scroll:EnableMouseWheel(true)
    local child=CreateFrame("Frame",nil,scroll); child:SetSize(328,216)
    local detail=Text(child,13); detail:SetPoint("TOPLEFT"); detail:SetWidth(326)
    detail:SetWordWrap(true); detail:SetNonSpaceWrap(true); detail:SetJustifyV("TOP"); detail:SetSpacing(2)
    scroll:SetScrollChild(child)
    panel.detail=detail; panel.scroll=scroll
    local bar=CreateFrame("Slider",nil,browser,"BackdropTemplate")
    bar:SetPoint("TOPLEFT",580,-104); bar:SetSize(20,156)
    bar:SetOrientation("VERTICAL"); bar:SetMinMaxValues(0,0); bar:SetValueStep(1); bar:SetObeyStepOnDrag(false)
    bar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    bar:SetBackdropColor(0.03,0.045,0.055,1); bar:SetBackdropBorderColor(0.3,0.39,0.34,1)
    bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb=bar:GetThumbTexture(); thumb:SetVertexColor(0.6,0.75,0.55,1)
    panel.scrollbar=bar
    local syncing=false
    local function SyncScrollbar()
        if syncing then return end
        syncing=true
        local range=math.max(0,scroll:GetVerticalScrollRange())
        local value=math.max(0,math.min(range,scroll:GetVerticalScroll()))
        bar:SetMinMaxValues(0,range); bar:SetValue(value); bar:SetEnabled(range>0)
        thumb:SetSize(16,math.max(20,bar:GetHeight()*scroll:GetHeight()/(scroll:GetHeight()+range)))
        thumb:SetShown(range>0)
        if scroll:GetVerticalScroll()~=value then scroll:SetVerticalScroll(value) end
        syncing=false
    end
    bar:SetScript("OnValueChanged",function(_,value)
        if syncing then return end
        panel.ClearFocus()
        scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),value)))
    end)
    scroll:SetScript("OnVerticalScroll",SyncScrollbar)
    scroll:SetScript("OnScrollRangeChanged",SyncScrollbar)
    local function ScrollDetails(delta)
        panel.ClearFocus()
        scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()+delta)))
    end
    scroll:SetScript("OnMouseWheel",function(_,delta) ScrollDetails(-delta*36) end)
    bar:EnableMouseWheel(true); bar:SetScript("OnMouseWheel",function(_,delta) ScrollDetails(-delta*36) end)
    panel.scrollUp=Button(browser,"^",580,74,20,function() ScrollDetails(-72) end)
    panel.scrollDown=Button(browser,"v",580,264,20,function() ScrollDetails(72) end)
    local function Details()
        local entry=panel.selected
        local sources=panel.view=="sources"
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT",sources and 0 or 244,-74)
        scroll:SetWidth(sources and 574 or 330); child:SetWidth(sources and 572 or 328); detail:SetWidth(sources and 570 or 326)
        detailLabel:ClearAllPoints(); detailLabel:SetPoint("TOPLEFT",sources and 0 or 244,-42)
        detail:SetText(Plain(sources and (panel.familySources or panel.problem or "No family sources recorded.")
            or (entry and (panel.showEvidence and entry.evidence or entry.details) or "Select a creature to see its recorded details.")))
        child:SetHeight(math.max(216,detail:GetStringHeight()+4))
        scroll:SetVerticalScroll(0)
        SyncScrollbar()
        panel.evidence.label:SetText(panel.showEvidence and "Show details" or "Show evidence")
        detailLabel:SetText(sources and "Family sources" or (panel.showEvidence and "Evidence" or "Details"))
    end
    panel.evidence=Button(browser,"Show evidence",474,38,126,function()
        panel.ClearFocus(); panel.showEvidence=not panel.showEvidence; Details()
    end)
    local function Portrait(row,entry)
        row.portrait:SetTexture(nil); row.portrait:Hide(); row.placeholder:Show()
        local fn=rawget(_G,"SetPortraitTextureFromCreatureDisplayID")
        if entry and entry.displayID and type(fn)=="function" then
            local ok=pcall(fn,row.portrait,entry.displayID)
            if ok then row.portrait:Show(); row.placeholder:Hide()
            else row.portrait:SetTexture(nil) end
        end
    end
    local function PaintRows()
        for i,row in ipairs(panel.rows) do
            local entry=panel.results[panel.offset+i]
            row.entry=entry; Portrait(row,entry); row:SetShown(entry~=nil)
            if entry then
                row.label:SetText(Plain(entry.label.."\n"..entry.family))
                row.marker:SetShown(panel.selected and entry.key==panel.selected.key)
            end
        end
        local total=#panel.results
        count:SetText(total==0 and "0 results" or ((panel.offset+1).."–"..math.min(total,panel.offset+ROWS).." / "..total))
    end
    function panel.ScrollRows(delta)
        panel.ClearFocus(); panel.offset=math.max(0,math.min(math.max(0,#panel.results-ROWS),panel.offset+delta)); PaintRows()
    end
    for i=1,ROWS do
        local row=Button(browser,"",0,48+(i-1)*ROW_HEIGHT,228,function(self)
            if not self.entry then return end
            panel.ClearFocus(); panel.selected=self.entry; panel.showEvidence=false; PaintRows(); Details()
        end)
        row:SetHeight(47); row.label:ClearAllPoints(); row.label:SetPoint("LEFT",50,0)
        row.label:SetSize(172,42); row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(true)
        row.portrait=row:CreateTexture(nil,"ARTWORK"); row.portrait:SetPoint("LEFT",4,0); row.portrait:SetSize(40,40)
        row.placeholder=Text(row,10,{0.65,0.72,0.75,1}); row.placeholder:SetPoint("LEFT",4,0)
        row.placeholder:SetSize(40,40); row.placeholder:SetJustifyH("CENTER"); row.placeholder:SetText("No\nportrait")
        row.marker=row:CreateTexture(nil,"OVERLAY"); row.marker:SetColorTexture(0.6,0.85,0.4,1)
        row.marker:SetPoint("LEFT"); row.marker:SetSize(2,40)
        row:EnableMouseWheel(true); row:SetScript("OnMouseWheel",function(_,delta) panel.ScrollRows(-delta) end)
        panel.rows[i]=row
    end
    panel.previous=Button(browser,"<",0,260,44,function() panel.ScrollRows(-ROWS) end)
    panel.next=Button(browser,">",184,260,44,function() panel.ScrollRows(ROWS) end)
    function panel.Refresh(resetOffset)
        local onIndex=panel.view=="families"
        index:SetShown(onIndex); browser:SetShown(not onIndex)
        search:SetShown(panel.view~="sources"); panel.clear:SetShown(panel.view~="sources")
        panel.navigation.label:SetText(onIndex and "Browse all creatures" or "Back to families")
        placeholder:SetText(onIndex and "Search families" or "Search names or families")
        placeholder:SetShown(search:GetText()=="" and not panel.HasFocus())
        if onIndex then
            panel.familyQuery=search:GetText()
            panel.familyResults=NS.GuideData.Filter(panel.families,search:GetText())
            for i,card in ipairs(panel.cards) do
                local family=panel.familyResults[i]; card.family=family; card:SetShown(family~=nil)
                card.icon:SetTexture(nil); card.icon:Hide(); card.placeholder:Show()
                if family then
                    card.label:SetText(Plain(family.displayLabel))
                    card.count:SetText(#NS.GuideData.Filter(panel.entries,"",family.key).." recorded")
                    if family.iconFileID then
                        local ok,result=pcall(card.icon.SetTexture,card.icon,family.iconFileID)
                        if ok and result~=false then card.icon:Show(); card.placeholder:Hide() end
                    end
                end
            end
            indexEmpty:SetText(panel.problem or (#panel.families==0 and "No families recorded." or "No matching families. Try another search."))
            indexEmpty:SetShown(#panel.familyResults==0)
            return
        end
        local creatures=panel.view=="creatures"
        for _,widget in ipairs({familyHeading,count,panel.previous,panel.next,panel.evidence}) do widget:SetShown(creatures) end
        if not creatures then
            empty:Hide(); for _,row in ipairs(panel.rows) do row:Hide() end
            Details(); return
        end
        local choice=NS.GuideData.Select(panel.families,panel.familyKey)
        familyHeading:SetText(Plain(panel.familyKey and choice and choice.displayLabel or "All recorded creatures"))
        panel.results=NS.GuideData.Filter(panel.entries,search:GetText(),panel.familyKey)
        local oldKey=panel.selected and panel.selected.key
        panel.selected=NS.GuideData.Select(panel.results,oldKey)
        if resetOffset then panel.offset=0 end
        panel.offset=math.min(panel.offset,math.max(0,#panel.results-ROWS))
        -- Keep a preserved selection visible after filtering.
        if panel.selected then
            for i,entry in ipairs(panel.results) do
                if entry.key==panel.selected.key and (i<=panel.offset or i>panel.offset+ROWS) then panel.offset=math.max(0,i-ROWS) end
            end
        end
        if not panel.selected or panel.selected.key~=oldKey then panel.showEvidence=false end
        local familyEmpty=panel.familyKey and #NS.GuideData.Filter(panel.entries,"",panel.familyKey)==0
        empty:SetText(panel.problem or (familyEmpty and "No creatures recorded in PetStable yet."
            or (#panel.entries==0 and "No creatures are recorded in this catalog yet." or "No matching creatures.\nTry another search or clear it.")))
        empty:SetShown(#panel.results==0)
        placeholder:SetShown(search:GetText()=="" and not panel.HasFocus())
        PaintRows(); Details()
    end
    search:SetScript("OnTextChanged",function() panel.Refresh(true) end)
    search:SetText("")
    panel:SetScript("OnHide",panel.ClearFocus)
    panel.Refresh(true)
    return panel
end
