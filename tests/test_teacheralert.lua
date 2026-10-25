-- Nearby teacher alert: eligibility, cooldown, snoozes, ignore list, hunters only, and the toast.
local source=(os.getenv('LIBGLASS') or '../LibGlass'):gsub('\\','/')
dofile(source..'/tests/wow_stubs.lua'); dofile('tests/guide_stubs.lua')
SlashCmdList={}
local class,playerLevel,combat='HUNTER',20,false
UnitClass=function() return class=='HUNTER' and 'Hunter' or 'Mage',class end
UnitLevel=function(unit) if unit=='player' then return playerLevel end return unitState.level end
function InCombatLockdown() return combat end
local now=1000
function GetTime() return now end
function time() return 1700000000 end
GetRealmName=function() return 'Realm' end
GetBuildInfo=function() return '1.60.1',70450 end
local locale='enUS'
function GetLocale() return locale end
local petGuid='Pet-0-1-1'
UIParent:SetSize(1920,1080)

local ns={}
for line in io.lines('PetStable.toc') do
    if line:match('^[%a]+%.lua$') then assert(loadfile(line))('PetStable',ns) end
end
WoW.fire('ADDON_LOADED','PetStable')
local TA,PS=ns.TeacherAlert,ns.PetState

-- A listed teacher of Bite rank 2 for Cats, and one of Scorpid Poison.
local function Teacher(abilityName,rank,familyKey)
    for id,list in pairs(TA.Index()) do
        for _,row in ipairs(list) do
            if row.ability.name==abilityName and row.rank.ordinal==rank
                and (row.rank.allFamilies or (function() for _,k in ipairs(row.rank.familyKeys) do if k==familyKey then return true end end end)()) then
                return id,row
            end
        end
    end
end
local biteID,biteRow=Teacher('Bite',2,'family-cat')
assert(biteID,'the catalog lists a Bite 2 teacher for Cats')
-- A teacher whose every listed ability is closed to Cats.
local scorpID
for id,list in pairs(TA.Index()) do
    local fitsCat=false
    for _,row in ipairs(list) do
        if row.rank.allFamilies then fitsCat=true end
        for _,k in ipairs(row.rank.familyKeys) do if k=='family-cat' then fitsCat=true end end
    end
    if not fitsCat then scorpID=id; break end
end

