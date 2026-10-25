-- Use the material's shared widget mocks and the actual embedded release.
local source = (os.getenv("LIBGLASS") or "../LibGlass"):gsub("\\", "/")
dofile(source .. "/tests/wow_stubs.lua")
dofile("tests/guide_stubs.lua")
rawset(_G,"SlashCmdList",{})
rawset(_G,"UnitClass",function() return "Mage", "MAGE" end)
UIParent:SetSize(1920,1080)
local function loadAddon()
    local ns={}
    assert(loadfile("Util.lua"))("PetStable",ns)
    assert(loadfile("Core.lua"))("PetStable",ns)
    assert(loadfile("Catalog.lua"))("PetStable",ns)
    assert(loadfile("CatalogData.lua"))("PetStable",ns)
    assert(loadfile("PetState.lua"))("PetStable",ns)
    assert(loadfile("GuideData.lua"))("PetStable",ns)
    assert(loadfile("GuideModels.lua"))("PetStable",ns)
    assert(loadfile("GuideAppearances.lua"))("PetStable",ns)
    assert(loadfile("GuideUI.lua"))("PetStable",ns)
    assert(loadfile("UpgradesData.lua"))("PetStable",ns)
    assert(loadfile("UpgradesUI.lua"))("PetStable",ns)
    assert(loadfile("PetsUI.lua"))("PetStable",ns)
    assert(loadfile("UI.lua"))("PetStable",ns)
    return ns
end
local function checkEscape(window, toggle)
    local propagated
    local propagate=window.SetPropagateKeyboardInput
    window.SetPropagateKeyboardInput=function(self, value) propagated=value; propagate(self,value) end
    local keyDown=assert(window:GetScript("OnKeyDown"))
    keyDown(window,"W")
    assert(window:IsShown() and propagated, "ordinary keys must pass through without closing")
    keyDown(window,"ESCAPE")
    assert(not window:IsShown() and propagated==false, "Escape must close without reaching the game menu")
    toggle()
    keyDown(window,"W")
    assert(window:IsShown() and propagated, "ordinary keys must pass through after reopening")
    keyDown(window,"ESCAPE")
    assert(not window:IsShown() and propagated==false, "Escape must also close after reopening")
    toggle()
