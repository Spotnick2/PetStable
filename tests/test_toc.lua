-- PetStable.toc: what every addon TOC must get right (WowTestKit's Kit.checkToc: the 1.60.1
-- interface, the packager's version token, every listed .lua file exists and is listed once),
-- then PetStable's own: the embedded LibGlass loads first, through its XML.
dofile("tests/kit.lua")
Kit.checkToc("PetStable.toc")
local lines = Kit.tocLines("PetStable.toc")
eq(lines[1], [[Libs\LibGlass-1.0\LibGlass-1.0.xml]], "LibGlass loads before the addon's files")
local xml = 0
for _, line in ipairs(lines) do if not line:match("%.lua$") then xml = xml + 1 end end
eq(xml, 1, "the library's XML is the only non-Lua line")
done("test_toc")
