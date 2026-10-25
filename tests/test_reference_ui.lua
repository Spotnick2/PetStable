local source=(os.getenv('LIBGLASS') or '../LibGlass'):gsub('\\','/')
dofile(source..'/tests/wow_stubs.lua'); dofile('tests/guide_stubs.lua')
SlashCmdList={}; UnitClass=function() return 'Hunter','HUNTER' end
UIParent:SetSize(1920,1080)
local ns={}
for line in io.lines('PetStable.toc') do
    if line:match('^[%a]+%.lua$') then assert(loadfile(line))('PetStable',ns) end
end
WoW.fire('ADDON_LOADED','PetStable'); ns.Toggle()
assert(#ns.guide.entries==808 and ns.db.captureSightings)
ns.settingsButton:GetScript('OnClick')(); ns.settings.Sync()
local guide=ns.guide; guide.OpenFamily('family-cat')
local ui=guide.appearances
assert(#ui.results>#ui.cards and #ui.cards==9,'full catalog uses bounded preview pool')
ui.search:SetText('Young Nightsaber')
local nightsaber=ui.results[1].group
assert(#ui.results==1 and nightsaber.displayID==nightsaber.displayIDs[1])
local listed=false; for _,id in ipairs(nightsaber.displayIDs) do listed=listed or id==11454 end; assert(listed)
local card=ui.cards[1]
assert(card.preview.actor.alpha==0 and card.preview.actor.scale==1,'unfitted unit-scale model stays invisible')
card.preview:GetScript('OnUpdate')(card.preview,0.3)
assert(card.preview.ready and card.preview.actor.alpha==1 and card.preview.actor.scale~=1)
assert(not card.result.group.modelVerified)
assert(ns.Sightings.count==0,'rendering a reference model is not a sighting')
card:GetScript('OnClick')(card)
assert(guide.view=='appearance' and ui.specific:GetText():find('not verified in game',1,true))
ui.preview:GetScript('OnUpdate')(ui.preview,0.3)
assert(ui.preview.ready and not ui.results[1].group.modelVerified)
ui.Back(); WoW.rejectModel=true
ui.cards[1].preview.Clear(); ui.cards[1].preview.Set(ui.results[1].group)
assert(not ui.cards[1].preview.ready,'missing reference models retain honest fallback')
WoW.rejectModel=nil
guide.OpenFamily('family-wolf')
local looks=#ui.results
for _,result in ipairs(ui.results) do assert(result.group.displayID,"unresolved creatures wait behind the disclosure") end
assert(ui.more:IsShown()); ui.more:GetScript('OnClick')(ui.more)
assert(#ui.results>looks and not ui.results[#ui.results].group.displayID)
ui.more:GetScript('OnClick')(ui.more); assert(#ui.results==looks)
ui.OpenAppearance(ui.results[1])
assert(ui.taming:GetText():find('Reported tameable',1,true) and ui.zoneBlock:IsShown() and not ui.openMap:IsShown())
ui.Back()
guide.OpenFamily('family-fox'); assert(#ui.results>0)
guide.OpenFamily('family-core-hound'); assert(#ui.results==0)
guide.OpenFamily(nil); assert(guide.view=='creatures')
ns.Toggle(); ns.Toggle(); assert(ns.frame:IsShown())
io.write('PASS: shipped TOC, full reference gallery, model fallback, proof separation, settings and navigation\n')