end
local ns=loadAddon()
local catalogErrors,catalogConflicts=ns.Catalog.Validate(ns.CatalogData)
assert(#catalogErrors==0 and #catalogConflicts==0, "player addon must load the validated catalog")
assert(not ns.db and rawget(_G,"PetStableDB")==nil)
WoW.fire("ADDON_LOADED","OtherAddon")
assert(not ns.db)
WoW.fire("ADDON_LOADED","PetStable")
assert(ns.db.scale==1 and not ns.frame, "load must not open a window or require pets")
assert(ns.db.width==1040 and ns.db.height==700,"old settings receive default window dimensions")
SlashCmdList.PETSTABLE("")
assert(ns.frame:IsShown() and not ns.Glass, "missing library must use flat frame")
for _,key in ipairs({"guide","upgrades","pets"}) do
    ns.buttons[key]:GetScript("OnClick")()
    assert(ns.db.page==key)
end
checkEscape(ns.frame,ns.Toggle)
dofile("tests/guide_cases.lua")(ns)
dofile("tests/appearance_cases.lua")(ns)
dofile("tests/history_cases.lua")(ns)
ns.resize:GetScript("OnMouseDown")(ns.resize,"LeftButton")
ns.frame:SetSize(900,620)
ns.resize:GetScript("OnMouseUp")(ns.resize,"LeftButton")
assert(ns.db.width==900 and ns.db.height==620,"grip resize must persist dimensions")
ns.settingsButton:GetScript("OnClick")()
assert(ns.settings:IsShown())
ns.settings.scale:SetValue(0.85)
assert(ns.db.scale==0.85 and ns.frame:GetScale()==0.85)
ns.settings.reset:GetScript("OnClick")()
assert(ns.db.width==1040 and ns.db.height==700 and ns.db.scale==1)
SlashCmdList.PETSTABLE("scale 99")
assert(ns.db.scale==1.3)
SlashCmdList.PETSTABLE("reset")
assert(ns.db.scale==1 and ns.db.position.x==0)
ns.frame.GetPoint=function() return "TOPLEFT",UIParent,"TOPLEFT",120,-90 end
ns.frame:GetScript("OnHide")()
assert(ns.db.position.x==120 and ns.db.position.y==-90)
ns.SelectPage("pets")
local saved=ns.db
local fresh=loadAddon()
WoW.fire("ADDON_LOADED","PetStable")
assert(fresh.db==saved and fresh.db.position.x==120 and fresh.db.page=="pets")
saved.scale=0/0; saved.width=math.huge; saved.height=-5; saved.position={point="bad"}; saved.page="invalid"
fresh.Initialize()
assert(saved.scale==1 and saved.position.point=="CENTER" and saved.page=="guide")
assert(saved.width==1040 and saved.height==560)
saved.height=700

-- Real r9 library, including LibStub, loaded with the consumer addon name.
local embedded=os.getenv("PETSTABLE_LIBGLASS") or "Libs/LibGlass-1.0"
local f=assert(io.open(embedded.."/LibGlass-1.0.xml","rb"))
local xml=f:read("*a"):gsub("<!%-%-.-%-%->",""); f:close()
for path in xml:gmatch('<Script%s+file="([^"]+)"') do
    assert(loadfile(embedded.."/"..path:gsub("\\","/")))("PetStable",{})
end
local lib=LibStub("LibGlass-1.0")
assert(lib.ready==9, "tests must load the pinned r9 release")
local other=lib:New({bodyAlpha=0.3})
local shell, reflectionCount
local reflect=lib.impl.Reflect
lib.impl.Reflect=function(inst, surface, host, opts)
    shell=surface; reflectionCount=(reflectionCount or 0)+1
    assert(host==fresh.frame and opts.header==70, "reflection must stay within the window header")
    return reflect(inst, surface, host, opts)
end
fresh.Toggle()
lib.impl.Reflect=reflect
assert(reflectionCount==1 and shell.reflect, "window must use one library-owned reflective shell")
checkEscape(fresh.frame,fresh.Toggle)
dofile("tests/guide_cases.lua")(fresh)
dofile("tests/appearance_cases.lua")(fresh)
dofile("tests/history_cases.lua")(fresh)
assert(fresh.Glass and fresh.Glass~=other)
assert(fresh.Glass.STYLE.bodyAlpha==0.88 and other.STYLE.bodyAlpha==0.3)
assert(fresh.Glass.MEDIA:find("PetStable",1,true), "media must use consuming addon path")
UIParent:SetSize(640,480)
fresh.Layout()
local scale
for _,call in ipairs(fresh.frame._log) do if call[1]=="SetScale" then scale=call[2] end end
assert(scale and fresh.frame:GetWidth()*scale<=640-32+0.001 and fresh.frame:GetHeight()*scale<=480-32+0.001,"window must fit small screens")
for _,key in ipairs({"guide","upgrades","pets"}) do fresh.SelectPage(key) end
local widgetCount, selected, position = #WoW.widgets, fresh.db.page, fresh.db.position
local window = fresh.frame
assert(fresh.SetMaterial("flat"))
for _,layer in pairs(shell.reflect) do assert(not layer:IsShown(), "flat mode must hide reflections") end
assert(fresh.SetMaterial("reflective"))
for _,layer in pairs(shell.reflect) do assert(layer:IsShown(), "reflective mode must restore reflections") end
fresh.Glass.SetSurfaceEnabled(shell,false)
fresh.SetMaterial("reflective")
assert(shell.dark:GetAlpha()<0.55, "material repaint must preserve disabled dimming")
fresh.Glass.SetSurfaceEnabled(shell,true)
assert(shell.rim:GetAlpha()==0.12 and shell.dark:GetAlpha()==0.55
    and shell.shadow:GetAlpha()==0.18 and shell.grain:GetAlpha()==0,
    "enabling must restore PetStable's per-surface alpha settings")
fresh.Glass.SetRimAlpha(0.9)
assert(shell.rim:GetAlpha()==0.12, "instance rim changes must preserve the shell's own alpha")
assert(not fresh.SetMaterial("invalid"))
assert(#WoW.widgets==widgetCount and fresh.frame==window, "comparison must repaint existing layers")
assert(fresh.db.page==selected and fresh.db.position==position, "comparison must preserve navigation and placement")
assert(other.STYLE.bodyAlpha==0.3, "comparison must not modify another glass instance")
io.write("PASS: addon lifecycle, guide rows/portraits/focus/scrolling, Escape, non-hunter navigation, fallback, saved settings, scaling, and embedded LibGlass\n")
