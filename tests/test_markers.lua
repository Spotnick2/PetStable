-- Pet Guide family markers and opening on the active pet's family.
local source=(os.getenv('LIBGLASS') or '../LibGlass'):gsub('\\','/')
dofile(source..'/tests/wow_stubs.lua'); dofile('tests/guide_stubs.lua')
SlashCmdList={}; UnitClass=function() return 'Hunter','HUNTER' end
UIParent:SetSize(1920,1080)
function time() return 1700000000 end
UnitExists=function(unit) return unit=='pet' end
UnitName=function(unit) return unit=='pet' and 'Whiskers' or 'Hunt' end
UnitLevel=function() return 12 end
UnitCreatureFamily=function() return 'Cat',2 end
GetRealmName=function() return 'Realm' end
GetBuildInfo=function() return '1.60.1',70450 end
Enum=Enum or {}; Enum.SpellBookSpellBank={Pet=1}
C_SpellBook={HasPetSpells=function() return 0 end,GetSpellBookItemInfo=function() end}
local stabled={{petNumber=2,slotID=3,name='Grumpy',level=8,familyName='Bear'},
    {petNumber=3,slotID=4,name='Biter',level=9,familyName='Bear'},{petNumber=4,slotID=5,name='Twin',level=9,familyName='Cat'}}
C_StableInfo={GetActivePetList=function() return {{petNumber=1,slotID=1,name='Whiskers',level=12,familyName='Cat'}} end,
    GetStabledPetList=function() return stabled end}

local function Start(setting,saved,noScan)
    local ns={}
    PetStableDB=saved or (setting~=nil and {startOnActivePet=setting} or nil)
    for line in io.lines('PetStable.toc') do
        if line:match('^[%a]+%.lua$') then assert(loadfile(line))('PetStable',ns) end
    end
    WoW.fire('ADDON_LOADED','PetStable')
    if not noScan then ns.PetState.Refresh('test') end
    return ns
end
local function Marks(ns)
    local out={}
    for _,card in ipairs(ns.guide.cards) do
        if card:IsShown() and card.family and card.mark:IsShown() then out[card.family.key]=card.mark:GetText() end
    end
    return out
end

-- Default: opens on the pet's family; going back to the index shows the marks.
local ns=Start(); ns.Toggle()
assert(ns.db.startOnActivePet==true)
assert(ns.guide.view=='appearances' and ns.guide.appearances.family and ns.guide.appearances.family.key=='family-cat',
    "the first open starts on the active pet's family")
ns.guide.ShowFamilies()
local marks=Marks(ns)
assert(marks['family-cat']=='Your pet · 1 in stable','active pet with a stabled twin: '..tostring(marks['family-cat']))
assert(marks['family-bear']=='In stable (2)')
local plain=0
for _,card in ipairs(ns.guide.cards) do if card:IsShown() and not card.mark:IsShown() then plain=plain+1 end end
assert(plain==17,'other families carry no mark')

-- A new scan updates the marks without leaving the index.
for i=#stabled,1,-1 do stabled[i]=nil end
ns.PetState.Refresh('test')
marks=Marks(ns); assert(marks['family-cat']=='Your pet' and marks['family-bear']==nil)

-- Saved data from an earlier session is not current: no "Your pet", and stable pets are labelled as earlier.
stabled[1]={petNumber=2,slotID=3,name='Grumpy',level=8,familyName='Bear'}
ns.PetState.Refresh('test')
local earlier=Start(nil,ns.db,true); earlier.Toggle()
assert(earlier.PetState.State()=='stale' and earlier.guide.view=='families',"stale data does not open the guide on a family")
marks=Marks(earlier)
assert(marks['family-cat']==nil and marks['family-bear']=='Was in stable (earlier visit)',
    'before the first scan: '..tostring(marks['family-cat'])..' / '..tostring(marks['family-bear']))
earlier.PetState.Refresh('test')
earlier.guide.Refresh(false)
marks=Marks(earlier); assert(marks['family-cat']=='Your pet' and marks['family-bear']=='In stable')

-- A later scan that cannot read the stabled list keeps its entries but no longer calls them current.
C_StableInfo.GetStabledPetList=function() return nil end
earlier.PetState.Refresh('test')
marks=Marks(earlier)
assert(marks['family-bear']=='Was in stable (earlier visit)' and marks['family-cat']=='Your pet')
C_StableInfo.GetStabledPetList=function() return stabled end

-- The setting turns the start off; a restored non-guide page is never replaced.
local off=Start(false); off.Toggle()
assert(off.guide.view=='families','the setting keeps the index')
local on=Start(true); on.db.page='pets'; on.Toggle()
assert(on.db.page=='pets','a restored page is kept')
io.write('PASS: family markers follow observed pets, and the guide opens on the active family only when enabled\n')
