-- Which PlayerModel binding path reports a wild unit's display and model file?
-- The first discovery capture saw SetUnit("target") return false on build 70425
-- with a hidden model; sighting capture depends on a path that works.
local _, NS = ...
local Probe, FP = NS.Probe, ForeverProbe
local STEP, SPAN = 0.1, 2

local VARIANTS = {
    { key = "hidden-default", shown = false },
    { key = "hidden-noblend", shown = false, args = { false } },
    { key = "hidden-blend", shown = false, args = { true } },
    { key = "shown-noblend", shown = true, args = { false } },
    { key = "shown-default", shown = true },
}

local models, run = {}, nil

local function Store()
    local db = NS.GetDB()
    if not db then error("PetStableProbe SavedVariables are not ready") end
    db.binding = db.binding or { runs = {} }
    return db.binding
end

local function Num(v) return type(v) == "number" and not FP.IsSecret(v) and v end

local function Model(variant)
    local frame = models[variant.key]
    if not frame then
        frame = CreateFrame("PlayerModel", nil, UIParent)
        frame:SetSize(64, 64)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetAlpha(0)
        models[variant.key] = frame
    end
    frame:SetShown(variant.shown)
    return frame
end

local function Read(variant, frame)
    local _, display = Probe:Try("GetDisplayInfo", frame.GetDisplayInfo, frame)
    local _, file = Probe:Try("GetModelFileID", frame.GetModelFileID, frame)
    return Num(display), Num(file)
end

local function Stop()
    if not run then return end
    run.watcher:SetScript("OnUpdate", nil)
    for _, variant in ipairs(VARIANTS) do
        local row = run.rows[variant.key]
        Probe:Say(string.format("bind %s: SetUnit=%s display=%s file=%s at=%s", variant.key,
            Probe.Show(row.bound), Probe.Show(row.display), Probe.Show(row.file), Probe.Show(row.at)))
    end
    run.done = true
end

local function Start(unit)
    if run and run.watcher then run.watcher:SetScript("OnUpdate", nil) end
    local ok, guid = Probe:Try("UnitGUID", rawget(_G, "UnitGUID"), unit)
    local _, build = Probe:Try("GetBuildInfo", rawget(_G, "GetBuildInfo"))
    local _, creatureID = Probe:Try("UnitCreatureID", rawget(_G, "UnitCreatureID"), unit)
    local kind = type(guid) == "string" and not FP.IsSecret(guid) and guid:match("^(%a+)%-") or nil
    run = { unit = unit, rows = {}, elapsed = 0, since = 0, kind = kind,
        watcher = (run and run.watcher) or CreateFrame("Frame") }
    local saved = { unit = unit, guidKind = kind, creatureID = Num(creatureID), rows = run.rows,
        build = Probe.Show(build), time = rawget(_G, "time") and time() or nil }
    local runs = Store().runs
    runs[#runs + 1] = saved
    if #runs > 20 then table.remove(runs, 1) end
    if not ok or kind ~= "Creature" then
        Probe:Say("bind: " .. unit .. " is not a Creature unit; target a wild beast")
        run.done = true
        return
    end
    for _, variant in ipairs(VARIANTS) do
        local frame = Model(variant)
        Probe:Try("ClearModel", frame.ClearModel, frame)
        local _, bound = Probe:Try("SetUnit", frame.SetUnit, frame, unit, unpack(variant.args or {}))
        local row = { bound = bound, shown = variant.shown }
        run.rows[variant.key] = row
        row.display, row.file = Read(variant, frame)
        if row.display and row.display > 0 and row.file and row.file > 0 then row.at = 0 end
    end
    run.watcher:SetScript("OnUpdate", function(_, delta)
        run.elapsed, run.since = run.elapsed + delta, run.since + delta
        if run.since < STEP then return end
        run.since = 0
        for _, variant in ipairs(VARIANTS) do
            local row = run.rows[variant.key]
            if not row.at then
                row.display, row.file = Read(variant, models[variant.key])
                if row.display and row.display > 0 and row.file and row.file > 0 then
                    row.at = math.floor(run.elapsed * 10 + 0.5) / 10
                end
            end
        end
        if run.elapsed >= SPAN then Stop() end
    end)
end

local function Result()
    if not run or not run.done then return false end
    for _, row in pairs(run.rows) do if row.at then return true, "a variant resolved" end end
    return true, "no variant resolved"
end

Probe:Command("bind", function(args) Start(args ~= "" and args:match("^%S+") or "target") end,
    "Try PlayerModel:SetUnit variants (hidden/shown, blend) on a unit and record when each resolves")

Probe:Steps("bind", {
    rev = 1, title = "Model binding on a wild beast",
    { text = "Stand near a wild beast in the open world (no taming). Target it and keep it targeted." },
    { text = "Try every binding variant for about two seconds.", button = "Run variants", run = function() Start("target") end },
    { text = "Waiting for the variants to finish.", wait = function() return Result() end, timeout = 6,
      check = function()
          if not run then return false, "no run" end
          for _, row in pairs(run.rows) do if row.at then return true, "resolved" end end
          return false, "no variant produced a display ID and model file ID"
      end },
    { text = "Mouse over a different wild beast without targeting it, then run the same variants on mouseover.",
      button = "Run on mouseover", run = function() Start("mouseover") end },
    { text = "Waiting for the variants to finish.", wait = function() return Result() end, timeout = 6 },
    { text = "Does the beast on screen look normal (no model of it is visible anywhere on the screen)? Say what you see in Notes.", ask = true },
    { text = "Press Finish, then type /reload to save the results." },
})

NS._test.Binding = { Start = Start }
