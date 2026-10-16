local _, NS = ...
local ROWS, ROW_HEIGHT = 4, 51
local function Plain(text) return (text or ""):gsub("|","||") end

function NS.CreateGuide(parent, window, Text)
    local panel=CreateFrame("Frame",nil,parent)
    panel:SetPoint("TOPLEFT",232,-150); panel:SetSize(600,300)
    panel.entries,panel.families,panel.problem=NS.GuideData.Build(NS.CatalogData)
    panel.rows={}; panel.offset=0; panel.familyIndex=0; panel.showEvidence=false
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
        panel.ClearFocus(); panel.familyIndex=0; search:SetText(""); panel.Refresh(true)
    end)
    panel.family=Button(panel,"Family: All >",426,0,174,function()
        panel.ClearFocus(); panel.familyIndex=(panel.familyIndex+1)%(#panel.families+1); panel.Refresh(true)
    end)
    local empty=Text(panel,14); empty:SetPoint("TOPLEFT",4,-62); empty:SetSize(222,160); empty:SetJustifyV("TOP")
    panel.empty=empty
    local count=Text(panel,12); count:SetPoint("TOPLEFT",54,-266); count:SetWidth(120); count:SetJustifyH("CENTER")
    panel.count=count
    local detailLabel=Text(panel,14,{0.78,0.94,0.65,1})
    detailLabel:SetPoint("TOPLEFT",244,-42); detailLabel:SetText("Details")
    local scroll=CreateFrame("ScrollFrame",nil,panel)
    scroll:SetPoint("TOPLEFT",244,-74); scroll:SetSize(330,216); scroll:EnableMouseWheel(true)
    local child=CreateFrame("Frame",nil,scroll); child:SetSize(328,216)
    local detail=Text(child,13); detail:SetPoint("TOPLEFT"); detail:SetWidth(326)
    detail:SetWordWrap(true); detail:SetNonSpaceWrap(true); detail:SetJustifyV("TOP"); detail:SetSpacing(2)
    scroll:SetScrollChild(child)
    panel.detail=detail; panel.scroll=scroll
    local bar=CreateFrame("Slider",nil,panel,"BackdropTemplate")
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
    panel.scrollUp=Button(panel,"^",580,74,20,function() ScrollDetails(-72) end)
    panel.scrollDown=Button(panel,"v",580,264,20,function() ScrollDetails(72) end)
    local function Details()
        local entry=panel.selected
        detail:SetText(Plain(entry and (panel.showEvidence and entry.evidence or entry.details) or "Select a creature to see its recorded details."))
        child:SetHeight(math.max(216,detail:GetStringHeight()+4))
        scroll:SetVerticalScroll(0)
        SyncScrollbar()
        panel.evidence.label:SetText(panel.showEvidence and "Show details" or "Show evidence")
        detailLabel:SetText(panel.showEvidence and "Evidence" or "Details")
    end
    panel.evidence=Button(panel,"Show evidence",474,38,126,function()
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
        local row=Button(panel,"",0,48+(i-1)*ROW_HEIGHT,228,function(self)
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
    panel.previous=Button(panel,"<",0,260,44,function() panel.ScrollRows(-ROWS) end)
    panel.next=Button(panel,">",184,260,44,function() panel.ScrollRows(ROWS) end)
    function panel.Refresh(resetOffset)
        local choice=panel.families[panel.familyIndex]
        panel.family.label:SetText(Plain("Family: "..(choice and choice.label or "All").." >"))
        panel.results=NS.GuideData.Filter(panel.entries,search:GetText(),choice and choice.key)
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
        empty:SetText(panel.problem or (#panel.entries==0 and "No creatures are recorded in this catalog yet." or "No matching creatures.\nTry another search or clear the filters."))
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
