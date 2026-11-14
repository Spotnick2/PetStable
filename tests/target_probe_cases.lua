-- The Target button probe reads the live button and notice, and survives their absence.
return function(ns)
    local saved={}
    for _,name in ipairs({"PetStableTargetButton","PetStableToast","InCombatLockdown","GetCVar","UnitName","UnitIsDead"}) do saved[name]=rawget(_G,name) end
    local db=ns.GetDB()
    -- Nothing built yet (PetStable not loaded): recorded as absent, not an error.
    PetStableTargetButton,PetStableToast=nil,nil
    local index=ns._test.Target.Capture("bare")
    local bare=db.target.captures[index]
    assert(bare.buttonExists==false and bare.noticeExists==false and bare.shown==nil)
    -- A live armed button and its notice.
    local attributes={type="macro",macrotext="/cleartarget\n/targetexact Prowler\n/cleartarget [dead]",["state-petstablecombat"]=0}
    local label={GetText=function() return "Target Prowler" end}
    PetStableTargetButton={IsShown=function() return true end,GetAttribute=function(_,k) return attributes[k] end,
        IsProtected=function() return true end,GetLeft=function() return 774 end,GetTop=function() return 900 end,
        GetWidth=function() return 372 end,GetHeight=function() return 26 end,label=label}
    PetStableToast={IsShown=function() return true end,IsProtected=function() return false end,
        GetLeft=function() return 760 end,GetTop=function() return 930 end,GetHeight=function() return 200 end}
    InCombatLockdown=function() return false end
    GetCVar=function(name) return name=="ActionButtonUseKeyDown" and "1" or nil end
    UnitName=function() return "Prowler" end; UnitIsDead=function() return false end
    local row=db.target.captures[ns._test.Target.Capture("armed")]
    assert(row.shown[2]==true and row.type[2]=="macro" and row.latchState[2]==0 and row.keyDown[2]=="1")
    assert(row.macrotext[2]:find("/targetexact Prowler",1,true) and row.label=="armed" and row.buttonText[2]=="Target Prowler" and row.target[2]=="Prowler")
    assert(row.protected[2]==true and row.noticeProtected[2]==false,"the button is protected, the notice is not")
    assert(row.rect.top[2]==900 and row.noticeRect.top[2]==930,"positions recorded to check the band")
    -- Show notice asks PetStable to check the target now, then records.
    local savedSlash=rawget(_G,"SlashCmdList"); local asked
    SlashCmdList={PETSTABLE=function(message) asked=message end}
    local before=#db.target.captures
    ns._test.Target.Show("shown")()
    assert(asked=="teachers check" and db.target.captures[#db.target.captures].label=="shown","Show runs the check, then captures")
    assert(#db.target.captures==math.min(before+1,40))
    SlashCmdList={}; assert(not pcall(ns._test.Target.Show("missing")),"without PetStable the step fails")
    SlashCmdList=savedSlash
    -- A combat end records the lockdown, the latch condition and the button.
    local parse=rawget(_G,"SecureCmdOptionParse"); SecureCmdOptionParse=function() return "1" end
    ns._test.Target.RegenSample("event")
    local sample=db.target.regen[#db.target.regen]
    assert(sample.when=="event" and sample.condition[2]=="1" and sample.lockdown[2]==false and sample.shown[2]==true and sample.latch[2]==0)
    SecureCmdOptionParse=nil; ns._test.Target.RegenSample("missing")
    assert(db.target.regen[#db.target.regen].condition[1]~=true,"a missing API is recorded, not an error")
    SecureCmdOptionParse=parse
    for name,value in pairs(saved) do rawset(_G,name,value) end
end
