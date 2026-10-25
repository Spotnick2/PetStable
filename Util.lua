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
