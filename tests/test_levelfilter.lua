-- The level filter: creatures and ranks above the hunter's level are hidden, and it can be turned off.
local source=(os.getenv('LIBGLASS') or '../LibGlass'):gsub('\\','/')
dofile(source..'/tests/wow_stubs.lua'); dofile('tests/guide_stubs.lua')
SlashCmdList={}
local class,level='HUNTER',12
UnitClass=function() return class=='HUNTER' and 'Hunter' or 'Mage',class end
UnitLevel=function() return level end
UIParent:SetSize(1920,1080)
local ns={}
for line in io.lines('PetStable.toc') do
    if line:match('^[%a]+%.lua$') then assert(loadfile(line))('PetStable',ns) end
end
WoW.fire('ADDON_LOADED','PetStable'); ns.Toggle()
local G,U=ns.GuideData,ns.UpgradesData
assert(ns.db.filterToLevel==true and ns.LevelCap()==12 and ns.PlayerLevel()==12)

-- The helpers: unknown levels are never hidden, and the lowest listed level decides.
local function E(low,high,observed) return {key='k'..tostring(low or observed),label='x',levelMin=low,levelMax=high,observedLevel=observed} end
assert(G.AboveLevel(E(13,15),12) and not G.AboveLevel(E(12,15),12) and not G.AboveLevel(E(nil,nil,nil),12))
assert(G.AboveLevel(E(nil,nil,20),12) and not G.AboveLevel(E(40,50),nil))
local ordered=G.ByLevel({E(30,31),E(nil,nil,nil),E(5,6),E(nil,nil,9)})
assert(ordered[1].levelMin==5 and ordered[2].observedLevel==9 and ordered[3].levelMin==30 and ordered[4].levelMin==nil and ordered[4].observedLevel==nil)

-- All Creatures: only creatures whose lowest level is within the hunter's level (or unknown).
local guide=ns.guide
guide.OpenFamily(nil)
local filtered=#guide.results
for _,entry in ipairs(guide.results) do assert(not G.AboveLevel(entry,12),entry.key) end
level=60; ns.RefreshFilters(); guide.Refresh(true)
local atSixty=#guide.results
level=12; ns.RefreshFilters(); guide.Refresh(true)
assert(filtered==#guide.results and filtered<atSixty and filtered>0,'a higher level shows more: '..filtered..' < '..atSixty)

-- Turning the filter off shows every creature, with the same count as the catalog.
SlashCmdList.PETSTABLE('levelfilter off')
assert(ns.db.filterToLevel==false and ns.LevelCap()==nil)
guide.Refresh(true); local unfiltered=#guide.results
assert(unfiltered==#guide.entries and unfiltered>=atSixty)
SlashCmdList.PETSTABLE('levelfilter on'); guide.Refresh(true)
assert(ns.db.filterToLevel==true and #guide.results==filtered)

-- Other classes are never filtered.
class='MAGE'; assert(ns.LevelCap()==nil and ns.PlayerLevel()==nil)
guide.Refresh(true); assert(#guide.results==unfiltered)
class='HUNTER'; guide.Refresh(true)

-- Appearance galleries lose looks whose creatures are all above the level; the detail says so.
guide.OpenFamily('family-cat')
local ui=guide.appearances
local looks=#ui.results
ns.db.filterToLevel=false; guide.OpenFamily('family-cat'); ui.Refresh()
local allLooks=#ui.results
assert(looks<=allLooks,'the level filter never adds looks')
ns.db.filterToLevel=true; ui.Refresh()
assert(#ui.results==looks)
for _,result in ipairs(ui.results) do
    for _,entry in ipairs(result.matches) do assert(not G.AboveLevel(entry,12)) end
end

-- An open look follows the filter and the hunter's level without going back to the gallery.
do
    local mixed
    for _,family in ipairs(guide.families) do
        ns.db.filterToLevel=true; guide.OpenFamily(family.key)
        for _,result in ipairs(ui.results) do
            local above,below=0,0
            for _,entry in ipairs(result.group.entries) do
                if G.AboveLevel(entry,12) then above=above+1 elseif entry.levelMin or entry.observedLevel then below=below+1 end
            end
            if above>0 and below>0 then mixed=result; break end
        end
        if mixed then break end
    end
    assert(mixed,'the catalog has a look with creatures both above and within level 12')
    ui.OpenAppearance(mixed)
    local function Shown() local n=0; for _,e in ipairs(ui.detailEntries) do n=n+1 end; return n end
    local within=Shown()
    assert(within==#mixed.matches and within<#mixed.group.entries)
    ns.db.filterToLevel=false; ns.RefreshFilters()
    assert(Shown()==#mixed.group.entries,'turning the filter off reveals the hidden creatures in the open look')
    ns.db.filterToLevel=true; ns.RefreshFilters()
    assert(Shown()==within,'turning it back on hides them again without leaving the look')
    level=60; ns.levelHint=nil; ns.RefreshFilters()
    assert(Shown()>within,'a level-up reveals newly eligible creatures')
    level=12; ns.RefreshFilters(); assert(Shown()==within)
    ui.Back()
end

-- Ability Upgrades hides ranks above the level and teachers above it.
local abilities=U.Build(ns.CatalogData,guide.entries,guide.families)
local cap=12
local visible=U.Filter(abilities,nil,cap)
assert(#visible>0 and #visible<=#abilities)
for _,ability in ipairs(visible) do
    local any=false
    for _,rank in ipairs(ability.ranks) do if U.Visible(rank,cap) then any=true end end
    assert(any,ability.name)
end
for _,ability in ipairs(abilities) do
    for _,rank in ipairs(ability.ranks) do
        for _,entry in ipairs(U.Teachers(rank,nil,cap)) do assert(not G.AboveLevel(entry,cap)) end
        assert(#U.Teachers(rank,nil,nil)==#rank.teachers)
    end
end
assert(not U.Visible({petLevel=40},12) and U.Visible({petLevel=8},12) and U.Visible({petLevel=40},nil) and U.Visible({},12))

-- The Settings button flips it and repaints.
ns.settingsButton:GetScript('OnClick')(); ns.settings.Sync()
local button
for _,f in ipairs(WoW.frames) do if f.label and f.label.GetText and f.label:GetText()=='Filter to your level: On' then button=f end end
assert(button,'Settings has the level filter button')
button:GetScript('OnClick')(button)
assert(ns.db.filterToLevel==false and button.label:GetText()=='Filter to your level: Off')
button:GetScript('OnClick')(button); assert(ns.db.filterToLevel==true)
SlashCmdList.PETSTABLE('levelfilter off')
assert(button.label:GetText()=='Filter to your level: Off','the slash command updates an open Settings panel')
SlashCmdList.PETSTABLE('levelfilter on')
assert(button.label:GetText()=='Filter to your level: On')
io.write('PASS: level filter hides creatures and ranks above the hunter, keeps unknown levels, other classes, and turns off\n')
