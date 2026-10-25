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
        bar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); bar:SetBackdropColor(0.06,0.08,0.07,0.45)
        bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8"); bar:GetThumbTexture():SetVertexColor(0.38,0.46,0.4,0.75)
        local syncing=false
        function bar.Sync()
            if syncing then return end; syncing=true
            local range=math.max(0,scroll:GetVerticalScrollRange())
            if range<1 then range=0 end -- Ignore subpixel overflow when all cards fit.
            local value=math.max(0,math.min(range,scroll:GetVerticalScroll()))
            bar:SetMinMaxValues(0,range); bar:SetValue(value); bar:SetShown(range>0)
            bar:GetThumbTexture():SetSize(6,math.max(24,bar:GetHeight()*scroll:GetHeight()/math.max(1,scroll:GetHeight()+range)))
            bar:GetThumbTexture():SetShown(range>0)
            if scroll:GetVerticalScroll()~=value then scroll:SetVerticalScroll(value) end
            syncing=false
        end
        -- The wheel eases toward its target instead of jumping a whole step.
        local animator,target=CreateFrame("Frame",nil,host)
        function bar.StopEasing() target=nil; animator:SetScript("OnUpdate",nil) end
        local function Ease(_,elapsed)
            local current=scroll:GetVerticalScroll()
            target=math.max(0,math.min(scroll:GetVerticalScrollRange(),target))
            local value=current+(target-current)*math.min(1,elapsed*15)
            if math.abs(target-value)<0.5 then value=target; bar.StopEasing() end
            scroll:SetVerticalScroll(value)
        end
        bar:SetScript("OnValueChanged",function(_,value)
            if not syncing then panel.ClearFocus(); bar.StopEasing(); scroll:SetVerticalScroll(value) end
        end)
        scroll:SetScript("OnScrollRangeChanged",bar.Sync)
        local function Wheel(_,delta)
            panel.ClearFocus(); root.ResetHover()
            target=math.max(0,math.min(scroll:GetVerticalScrollRange(),(target or scroll:GetVerticalScroll())-delta*90))
            animator:SetScript("OnUpdate",Ease)
        end
        scroll:SetScript("OnMouseWheel",Wheel); bar:EnableMouseWheel(true); bar:SetScript("OnMouseWheel",Wheel)
        return bar,Wheel
    end
    local galleryBar,Wheel=Scrollbar(root,gallery); root.galleryBar=galleryBar
    local empty=Label(root,14); root.empty=empty
    local footer=Label(root,12); root.footer=footer
    root.more=Button(root,"",function() state.unresolved=not state.unresolved; root.Refresh() end)
    local measure,measureName=Label(root,12),Label(root,15); measure:Hide(); measureName:Hide()
    root.cards={}
    -- Up to three columns, two visible rows plus one partial row; reuse the nine slots.
    for i=1,9 do
        local card=Button(canvas,"",function(self) if self.result then root.OpenAppearance(self.result) end end)
        card.preview=NS.CreateAppearancePreview(card,Text,false)
        -- A darker band carries the look's name and where to find it.
        card.band=card:CreateTexture(nil,"BORDER"); card.band:SetColorTexture(0,0,0,0.24)
        card.title=Label(card,15); card.title:SetWordWrap(true)
        card.level=Label(card,12); card.level:SetTextColor(0.72,0.78,0.74,1)
        card.arrow=Label(card,20); card.arrow:SetText("›")
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
    local locationTitle=Label(bodyChild,20); locationTitle:SetText("Where to tame this look")
    local matchText=Label(bodyChild,12); matchText:SetTextColor(0.72,0.78,0.74,1)
    root.showAll=Button(bodyChild,"Show all associated creatures",function() state.showAll=not state.showAll; root.PaintDetail() end)
    local columnNames={Label(bodyChild,12),Label(bodyChild,12),Label(bodyChild,12)}
    columnNames[1]:SetText("Creature"); columnNames[2]:SetText("Level"); columnNames[3]:SetText("Location")
    local rows={}; root.rows=rows
    local rule=bodyChild:CreateTexture(nil,"ARTWORK"); rule:SetColorTexture(0.35,0.43,0.39,0.4)
    local taming,spawn=Label(bodyChild,13),Label(bodyChild,13); root.taming,root.spawn=taming,spawn
    -- The selected creature's zone, with the world map when the client knows it.
    local zone=CreateFrame("Frame",nil,bodyChild,"BackdropTemplate"); root.zoneBlock=zone
    zone:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    zone:SetBackdropColor(0.03,0.045,0.04,0.9); zone:SetBackdropBorderColor(0.3,0.4,0.34,0.6)
    local zoneName,zoneParent=Label(zone,17),Label(zone,12); root.zoneName=zoneName
    zoneParent:SetTextColor(0.72,0.78,0.74,1)
    root.openMap=Button(zone,"Open zone map",function(self)
        local open=rawget(_G,"OpenWorldMap")
        if self.mapID and type(open)=="function" then pcall(open,self.mapID) end
    end)
    local selectedTitle=Label(bodyChild,16)
    local specific=Label(bodyChild,13); root.specific=specific
    local familyText=Label(bodyChild,13); root.familyText=familyText
    root.familyRow=Button(bodyChild,"Family abilities & diet ›",function() state.family=not state.family; root.PaintDetail() end)
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
        root.StopLoading(); galleryBar.StopEasing(); bodyBar.StopEasing()
        preview.Clear(); for _,card in ipairs(root.cards) do card.preview.Clear() end
        root.ResetHover(); root.ClearFocus(); info:Hide()
    end
    -- Models load only once scrolling rests: passing cards never load one, and
    -- each load pulls a creature's model and textures into client memory.
    local loader=CreateFrame("Frame",nil,root)
    function root.StopLoading() loader:SetScript("OnUpdate",nil) end
    local function LoadCards()
        root.StopLoading()
        for _,card in ipairs(root.cards) do if card.result then card.preview.Set(card.result.group) end end
    end
    local function Settle(self,elapsed)
        self.wait=self.wait-elapsed; if self.wait<=0 then LoadCards() end
    end
    function root.Caption(matches)
        local level,zone=G.AppearanceSummary(matches)
        return level.."   ·   "..zone
    end
    function root.PaintCards(scrolling)
        if panel.view~="appearances" or not root.results or not root.nameHeight then return end
        local cols,stride,pool=root.columns,root.cardHeight+12,#root.cards
        local offset=gallery:GetVerticalScroll(); local first=math.floor(offset/stride)*cols
        -- A result keeps its card while visible, so crossing a row reloads only that row.
        local shown={}
        for index=first+1,first+pool do
            local result=root.results[index]
            local y=math.floor((index-1)/cols)*stride
            if result and y<offset+gallery:GetHeight() and y+root.cardHeight>offset then
                local card=root.cards[(index-1)%pool+1]; shown[card]=true
                if card.result~=result or card.layout~=root.layout then
                    if card.result~=result then card.preview.Clear(); card.ResetHover() end
                    card.result=result; card.layout=root.layout
                    local bandHeight=root.nameHeight+root.captionHeight+24
                    local bandY=root.cardHeight-bandHeight
                    Place(card.preview,8,8,root.cardWidth-16,bandY-12)
                    Place(card.band,1,bandY,root.cardWidth-2,bandHeight-1)
                    Place(card.title,16,bandY+10,root.cardWidth-60,root.nameHeight); card.title:SetText(Plain(result.group.label))
                    Place(card.level,16,bandY+14+root.nameHeight,root.cardWidth-60,root.captionHeight)
                    card.level:SetText(Plain(root.Caption(result.matches)))
                    Place(card.arrow,root.cardWidth-32,bandY+bandHeight/2-12,20,24)
                end
                Place(card,((index-1)%cols)*(root.cardWidth+12),y,root.cardWidth,root.cardHeight); card:Show()
            end
        end
        for _,card in ipairs(root.cards) do
            if not shown[card] then card.result=nil; card:Hide(); card.preview.Clear(); card.ResetHover() end
        end
        if scrolling then loader.wait=0.15; loader:SetScript("OnUpdate",Settle) else LoadCards() end
        state.scroll=offset; galleryBar.Sync()
    end
    gallery:SetScript("OnVerticalScroll",function() root.ResetHover(); root.PaintCards(true) end)
    function root.PaintDetail()
        if not state.result then return end
        local group=state.result.group
        group.seen=false
        if NS.Sightings then
            for _,entry in ipairs(group.entries) do
                for _,id in ipairs(group.displayIDs or {}) do
                    if NS.Sightings.Seen(entry.familyID,id) then group.seen=true end
                end
            end
        end
        local entries=G.ByLevel(state.showAll and group.entries or state.result.matches)
        local hunterLevel,cap=NS.PlayerLevel(),NS.LevelCap()
        local hiddenAbove=0
        if cap then for _,entry in ipairs(group.entries) do if G.AboveLevel(entry,cap) then hiddenAbove=hiddenAbove+1 end end end
        root.detailEntries=entries
        local width=body:GetWidth()-4; local y=0
        local function TextRow(widget,text,size)
            widget:Show(); if text then widget:SetText(Plain(text)) end
            Place(widget,0,y,width); y=y+math.max(size or 18,widget:GetStringHeight())+12
        end
        local function Disclosure(button,open,text)
            Place(button,0,y,width,40); button.label:SetWidth(width-24); button.label:SetJustifyH("LEFT")
            button.label:SetText(text..(open and "  ‹" or "  ›")); y=y+50
        end
        -- Only a recorded spawn makes this a place to tame; website zones are reports.
        local located=false
        for _,entry in ipairs(group.entries) do if entry.spawn then located=true end end
        locationTitle:SetText(located and "Where to tame this look" or "Reported locations for this look")
        TextRow(locationTitle)
        local filtered=#state.result.matches<#group.entries
        local status=group.modelVerified and "Verified in game" or "Listed by references · Awaiting in-game confirmation"
        if group.seen then status=status.." · Seen by you" end
        if group.look and group.look.availability~="obtainable" then
            status=status.."\nPetopia lists this look as "..(group.look.availability=="unused" and "unused in game" or group.look.availability).."."
        end
        if hiddenAbove>0 and not state.showAll then
            status=status.."\n"..hiddenAbove..(hiddenAbove==1 and " creature is" or " creatures are").." above your level "..cap.." and hidden. Settings can turn the level filter off."
        end
        if filtered then status=status.."\n"..(state.showAll and "Showing all associated creatures." or "Showing creatures matching your search and filters.") end
        TextRow(matchText,status)
        root.showAll:SetShown(filtered)
        if filtered then
            root.showAll.label:SetText(state.showAll and "Show matching creatures" or "Show all associated creatures")
            Place(root.showAll,0,y,width,28); root.showAll.label:SetWidth(width-12); y=y+40
        end
        -- Column headings share the row widths, including at the minimum window size.
        Place(columnNames[1],16,y,width*0.46-20,20)
        Place(columnNames[2],width*0.46,y,width*0.2-8,20)
        Place(columnNames[3],width*0.66,y,width*0.34-8,20); y=y+26
        for i,entry in ipairs(entries) do
            local row=rows[i]
            if not row then
                row=Button(bodyChild,"",function(self)
                    state.selected=self.entry; state.sources=false; state.technical=false; state.copy=false; root.PaintDetail()
                end)
                row.name=Label(row,13); row.level=Label(row,13); row.zone=Label(row,13); rows[i]=row
                row.accent=row:CreateTexture(nil,"OVERLAY"); row.accent:SetColorTexture(0.62,0.8,0.5,1)
                row.accent:SetPoint("TOPLEFT"); row.accent:SetPoint("BOTTOMLEFT"); row.accent:SetWidth(3)
            end
            row.entry=entry; row:Show(); Place(row,0,y,width,44)
            Place(row.name,16,12,width*0.46-20,20); row.name:SetText(Plain(entry.label))
            Place(row.level,width*0.46,12,width*0.2-8,20); row.level:SetText(Plain(G.Level(entry)..(G.AboveLevel(entry,hunterLevel) and "\nAbove your level" or "")))
            Place(row.zone,width*0.66,12,width*0.34-8,20); row.zone:SetText(Plain(G.Zone(entry)))
            local rowHeight=math.max(44,row.name:GetStringHeight()+24,row.level:GetStringHeight()+24,row.zone:GetStringHeight()+24)
            row:SetHeight(rowHeight)
            row.name:SetHeight(rowHeight-24); row.level:SetHeight(rowHeight-24); row.zone:SetHeight(rowHeight-24)
            y=y+rowHeight+6
        end
        for i=#entries+1,#rows do rows[i].entry=nil; rows[i]:Hide() end
        local selected=G.Select(entries,state.selected and state.selected.key); state.selected=selected
        for _,row in ipairs(rows) do
            row.active=row.entry==selected and selected~=nil; row.accent:SetShown(row.active); row.Paint()
        end
        y=y+8; Place(rule,0,y,width,1); y=y+18
        local spawnText="Exact location not recorded"
        if selected and selected.spawn then
            spawnText=string.format("UI map %d (%.1f%%, %.1f%%)",selected.spawn.mapID,selected.spawn.x*100,selected.spawn.y*100)
        end
        taming:SetText(Plain("Taming\n"..(selected and selected.taming or "Not recorded")))
        spawn:SetText(Plain("Spawn\n"..spawnText))
        Place(taming,0,y,width/2-12); Place(spawn,width/2,y,width/2)
        y=y+math.max(40,taming:GetStringHeight(),spawn:GetStringHeight())+16
        zone:SetShown(selected~=nil)
        if selected then
            local mapID,mapName,parentName=G.ZoneMap(selected)
            local extra=selected.zoneNames and #selected.zoneNames>1 and (" +"..(#selected.zoneNames-1).." more") or ""
            local zoneLabel=(mapName or (selected.zoneNames and selected.zoneNames[1]) or G.Zone(selected))..extra
            if not selected.spawn and (selected.zoneNames and #selected.zoneNames>0) then zoneLabel=zoneLabel.." (reference)" end
            zoneName:SetText(Plain(zoneLabel))
            zoneParent:SetText(Plain(parentName or (mapID and "" or "No map for this zone in your client")))
            root.openMap.mapID=mapID; root.openMap:SetShown(mapID~=nil and type(rawget(_G,"OpenWorldMap"))=="function")
            Place(zone,0,y,width,72); Place(zoneName,16,14,width-200,22); Place(zoneParent,16,40,width-200,18)
            Place(root.openMap,width-168,20,152,32); root.openMap.label:SetWidth(144); y=y+84
        end
        Disclosure(root.familyRow,state.family,"Family abilities & diet")
        familyText:SetShown(state.family==true)
        if state.family then
            local family=root.family
            local diet=family and family.diet and #family.diet>0
                and (table.concat(family.diet,", ").." (client family table, build "..family.traitBuild..")") or "Not recorded"
            TextRow(familyText,(family and family.displayLabel or "Family").."\nRole: Unknown\nDiet: "..diet.."\nLearnable family abilities: Not verified\nCreature observations are not family ability eligibility.")
        end
        Disclosure(root.sources,state.sources,"Sources & observations")
        -- Facts are set even while collapsed, so reopening never shows stale text.
        specific:SetText(Plain(selected and selected.details or "No creature records."))
        selectedTitle:SetText(Plain(selected and selected.label or "Select a creature"))
        for _,widget in ipairs({selectedTitle,specific,sourceText,root.technical,root.copy}) do widget:SetShown(state.sources==true) end
        technicalText:SetShown(state.sources and state.technical or false); urls:SetShown(state.sources and state.copy or false); urlHelp:SetShown(state.sources and state.copy or false)
        if state.sources then
            TextRow(selectedTitle); TextRow(specific)
            local skinNote=#(group.displayIDs or {})>1 and ("Same skin at different sizes: displays "..table.concat(group.displayIDs,", ")..".\n\n") or ""
            local lookNote=group.look and ("Look name from Petopia, matched by the skin texture "..group.look.texture..".\n"..group.look.url.."\n\n") or ""
            TextRow(sourceText,skinNote..lookNote.."Facts below apply individually to "..(selected and selected.label or "this creature")..". They do not certify other fields or the current build.\n\n"..(selected and selected.sourceSummary or "No sources recorded."))
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
        local isDetail=panel.view=="appearance"
        Place(icon,0,0,44,44); Place(root.back,56,0,96,22); Place(breadcrumb,160,3,width-600,18)
        Place(heading,56,22,width-420)
        local headingHeight=math.max(28,heading:GetStringHeight()); heading:SetHeight(headingHeight)
        Place(root.familyInfo,width-214,0,214,30); root.familyInfo.label:SetWidth(202)
        Place(root.backGallery,width-214,0,214,30); root.backGallery.label:SetWidth(202)
        Place(root.all,width-344,0,122,30); root.all.label:SetWidth(112)
        Place(info,math.max(0,width-420),36,420,164)
        local controlsY=math.max(56,headingHeight+28)
        Place(search,0,controlsY,width-330,32); hint:SetWidth(width-380)
        Place(root.level,width-318,controlsY,154,32); root.level.label:SetWidth(140)
        Place(root.zone,width-154,controlsY,154,32); root.zone.label:SetWidth(140)
        if isDetail then Place(subtitle,56,24+headingHeight,width-420,18) else Place(subtitle,0,controlsY+42,width-24,18) end
        local galleryY=controlsY+66
        Place(gallery,0,galleryY,width-22,math.max(120,height+6-galleryY)); Place(galleryBar,width-8,galleryY,6,gallery:GetHeight())
        -- Two wide columns keep models large; a wide window fits a third.
        root.columns=width>=1300 and 3 or 2
        root.cardWidth=(gallery:GetWidth()-(root.columns-1)*12)/root.columns
        root.cardHeight=math.max(200,(gallery:GetHeight()-12)/2)
        canvas:SetWidth(gallery:GetWidth())
        Place(empty,8,galleryY+14,width-32,70)
        Place(root.more,0,height+12,340,26); root.more.label:SetWidth(330)
        Place(footer,width-420,height+18,420,20); footer:SetJustifyH("RIGHT")
        local detailY=headingHeight+54
        Place(detail,0,detailY,width,math.max(160,height+16-detailY))
        local left=math.floor(width*0.48)
        Place(preview,0,0,left,detail:GetHeight()-56)
        Place(previewHelp,8,detail:GetHeight()-50,left-16,16)
        for i,b in ipairs(modelButtons) do
            local w=(left-16)/5; Place(b,(i-1)*(w+4),detail:GetHeight()-30,w,26); b.label:SetWidth(w-4)
        end
        Place(body,left+24,0,width-left-44,detail:GetHeight()); Place(bodyBar,width-8,0,6,detail:GetHeight())
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
        root.backGallery:SetShown(isDetail); galleryBar:SetShown(not isDetail); empty:Hide(); root.more:Hide()
        breadcrumb:SetText(Plain("› "..familyName..(isDetail and (" › "..state.result.group.label) or "")))
        breadcrumb:SetWordWrap(false)
        heading:SetText(Plain(isDetail and state.result.group.label or familyName))
        local reference=isDetail and state.result.group.referencePreview and not state.result.group.modelVerified
        subtitle:SetText(isDetail and ((state.result.group.family or "Family").." appearance"..(reference and " · reference preview" or ""))
            or "Choose a look to see where to tame it. Includes website references.")
        Position(root:GetWidth(),root:GetHeight()-40)
        if isDetail then
            for _,card in ipairs(root.cards) do card.preview.Clear() end
            -- The matches were captured when the look opened; the level, the level filter and the
            -- search may have changed since, so recompute them for this look before painting.
            local group=state.result.group
            local level=root.levels and root.levels[state.level]
            local zone=root.zones and root.zones[state.zone]
            local again=G.FilterAppearances({group},state.query,level and level.value,zone and zone.value,NS.LevelCap())
            state.result={group=group,matches=again[1] and again[1].matches or {}}
            galleryBar:Hide(); footer:SetText(Plain(familyName)); root.PaintDetail(); return
        end
        root.groups=G.Appearances(panel.entries,panel.familyKey)
        root.levels,root.zones=G.AppearanceFilters(root.groups)
        state.level=math.min(state.level,#root.levels); state.zone=math.min(state.zone,#root.zones)
        local level,zone=root.levels[state.level],root.zones[state.zone]
        root.level.label:SetText(Plain(level.label.." ›")); root.zone.label:SetText(Plain(zone.label.." ›"))
        -- Creatures without a matched display sit behind a disclosure below the looks,
        -- unless nothing else matches.
        local resolved,unresolved={},{}
        for _,result in ipairs(G.FilterAppearances(root.groups,state.query,level.value,zone.value,NS.LevelCap())) do
            if result.group.displayID then resolved[#resolved+1]=result else unresolved[#unresolved+1]=result end
        end
        root.results=resolved
        if state.unresolved or #resolved==0 then for _,result in ipairs(unresolved) do root.results[#root.results+1]=result end end
        root.more:SetShown(#unresolved>0 and #resolved>0)
        local plural=#unresolved==1 and " creature" or " creatures"
        root.more.label:SetText(state.unresolved and ("Hide "..#unresolved..plural.." without a matched look  ‹")
            or (#unresolved..plural.." without a matched look  ›"))
        root.nameHeight,root.captionHeight=18,16; root.layout={}
        measure:SetWidth(root.cardWidth-60); measureName:SetWidth(root.cardWidth-60)
        for _,result in ipairs(root.results) do
            measureName:SetText(Plain(result.group.label)); root.nameHeight=math.max(root.nameHeight,measureName:GetStringHeight())
            measure:SetText(Plain(root.Caption(result.matches))); root.captionHeight=math.max(root.captionHeight,measure:GetStringHeight())
        end
        root.cardHeight=math.max(root.cardHeight,root.nameHeight+root.captionHeight+24+110)
        hint:SetShown(state.query==""); root.clear:SetShown(state.query~="")
        local restoreScroll=state.scroll
        canvas:SetHeight(math.max(gallery:GetHeight(),math.ceil(#root.results/root.columns)*(root.cardHeight+12)-12))
        gallery:SetVerticalScroll(math.min(restoreScroll,gallery:GetVerticalScrollRange()))
        local cap=NS.LevelCap()
        local belowCap=cap and #G.FilterAppearances(root.groups,state.query,level.value,zone.value)>0
        empty:SetText(panel.problem or (#root.groups==0 and "No creatures recorded in PetStable yet."
            or (belowCap and ("Every matching creature is above your level "..cap..". Settings can turn the level filter off.")
            or "No matching appearances. Clear search or change the filters.")))
        empty:SetShown(#root.results==0)
        local verified=0
        for _,result in ipairs(resolved) do
            if result.group.modelVerified or result.group.portraitVerified then verified=verified+1 end
        end
        footer:SetText(#resolved..(#resolved==1 and " look · " or " looks · ")..verified.." verified · "..(#resolved-verified).." reference"
            ..(#unresolved>0 and (" · "..#unresolved.." unresolved") or ""))
        root.PaintCards()
    end
    search:SetScript("OnTextChanged",function()
        if not root.restoring then state.query=search:GetText(); state.scroll=0; root.Refresh() end
    end)
    root:SetScript("OnHide",root.Stop)
    root.Layout(panel:GetWidth(),panel:GetHeight()); info:Hide(); root:Hide()
    return root
end
