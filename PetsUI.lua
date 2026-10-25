local _, NS = ...
local ROW = 30
local COLOR = { gold = {0.78, 0.94, 0.65, 1}, dim = {0.68, 0.74, 0.79, 1}, text = {0.9, 0.93, 0.95, 1} }

-- My Pets: what was last observed about the active pet and the stable. Only the
-- active pet's abilities can be read, and the hunter's own learned ranks are not
-- tracked, so neither is shown as complete.
function NS.CreatePets(parent, window, Text)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", 24, -136); panel:SetSize(992, 502)
    local PS = NS.PetState
    local interactive = {}

    local scroll = CreateFrame("ScrollFrame", nil, panel); scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll); child:SetSize(600, 10); scroll:SetScrollChild(child)
    local function Wheel(_, delta)
        scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() - delta * 60)))
    end
    scroll:SetScript("OnMouseWheel", Wheel)

    local pools = { text = {}, button = {} }
    local used = { text = 0, button = 0 }
    local function Take(kind, make)
        used[kind] = used[kind] + 1
        local item = pools[kind][used[kind]]
        if not item then item = make(); pools[kind][used[kind]] = item end
        item:Show()
        return item
    end
    local function Reset()
        for kind, list in pairs(pools) do
            for i = 1, #list do list[i]:Hide() end
            used[kind] = 0
        end
    end
    function panel.ResetHover() for _, b in ipairs(interactive) do b.ResetHover() end end

    local function Line(y, text, size, color)
        local t = Take("text", function() local f = Text(child, size or 13, color or COLOR.text); f:SetWordWrap(true); return f end)
        t:SetFont("Fonts\\FRIZQT__.TTF", size or 13, ""); t:SetTextColor(unpack(color or COLOR.text))
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", 0, -y); t:SetWidth(child:GetWidth()); t:SetText(text)
        return y + math.max(size or 13, t:GetStringHeight()) + 8
    end
    local function Date(stamp)
        local format = rawget(_G, "date")
        return stamp and format and format("%Y-%m-%d %H:%M", stamp) or "an earlier session"
    end
    local function Describe(pet)
        local parts = { pet.name or "Unnamed pet" }
        if pet.level then parts[#parts + 1] = "Level " .. pet.level end
        parts[#parts + 1] = pet.family or "Family unknown"
        return table.concat(parts, " · ")
    end

    function panel.Refresh()
        Reset()
        local y = 0
        local _, class = UnitClass("player")
        if class ~= "HUNTER" then
            y = Line(y, "My Pets is for hunters. Switch to a hunter to see its pet and stable.", 14, COLOR.dim)
            child:SetHeight(math.max(10, y)); return
        end
        local state, active = PS.State(), PS.Active()
        local pets, stableTime = PS.Stable()
        y = Line(y, state == "fresh" and "Checked this session." or state == "stale"
            and ("From an earlier session (" .. Date(active and active.observed or stableTime) .. "). It updates when you log in as this hunter.")
            or "Nothing observed yet. Log in as a hunter and summon your pet.", 13, COLOR.dim)
        y = Line(y + 6, "Active pet", 20, COLOR.gold)
        if not active then y = Line(y, "No pet has been seen yet.", 13, COLOR.dim)
        elseif not active.present then y = Line(y, "No pet was summoned at the last check (" .. Date(active.observed) .. ").", 13, COLOR.dim)
        else
            y = Line(y, Describe(active), 15)
            if active.abilitiesRead and #active.abilities > 0 then
                y = Line(y, "Abilities on this pet", 13, COLOR.dim)
                for _, ability in ipairs(active.abilities) do
                    y = Line(y, ability.name .. (ability.rank and ("  ·  Rank " .. ability.rank) or ""), 13)
                end
            else y = Line(y, "This pet's abilities could not be read.", 13, COLOR.dim) end
        end
        y = Line(y + 10, "Stable", 20, COLOR.gold)
        local stabled = 0
        for _, pet in ipairs(pets) do
            if not pet.active then
                stabled = stabled + 1
                local button = Take("button", function()
                    local b = CreateFrame("Button", nil, child, "BackdropTemplate"); b:SetSize(300, ROW - 4)
                    b.label = Text(b, 13); b.label:SetPoint("LEFT", 10, 0); b.label:SetJustifyH("LEFT")
                    b:SetScript("OnClick", function(self)
                        if self.pet.familyKey and NS.SelectPage and NS.guide then
                            NS.SelectPage("guide"); NS.guide.OpenFamily(self.pet.familyKey)
                        end
                    end)
                    b:EnableMouseWheel(true); b:SetScript("OnMouseWheel", Wheel)
                    NS.StyleButton(b); interactive[#interactive + 1] = b
                    return b
                end)
                button:ClearAllPoints(); button:SetPoint("TOPLEFT", 0, -y); button:SetWidth(child:GetWidth() - 8)
                button.label:SetWidth(child:GetWidth() - 28); button.pet = pet
                button.label:SetText(Describe(pet) .. (pet.slotID and ("  ·  slot " .. pet.slotID) or ""))
                y = y + ROW
            end
        end
        if stabled == 0 then
            y = Line(y, stableTime and "No stabled pets were recorded at the last check." or "No stable list has been read yet.", 13, COLOR.dim)
        else y = Line(y + 4, "Pick a pet to open its family in the Pet Guide.", 12, COLOR.dim) end
        if stableTime then y = Line(y, "Stable last read " .. Date(stableTime) .. ".", 12, COLOR.dim) end
        y = Line(y + 10, "The abilities of stabled pets cannot be read, and what your hunter has learned is not tracked yet, so neither is shown.", 12, COLOR.dim)
        child:SetHeight(math.max(10, y))
    end

    -- The visible text, for tests and diagnostics.
    function panel.Lines()
        local out = {}
        for i = 1, used.text do out[#out + 1] = pools.text[i]:GetText() end
        for i = 1, used.button do out[#out + 1] = pools.button[i].label:GetText() end
        return table.concat(out, "\n")
    end

    function panel.Layout(width, height)
        panel.ResetHover(); panel:SetSize(width, height)
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 0, 0); scroll:SetSize(width, height)
        child:SetWidth(math.min(width - 20, 720))
        if panel:IsShown() then panel.Refresh() end
    end
    PS.Subscribe(function() if panel:IsShown() then panel.Refresh() end end)
    panel:Hide()
    return panel
end
