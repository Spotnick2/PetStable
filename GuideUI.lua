local _, NS = ...
local ROWS, ROW_HEIGHT = 4, 72
local function Plain(text) return (text or ""):gsub("|","||") end

function NS.CreateGuide(parent, window, Text)
    local panel=CreateFrame("Frame",nil,parent)
    panel:SetPoint("TOPLEFT",24,-136); panel:SetSize(992,502)
    panel.visibleRows=ROWS; panel.listWidth=320
    panel.entries,panel.families,panel.problem,panel.familySources=NS.GuideData.Build(NS.CatalogData)
    panel.rows={}; panel.offset=0; panel.showEvidence=false; panel.view="families"; panel.familyQuery=""
    local browser=CreateFrame("Frame",nil,panel); browser:SetAllPoints(panel)
    local index=CreateFrame("Frame",nil,panel); index:SetAllPoints(panel)
    panel.browser=browser; panel.index=index; panel.cards={}
    local interactive={}
    local function Button(host,label,x,y,width,click,fontSize)
        local b=CreateFrame("Button",nil,host,"BackdropTemplate")
        b:SetPoint("TOPLEFT",x,-y); b:SetSize(width,26)
        b.label=Text(b,fontSize or 12); b.label:SetPoint("CENTER"); b.label:SetWidth(width-8); b.label:SetJustifyH("CENTER")
        b.label:SetText(label); b:SetScript("OnClick",click)
        NS.StyleButton(b); interactive[#interactive+1]=b
        return b
    end
    function panel.ResetHover()
        for _,b in ipairs(interactive) do b.ResetHover() end
        if panel.appearances then panel.appearances.ResetHover() end
    end
    panel.search=CreateFrame("EditBox",nil,panel,"BackdropTemplate")
    local search=panel.search
    search:SetPoint("TOPLEFT"); search:SetSize(800,34)
    search:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    search:SetBackdropColor(0.03,0.045,0.055,1); search:SetBackdropBorderColor(0.35,0.45,0.38,1)
    search:SetFont("Fonts\\FRIZQT__.TTF",14,""); search:SetTextColor(0.95,0.97,0.95,1)
    search:SetTextInsets(12,38,0,0); search:SetAutoFocus(false); search:SetMultiLine(false); search:SetMaxLetters(120)
    search:SetPropagateKeyboardInput(false)
    local placeholder=Text(search,13,{0.65,0.72,0.75,1})
    placeholder:SetPoint("LEFT",12,0); placeholder:SetText("Search families..."); panel.placeholder=placeholder
    function panel.ClearFocus() search:ClearFocus(); if panel.appearances then panel.appearances.ClearFocus() end end
    function panel.HasFocus() return search:HasFocus()==true or (panel.appearances and panel.appearances.HasFocus()) or false end
    local function Focus()
        placeholder:SetShown(search:GetText()=="")
        window:SetPropagateKeyboardInput(not panel.HasFocus())
    end
    search:SetScript("OnEditFocusGained",Focus); search:SetScript("OnEditFocusLost",Focus)
    search:SetScript("OnEnterPressed",panel.ClearFocus)
    search:SetScript("OnEscapePressed",function()
        panel.ClearFocus(); window:Hide(); window:SetPropagateKeyboardInput(false)
    end)
    panel.clear=Button(search,"×",0,0,26,function()
        panel.ClearFocus(); search:SetText(""); panel.Refresh(true)
    end)
    local creatureStates={}
    local function SaveView()
        if panel.view=="creatures" then
            creatureStates[panel.familyKey or "all"]={query=search:GetText(),selected=panel.selected,
                evidence=panel.showEvidence,offset=panel.offset,scroll=panel.scroll:GetVerticalScroll()}
        end
    end
    function panel.ShowFamilies()
        panel.sourceFamily=nil
        SaveView()
        panel.ClearFocus(); panel.ResetHover(); panel.view="families"; panel.familyKey=nil; panel.selected=nil; panel.showEvidence=false
        search:SetText(panel.familyQuery); panel.Refresh(true)
    end
    function panel.OpenFamily(key)
        if key then SaveView(); panel.ClearFocus(); panel.appearances.Open(key); return end
        if panel.view=="creatures" and panel.familyKey==key then panel.ClearFocus(); return end
        SaveView()
        panel.ClearFocus(); panel.ResetHover(); panel.view="creatures"; panel.familyKey=key; panel.selected=nil; panel.showEvidence=false
        local saved=creatureStates[key or "all"]
        panel.selected=saved and saved.selected; panel.showEvidence=saved and saved.evidence or false; panel.offset=saved and saved.offset or 0
        panel.restoring=true; search:SetText(saved and saved.query or ""); panel.restoring=false; panel.Refresh(false)
        if saved then panel.scroll:SetVerticalScroll(math.min(saved.scroll,panel.scroll:GetVerticalScrollRange())) end
    end
    panel.familiesTab=Button(panel,"Families",0,-40,110,function() panel.ShowFamilies() end)
    panel.allTab=Button(panel,"All Creatures",0,-40,130,function() panel.OpenFamily(nil) end)
    panel.navigation=Button(panel,"< Families",0,44,100,function()
        local key=panel.sourceFamily; panel.sourceFamily=nil
        if key then panel.OpenFamily(key) else panel.ShowFamilies() end
    end)
    local breadcrumb=Text(panel,13,{0.7,0.78,0.72,1}); breadcrumb:SetPoint("TOPLEFT",114,-51); panel.breadcrumb=breadcrumb
    function panel.OpenSources()
        SaveView()
        panel.ClearFocus(); panel.ResetHover(); panel.view="sources"; panel.Refresh(true)
    end
    panel.sources=Button(panel,"i  Sources",0,0,92,function() panel.OpenSources() end)
    local footer=Text(panel,12,{0.72,0.82,0.66,1}); footer:SetPoint("BOTTOMLEFT",0,0); panel.footer=footer
    local gallery=CreateFrame("ScrollFrame",nil,index); gallery:SetPoint("TOPLEFT",0,-80); gallery:SetSize(968,392); gallery:EnableMouseWheel(true)
    local galleryChild=CreateFrame("Frame",nil,gallery); galleryChild:SetSize(968,392); gallery:SetScrollChild(galleryChild)
    panel.gallery=gallery
    local galleryBar=CreateFrame("Slider",nil,index,"BackdropTemplate"); panel.galleryBar=galleryBar
    galleryBar:SetOrientation("VERTICAL"); galleryBar:SetMinMaxValues(0,0); galleryBar:SetValueStep(1); galleryBar:SetObeyStepOnDrag(false)
    galleryBar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); galleryBar:SetBackdropColor(0.06,0.08,0.07,0.45)
    galleryBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8"); local galleryThumb=galleryBar:GetThumbTexture()
    galleryThumb:SetVertexColor(0.38,0.46,0.4,0.75)
    local gallerySyncing=false
    local function SyncGallery()
        if gallerySyncing then return end
        gallerySyncing=true
        local range=math.max(0,gallery:GetVerticalScrollRange())
        if range<1 then range=0 end -- Ignore subpixel layout noise when every card fits.
        local value=math.max(0,math.min(range,gallery:GetVerticalScroll()))
        galleryBar:SetMinMaxValues(0,range); galleryBar:SetValue(value); galleryBar:SetShown(range>0)
        galleryThumb:SetSize(6,math.max(24,galleryBar:GetHeight()*gallery:GetHeight()/(gallery:GetHeight()+range)))
        galleryThumb:SetShown(range>0)
        if gallery:GetVerticalScroll()~=value then gallery:SetVerticalScroll(value) end
        gallerySyncing=false
    end
    local function ScrollGallery(_,delta)
        panel.ClearFocus(); panel.ResetHover()
        gallery:SetVerticalScroll(math.max(0,math.min(gallery:GetVerticalScrollRange(),gallery:GetVerticalScroll()-delta*80)))
    end
    gallery:SetScript("OnMouseWheel",ScrollGallery); galleryBar:EnableMouseWheel(true); galleryBar:SetScript("OnMouseWheel",ScrollGallery)
    gallery:SetScript("OnVerticalScroll",SyncGallery); gallery:SetScript("OnScrollRangeChanged",SyncGallery)
    galleryBar:SetScript("OnValueChanged",function(_,value)
        if not gallerySyncing then panel.ClearFocus(); panel.ResetHover(); gallery:SetVerticalScroll(value) end
    end)
    local indexEmpty=Text(index,14); indexEmpty:SetPoint("TOPLEFT",0,-90); indexEmpty:SetWidth(580)
    panel.indexEmpty=indexEmpty
    for i=1,#panel.families do
        local card=Button(galleryChild,"",0,0,186,function(self)
            if self.family then panel.OpenFamily(self.family.key) end
        end,16.5)
        card.familyCard=true; card.Paint()
        card.label:SetFont("Fonts\\FRIZQT__.TTF",16.5,"")
        if not NS.Glass then
            local shade=card:CreateTexture(nil,"BACKGROUND")
            shade:SetPoint("TOPLEFT",1,-1); shade:SetPoint("BOTTOMRIGHT",-1,1)
            shade:SetColorTexture(1,1,1,1)
            shade:SetGradient("VERTICAL",CreateColor(1,1,1,0),CreateColor(1,1,1,0.055))
        end
        card:SetHeight(84); card.label:ClearAllPoints(); card.label:SetPoint("LEFT",82,0)
        card.label:SetSize(92,68); card.label:SetJustifyH("LEFT"); card.label:SetJustifyV("MIDDLE"); card.label:SetWordWrap(true)
        card.icon=card:CreateTexture(nil,"ARTWORK"); card.icon:SetPoint("LEFT",8,0); card.icon:SetSize(64,64)
        card.placeholder=Text(card,24,{0.65,0.72,0.75,1}); card.placeholder:SetPoint("LEFT",32,0); card.placeholder:SetText("?")
        card.arrow=Text(card,18,{0.74,0.9,0.64,1}); card.arrow:SetPoint("RIGHT",-5,0); card.arrow:SetText("›"); card.arrow:Hide()
        -- "Your pet" / "In stable": text plus a thin accent, never colour alone.
        card.mark=Text(card,11,{0.74,0.9,0.64,1}); card.mark:SetPoint("BOTTOMLEFT",82,7); card.mark:SetJustifyH("LEFT"); card.mark:Hide()
        card.accent=card:CreateTexture(nil,"OVERLAY"); card.accent:SetPoint("TOPLEFT",1,-8); card.accent:SetPoint("BOTTOMLEFT",1,8)
        card.accent:SetWidth(3); card.accent:SetColorTexture(1,1,1,1); card.accent:Hide()
        card:EnableMouseWheel(true); card:SetScript("OnMouseWheel",ScrollGallery)
        panel.cards[i]=card
    end
    local empty=Text(browser,14); empty:SetPoint("TOPLEFT",4,-90); empty:SetSize(300,160); empty:SetJustifyV("TOP")
    panel.empty=empty
    local count=Text(browser,12); count:SetPoint("TOPLEFT",54,-266); count:SetWidth(120); count:SetJustifyH("CENTER")
    panel.count=count
    local detailLabel=Text(browser,14,{0.78,0.94,0.65,1})
    detailLabel:SetPoint("TOPLEFT",244,-42); detailLabel:SetText("Details")
    local scroll=CreateFrame("ScrollFrame",nil,browser)
    scroll:SetPoint("TOPLEFT",244,-74); scroll:SetSize(330,216); scroll:EnableMouseWheel(true)
    local child=CreateFrame("Frame",nil,scroll); child:SetSize(328,216)
    local detail=Text(child,14); detail:SetPoint("TOPLEFT"); detail:SetWidth(326)
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
    local LayoutDetails
    local function Details()
        local entry=panel.selected
        local sources=panel.view=="sources"
        detailLabel:SetShown(not sources)
        LayoutDetails()
        detail:SetText(Plain(sources and (panel.familySources or panel.problem or "No family sources recorded.")
            or (entry and (panel.showEvidence and entry.evidence or entry.details) or "Select a creature to see its recorded details.")))
        child:SetHeight(math.max(scroll:GetHeight(),detail:GetStringHeight()+4))
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
            local entry=i<=panel.visibleRows and panel.results[panel.offset+i] or nil
            row.entry=entry; Portrait(row,entry); row:SetShown(entry~=nil)
            if entry then
                row.label:SetText(Plain(entry.label.."\n"..entry.family))
                row.marker:SetShown(panel.selected and entry.key==panel.selected.key)
                row.active=panel.selected and entry.key==panel.selected.key; row.Paint()
            end
        end
        local total=#panel.results
        count:SetText(total==0 and "0 results" or ((panel.offset+1).."–"..math.min(total,panel.offset+panel.visibleRows).." / "..total))
        footer:SetText(total..(total==1 and " recorded creature" or " recorded creatures")..(panel.familyKey and " in this family" or ""))
        panel.previous.disabled=panel.offset==0; panel.next.disabled=panel.offset>=math.max(0,total-panel.visibleRows)
        for _,b in ipairs({panel.previous,panel.next}) do b:SetEnabled(not b.disabled); b.Paint() end
    end
    function panel.ScrollRows(delta)
        panel.ClearFocus(); panel.ResetHover(); panel.offset=math.max(0,math.min(math.max(0,#panel.results-panel.visibleRows),panel.offset+delta)); PaintRows()
    end
    for i=1,ROWS do
        local row=Button(browser,"",0,80+(i-1)*ROW_HEIGHT,320,function(self)
            if not self.entry then return end
            panel.ClearFocus(); panel.selected=self.entry; panel.showEvidence=false; PaintRows(); Details()
        end)
        row:SetHeight(64); row.label:ClearAllPoints(); row.label:SetPoint("LEFT",70,0)
        row.label:SetSize(242,54); row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(true)
        row.portrait=row:CreateTexture(nil,"ARTWORK"); row.portrait:SetPoint("LEFT",4,0); row.portrait:SetSize(56,56)
        row.placeholder=Text(row,10,{0.65,0.72,0.75,1}); row.placeholder:SetPoint("LEFT",4,0)
        row.placeholder:SetSize(40,40); row.placeholder:SetJustifyH("CENTER"); row.placeholder:SetText("No\nportrait")
        row.marker=row:CreateTexture(nil,"OVERLAY"); row.marker:SetColorTexture(0.6,0.85,0.4,1)
        row.marker:SetPoint("LEFT"); row.marker:SetSize(2,40)
        row:EnableMouseWheel(true); row:SetScript("OnMouseWheel",function(_,delta) panel.ScrollRows(-delta) end)
        panel.rows[i]=row
    end
    panel.previous=Button(browser,"<",0,260,36,function() panel.ScrollRows(-panel.visibleRows) end)
    panel.next=Button(browser,">",184,260,36,function() panel.ScrollRows(panel.visibleRows) end)
    local function Place(widget,x,y,width,height)
        widget:ClearAllPoints(); widget:SetPoint("TOPLEFT",x,-y)
        if width then widget:SetWidth(width) end
        if height then widget:SetHeight(height) end
    end
    LayoutDetails=function()
        local width,height=panel:GetWidth(),panel:GetHeight()
        local x=panel.view=="sources" and 0 or panel.listWidth+24
        Place(scroll,x,80,width-x-26,height-110)
        child:SetWidth(scroll:GetWidth()-2); detail:SetWidth(scroll:GetWidth()-4)
        child:SetHeight(math.max(scroll:GetHeight(),detail:GetStringHeight()+4))
        Place(detailLabel,x,52)
        Place(bar,width-18,110,18,math.max(32,height-170))
        Place(panel.scrollUp,width-18,80,18,24); Place(panel.scrollDown,width-18,height-54,18,24)
        Place(panel.evidence,width-126,44,126,28)
        SyncScrollbar()
    end
    local function LayoutGallery()
        local width,height=panel:GetWidth(),panel:GetHeight()
        Place(gallery,0,50,width-24,height-80)
        Place(galleryBar,width-14,50,14,height-80)
        local columns=math.max(1,math.min(5,math.floor((gallery:GetWidth()+10)/186)))
        local cardWidth=(gallery:GetWidth()-(columns-1)*10)/columns
        panel.columns=columns
        galleryChild:SetWidth(gallery:GetWidth())
        for i,card in ipairs(panel.cards) do
            Place(card,((i-1)%columns)*(cardWidth+10),math.floor((i-1)/columns)*94,cardWidth,84)
            card.label:SetSize(cardWidth-100,card.mark:IsShown() and 50 or 68)
        end
        local rows=math.ceil(#(panel.familyResults or panel.families)/columns)
        galleryChild:SetHeight(math.max(gallery:GetHeight(),rows*94-10))
        SyncGallery()
    end
    function panel.Layout(width,height)
        panel.ResetHover(); panel:SetSize(width,height)
        Place(search,0,0,width-108,34); placeholder:SetWidth(width-162)
        panel.clear:ClearAllPoints(); panel.clear:SetPoint("RIGHT",search,"RIGHT",-4,0); panel.clear:SetSize(26,26)
        Place(panel.sources,width-92,4,92,26)
        Place(panel.familiesTab,width-240,-40,110,28); Place(panel.allTab,width-130,-40,130,28)
        breadcrumb:SetWidth(width-260); indexEmpty:SetWidth(width-32)
        panel.listWidth=math.max(260,math.min(360,math.floor(width*0.34)))
        panel.visibleRows=math.max(1,math.min(ROWS,math.floor((height-110)/ROW_HEIGHT)))
        for i,row in ipairs(panel.rows) do Place(row,0,80+(i-1)*ROW_HEIGHT,panel.listWidth,64); row.label:SetWidth(panel.listWidth-82) end
        empty:SetWidth(panel.listWidth-8)
        Place(panel.previous,0,height-54,36,24); Place(panel.next,panel.listWidth-36,height-54,36,24)
        Place(count,44,height-50,panel.listWidth-88)
        LayoutGallery(); LayoutDetails()
        if panel.results then panel.offset=math.min(panel.offset,math.max(0,#panel.results-panel.visibleRows)) end
        if panel.view=="creatures" then PaintRows() end
        if panel.appearances then panel.appearances.Layout(width,height) end
    end
    function panel.Refresh(resetOffset)
        panel.ResetHover()
        local drill=panel.view=="appearances" or panel.view=="appearance"
        if NS.guideTitle then NS.guideTitle:SetShown(not drill) end
        if panel.appearances then panel.appearances:SetShown(drill) end
        for _,widget in ipairs({panel.familiesTab,panel.allTab,panel.sources,breadcrumb,footer}) do widget:SetShown(not drill) end
        if drill then
            index:Hide(); browser:Hide(); search:Hide(); panel.navigation:Hide()
            panel.appearances.Refresh(); return
        end
        local onIndex=panel.view=="families"
        index:SetShown(onIndex); browser:SetShown(not onIndex)
        search:SetShown(panel.view~="sources"); panel.clear:SetShown(search:GetText()~="")
        panel.navigation:SetShown(not onIndex)
        panel.navigation.label:SetText(panel.view=="sources" and panel.sourceFamily and "‹ Appearances" or "‹ Families")
        panel.familiesTab.active=onIndex or panel.familyKey~=nil; panel.familiesTab.Paint()
        panel.allTab.active=panel.view=="creatures" and panel.familyKey==nil; panel.allTab.Paint()
        placeholder:SetText(onIndex and "Search families..." or "Search creature names or families...")
        placeholder:SetShown(search:GetText()=="")
        if onIndex then
            breadcrumb:Hide()
            panel.familyQuery=search:GetText()
            panel.familyResults=NS.GuideData.Filter(panel.families,search:GetText())
            local owned=NS.PetState and NS.PetState.Owned() or {}
            for i,card in ipairs(panel.cards) do
                local family=panel.familyResults[i]; card.family=family; card:SetShown(family~=nil)
                card.icon:SetTexture(nil); card.icon:Hide(); card.placeholder:Show()
                local mine=family and owned[family.key]
                card.mark:SetShown(mine~=nil); card.accent:SetShown(mine~=nil)
                if mine then
                    card.mark:SetText(mine.active and ("Your pet"..(mine.stabled>0 and " · "..mine.stabled.." in stable" or ""))
                        or ("In stable"..(mine.stabled>1 and " ("..mine.stabled..")" or "")))
                    if mine.active then card.accent:SetColorTexture(0.55,0.85,0.5,0.9) else card.accent:SetColorTexture(0.5,0.7,0.9,0.9) end
                end
                if family then
                    card.label:SetText(Plain(family.displayLabel))
                    if family.iconFileID then
                        local ok,result=pcall(card.icon.SetTexture,card.icon,family.iconFileID)
                        if ok and result~=false then card.icon:Show(); card.placeholder:Hide() end
                    end
                end
            end
            indexEmpty:SetText(panel.problem or (#panel.families==0 and "No families recorded." or "No matching families. Try another search."))
            indexEmpty:SetShown(#panel.familyResults==0)
            Place(indexEmpty,0,60)
            footer:SetText(#panel.familyResults..(#panel.familyResults==1 and " family" or " families"))
            LayoutGallery(); if resetOffset then gallery:SetVerticalScroll(0) end
            return
        end
        local creatures=panel.view=="creatures"
        for _,widget in ipairs({count,panel.previous,panel.next,panel.evidence}) do widget:SetShown(creatures) end
        Place(breadcrumb,114,51)
        if not creatures then
            empty:Hide(); for _,row in ipairs(panel.rows) do row:Hide() end
            breadcrumb:SetText("/ Family sources"); footer:SetText("Reference roster and observed client metadata")
            Details(); return
        end
        local choice=NS.GuideData.Select(panel.families,panel.familyKey)
        breadcrumb:SetText(Plain("/ "..(panel.familyKey and choice and choice.displayLabel or "All Creatures")))
        panel.results=NS.GuideData.Filter(panel.entries,search:GetText(),panel.familyKey)
        local oldKey=panel.selected and panel.selected.key
        panel.selected=NS.GuideData.Select(panel.results,oldKey)
        if resetOffset then panel.offset=0 end
        panel.offset=math.min(panel.offset,math.max(0,#panel.results-panel.visibleRows))
        -- Keep a preserved selection visible after filtering.
        if panel.selected then
            for i,entry in ipairs(panel.results) do
                if entry.key==panel.selected.key and (i<=panel.offset or i>panel.offset+panel.visibleRows) then panel.offset=math.max(0,i-panel.visibleRows) end
            end
        end
        if not panel.selected or panel.selected.key~=oldKey then panel.showEvidence=false end
        local familyEmpty=panel.familyKey and #NS.GuideData.Filter(panel.entries,"",panel.familyKey)==0
        empty:SetText(panel.problem or (familyEmpty and "No creatures recorded in PetStable yet."
            or (#panel.entries==0 and "No creatures are recorded in this catalog yet." or "No matching creatures.\nTry another search or clear it.")))
        empty:SetShown(#panel.results==0)
        placeholder:SetShown(search:GetText()=="")
        PaintRows(); Details()
    end
    search:SetScript("OnTextChanged",function() if not panel.restoring then panel.Refresh(true) end end)
    search:SetText("")
    panel.appearances=NS.CreateAppearanceBrowser(panel,window,Text)
    function panel.Capture()
        return {view=panel.view,familyKey=panel.familyKey,sourceFamily=panel.sourceFamily,
            query=search:GetText(),familyQuery=panel.familyQuery,selected=panel.selected,
            evidence=panel.showEvidence,offset=panel.offset,scroll=scroll:GetVerticalScroll(),
            galleryScroll=gallery:GetVerticalScroll(),appearance=panel.appearances.Capture()}
    end
    function panel.Restore(saved)
        panel.ClearFocus(); panel.ResetHover(); panel.appearances.Stop()
        panel.familyQuery=saved.familyQuery; panel.sourceFamily=saved.sourceFamily
        if saved.view=="appearances" or saved.view=="appearance" then
            panel.appearances.Restore(saved.appearance,saved.view,saved.familyKey); return
        end
        panel.view=saved.view; panel.familyKey=saved.familyKey; panel.selected=saved.selected
        panel.showEvidence=saved.evidence; panel.offset=saved.offset
        panel.restoring=true; search:SetText(saved.query); panel.restoring=false
        panel.Refresh(false)
        scroll:SetVerticalScroll(math.min(saved.scroll,scroll:GetVerticalScrollRange()))
        gallery:SetVerticalScroll(math.min(saved.galleryScroll,gallery:GetVerticalScrollRange()))
    end
    panel:SetScript("OnHide",function() panel.ClearFocus(); panel.ResetHover(); panel.appearances.Stop() end)
    panel.Layout(992,502)
    panel.Refresh(true)
    -- Marks follow the observed pets whenever they are re-read.
    if NS.PetState then
        NS.PetState.Subscribe(function() if panel.view=="families" and panel:IsShown() then panel.Refresh(false) end end)
    end
    return panel
end
