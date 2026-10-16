local ADDON, NS = ...
local anchors = { CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true,
    TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true }
local pages = { guide=true, upgrades=true, pets=true }
local function Number(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end

function NS.Initialize()
    if type(rawget(_G, "PetStableDB")) ~= "table" then PetStableDB = {} end
    local db = PetStableDB
    db.version = 1
    if not Number(db.scale) then db.scale = 1 end
    db.scale = math.max(0.65, math.min(1.3, db.scale))
    db.width = Number(db.width) and math.max(800, math.min(1440, db.width)) or 1040
    db.height = Number(db.height) and math.max(560, math.min(1000, db.height)) or 700
    if not pages[db.page] then db.page = "guide" end
    local p = db.position
    if type(p) ~= "table" or not anchors[p.point] or not anchors[p.relativePoint]
        or not Number(p.x) or not Number(p.y) then
        db.position = { point="CENTER", relativePoint="CENTER", x=0, y=0 }
    end
    NS.db = db
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    NS.Initialize()
    self:UnregisterEvent("ADDON_LOADED")
end)

SLASH_PETSTABLE1 = "/petstable"
SlashCmdList.PETSTABLE = function(message)
    if not NS.db then return end
    local command, value = message:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "material" then
        if not NS.SetMaterial(value) then print("PetStable: /petstable material reflective|flat") end
    elseif command == "scale" then
        local scale = tonumber(value)
        if Number(scale) then
            NS.db.scale = math.max(0.65, math.min(1.3, scale))
            NS.Layout()
        else print("PetStable: /petstable scale 0.65–1.3") end
    elseif command == "reset" then
        NS.db.position = { point="CENTER", relativePoint="CENTER", x=0, y=0 }
        NS.db.scale = 1
        NS.db.width, NS.db.height = 1040, 700
        NS.Layout()
    elseif command == "" then NS.Toggle()
    else print("PetStable: /petstable, /petstable scale 0.65–1.3, /petstable reset, /petstable material reflective|flat") end
end
