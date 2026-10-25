-- The binding probe records every variant's SetUnit result and when it resolves.
return function(ns)
    local state = { display = 0 }
    local oldGUID, oldID = rawget(_G, "UnitGUID"), rawget(_G, "UnitCreatureID")
    UnitGUID = function() return "Creature-0-1-2-3-100-1" end
    UnitCreatureID = function() return 100 end
    local made = {}
    local create = CreateFrame
    CreateFrame = function(kind, ...)
        local f = create(kind, ...)
        if kind == "PlayerModel" then
            f.ClearModel = function() state.display = 0 end
            f.SetUnit = function(self) self.bound = true; return self.shown_ end
            f.GetDisplayInfo = function() return state.display end
            f.GetModelFileID = function() return state.display > 0 and 900 or nil end
            made[#made + 1] = f
        end
        return f
    end
    local db = ns.GetDB()
    ns._test.Binding.Start("target")
    local runs = db.binding.runs
    local run = runs[#runs]
    assert(run.guidKind == "Creature" and run.creatureID == 100)
    assert(#made == 5, "one model per variant")
    for _, row in pairs(run.rows) do assert(row.at == nil, "nothing resolved before the display loads") end
    state.display = 1234
    for _ = 1, 25 do for _, f in ipairs(WoW.frames) do
        if f._scripts.OnUpdate then f._scripts.OnUpdate(f, 0.1) end
    end end
    for key, row in pairs(run.rows) do assert(row.at and row.display == 1234 and row.file == 900, key) end
    UnitGUID = function() return "Player-0-1" end
    ns._test.Binding.Start("target")
    assert(db.binding.runs[#db.binding.runs].rows and not next(db.binding.runs[#db.binding.runs].rows), "non-creature units are not bound")
    CreateFrame, UnitGUID, UnitCreatureID = create, oldGUID, oldID
end
