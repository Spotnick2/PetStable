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
    if type(db.startOnActivePet) ~= "boolean" then db.startOnActivePet = true end
    if type(db.filterToLevel) ~= "boolean" then db.filterToLevel = true end
    if type(db.teacherAlerts) ~= "boolean" then db.teacherAlerts = false end
    db.width = Number(db.width) and math.max(800, math.min(1440, db.width)) or 1040
    db.height = Number(db.height) and math.max(560, math.min(1000, db.height)) or 700
    if not pages[db.page] then db.page = "guide" end
    local p = db.position
    if type(p) ~= "table" or not anchors[p.point] or not anchors[p.relativePoint]
        or not Number(p.x) or not Number(p.y) then
        db.position = { point="CENTER", relativePoint="CENTER", x=0, y=0 }
    end
    NS.db = db
    if NS.Sightings then NS.Sightings.Initialize() end
    if NS.PetState then NS.PetState.Initialize() end
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
    if command == "sightings" and NS.Sightings then NS.Sightings.Command(value:lower())
    elseif command == "teachers" then
        if (value:lower() == "on" or value:lower() == "off") and NS.TeacherAlert then
            NS.TeacherAlert.SetEnabled(value:lower() == "on")
            if NS.settings then NS.settings.Sync() end
        end
        print("PetStable: nearby teacher alerts " .. (NS.db.teacherAlerts and "on" or "off") .. ". /petstable teachers on|off")
    elseif command == "levelfilter" then
        if value:lower() == "on" or value:lower() == "off" then
            NS.db.filterToLevel = value:lower() == "on"
            if NS.RefreshFilters then NS.RefreshFilters() end
        end
        print("PetStable: level filter " .. (NS.db.filterToLevel and "on" or "off") .. ". /petstable levelfilter on|off")
    elseif command == "material" then
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
