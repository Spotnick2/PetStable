-- Target button (#39): structure, combat rules and the latch, sequencing, geometry, names.
-- The secure rules are modelled here: insecure code may not call a protected method on the secure
-- button in combat; the state driver evaluates on a separate "next update", and runs the button's real
-- latch snippet in a secure context.
local source=(os.getenv('LIBGLASS') or '../LibGlass'):gsub('\\','/')
dofile(source..'/tests/wow_stubs.lua'); dofile('tests/guide_stubs.lua')
SlashCmdList={}
local class,combat='HUNTER',false
UnitClass=function() return class=='HUNTER' and 'Hunter' or 'Mage',class end
function InCombatLockdown() return combat end
local SECRET={}
function issecretvalue(v) return v==SECRET end
UIParent:SetSize(1920,1080)

-- Secure model -------------------------------------------------------------------------------------
local errors,secure={},false
local PROTECTED={'SetAttribute','Show','Hide','SetPoint','ClearAllPoints','SetParent','SetSize','SetWidth','SetHeight',
    'SetScale','RegisterForClicks','SetFrameLevel','SetFrameStrata'}
local create=CreateFrame
CreateFrame=function(kind,name,parent,template)
    local f=create(kind,name,parent,template)
    if type(template)=='string' and template:find('SecureActionButtonTemplate',1,true) then
        f.protected,f.attributes=true,{}
        for _,m in ipairs(PROTECTED) do
            local original=f[m]
            f[m]=function(self,...)
                if combat and not secure then errors[#errors+1]=m end
                if m=='SetAttribute' then local k,v=...; self.attributes[k]=v end
                return original(self,...)
            end
        end
        f.GetAttribute=function(self,k) return self.attributes[k] end
        f.SetScript=function() error('no script may be set on the secure button') end
    end
    return f
end
local drivers={}
local function Evaluate(f)
    local d=drivers[f]; if not d then return end
    assert(d.cond=='[combat] 1; 0','the latch condition')
    local value=combat and 1 or 0
    if f.attributes['state-'..d.state]~=value then
        f.attributes['state-'..d.state]=value
        local snippet=f.attributes['_onstate-'..d.state]
        if snippet then
            secure=true
            local handle={SetAttribute=function(_,k,v) f:SetAttribute(k,v) end,Hide=function() f:Hide() end}
            local fn=assert(loadstring(snippet)); setfenv(fn,{newstate=value,self=handle}); fn()
            secure=false
        end
    end
end
function RegisterStateDriver(f,state,cond)
    if combat then errors[#errors+1]='RegisterStateDriver' end
    drivers[f]={state=state,cond=cond}; Evaluate(f) -- registering evaluates at once
end
function UnregisterStateDriver(f)
    if combat then errors[#errors+1]='UnregisterStateDriver' end
    drivers[f]=nil
end
local function DriverUpdate() for f in pairs(drivers) do Evaluate(f) end end -- the secure manager's next update

-- Helpers ------------------------------------------------------------------------------------------
local function Load()
    local ns={}
    for _,file in ipairs({'Util.lua','Toast.lua','TargetButton.lua'}) do assert(loadfile(file))('PetStable',ns) end
    return ns
end
local function Event(ns,event) local w=ns.TargetButton.watcher; w:GetScript('OnEvent')(w,event) end
local function Calls(f,name)
    local out={}
    for _,entry in ipairs(f._log) do if entry[1]==name then out[#out+1]=entry end end
    return out
end
local function Armed(b,name)
    return b:IsShown() and b:GetAttribute('type')=='macro'
        and b:GetAttribute('macrotext')=='/cleartarget\n/targetexact '..name..'\n/cleartarget [dead]'
end
local function Disarmed(b) return not b:IsShown() and b:GetAttribute('type')==nil and b:GetAttribute('macrotext')==nil end
local function Notice(name,extra)
    local opts={title='PET ABILITY NEARBY',body='Prowler is listed as teaching Bite rank 2.',note='Listed by references.',
        buttons={{text='Snooze 15 min'},{text='Snooze while I keep this pet'},{text='Ignore Bite'}},
        target=name and {id=118,name=name} or nil}
    for k,v in pairs(extra or {}) do opts[k]=v end
    return opts
end

-- Structure ----------------------------------------------------------------------------------------
local ns=Load(); local TB,Toast=ns.TargetButton,ns.Toast
Event(ns,'PLAYER_LOGIN')
local b=TB.button; assert(b and b.protected,'a hunter gets the secure button at login')
local toast=Toast.Frame()
assert(b:GetParent()==UIParent and toast:GetParent()==UIParent,'both are UIParent children')
assert(not toast.protected,'the notice stays unprotected')
local p=b._points; assert(#p==1 and p[1][1]=='TOPLEFT' and p[1][2]==UIParent and p[1][3]=='TOP' and p[1][4]==-186 and p[1][5]==-180,
    'anchored once to UIParent, at the band')
for _,f in ipairs(WoW.frames) do
    for _,point in ipairs(f._points or {}) do
        if f==b then assert(point[2]~=toast,'the button never anchors to the notice') end
        if f==toast then assert(point[2]~=b,'the notice never anchors to the button') end
    end
end
assert(b:GetWidth()==372 and b:GetHeight()==26)
assert(Calls(b,'SetFrameStrata')[1][2]=='DIALOG' and b:GetFrameLevel()==30 and toast:GetFrameLevel()==20,'above the notice')
local clicks=Calls(b,'RegisterForClicks'); assert(#clicks==1 and clicks[1][2]=='AnyUp' and clicks[1][3]=='AnyDown','both click edges')
-- In the stub, SetScript on the secure button throws and no XML template runs, so _scripts==nil means
-- PetStable set no script. A real button keeps the scripts its templates install (OnClick among them).
assert(b:GetAttribute('typerelease')==nil and b._scripts==nil,'no typerelease, no script: the template keeps its OnClick')
assert(b:GetAttribute('_onstate-petstablecombat')==TB.LATCH,'the latch snippet is installed')
assert(not b:IsShown() and b:GetAttribute('type')==nil,'built hidden and unarmed')
local clamp=Calls(toast,'SetClampedToScreen'); assert(#clamp==1 and clamp[1][2]==false,'the notice is never clamped')
TB.Build(); TB.Build()
local count=0; for _,f in ipairs(WoW.frames) do if f==_G.PetStableTargetButton then count=count+1 end end
assert(count==1,'building twice makes one button')

-- Arm and disarm out of combat ---------------------------------------------------------------------
Toast.Show(Notice('Prowler'))
assert(Armed(b,'Prowler') and b.label:GetText()=='Target Prowler','armed for the notice')
assert(drivers[b] and b:GetAttribute('state-petstablecombat')==0,'latch driver registered, out of combat')
local w=Toast._test.widgets()
assert(w.body._points[1][3]==-64,'the body starts under the band')
assert(w.band:IsShown() and w.band:GetText()=='','band reserved, no hint out of combat')
for _,button in ipairs(w.buttons) do if button:IsShown() then assert(-button._points[1][3]>56,'notice buttons below the band') end end
assert(-w.note._points[1][3]>56,'the note below the band')
-- The close button ends above the band (TOPRIGHT -6,-6, 22 high).
assert(w.close._points[1][3]==-6 and w.close:GetHeight()==22 and 6+22<30,'close button above the band')
Toast.Hide(); assert(Disarmed(b) and drivers[b]==nil,'closing disarms and unregisters the latch')

-- The latch ----------------------------------------------------------------------------------------
Toast.Show(Notice('Prowler')); combat=true
assert(Armed(b,'Prowler'),'until the secure manager updates, the button is still armed (accepted window)')
DriverUpdate(); assert(Disarmed(b) or (not b:IsShown() and b:GetAttribute('type')==nil),'combat latches it off')
Toast.Hide(); assert(#errors==0,'closing the notice in combat touches nothing protected: '..table.concat(errors,','))
combat=false; DriverUpdate(); assert(not b:IsShown(),'combat ending does not bring it back by itself')
Event(ns,'PLAYER_REGEN_ENABLED'); assert(Disarmed(b) and drivers[b]==nil,'the notice is gone: disarmed at regen')

-- Re-armed unconditionally at regen when the same notice is still up, in either driver order.
for _,driverFirst in ipairs({true,false}) do
    Toast.Show(Notice('Prowler')); combat=true; DriverUpdate(); assert(not b:IsShown())
    combat=false
    if driverFirst then DriverUpdate(); assert(not b:IsShown()) end
    Event(ns,'PLAYER_REGEN_ENABLED'); assert(Armed(b,'Prowler'),'re-armed at regen even though desired never changed')
    if not driverFirst then DriverUpdate(); assert(Armed(b,'Prowler'),'a later driver update leaves it armed') end
    Toast.Hide()
end
-- Rapid re-entry.
Toast.Show(Notice('Prowler')); combat=true; DriverUpdate(); combat=false; Event(ns,'PLAYER_REGEN_ENABLED')
combat=true; DriverUpdate(); assert(not b:IsShown() and b:GetAttribute('type')==nil,'latched again')
combat=false; Event(ns,'PLAYER_REGEN_ENABLED'); assert(Armed(b,'Prowler')); Toast.Hide()

-- A notice shown in combat: no button until combat ends.
combat=true; Toast.Show(Notice('Prowler'))
assert(not b:IsShown() and w.band:GetText()=='Target button after combat','hint in the band')
combat=false; Event(ns,'PLAYER_REGEN_ENABLED'); assert(Armed(b,'Prowler'),'armed at regen'); Toast.Hide()

-- A closes and B opens through onHide, out of combat and in combat.
local queue={}
Toast.onHide=function() local nextName=table.remove(queue,1); if nextName then Toast.Show(Notice(nextName)) end end
queue={'Bristleback'}; Toast.Show(Notice('Prowler')); Toast.Hide()
assert(Toast.IsShown() and Armed(b,'Bristleback'),'B is armed, not cleared by A going')
Toast.Hide(); assert(Disarmed(b))
queue={'Bristleback'}; Toast.Show(Notice('Prowler')); combat=true; DriverUpdate(); Toast.Hide()
assert(TB.Desired().name=='Bristleback' and #errors==0)
combat=false; Event(ns,'PLAYER_REGEN_ENABLED'); assert(Armed(b,'Bristleback'),'regen arms the notice that is up: B'); Toast.Hide()
queue={'Bristleback'}; Toast.Show(Notice('Prowler')); combat=true; DriverUpdate(); Toast.Hide(); Toast.Hide()
combat=false; Event(ns,'PLAYER_REGEN_ENABLED'); assert(Disarmed(b),'A and B both closed before regen: disarmed')
Toast.onHide=nil

-- Expiry takes the same path as Close.
Toast.Show(Notice('Prowler')); assert(Armed(b,'Prowler'))
toast:GetScript('OnUpdate')(toast,46); assert(not Toast.IsShown() and Disarmed(b),'expiry disarms')

-- Names ----------------------------------------------------------------------------------------------
for _,bad in ipairs({SECRET,'Two\nLines','',string.rep('x',101),42}) do
    assert(not TB.SafeName(bad),'rejected: '..tostring(bad))
    Toast.Show(Notice(nil,{target={id=1,name=bad}}))
    assert(Disarmed(b) and w.body._points[1][3]==-30,'an unsafe name: no button and no band')
    Toast.Hide()
end
assert(TB.SafeName(string.rep('x',100)) and TB.SafeName('Mottled Boar'))
Toast.Show(Notice('Prowler')); TB.Want({id=2,name='Bad\n'}); assert(Disarmed(b),'an invalid request after a valid one disarms'); Toast.Hide()
assert(TB.Macro('Prowler')=='/cleartarget\n/targetexact Prowler\n/cleartarget [dead]')

-- Geometry under long text: capped at 300, everything below the band.
Toast.Show(Notice('Prowler',{body=string.rep('A very long teaching line. ',80),note=string.rep('A long note. ',20)}))
assert(toast:GetHeight()<=300,'height capped at 300 (got '..toast:GetHeight()..')')
assert(w.body:GetStringHeight()<=300-64,'the body was cut')
for _,button in ipairs(w.buttons) do
    if button:IsShown() then
        assert(-button._points[1][3]>56)
        assert(-button._points[1][3]+24<=toast:GetHeight(),'every button ends inside the capped notice')
    end
end
assert(-w.note._points[1][3]+w.note:GetStringHeight()<=toast:GetHeight(),'the note ends inside the capped notice')
Toast.Hide()

-- No state driver on this client: no button at all.
local register=RegisterStateDriver; RegisterStateDriver=nil
Toast.Show(Notice('Prowler')); assert(Disarmed(b) and not TB.Offered({name='Prowler'}),'no latch, no button'); Toast.Hide()
assert(pcall(TB.Want,{id=1,name='Prowler'}) and Disarmed(b),'a direct request without the driver arms nothing')
RegisterStateDriver=register

-- The guard itself works: an insecure protected call in combat is caught.
combat=true; b:Show(); assert(errors[#errors]=='Show','the stub catches insecure combat calls'); table.remove(errors); b:Hide(); table.remove(errors); combat=false
assert(#errors==0,'no insecure protected call in combat anywhere: '..table.concat(errors,','))

-- Initialisation: another class builds nothing; a login under lockdown builds at regen.
class='MAGE'; local mage=Load(); Event(mage,'PLAYER_LOGIN'); assert(mage.TargetButton.button==nil,'a mage gets no button')
class='HUNTER'; combat=true; local locked=Load(); Event(locked,'PLAYER_LOGIN'); assert(locked.TargetButton.button==nil,'nothing built under lockdown')
combat=false; Event(locked,'PLAYER_REGEN_ENABLED'); assert(locked.TargetButton.button,'built at the first regen')
assert(#errors==0)

io.write("PASS: Target button structure, combat latch, regen reconcile, A->B sequencing, expiry, names and geometry\n")
