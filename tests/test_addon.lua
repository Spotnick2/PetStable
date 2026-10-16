-- Use the material's shared widget mocks and the actual embedded release.
local source = (os.getenv("LIBGLASS") or "../LibGlass"):gsub("\\", "/")
dofile(source .. "/tests/wow_stubs.lua")
dofile("tests/guide_stubs.lua")
rawset(_G,"SlashCmdList",{})
rawset(_G,"UnitClass",function() return "Mage", "MAGE" end)
UIParent:SetSize(1920,1080)
local function loadAddon()
    local ns={}
    assert(loadfile("Core.lua"))("PetStable",ns)
    assert(loadfile("Catalog.lua"))("PetStable",ns)
    assert(loadfile("CatalogData.lua"))("PetStable",ns)
    assert(loadfile("GuideData.lua"))("PetStable",ns)
    assert(loadfile("GuideUI.lua"))("PetStable",ns)
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
SlashCmdList.PETSTABLE("")
assert(ns.frame:IsShown() and not ns.Glass, "missing library must use flat frame")
for _,key in ipairs({"guide","upgrades","pets"}) do
    ns.buttons[key]:GetScript("OnClick")()
    assert(ns.db.page==key)
end
checkEscape(ns.frame,ns.Toggle)
dofile("tests/guide_cases.lua")(ns)
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
saved.scale=0/0; saved.position={point="bad"}; saved.page="invalid"
fresh.Initialize()
assert(saved.scale==1 and saved.position.point=="CENTER" and saved.page=="guide")

-- Real r8 library, including LibStub, loaded with the consumer addon name.
local embedded=os.getenv("PETSTABLE_LIBGLASS") or "Libs/LibGlass-1.0"
local f=assert(io.open(embedded.."/LibGlass-1.0.xml","rb"))
local xml=f:read("*a"):gsub("<!%-%-.-%-%->",""); f:close()
for path in xml:gmatch('<Script%s+file="([^"]+)"') do
    assert(loadfile(embedded.."/"..path:gsub("\\","/")))("PetStable",{})
end
local lib=LibStub("LibGlass-1.0")
local other=lib:New({bodyAlpha=0.3})
fresh.Toggle()
checkEscape(fresh.frame,fresh.Toggle)
dofile("tests/guide_cases.lua")(fresh)
assert(fresh.Glass and fresh.Glass~=other)
assert(fresh.Glass.STYLE.bodyAlpha==0.88 and other.STYLE.bodyAlpha==0.3)
assert(fresh.Glass.MEDIA:find("PetStable",1,true), "media must use consuming addon path")
UIParent:SetSize(640,480)
fresh.Layout()
local scale
for _,call in ipairs(fresh.frame._log) do if call[1]=="SetScale" then scale=call[2] end end
assert(scale and scale <= (640-32)/860, "window must fit small screens")
for _,key in ipairs({"guide","upgrades","pets"}) do fresh.SelectPage(key) end
local widgetCount, selected, position = #WoW.widgets, fresh.db.page, fresh.db.position
local window = fresh.frame
assert(fresh.SetMaterial("flat"))
assert(fresh.SetMaterial("reflective"))
assert(not fresh.SetMaterial("invalid"))
assert(#WoW.widgets==widgetCount and fresh.frame==window, "comparison must repaint existing layers")
assert(fresh.db.page==selected and fresh.db.position==position, "comparison must preserve navigation and placement")
assert(other.STYLE.bodyAlpha==0.3, "comparison must not modify another glass instance")
io.write("PASS: addon lifecycle, guide rows/portraits/focus/scrolling, Escape, non-hunter navigation, fallback, saved settings, scaling, and embedded LibGlass\n")
