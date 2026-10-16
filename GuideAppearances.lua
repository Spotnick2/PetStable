local _, NS = ...
local G=NS.GuideData
local function Plain(value) return (value or ""):gsub("|","||") end
local function Place(widget,x,y,w,h)
    widget:ClearAllPoints(); widget:SetPoint("TOPLEFT",x,-y)
    if w then widget:SetWidth(w) end; if h then widget:SetHeight(h) end
end

function NS.CreateAppearanceBrowser(panel,window,Text)
    local root=CreateFrame("Frame",nil,panel); root:SetPoint("TOPLEFT",0,40)
    local state,states={},{}
    local buttons={}
    local function Button(host,label,click)
        local b=CreateFrame("Button",nil,host,"BackdropTemplate"); b:SetSize(120,28)
        b.label=Text(b,12); b.label:SetPoint("CENTER"); b.label:SetWordWrap(true); b.label:SetJustifyH("CENTER")
        b.label:SetWidth(112); b.label:SetText(label); NS.StyleButton(b)
        b:SetScript("OnClick",function(self) panel.ClearFocus(); click(self) end)
        buttons[#buttons+1]=b; return b
    end
    local function Label(host,size)
        local t=Text(host,size); t:SetWordWrap(true); t:SetJustifyV("TOP"); return t
    end
    root.back=Button(root,"‹ Families",function() panel.ShowFamilies() end)
    root.all=Button(root,"All Creatures",function() panel.OpenFamily(nil) end)
    local breadcrumb=Label(root,12); root.breadcrumb=breadcrumb
    local icon=root:CreateTexture(nil,"ARTWORK"); icon:SetSize(44,44)
    local heading=Label(root,22); root.heading=heading
    local subtitle=Label(root,12)
    root.backGallery=Button(root,"‹ Back to appearances",function() root.Back() end)
    local info=CreateFrame("Frame",nil,root,"BackdropTemplate"); root.info=info
    info:SetFrameLevel(root:GetFrameLevel()+30); info:EnableMouse(true)
    info:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    info:SetBackdropColor(0.035,0.055,0.045,1); info:SetBackdropBorderColor(0.35,0.45,0.36,1)
    local infoText=Label(info,13); Place(infoText,14,14,380)
    infoText:SetText("Family role: Unknown\nLearnable family abilities: Not verified\nDiet: Not verified\n\nCreature observations do not establish family abilities.")
    local infoSources=Button(info,"Family sources",function()
        info:Hide(); panel.sourceFamily=panel.familyKey; panel.sources:GetScript("OnClick")(panel.sources)
    end)
    Place(infoSources,14,122,160,28)
    local infoClose=Button(info,"Close",function() info:Hide() end); Place(infoClose,184,122,90,28)
    root.familyInfo=Button(root,"Family abilities & diet",function() info:SetShown(not info:IsShown()) end)
    local search=CreateFrame("EditBox",nil,root,"BackdropTemplate"); root.search=search
    search:SetFont("Fonts\\FRIZQT__.TTF",13,""); search:SetAutoFocus(false); search:SetMaxLetters(120)
    search:SetTextInsets(10,34,0,0); search:SetPropagateKeyboardInput(false)
    search:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    search:SetBackdropColor(0.03,0.045,0.04,1); search:SetBackdropBorderColor(0.3,0.4,0.34,1)
    local hint=Label(search,12); hint:SetPoint("LEFT",10,0); hint:SetText("Search appearances or creature names...")
    root.clear=Button(search,"×",function() search:SetText("") end)
    root.clear:SetPoint("RIGHT",-3,0); root.clear:SetSize(26,26); root.clear.label:SetWidth(20)
    local function Cycle(field,choices)
        state[field]=(state[field] or 1)%#choices+1; state.scroll=0; root.Refresh()
    end
    root.level=Button(root,"All levels",function() Cycle("level",root.levels) end)
    root.zone=Button(root,"All zones",function() Cycle("zone",root.zones) end)
    local gallery=CreateFrame("ScrollFrame",nil,root); root.gallery=gallery; gallery:EnableMouseWheel(true)
    local canvas=CreateFrame("Frame",nil,gallery); canvas:SetSize(900,300); gallery:SetScrollChild(canvas)
    local function Scrollbar(host,scroll)
        local bar=CreateFrame("Slider",nil,host,"BackdropTemplate")
        bar:SetOrientation("VERTICAL"); bar:SetMinMaxValues(0,0); bar:SetValueStep(1); bar:SetObeyStepOnDrag(false)
        bar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); bar:SetBackdropColor(0.07,0.10,0.08,1)
        bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8"); bar:GetThumbTexture():SetVertexColor(0.6,0.76,0.53,1)
        local syncing=false
        function bar.Sync()
            if syncing then return end; syncing=true
            local range=math.max(0,scroll:GetVerticalScrollRange())
            local value=math.max(0,math.min(range,scroll:GetVerticalScroll()))
            bar:SetMinMaxValues(0,range); bar:SetValue(value); bar:SetShown(range>0)
            bar:GetThumbTexture():SetSize(12,math.max(24,bar:GetHeight()*scroll:GetHeight()/math.max(1,scroll:GetHeight()+range)))
            if scroll:GetVerticalScroll()~=value then scroll:SetVerticalScroll(value) end
            syncing=false
        end
        bar:SetScript("OnValueChanged",function(_,value) if not syncing then panel.ClearFocus(); scroll:SetVerticalScroll(value) end end)
        scroll:SetScript("OnScrollRangeChanged",bar.Sync)
        local function Wheel(_,delta)
            panel.ClearFocus(); root.ResetHover()
            scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()-delta*90)))
        end
        scroll:SetScript("OnMouseWheel",Wheel); bar:EnableMouseWheel(true); bar:SetScript("OnMouseWheel",Wheel)
        return bar,Wheel
    end
    local galleryBar,Wheel=Scrollbar(root,gallery); root.galleryBar=galleryBar
    local empty=Label(root,14); root.empty=empty
    local footer=Label(root,12); root.footer=footer
    local measure=Label(root,12); measure:Hide()
    root.cards={}
    -- Three columns, two visible rows plus one partial row; reuse the nine slots.
    for i=1,9 do
        local card=Button(canvas,"",function(self) if self.result then root.OpenAppearance(self.result) end end)
        card.preview=NS.CreateAppearancePreview(card,Text,false)
        card.level=Label(card,11); card.zone=Label(card,11)
        card.arrow=Label(card,18); card.arrow:SetPoint("BOTTOMRIGHT",-8,12); card.arrow:SetText("›"); card.arrow:Hide()
        card:EnableMouseWheel(true); card:SetScript("OnMouseWheel",Wheel)
        root.cards[i]=card
    end
    local detail=CreateFrame("Frame",nil,root); root.detail=detail
    local preview=NS.CreateAppearancePreview(detail,Text,true); root.preview=preview
    local previewHelp=Label(detail,11); previewHelp:SetText("Drag to rotate · Scroll to zoom")
    local modelButtons={
        Button(detail,"‹ Rotate",function() preview.Rotate(-0.4) end),
        Button(detail,"−",function() preview.Zoom(-0.1) end),
        Button(detail,"Reset",preview.Reset),
        Button(detail,"+",function() preview.Zoom(0.1) end),
        Button(detail,"Rotate ›",function() preview.Rotate(0.4) end),
    }
    root.modelButtons=modelButtons
    preview.OnReady=function(ready)
        for _,button in ipairs(modelButtons) do button:SetShown(ready) end
        previewHelp:SetShown(ready)
    end
    local body=CreateFrame("ScrollFrame",nil,detail); root.body=body; body:EnableMouseWheel(true)
    local bodyChild=CreateFrame("Frame",nil,body); bodyChild:SetSize(500,400); body:SetScrollChild(bodyChild)
    local bodyBar=Scrollbar(detail,body); root.bodyBar=bodyBar
    body:SetScript("OnVerticalScroll",bodyBar.Sync)
    local locationTitle=Label(bodyChild,17); locationTitle:SetText("Where to find this appearance")
    local matchText=Label(bodyChild,12)
    root.showAll=Button(bodyChild,"Show all associated creatures",function() state.showAll=not state.showAll; root.PaintDetail() end)
    local columnNames={Label(bodyChild,12),Label(bodyChild,12),Label(bodyChild,12)}
    columnNames[1]:SetText("Creature"); columnNames[2]:SetText("Level"); columnNames[3]:SetText("Location")
    local rows={}; root.rows=rows
    local selectedTitle=Label(bodyChild,16)
    local specific=Label(bodyChild,13); root.specific=specific
    local familyText=Label(bodyChild,13)
    root.sources=Button(bodyChild,"Sources & observations ›",function() state.sources=not state.sources; root.PaintDetail() end)
    local sourceText=Label(bodyChild,12); root.sourceText=sourceText
    root.technical=Button(bodyChild,"Technical evidence ›",function() state.technical=not state.technical; root.PaintDetail() end)
    local technicalText=Label(bodyChild,12); technicalText:SetNonSpaceWrap(true)
    root.copy=Button(bodyChild,"Select source URLs",function()
        state.copy=not state.copy; root.PaintDetail()
        if state.copy then root.urls:SetFocus(); root.urls:HighlightText() end
    end)
    local urls=CreateFrame("EditBox",nil,bodyChild,"BackdropTemplate"); root.urls=urls
    urls:SetFont("Fonts\\FRIZQT__.TTF",12,""); urls:SetAutoFocus(false); urls:SetMultiLine(true)
    urls:SetTextInsets(6,6,6,6); urls:SetPropagateKeyboardInput(false)
    urls:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); urls:SetBackdropColor(0.02,0.03,0.025,1)
    local urlHelp=Label(bodyChild,11); urlHelp:SetText("Select text and press Ctrl+C to copy. Changes here are not saved.")
    local urlMeasure=Label(bodyChild,12); urlMeasure:SetNonSpaceWrap(true); urlMeasure:Hide()
    function root.ClearFocus() search:ClearFocus(); urls:ClearFocus() end
    function root.HasFocus() return search:HasFocus()==true or urls:HasFocus()==true end
    local function Focus() window:SetPropagateKeyboardInput(not panel.HasFocus()) end
    for _,edit in ipairs({search,urls}) do
        edit:SetScript("OnEditFocusGained",Focus); edit:SetScript("OnEditFocusLost",Focus)
        edit:SetScript("OnEnterPressed",root.ClearFocus)
        edit:SetScript("OnEscapePressed",function() panel.ClearFocus(); window:Hide(); window:SetPropagateKeyboardInput(false) end)
    end
    function root.ResetHover() for _,b in ipairs(buttons) do b.ResetHover() end end
    function root.Stop()
        preview.Clear(); for _,card in ipairs(root.cards) do card.preview.Clear() end
        root.ResetHover(); root.ClearFocus(); info:Hide()
    end
    function root.PaintCards()
        if panel.view~="appearances" or not root.results or not root.nameHeight then return end
        local cols,stride=root.columns,root.cardHeight+10
        local offset=gallery:GetVerticalScroll(); local first=math.floor(offset/stride)*cols
        for i,card in ipairs(root.cards) do
            local index=first+i; local result=root.results[index]
            local y=math.floor((index-1)/cols)*stride
            local visible=result and y<offset+gallery:GetHeight() and y+root.cardHeight>offset
            card.result=visible and result or nil; card:SetShown(visible~=nil and visible~=false)
            if visible then
                Place(card,((index-1)%cols)*(root.cardWidth+10),y,root.cardWidth,root.cardHeight)
                local labelY=root.cardHeight-root.nameHeight-root.levelHeight-root.zoneHeight-12
                Place(card.preview,8,8,root.cardWidth-16,labelY-16)
                Place(card.label,10,labelY,root.cardWidth-30,root.nameHeight); card.label:SetJustifyH("LEFT")
                card.label:SetJustifyV("TOP"); card.label:SetText(Plain(result.group.label))
                local level,zone=G.AppearanceSummary(result.matches)
                Place(card.level,10,labelY+root.nameHeight,root.cardWidth-30,root.levelHeight); card.level:SetText(Plain(level))
                Place(card.zone,10,labelY+root.nameHeight+root.levelHeight,root.cardWidth-30,root.zoneHeight); card.zone:SetText(Plain(zone))
                card.preview.Set(result.group)
            else card.preview.Clear(); card.ResetHover() end
        end
        state.scroll=offset; galleryBar.Sync()
    end
    gallery:SetScript("OnVerticalScroll",function() root.ResetHover(); root.PaintCards() end)
    function root.PaintDetail()
        if not state.result then return end
        local group=state.result.group
        local entries=state.showAll and group.entries or state.result.matches
        root.detailEntries=entries
        local width=body:GetWidth()-4; local y=0
        local function TextRow(widget,text,size)
            widget:Show(); if text then widget:SetText(Plain(text)) end
            Place(widget,0,y,width); y=y+math.max(size or 18,widget:GetStringHeight())+12
        end
        TextRow(locationTitle)
        local filtered=#state.result.matches<#group.entries
        TextRow(matchText,filtered and (state.showAll and "Showing all associated creatures." or "Showing only creatures matching your search and filters.")
            or "All recorded creatures for this appearance. Locations may be unknown.")
        root.showAll:SetShown(filtered)
        if filtered then
            root.showAll.label:SetText(state.showAll and "Show matching creatures" or "Show all associated creatures")
            Place(root.showAll,0,y,width,28); root.showAll.label:SetWidth(width-12); y=y+40
        end
        -- Column headings share the row widths, including at the minimum window size.
        Place(columnNames[1],8,y,width*0.42-12,20)
        Place(columnNames[2],width*0.42,y,width*0.24-8,20)
        Place(columnNames[3],width*0.66,y,width*0.34-8,20); y=y+28
        for i,entry in ipairs(entries) do
            local row=rows[i]
            if not row then
                row=Button(bodyChild,"",function(self)
                    state.selected=self.entry; state.sources=false; state.technical=false; state.copy=false; root.PaintDetail()
                end)
                row.name=Label(row,12); row.level=Label(row,12); row.zone=Label(row,12); rows[i]=row
            end
            row.entry=entry; row:Show(); Place(row,0,y,width,76)
            Place(row.name,8,8,width*0.42-12,60); row.name:SetText(Plain(entry.label))
            Place(row.level,width*0.42,8,width*0.24-8,60); row.level:SetText(Plain(G.Level(entry)))
            Place(row.zone,width*0.66,8,width*0.34-8,60); row.zone:SetText(Plain(G.Zone(entry)))
            local rowHeight=math.max(76,row.name:GetStringHeight()+16,row.level:GetStringHeight()+16,row.zone:GetStringHeight()+16)
            row:SetHeight(rowHeight)
            row.name:SetHeight(rowHeight-16); row.level:SetHeight(rowHeight-16); row.zone:SetHeight(rowHeight-16)
            row.active=state.selected==entry; row.Paint(); y=y+rowHeight+8
        end
        for i=#entries+1,#rows do rows[i].entry=nil; rows[i]:Hide() end
        local selected=G.Select(entries,state.selected and state.selected.key); state.selected=selected
        for _,row in ipairs(rows) do row.active=row.entry==selected and selected~=nil; row.Paint() end
        TextRow(selectedTitle,selected and selected.label or "Select a creature")
        TextRow(specific,selected and selected.details or "No creature records.")
        TextRow(familyText,(root.family and root.family.displayLabel or "Family").."\nRole: Unknown · Diet: Not verified\nLearnable family abilities: Not verified\nCreature observations are not family ability eligibility.")
        Place(root.sources,0,y,width,28); root.sources.label:SetWidth(width-12)
        root.sources.label:SetText(state.sources and "Sources & observations ‹" or "Sources & observations ›"); y=y+40
        sourceText:SetShown(state.sources==true); root.technical:SetShown(state.sources==true); root.copy:SetShown(state.sources==true)
        technicalText:SetShown(state.sources and state.technical or false); urls:SetShown(state.sources and state.copy or false); urlHelp:SetShown(state.sources and state.copy or false)
        if state.sources then
            TextRow(sourceText,"Facts below apply individually to "..(selected and selected.label or "this creature")..". They do not certify other fields or the current build.\n\n"..(selected and selected.sourceSummary or "No sources recorded."))
            Place(root.technical,0,y,width,28); root.technical.label:SetWidth(width-12); y=y+40
            if state.technical then TextRow(technicalText,selected and selected.evidence or "No evidence recorded.") end
            Place(root.copy,0,y,width,28); root.copy.label:SetWidth(width-12); y=y+40
            if state.copy then
                local value=table.concat(selected and selected.sourceURLs or {},"\n")
                urlMeasure:SetWidth(width-12); urlMeasure:SetText(value)
                local urlHeight=math.max(80,urlMeasure:GetStringHeight()+20)
                Place(urls,0,y,width,urlHeight); urls:SetText(value); y=y+urlHeight+8
                TextRow(urlHelp)
            end
        end
        bodyChild:SetSize(width,math.max(body:GetHeight(),y)); bodyBar.Sync()
        preview.Set(group)
        local controls=preview.ready==true
        for _,b in ipairs(modelButtons) do b:SetShown(controls) end
        previewHelp:SetShown(controls)
    end
    function root.OpenAppearance(result)
        panel.ClearFocus(); root.Stop(); state.result=result; state.selected=result.matches[1]
        state.sources=false; state.technical=false; state.copy=false; state.showAll=false
        panel.view="appearance"; panel.Refresh(false); body:SetVerticalScroll(0)
    end
    function root.Back()
        root.Stop(); panel.view="appearances"; state.result=nil; panel.Refresh(false)
    end
    -- Copy mutable view state; catalog/group records themselves are read-only.
    function root.Capture()
        local saved={}; for key,value in pairs(state) do saved[key]=value end
        saved.bodyScroll=body:GetVerticalScroll()
        return saved
    end
    function root.Restore(saved,view,key)
        root.Stop(); state={}; for field,value in pairs(saved) do state[field]=value end
        states[key]=state; panel.familyKey=key; panel.view=view
        root.restoring=true; search:SetText(state.query); root.restoring=false
        local offset=state.scroll
        panel.Refresh(false)
        if view=="appearances" then gallery:SetVerticalScroll(math.min(offset,gallery:GetVerticalScrollRange())) end
        if view=="appearance" then body:SetVerticalScroll(math.min(saved.bodyScroll,body:GetVerticalScrollRange())) end
    end
    function root.Open(key)
        root.Stop(); panel.familyKey=key; panel.view="appearances"
        state=states[key] or {query="",level=1,zone=1,scroll=0}; states[key]=state; state.result=nil
        root.restoring=true; search:SetText(state.query); root.restoring=false; panel.Refresh(false)
    end
    local function Position(width,height)
        root:SetSize(width,height+40)
        Place(root.back,0,0,100,24); Place(breadcrumb,114,5,width-260,20); Place(root.all,width-130,0,130,24)
        Place(icon,0,32,44,44); Place(heading,56,30,width-282)
        local headingHeight=math.max(28,heading:GetStringHeight()); heading:SetHeight(headingHeight)
        Place(subtitle,56,34+headingHeight,width-282,20)
        local controlsY=math.max(86,headingHeight+60)
        local galleryY=controlsY+42
        Place(root.familyInfo,width-214,38,214,30); root.familyInfo.label:SetWidth(202)
        Place(root.backGallery,width-214,38,214,30); root.backGallery.label:SetWidth(202)
        Place(info,math.max(0,width-420),76,420,164)
        Place(search,0,controlsY,width-330,32); hint:SetWidth(width-380)
        Place(root.level,width-318,controlsY,154,32); root.level.label:SetWidth(140)
        Place(root.zone,width-154,controlsY,154,32); root.zone.label:SetWidth(140)
        Place(gallery,0,galleryY,width-22,math.max(120,height+12-galleryY)); Place(galleryBar,width-12,galleryY,12,gallery:GetHeight())
        root.columns=width>=900 and 3 or 2
        root.cardWidth=(gallery:GetWidth()-(root.columns-1)*10)/root.columns
        root.cardHeight=math.max(180,(gallery:GetHeight()-10)/2)
        canvas:SetWidth(gallery:GetWidth())
        Place(empty,8,galleryY+14,width-32,70); Place(footer,0,height+18,width,20)
        local detailY=math.max(94,headingHeight+66)
        Place(detail,0,detailY,width,math.max(160,height+16-detailY))
        local left=math.floor(width*0.42)
        Place(preview,0,0,left,detail:GetHeight()-56)
        Place(previewHelp,8,detail:GetHeight()-50,left-16,16)
        for i,b in ipairs(modelButtons) do
            local w=(left-16)/5; Place(b,(i-1)*(w+4),detail:GetHeight()-30,w,26); b.label:SetWidth(w-4)
        end
        Place(body,left+20,0,width-left-40,detail:GetHeight()); Place(bodyBar,width-12,0,12,detail:GetHeight())
        bodyChild:SetWidth(body:GetWidth()-4)
    end
    function root.Layout(width,height)
        Position(width,height)
        if panel.view=="appearance" then root.PaintDetail() elseif panel.view=="appearances" then root.Refresh() end
    end
    function root.Refresh()
        root.ResetHover(); root.family=G.Select(panel.families,panel.familyKey)
        local familyName=root.family and root.family.displayLabel or "Family unresolved"
        icon:SetTexture(root.family and root.family.iconFileID)
        local isDetail=panel.view=="appearance"; root:Show(); detail:SetShown(isDetail); gallery:SetShown(not isDetail)
        for _,widget in ipairs({search,root.level,root.zone,root.familyInfo}) do widget:SetShown(not isDetail) end
        root.backGallery:SetShown(isDetail); galleryBar:SetShown(not isDetail); empty:Hide()
        breadcrumb:SetText(Plain("› "..familyName..(isDetail and (" › "..state.result.group.label) or "")))
        breadcrumb:SetWordWrap(false)
        heading:SetText(Plain(isDetail and state.result.group.label or familyName))
        subtitle:SetText(isDetail and "Appearance details" or "Browse appearances")
        Position(root:GetWidth(),root:GetHeight()-40)
        if isDetail then
            for _,card in ipairs(root.cards) do card.preview.Clear() end
            galleryBar:Hide(); footer:SetText(Plain(familyName)); root.PaintDetail(); return
        end
        root.groups=G.Appearances(panel.entries,panel.familyKey)
        root.levels,root.zones=G.AppearanceFilters(root.groups)
        state.level=math.min(state.level,#root.levels); state.zone=math.min(state.zone,#root.zones)
        local level,zone=root.levels[state.level],root.zones[state.zone]
        root.level.label:SetText(Plain(level.label.." ›")); root.zone.label:SetText(Plain(zone.label.." ›"))
        root.results=G.FilterAppearances(root.groups,state.query,level.value,zone.value)
        root.nameHeight,root.levelHeight,root.zoneHeight=16,16,18
        measure:SetWidth(root.cardWidth-30)
        for _,result in ipairs(root.results) do
            local levelText,zoneText=G.AppearanceSummary(result.matches)
            for field,value in pairs({nameHeight=result.group.label,levelHeight=levelText,zoneHeight=zoneText}) do
                measure:SetText(Plain(value)); root[field]=math.max(root[field],measure:GetStringHeight())
            end
        end
        root.cardHeight=math.max(root.cardHeight,root.nameHeight+root.levelHeight+root.zoneHeight+116)
        hint:SetShown(state.query==""); root.clear:SetShown(state.query~="")
        local restoreScroll=state.scroll
        canvas:SetHeight(math.max(gallery:GetHeight(),math.ceil(#root.results/root.columns)*(root.cardHeight+10)-10))
        gallery:SetVerticalScroll(math.min(restoreScroll,gallery:GetVerticalScrollRange()))
        empty:SetText(panel.problem or (#root.groups==0 and "No creatures recorded in PetStable yet." or "No matching appearances. Clear search or change the filters."))
        empty:SetShown(#root.results==0)
        local unresolved=0; for _,result in ipairs(root.results) do if not result.group.displayID then unresolved=unresolved+1 end end
        footer:SetText(#root.results.." results · "..(#root.results-unresolved).." verified appearances"..(unresolved>0 and (" · "..unresolved.." unresolved") or ""))
        root.PaintCards()
    end
    search:SetScript("OnTextChanged",function()
        if not root.restoring then state.query=search:GetText(); state.scroll=0; root.Refresh() end
    end)
    root:SetScript("OnHide",root.Stop)
    root.Layout(panel:GetWidth(),panel:GetHeight()); info:Hide(); root:Hide()
    return root
end
