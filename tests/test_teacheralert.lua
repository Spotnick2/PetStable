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
-- Widgets from the shared stubs lack secure attributes; keep them on the widget.
local create=CreateFrame
local locale='enUS'
function GetLocale() return locale end
local petGuid='Pet-0-1-1'
local secureCalls=0
CreateFrame=function(kind,name,...)
    local f=create(kind,name,...)
    f.attributes={}
    function f:SetAttribute(k,v) self.attributes[k]=v end
    function f:GetAttribute(k) return self.attributes[k] end
    if name=='PetStableToastTarget' then
        -- The secure button is protected: these calls are refused in combat.
        for _,method in ipairs({'Show','Hide','SetPoint','ClearAllPoints','SetWidth'}) do
            local original=f[method]
            f[method]=function(self,...) secureCalls=secureCalls+1; assert(not combat,'protected call '..method..' in combat'); return original(self,...) end
        end
        local setAttribute=f.SetAttribute
        f.SetAttribute=function(self,...) assert(not combat,'protected SetAttribute in combat'); return setAttribute(self,...) end
    end
    return f
end
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
UnitGUID=function(unit) if unit=='pet' then return petGuid end return unitState.guid end
UnitCreatureID=function() return unitState.id end
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
UnitLevel=function(unit) if unit=='player' then return playerLevel end if unit=='pet' then return petLevel end return unitState.level end
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

-- Catalog ability names are English: a localized spellbook is not matched.
Reset(); locale='deDE'; PS.Refresh('test'); assert(not Fires(),'no rank matching on a localized client'); locale='enUS'; PS.Refresh('test'); assert(Fires())

-- The toast: buttons act and close it; the Target button is a secure macro.
Reset()
local found=TA.Consider('target'); assert(found and ns.Toast.IsShown())
local target
for _,f in ipairs(WoW.frames) do if f.attributes and f.attributes.type=='macro' then target=f end end
assert(target and target.attributes.macrotext=='/targetexact Teacher','the Target button is a macro for the creature')
assert(target:GetParent()==UIParent,'the secure button is not a child of the notice')
local function ByLabel(text) for _,f in ipairs(WoW.frames) do if f.label and f.label.GetText and f.label:GetText()==text then return f end end end
local ignore=ByLabel('Ignore Bite'); assert(ignore and ByLabel('Snooze 15 min') and ByLabel('Snooze while I keep this pet'))
ignore:GetScript('OnClick')(ignore); assert(TA.Ignored('Bite') and not ns.Toast.IsShown()); TA.Ignore('Bite',false)

-- Shown out of combat, then dismissed and replaced in combat: no protected call may be made in combat.
Reset()
assert(TA.Consider('target') and target:IsShown())
combat=true
local calls=secureCalls
ns.Toast.Hide()
assert(not ns.Toast.IsShown() and secureCalls==calls,'the notice hides in combat without touching the secure button')
assert(target:GetAlpha()==0,'the secure button is only made transparent in combat')
now=now+901
unitState.id=biteID
local again=TA.Consider('target')
assert(again and ns.Toast.IsShown(),'an alert can show in combat, without a Target button')
assert(secureCalls==calls,'still no protected call in combat')
local pending=ByLabel('Target (after combat)'); assert(pending,'a placeholder holds the Target slot in combat')
ns.Toast.Hide()
combat=false
local frameWithEvents
for _,f in ipairs(WoW.frames) do if f._events and f._events.PLAYER_REGEN_ENABLED and f:GetScript('OnEvent') then frameWithEvents=f end end
assert(frameWithEvents,'the notice listens for the end of combat')
frameWithEvents:GetScript('OnEvent')(frameWithEvents,'PLAYER_REGEN_ENABLED')
assert(not target:IsShown(),'the secure button is hidden once combat ends')
Reset(); now=now+901
assert(TA.Consider('target') and target:IsShown() and target:GetAlpha()==1,'out of combat it works again')
ns.Toast.Hide()

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
io.write('PASS: teacher alerts: eligibility, cooldown, snoozes, pet hold, ignore list, secure Target and hunters only\n')
