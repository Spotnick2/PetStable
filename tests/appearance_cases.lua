return function(ns)
    local guide=ns.guide
    local ui=guide.appearances
    local function Click(button) assert(button:GetScript("OnClick"))(button) end
    local function Tick(preview,seconds)
        local fn=preview:GetScript("OnUpdate"); if fn then fn(preview,seconds or 0.3) end
    end
    ns.SelectPage("guide"); guide.OpenFamily("family-cat")
    assert(ui.columns==3 and #ui.results==1 and not guide.browser:IsShown())
    local card=ui.cards[1]; Tick(card.preview)
    assert(card.preview.ready and card.preview.actor.display==1059)
    assert(card.preview.actor.animation[3]==0 and not card.preview:GetScript("OnUpdate"),"gallery model must settle without a continuing update")
    Click(card)
    assert(guide.view=="appearance" and #ui.detailEntries==1 and not ui.sourceText:IsShown())
    Tick(ui.preview)
    assert(ui.preview.ready and ui.modelButtons[1]:IsShown())
    local originalScale=ui.preview.actor.scale
    Click(ui.modelButtons[4]); assert(ui.preview.actor.scale>originalScale)
    Click(ui.modelButtons[1]); assert(ui.preview.actor.yaw<0.5)
    Click(ui.modelButtons[3]); assert(ui.preview.actor.yaw==0.5 and ui.preview.zoom==1)
    rawset(_G,"GetCursorPosition",function() return 100,0 end)
    ui.preview:GetScript("OnMouseDown")(ui.preview,"LeftButton")
    rawset(_G,"GetCursorPosition",function() return 125,0 end)
    Tick(ui.preview); assert(ui.preview.actor.yaw>0.5)
    ui.preview:GetScript("OnMouseUp")(ui.preview); assert(not ui.preview:GetScript("OnUpdate"))
    Click(ui.sources); assert(ui.sourceText:IsShown() and ui.sourceText:GetText():find("Portrait verification",1,true))
    Click(ui.copy); assert(guide.HasFocus() and ui.urls:GetText():find("https://github.com/",1,true))
    ns.SelectPage("pets"); assert(not guide.HasFocus() and not ui.preview.actor.display)
    ns.SelectPage("guide"); Tick(ui.preview); assert(ui.preview.actor.display==1059)
    Click(ui.backGallery); assert(guide.view=="appearances" and not ui.preview.actor.display)
    guide.OpenFamily("family-tallstrider")
    card=ui.cards[1]; assert(not card.preview.actor.display and not card.preview:GetScript("OnUpdate"))
    Click(card); assert(ui.specific:GetText():find("Observer context is not a spawn location",1,true))
    assert(not ui.modelButtons[1]:IsShown() and not ui.preview.actor.display)
    Click(ui.backGallery)
    Click(ui.level); Click(ui.zone); ui.search:SetText("Ornery")
    assert(#ui.results==1)
    Click(ui.cards[1]); Click(ui.backGallery)
    assert(ui.search:GetText()=="Ornery" and ui.level.label:GetText():find("9",1,true) and ui.zone.label:GetText():find("unknown",1,true))
    ui.search:SetText("missing"); assert(#ui.results==0 and ui.empty:IsShown())
    Click(ui.clear); assert(#ui.results==1)

    -- Many appearances and shared creatures exercise virtualization, record-level
    -- filtering, all/matching disclosure and retained scroll at both window sizes.
    local original=guide.entries
    local fixtures={}
    for i=1,24 do
        fixtures[i]={key="gallery-"..i,label="Creature "..i,family="Cat",familyKey="family-cat",
            displayID=1000+i,modelVerified=true,portraitVerified=true,observedLevel=i,
            details="Specific facts for "..i,evidence="Evidence for "..i,sourceSummary="Name: observed",sourceURLs={"https://example.com/"..i}}
    end
    fixtures[25]={key="shared",label="Shared appearance at another location",family="Cat",familyKey="family-cat",
        displayID=1001,modelVerified=true,portraitVerified=true,observedLevel=30,spawn={mapID=123,x=0.2,y=0.3},
        details="Different creature",evidence="Different evidence"}
    guide.entries=fixtures; guide.OpenFamily("family-cat"); Click(ui.clear)
    assert(#ui.results==24 and #ui.cards==9 and ui.gallery:GetVerticalScrollRange()>0)
    local widgets=#WoW.widgets
    ui.galleryBar:SetValue(ui.gallery:GetVerticalScrollRange())
    local savedScroll=ui.gallery:GetVerticalScroll()
    for _,c in ipairs(ui.cards) do if not c:IsShown() then assert(not c.preview.actor.display) end end
    assert(#WoW.widgets==widgets,"scrolling must reuse model cards")
    Click(ui.cards[1]); Click(ui.backGallery)
    assert(ui.gallery:GetVerticalScroll()==savedScroll)
    ui.search:SetText("Creature 1"); assert(ui.gallery:GetVerticalScroll()==0)
    local shared
    for _,result in ipairs(ui.results) do if result.group.displayID==1001 then shared=result end end
    ui.OpenAppearance(shared)
    assert(#ui.detailEntries==1 and ui.showAll:IsShown())
    Click(ui.showAll); assert(#ui.detailEntries==2)
    Click(ui.rows[2]); assert(ui.specific:GetText()=="Different creature")
    Click(ui.showAll); assert(#ui.detailEntries==1 and ui.specific:GetText()=="Specific facts for 1")
    Click(ui.backGallery); assert(ui.search:GetText()=="Creature 1")
    local w,h=ns.frame:GetWidth(),ns.frame:GetHeight()
    ns.frame:SetSize(800,560); assert(ui.columns==2 and ui.cardHeight>=180)
    fixtures[1].label=string.rep("Long creature name ",12)
    ui.search:SetText(""); ui.OpenAppearance(shared)
    assert(ui.rows[1]:GetHeight()>76,"long creature names must grow their rows instead of clipping")
    Click(ui.backGallery)
    ns.frame:SetSize(w,h); assert(ui.columns==3)
    -- Rejected models and bounds timeouts must leave no stale model or inert controls.
    WoW.rejectModel=true; ui.OpenAppearance(shared)
    assert(not ui.preview.ready and not ui.preview.actor.display and not ui.modelButtons[1]:IsShown())
    WoW.rejectModel=nil; Click(ui.backGallery)
    WoW.modelTimeout=true; ui.OpenAppearance(shared); Tick(ui.preview,4.1)
    assert(not ui.preview.ready and not ui.preview.actor.display and not ui.preview:GetScript("OnUpdate"))
    WoW.modelTimeout=nil
    local create=CreateFrame
    rawset(_G,"CreateFrame",function(kind,...) if kind=="ModelScene" then error("unsupported") end; return create(kind,...) end)
    local unavailable=ns.CreateAppearancePreview(ui, function(host,size)
        local text=host:CreateFontString(nil,"OVERLAY"); text:SetFont("Fonts\\FRIZQT__.TTF",size,""); return text
    end,false)
    unavailable:SetSize(200,150); unavailable.Set(shared.group)
    assert(not unavailable.actor and not unavailable:GetScript("OnUpdate"))
    unavailable.Clear(); rawset(_G,"CreateFrame",create)
    guide.entries=original; guide.OpenFamily("family-tallstrider"); Click(ui.familyInfo)
    assert(ui.info:IsShown()); Click(ui.all); assert(guide.view=="creatures" and not ui.info:IsShown())
    guide.entries=original; guide.ShowFamilies()
    io.write("PASS: appearance gallery/detail navigation, models, fallbacks, sources, filters and pooled scrolling\n")
end
