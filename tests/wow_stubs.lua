-- wow_stubs.lua: PetStable's WoW: Forever mock for its Lua 5.1 tests.
-- dofile("tests/wow_stubs.lua") FIRST in a test that loads the addon's UI;
-- drive it through the WoW table.
--
-- The mechanics are WowTestKit's core (tests/kit.lua loads it at the commit
-- and build tests/kit.pin names; its README is the reference): strict
-- globals, secrets, CreateFrame and the widget method recorder
-- (WoW.methodsCalled, checked by Kit.checkMethods in test_methods.lua),
-- events checked against the build, OnShow / OnHide, OnUpdate ticks, timers,
-- hooksecurefunc, print with the stray-"|" check, check / eq / done.
--
-- This file adds what PetStable's windows use beyond them: the EditBox,
-- Slider and ScrollFrame behaviour its browser relies on, the ModelScene
-- actor, and the two globals LibGlass reads (Enum, CreateColor). It used to
-- extend LibGlass's own test mock (../LibGlass/tests/wow_stubs.lua, loaded
-- from the sibling repo or $LIBGLASS) with tests/guide_stubs.lua: both are
-- folded in here, so no test loads another repo's test files (PetStable#42).
--
-- The addon reads every client API through rawget (Util.lua's NS.Call), so
-- the unit, spell and stable APIs stay with each test: a test defines the
-- ones its situation needs, and an API it leaves out reads as absent.

dofile("tests/kit.lua")
local Methods = WoW.Methods

--------------------------------------------------------------------------------
-- Client globals LibGlass and the addon read directly
--------------------------------------------------------------------------------

-- Enum: LibGlass's slice mode; a test adds the tables it needs
-- (Enum.SpellBookSpellBank).
Enum = { UITextureSliceMode = { Stretched = 0, Tiled = 1 } }
-- A colour object (the dump's colorRGBA), as SetGradient takes.
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end

--------------------------------------------------------------------------------
-- BackdropTemplate
--------------------------------------------------------------------------------

-- BackdropTemplateMixin adds SetBackdrop, SetBackdropColor and
-- SetBackdropBorderColor in Lua (wow-ui-source forever, 70959:
-- Blizzard_SharedXML/Backdrop.lua:336, :406, :429), so the dump's widget walk
-- can't see them: allowed on the four types PetStable makes with the
-- template. Only a frame made with it has them.
WoW.templates.BackdropTemplate = function(w) w._backdropTemplate = true end
local BACKDROP = "BackdropTemplateMixin (Blizzard_SharedXML/Backdrop.lua), with the BackdropTemplate"
local allowed = {}
for _, wtype in ipairs({ "Frame", "Button", "EditBox", "Slider" }) do
    for _, m in ipairs({ "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" }) do
        allowed[wtype .. ":" .. m] = BACKDROP
    end
end
Kit.allowMethods(allowed)
local function backdrop(w, m)
    assert(w._backdropTemplate, m .. ": only a frame made with BackdropTemplate has it")
end
function Methods.SetBackdrop(w, info) backdrop(w, "SetBackdrop"); w._backdrop = info end
function Methods.SetBackdropColor(w, r, g, b, a) backdrop(w, "SetBackdropColor"); w._backdropColor = { r, g, b, a } end
function Methods.SetBackdropBorderColor(w, r, g, b, a)
    backdrop(w, "SetBackdropBorderColor"); w._backdropBorder = { r, g, b, a }
end

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

-- The window's layout follows OnSizeChanged (UI.lua), which the client runs
-- when a resize changes the size.
local coreSetSize = Methods.SetSize
function Methods.SetSize(w, width, height)
    local changed = w._width ~= width or w._height ~= height
    coreSetSize(w, width, height)
    local fn = w._scripts.OnSizeChanged
    if changed and fn then fn(w, width, height) end
end
-- A scroll child's height moves its scroll frame's range: the client runs
-- the frame's OnScrollRangeChanged (GuideUI's pooled list re-lays out on it).
local coreSetHeight = Methods.SetHeight
function Methods.SetHeight(w, height)
    coreSetHeight(w, height)
    local sf = w._scrollFrame
    if sf and sf._scrollChild == w and sf._scripts.OnScrollRangeChanged then
        sf._scripts.OnScrollRangeChanged(sf, 0, Methods.GetVerticalScrollRange(sf))
    end
end
function Methods.SetScale(w, value) w._scale = value end
function Methods.GetScale(w) return w._scale or 1 end
-- Keyboard input reaches the game unless a frame stops it: tests read
-- w.propagate (guide_cases: typing in the search box never reaches a binding).
function Methods.SetPropagateKeyboardInput(w, value) w.propagate = value end
function Methods.HasScript() return true end

-- Mouse clicks: a Button, EditBox or Slider takes them from the start;
-- EnableMouse and SetMouseClickEnabled set them, and hooking OnMouseUp or
-- OnMouseDown turns them on, as a native mouse handler activates hit testing
-- (history_cases: the back / forward mouse buttons on the window's surfaces).
local CLICKS_BY_DEFAULT = { Button = true, EditBox = true, Slider = true }
local coreEnableMouse = Methods.EnableMouse
function Methods.EnableMouse(w, enabled)
    coreEnableMouse(w, enabled)
    w._clicks = enabled == true
end
function Methods.IsMouseClickEnabled(w)
    if w._clicks == nil then return CLICKS_BY_DEFAULT[w._type] == true end
    return w._clicks
end
local coreHookScript = Methods.HookScript
function Methods.HookScript(w, event, hook)
    if event == "OnMouseUp" or event == "OnMouseDown" then w._clicks = true end
    return coreHookScript(w, event, hook)
end

-- A font string's height: lines of about 7 pixels per character at its
-- width, 16 pixels each (the guide's detail text grows with its content).
function Methods.GetStringHeight(fs)
    local lines, perLine = 0, math.max(1, math.floor((fs._width or 0) / 7))
    local text = fs._text
    if type(text) ~= "string" then text = "" end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines = lines + math.max(1, math.ceil(#line / perLine))
    end
    return lines * 16
end

--------------------------------------------------------------------------------
-- EditBox: focus, and an empty text to start with
--------------------------------------------------------------------------------

-- An EditBox's font needs its flags on Forever ("" for none): the guide's
-- search box once passed nil.
local coreSetFont = Methods.SetFont
function Methods.SetFont(w, file, height, flags)
    if w._type == "EditBox" then
        assert(type(flags) == "string", "EditBox:SetFont requires explicit flags on Forever")
    end
    return coreSetFont(w, file, height, flags)
end
local coreGetText = Methods.GetText
function Methods.GetText(w)
    if w._type == "EditBox" and w._text == nil then return "" end
    return coreGetText(w)
end
function Methods.HasFocus(w) return w._focused == true end
function Methods.SetFocus(w)
    w._focused = true
    local fn = w._scripts.OnEditFocusGained
    if fn then fn(w) end
end
function Methods.ClearFocus(w)
    local had = w._focused
    w._focused = false
    local fn = w._scripts.OnEditFocusLost
    if had and fn then fn(w) end
end

--------------------------------------------------------------------------------
-- Slider: its value stays within its range, and changes run OnValueChanged
--------------------------------------------------------------------------------

local coreSetValue, coreGetValue, coreSetMinMax = Methods.SetValue, Methods.GetValue, Methods.SetMinMaxValues
function Methods.SetValue(w, value, ...)
    if w._type ~= "Slider" then return coreSetValue(w, value, ...) end
    value = math.max(w._min or 0, math.min(w._max or 0, value))
    if value == w._value then return end
    w._value = value
    local fn = w._scripts.OnValueChanged
    if fn then fn(w, value) end
end
function Methods.GetValue(w)
    if w._type == "Slider" then return w._value or 0 end
    return coreGetValue(w)
end
function Methods.SetMinMaxValues(w, minimum, maximum)
    coreSetMinMax(w, minimum, maximum)
    if w._type == "Slider" then Methods.SetValue(w, Methods.GetValue(w)) end
end
function Methods.GetMinMaxValues(w) return w._min, w._max end
function Methods.SetThumbTexture(w, file)
    w._thumb = Methods.CreateTexture(w, nil, "OVERLAY")
    Methods.SetTexture(w._thumb, file)
end
function Methods.GetThumbTexture(w) return w._thumb end

--------------------------------------------------------------------------------
-- ScrollFrame: its child, and the vertical scroll with OnVerticalScroll
--------------------------------------------------------------------------------

function Methods.SetScrollChild(sf, child)
    sf._scrollChild = child
    child._scrollFrame = sf
end
function Methods.GetScrollChild(sf) return sf._scrollChild end
function Methods.SetVerticalScroll(sf, value)
    if value == sf._scroll then return end
    sf._scroll = value
    local fn = sf._scripts.OnVerticalScroll
    if fn then fn(sf, value) end
end
function Methods.GetVerticalScroll(sf) return sf._scroll or 0 end
function Methods.GetVerticalScrollRange(sf)
    local child = sf._scrollChild
    return math.max(0, (child and child._height or 0) - sf._height)
end

--------------------------------------------------------------------------------
-- ModelScene: one actor per CreateActor
--------------------------------------------------------------------------------

-- The actor is a plain table, not a widget: the API dump has no
-- ModelSceneActor type (neither in its widget walk nor as a documented API),
-- so Kit.checkMethods can't check its calls; these are the ones
-- PetStableProbe's Models.lua measured in game. Its fields are what the
-- tests read (display, scale, alpha, yaw, animation). WoW.rejectModel makes
-- the display refused, WoW.modelTimeout keeps the bounding box from arriving.
function Methods.CreateActor()
    local actor = {}
    function actor:SetModelByCreatureDisplayID(id) self.display = id; return not WoW.rejectModel end
    function actor:ClearModel() self.display = nil; self.cleared = true end
    function actor:SetScale(value) self.scale = value end
    function actor:SetAlpha(value) self.alpha = value end
    function actor:SetUseCenterForOrigin() end
    function actor:SetPosition() end
    function actor:SetYaw(value) self.yaw = value end
    function actor:SetAnimation(...) self.animation = { ... } end
    function actor:GetActiveBoundingBox() if not WoW.modelTimeout then return -2, -1, -1, 2, 1, 3 end end
    return actor
end

-- LibStub: nil until the embedded library (or a test's copy) creates it.
-- PetStableDB and the probes' saved tables are read through rawget.
Kit.strict({ LibStub = true })
