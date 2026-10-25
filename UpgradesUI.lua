local _, NS = ...
local ROW_HEIGHT, LIST_WIDTH, GAP = 30, 300, 16
local COLOR = { gold = {0.78, 0.94, 0.65, 1}, dim = {0.68, 0.74, 0.79, 1}, text = {0.9, 0.93, 0.95, 1} }

-- Ability Upgrades: a reference browser of pet ability ranks and the creatures
-- listed as teaching them. Hunter and pet knowledge is not tracked yet, so no
-- rank is marked learned, missing or ready.
function NS.CreateUpgrades(parent, window, Text)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", 24, -136); panel:SetSize(992, 502)
    local U, G = NS.UpgradesData, NS.GuideData
    local entries, families, problem = G.Build(NS.CatalogData)
    panel.abilities = problem and {} or U.Build(NS.CatalogData, entries, families)
    panel.state = { familyKey = nil, selected = nil }
    local interactive = {}

    local function Button(host, label, width, click, size)
        local b = CreateFrame("Button", nil, host, "BackdropTemplate")
        b:SetSize(width, 26)
        b.label = Text(b, size or 12); b.label:SetPoint("CENTER"); b.label:SetWidth(width - 8); b.label:SetJustifyH("CENTER")
        b.label:SetText(label); b:SetScript("OnClick", click)
        NS.StyleButton(b); interactive[#interactive + 1] = b
        return b
    end
    function panel.ResetHover() for _, b in ipairs(interactive) do b.ResetHover() end end

    local note = Text(panel, 13, COLOR.dim); note:SetPoint("TOPLEFT", 0, 0); note:SetJustifyV("TOP"); note:SetWordWrap(true)
    note:SetText("Reference listing. Which ranks your hunter or pets have learned is not tracked yet, so nothing is marked learned, missing or ready.")
    local familyButton = Button(panel, "All families", 220, function() panel.CycleFamily() end, 13)

    -- A plain scroll area with a slim bar, shared by the list and the details.
    local function Scroller(host)
        local scroll = CreateFrame("ScrollFrame", nil, host); scroll:EnableMouseWheel(true)
        local child = CreateFrame("Frame", nil, scroll); child:SetSize(300, 10); scroll:SetScrollChild(child)
        local bar = CreateFrame("Slider", nil, host, "BackdropTemplate")
        bar:SetOrientation("VERTICAL"); bar:SetMinMaxValues(0, 0); bar:SetValueStep(1); bar:SetObeyStepOnDrag(false)
        bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" }); bar:SetBackdropColor(0.06, 0.08, 0.07, 0.45)
        bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8"); local thumb = bar:GetThumbTexture()
        thumb:SetVertexColor(0.38, 0.46, 0.4, 0.75)
        local syncing = false
        local function Sync()
            if syncing then return end
            syncing = true
            local range = math.max(0, scroll:GetVerticalScrollRange()); if range < 1 then range = 0 end
            local value = math.max(0, math.min(range, scroll:GetVerticalScroll()))
            bar:SetMinMaxValues(0, range); bar:SetValue(value); bar:SetShown(range > 0)
            thumb:SetSize(6, math.max(24, bar:GetHeight() * scroll:GetHeight() / (scroll:GetHeight() + range)))
            if scroll:GetVerticalScroll() ~= value then scroll:SetVerticalScroll(value) end
            syncing = false
        end
        local function Wheel(_, delta)
            panel.ResetHover()
            scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() - delta * 60)))
        end
        scroll:SetScript("OnMouseWheel", Wheel); bar:EnableMouseWheel(true); bar:SetScript("OnMouseWheel", Wheel)
        scroll:SetScript("OnVerticalScroll", Sync); scroll:SetScript("OnScrollRangeChanged", Sync)
        bar:SetScript("OnValueChanged", function(_, value) if not syncing then scroll:SetVerticalScroll(value) end end)
        return scroll, child, bar, Sync, Wheel
    end
    local listScroll, listChild, listBar, listSync, listWheel = Scroller(panel)
    local detailScroll, detailChild, detailBar, detailSync, detailWheel = Scroller(panel)

    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local row = Button(listChild, "", LIST_WIDTH - 12, function(self) panel.Select(self.ability.key) end, 13)
        row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 10, 0); row.label:SetJustifyH("LEFT")
        row.count = Text(row, 11, COLOR.dim); row.count:SetPoint("RIGHT", -10, 0); row.count:SetJustifyH("RIGHT")
        row:EnableMouseWheel(true); row:SetScript("OnMouseWheel", listWheel)
        rows[i] = row
        return row
    end

    local pools = { heading = {}, line = {}, teacher = {} }
    local used = { heading = 0, line = 0, teacher = 0 }
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

    local function Selected()
        for _, ability in ipairs(panel.visible or {}) do if ability.key == panel.state.selected then return ability end end
    end
    local function Teacher(entry)
        return table.concat({ entry.label, G.Level(entry), (G.Zone(entry)) }, " · ")
    end

    function panel.PaintDetails()
        Reset()
        local width = detailChild:GetWidth()
        local ability, y = Selected(), 0
        local cap = NS.LevelCap()
        if not ability then
            local text = Take("line", function() local t = Text(detailChild, 14, COLOR.dim); t:SetWordWrap(true); return t end)
            text:ClearAllPoints(); text:SetPoint("TOPLEFT", 0, 0); text:SetWidth(width)
            text:SetText(problem and "Catalog unavailable." or "No listed ability fits this family.")
            detailChild:SetHeight(40); detailSync(); return
        end
        local title = Take("heading", function() return Text(detailChild, 22, COLOR.gold) end)
        title:ClearAllPoints(); title:SetPoint("TOPLEFT", 0, 0); title:SetText(ability.name); y = 34
        local summary = Take("line", function() local t = Text(detailChild, 13, COLOR.dim); t:SetWordWrap(true); return t end)
        summary:ClearAllPoints(); summary:SetPoint("TOPLEFT", 0, -y); summary:SetWidth(width)
        local taught = ability.trainer and "Taught by any Pet Trainer."
            or (ability.teachers == 0 and "No teaching beast is listed yet." or ("Listed teachers: " .. ability.teachers .. " creatures."))
        summary:SetText("Families: " .. ability.familyLabel .. "\n" .. taught)
        -- A long family list wraps; the first rank starts below the rendered text.
        y = y + math.max(46, summary:GetStringHeight() + 8)
        panel.summary, panel.firstRankY = summary, y
        for _, rank in ipairs(ability.ranks) do
            if U.Fits(rank, panel.state.familyKey) and U.Visible(rank, cap) then
                local heading = Take("heading", function() return Text(detailChild, 15, COLOR.text) end)
                heading:ClearAllPoints(); heading:SetPoint("TOPLEFT", 0, -y); heading:SetText(U.RankLabel(rank)); y = y + 26
                local teachers = U.Teachers(rank, panel.state.familyKey, cap)
                if rank.trainer then
                    local line = Take("line", function() local t = Text(detailChild, 12, COLOR.dim); t:SetWordWrap(true); return t end)
                    line:ClearAllPoints(); line:SetPoint("TOPLEFT", 12, -y); line:SetWidth(width - 12)
                    line:SetText("Learned from a Pet Trainer."); y = y + 22
                elseif #teachers == 0 then
                    local line = Take("line", function() local t = Text(detailChild, 12, COLOR.dim); t:SetWordWrap(true); return t end)
                    line:ClearAllPoints(); line:SetPoint("TOPLEFT", 12, -y); line:SetWidth(width - 12)
                    line:SetText(#rank.teachers == 0 and "No teaching beast is listed."
                        or (cap and "No listed teacher at or below your level " .. cap .. " fits this view.")
                        or "No listed teacher of this family."); y = y + 22
                end
                for _, entry in ipairs(not rank.trainer and teachers or {}) do
                    local button = Take("teacher", function()
                        local b = Button(detailChild, "", width - 12, function(self) panel.OpenCreature(self.teacher) end, 12)
                        b.label:ClearAllPoints(); b.label:SetPoint("LEFT", 10, 0); b.label:SetJustifyH("LEFT")
                        b:EnableMouseWheel(true); b:SetScript("OnMouseWheel", detailWheel)
                        return b
                    end)
                    button:SetWidth(width - 12); button.label:SetWidth(width - 32)
                    button:ClearAllPoints(); button:SetPoint("TOPLEFT", 12, -y)
                    button.teacher = entry; button.label:SetText(Teacher(entry)); y = y + ROW_HEIGHT - 2
                end
                y = y + 12
            end
        end
        detailChild:SetHeight(math.max(10, y)); detailSync()
    end

    function panel.PaintList()
        panel.visible = U.Filter(panel.abilities, panel.state.familyKey, NS.LevelCap())
        local keep = false
        for _, ability in ipairs(panel.visible) do if ability.key == panel.state.selected then keep = true end end
        if not keep then panel.state.selected = panel.visible[1] and panel.visible[1].key or nil end
        for i, ability in ipairs(panel.visible) do
            local row = Row(i)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT); row:SetSize(LIST_WIDTH - 12, ROW_HEIGHT - 4)
            row.ability = ability; row.label:SetText(ability.name)
            row.count:SetText(ability.trainer and "Trainer" or (#ability.ranks .. " ranks"))
            row.active = ability.key == panel.state.selected; row.Paint(); row:Show()
        end
        for i = #panel.visible + 1, #rows do rows[i]:Hide() end
        listChild:SetHeight(math.max(10, #panel.visible * ROW_HEIGHT)); listSync()
    end

    function panel.Refresh()
        local label = "All families"
        for _, family in ipairs(families) do if family.key == panel.state.familyKey then label = family.label end end
        familyButton.label:SetText(label)
        panel.PaintList(); panel.PaintDetails()
    end
    function panel.Select(key)
        panel.state.selected = key; panel.ResetHover(); panel.PaintList(); panel.PaintDetails()
        detailScroll:SetVerticalScroll(0)
    end
    function panel.CycleFamily()
        local order = { false }
        for _, family in ipairs(families) do order[#order + 1] = family.key end
        local index = 1
        for i, key in ipairs(order) do if key == panel.state.familyKey then index = i end end
        local nextKey = order[index % #order + 1]
        panel.state.familyKey = nextKey or nil
        panel.ResetHover(); panel.Refresh(); detailScroll:SetVerticalScroll(0)
    end
    -- A listed creature opens its family in the Pet Guide.
    function panel.OpenCreature(entry)
        if not (entry and entry.familyKey and NS.SelectPage and NS.guide) then return end
        NS.SelectPage("guide")
        NS.guide.OpenFamily(entry.familyKey)
    end

    function panel.Layout(width, height)
        panel.ResetHover(); panel:SetSize(width, height)
        note:SetWidth(width - 240); familyButton:ClearAllPoints(); familyButton:SetPoint("TOPRIGHT", 0, 0)
        local top, bodyHeight = 56, height - 56
        listScroll:ClearAllPoints(); listScroll:SetPoint("TOPLEFT", 0, -top); listScroll:SetSize(LIST_WIDTH, bodyHeight)
        listChild:SetWidth(LIST_WIDTH - 12); listBar:ClearAllPoints(); listBar:SetPoint("TOPRIGHT", listScroll, "TOPRIGHT", 0, 0)
        listBar:SetSize(6, bodyHeight)
        local x = LIST_WIDTH + GAP
        detailScroll:ClearAllPoints(); detailScroll:SetPoint("TOPLEFT", x, -top); detailScroll:SetSize(width - x - 12, bodyHeight)
        detailChild:SetWidth(width - x - 14); detailBar:ClearAllPoints(); detailBar:SetPoint("TOPRIGHT", detailScroll, "TOPRIGHT", 12, 0)
        detailBar:SetSize(6, bodyHeight)
        if panel:IsShown() then panel.PaintDetails() end
    end
    panel:Hide()
    return panel
end