unitState={level=biteRow.creature.levelMin or 8,id=biteID,guid='Creature-0-1-2-3-'..biteID..'-1',name='Teacher',player=false,controlled=false,dead=false}
UnitExists=function() return true end
others={}
UnitGUID=function(unit) if unit=='pet' then return petGuid end if others[unit] then return 'Creature-0-1-2-3-'..others[unit].id..'-1' end return unitState.guid end
UnitCreatureID=function(unit) if others[unit] then return others[unit].id end return unitState.id end
UnitIsPlayer=function() return unitState.player end
UnitPlayerControlled=function() return unitState.controlled end
UnitIsDead=function() return unitState.dead end
UnitName=function(unit) if unit=='pet' then return 'Whiskers' end if unit=='player' then return 'Hunt' end return unitState.name end
UnitCreatureFamily=function() return 'Cat',2 end
UnitExists=function() return true end
Enum=Enum or {}; Enum.SpellBookSpellBank={Pet=1}
local spells={{name='Bite',subName='Rank 1',spellID=17255},{name='Claw',subName='Rank 1',spellID=16827}}
C_SpellBook={HasPetSpells=function() return #spells end,GetSpellBookItemInfo=function(i) return spells[i] end}
C_StableInfo=nil
local petLevel=12
UnitLevel=function(unit) if unit=='player' then return playerLevel end if unit=='pet' then return petLevel end if others[unit] then return others[unit].level end return unitState.level end
PS.Refresh('test')
assert(PS.Active().present and PS.ActiveRank('Bite')==1)

local function Reset() TA.ResetSnoozes(); ns.Toast.Hide() end
local function Fires(unit) Reset(); local found=TA.Consider(unit or 'target'); return found~=nil and ns.Toast.IsShown() end

-- Off by default: nothing happens until the player turns it on.
assert(ns.db.teacherAlerts==false and not Fires())
SlashCmdList.PETSTABLE('teachers on'); assert(ns.db.teacherAlerts==true)
assert(Fires(),'an eligible teacher shows the toast')

-- Repeats within the cooldown stay quiet, and return after it.
TA.Consider('target'); ns.Toast.Hide()
assert(not TA.Consider('target'),'cooldown'); now=now+901; assert(TA.Consider('target'),'cooldown over'); ns.Toast.Hide()

-- Situations where it must stay quiet.
unitState.level=playerLevel+5; assert(not Fires(),'a creature above the player cannot be tamed'); unitState.level=8
playerLevel=9; assert(not Fires(),'no pet below level 10'); playerLevel=20
local mageClass=class; class='MAGE'; assert(not Fires(),'other classes'); class=mageClass
unitState.controlled=true; assert(not Fires(),'your own pet is not a wild teacher'); unitState.controlled=false
unitState.player=true; assert(not Fires()); unitState.player=false
unitState.guid='Pet-0-1-2-3-1-1'; assert(not Fires(),'only Creature GUIDs'); unitState.guid='Creature-0-1-2-3-'..biteID..'-1'
unitState.dead=true; assert(not Fires()); unitState.dead=false
unitState.id=999999999; assert(not Fires(),'only listed teachers'); unitState.id=biteID
spells[1].subName='Rank 2'; PS.Refresh('test'); assert(not Fires(),'the pet already has Bite 2')
spells[1].subName='Rank 3'; PS.Refresh('test'); assert(not Fires(),'a higher rank is not the next one')
spells[1].subName='Rank 1'; PS.Refresh('test'); assert(Fires())
petLevel=5; PS.Refresh('test'); assert(not Fires(),'the pet is below the rank\'s pet level'); petLevel=12; PS.Refresh('test')
local savedBook=C_SpellBook; C_SpellBook=nil; PS.Refresh('test'); assert(not Fires(),'unreadable pet abilities are unknown, not empty'); C_SpellBook=savedBook
local held=spells; spells={}; C_SpellBook={HasPetSpells=function() return 0 end}; PS.Refresh('test')
assert(not Fires(),'a pet that knows nothing yet (a quest pet) is left alone')
spells=held; C_SpellBook=savedBook; PS.Refresh('test')
if scorpID then unitState.id=scorpID; assert(not Fires(),'a teacher whose abilities do not fit a Cat'); unitState.id=biteID end
UnitIsDead=function() return false end
local noPet=UnitExists; UnitExists=function(unit) return unit~='pet' end; PS.Refresh('test'); assert(not Fires(),'no active pet'); UnitExists=noPet; PS.Refresh('test')
assert(Fires())

-- Ignore and snooze controls.
TA.Ignore('Bite',true); assert(not Fires(),'an ignored ability'); TA.Ignore('Bite',false); assert(Fires())
assert(TA.Ignored('Cower') and not TA.Ignored('Bite'),'Cower is ignored by default')
Reset(); TA.Snooze(now); assert(not TA.Consider('target'),'timed snooze'); now=now+901; assert(TA.Consider('target'),'snooze over'); ns.Toast.Hide()

-- A pet already out may need stabling first: hold alerts while the same pet stays active.
Reset(); TA.SnoozeForPet(); assert(not TA.Consider('target'),'held for this pet'); now=now+5000
assert(not TA.Consider('target'),'a time-based wait does not end the hold')
petGuid='Pet-0-1-2' -- another pet with the same name and family
assert(TA.Consider('target'),'a different pet ends the hold even with the same name and family'); ns.Toast.Hide(); petGuid='Pet-0-1-1'
local noGuid=UnitGUID; UnitGUID=function(unit) if unit=='pet' then return nil end return unitState.guid end
Reset(); TA.SnoozeForPet(); assert(TA.Consider('target'),'with no pet identity there is no hold to apply'); ns.Toast.Hide(); UnitGUID=noGuid

-- Data from before this session's scan, or about to change, is not used: wait and look again.
Reset()
local watcherPS=PS.watcher
watcherPS:GetScript('OnEvent')(watcherPS,'UNIT_PET')
assert(PS.Pending() and not TA.Consider('target'),'a scan is pending')
assert(not ns.Toast.IsShown())
watcherPS:GetScript('OnUpdate')(watcherPS,0.3)
assert(not PS.Pending() and ns.Toast.IsShown(),'the unit is looked at again after the refresh, without a cooldown being spent')
ns.Toast.Hide()

-- A burst of nameplates during a pending scan: none is lost, one notice shows, the others stay alertable.
do
    local ids={}
    for id,list in pairs(TA.Index()) do
        for _,row in ipairs(list) do
            local fits=row.rank.allFamilies
            for _,k in ipairs(row.rank.familyKeys) do if k=='family-cat' then fits=true end end
            if row.ability.name=='Bite' and row.rank.ordinal==2 and fits then ids[#ids+1]=id end
        end
    end
    table.sort(ids); assert(#ids>=3,'three listed Bite 2 teachers for Cats')
    Reset()
    others={ nameplate1={id=ids[1],level=8}, nameplate2={id=ids[2],level=8} }
    watcherPS:GetScript('OnEvent')(watcherPS,'UNIT_PET')
    assert(not TA.Consider('nameplate1') and not TA.Consider('nameplate2') and not ns.Toast.IsShown())
    watcherPS:GetScript('OnUpdate')(watcherPS,0.3)
    assert(ns.Toast.IsShown(),'the first nameplate alerts after the refresh')
    ns.Toast.Hide()
    assert(ns.Toast.IsShown(),'the second nameplate alerts by itself when the first notice is dismissed')
    ns.Toast.Hide()
    assert(not ns.Toast.IsShown() and not TA.Consider('nameplate1') and not TA.Consider('nameplate2'),'both are now spent for the cooldown')

    -- Two refresh batches while a notice is open: the second batch queues behind the first and nothing is lost.
    Reset()
    others={ nameplate1={id=ids[1],level=8}, nameplate2={id=ids[2],level=8}, nameplate3={id=ids[3],level=8} }
    watcherPS:GetScript('OnEvent')(watcherPS,'UNIT_PET')
    TA.Consider('nameplate1'); TA.Consider('nameplate2')
    watcherPS:GetScript('OnUpdate')(watcherPS,0.3)
    assert(ns.Toast.IsShown(),'batch one shows nameplate 1; nameplate 2 waits')
    watcherPS:GetScript('OnEvent')(watcherPS,'UNIT_PET')
    TA.Consider('nameplate3')
    watcherPS:GetScript('OnUpdate')(watcherPS,0.3)
    assert(ns.Toast.IsShown(),'batch two does not replace the open notice')
    local shown=0
    for _=1,3 do if ns.Toast.IsShown() then shown=shown+1; ns.Toast.Hide() end end
    assert(shown==3 and not ns.Toast.IsShown(),'all three alert, one at a time, as each is dismissed (saw '..shown..')')
    -- A direct event while a notice is up waits behind it too.
    Reset(); others={ nameplate1={id=ids[1],level=8}, nameplate2={id=ids[2],level=8} }
    assert(TA.Consider('nameplate1') and ns.Toast.IsShown())
    assert(not TA.Consider('nameplate2'),'the open notice is not replaced')
    ns.Toast.Hide(); assert(ns.Toast.IsShown(),'the waiting unit alerts when the first goes'); ns.Toast.Hide()
    others={}
end

-- Catalog ability names are English: a localized spellbook is not matched.
Reset(); locale='deDE'; PS.Refresh('test'); assert(not Fires(),'no rank matching on a localized client'); locale='enUS'; PS.Refresh('test'); assert(Fires())

-- The toast: buttons act and close it, and it is fully insecure so it works in combat.
Reset()
local found=TA.Consider('target'); assert(found and ns.Toast.IsShown())
for _,f in ipairs(WoW.frames) do
    assert(f.GetName==nil or f:GetName()~='PetStableToastTarget','no secure Target frame exists')
    assert(not (f.attributes and f.attributes.type=='macro'))
end
local function ByLabel(text) for _,f in ipairs(WoW.frames) do if f.label and f.label.GetText and f.label:GetText()==text then return f end end end
local ignore=ByLabel('Ignore Bite'); assert(ignore and ByLabel('Snooze 15 min') and ByLabel('Snooze while I keep this pet'))
ignore:GetScript('OnClick')(ignore); assert(TA.Ignored('Bite') and not ns.Toast.IsShown()); TA.Ignore('Bite',false)
Reset(); combat=true
assert(TA.Consider('target') and ns.Toast.IsShown(),'an alert shows in combat')
ns.Toast.Hide(); assert(not ns.Toast.IsShown(),'and hides in combat'); combat=false

-- Other classes register nothing at login; hunters register the three unit signals.
local function Login(kind)
    class=kind
    local fresh={}
    assert(loadfile('Util.lua'))('PetStable',fresh); assert(loadfile('TeacherAlert.lua'))('PetStable',fresh)
    local w=fresh.TeacherAlert.watcher
    w:GetScript('OnEvent')(w,'PLAYER_LOGIN')
    return w
end
local mageWatcher=Login('MAGE')
assert(next(mageWatcher._events)==nil,'a mage registers no events')
local hunterWatcher=Login('HUNTER')
assert(hunterWatcher._events.PLAYER_TARGET_CHANGED and hunterWatcher._events.UPDATE_MOUSEOVER_UNIT and hunterWatcher._events.NAME_PLATE_UNIT_ADDED)
io.write('PASS: teacher alerts: eligibility, cooldown, snoozes, pet hold, ignore list, toast in combat and hunters only\n')
