local _, NS = ...

-- Shared by every client read: tolerate a missing API, an error, or a secret value.
-- Returns up to four results, or nothing when the call did not succeed.
function NS.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    local secret = rawget(_G, "issecretvalue")
    if ok and (not secret or not (secret(a) or secret(b) or secret(c) or secret(d))) then return a, b, c, d end
end

-- A plain string or finite number the client returned, never a secret.
function NS.Plain(value)
    local secret = rawget(_G, "issecretvalue")
    if secret and secret(value) then return nil end
    if type(value) == "string" then return value end
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
end

-- The hunter's own level, or nil for other classes and when the client gives none.
function NS.PlayerLevel()
    local _, class = NS.Call(rawget(_G, "UnitClass"), "player")
    if class ~= "HUNTER" then return nil end
    local level = NS.Plain(NS.Call(rawget(_G, "UnitLevel"), "player"))
    if NS.levelHint and (not level or NS.levelHint > level) then level = NS.levelHint end
    return type(level) == "number" and level > 0 and level or nil
end

-- The level the guide filters to: the hunter's level while the filter is on.
function NS.LevelCap()
    if NS.db and NS.db.filterToLevel == false then return nil end
    return NS.PlayerLevel()
end
