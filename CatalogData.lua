local _, NS = ...
local data={version=1, records={}, evidence={}, facts={}}
NS.CatalogData=data
local findings="https://github.com/Spotnick2/PetStable/blob/69f4f568eddadaef715da7617de4ceffc57a1fdc/docs/FOREVER-PROBE.md"
local function Evidence(key, anchor, locator)
    data.evidence[#data.evidence+1]={key=key, game="forever", kind="observation",
        date="2026-10-16", build="1.60.1.70425", locale="enUS", url=findings..anchor, locator=locator}
end
Evidence("cat-models", "#live-result-2026-10-16-build-160170425",
    "models revision 1, runs 85-86; screenshots 101626_142414, 142419, 142441, 142456")
Evidence("bear-models", "#live-bear-result-2026-10-16-build-160170425",
    "models revision 1, runs 87-88; screenshots 101626_143016, 143019, 143036, 143051")
Evidence("galestrider", "#live-discovery-2026-10-16-build-160170425",
    "discover revision 1, run 91, captures 1-3; tooltip follow-up run 94, capture 6")
Evidence("pet-switch", "#initial-live-pet-switch-results-build-160170425",
    "switch run 63, captures 1-4; active pet spellbook only; enumeration marked partial")
Evidence("trainer", "#live-trainer-results-2026-10-16-build-160170425",
    "trainer revision 1, runs 66-67, captures 5-7; level-16 hunter, level-7 Cat; used filter off")
data.evidence[#data.evidence+1]={key="petopia-stamina", game="classic", kind="reference",
    date="2026-10-16", url="https://www.wow-petopia.com/classic/abilities.php",
    locator="Great Stamina, ranks 2-4; trainer source and minimum pet level; no spell IDs supplied"}
-- Reviewed reference, deliberately not used to certify any in-game fact.
data.evidence[#data.evidence+1]={key="beastmaster-forever", game="forever", kind="reference",
    date="2026-10-16", url="https://beastmaster.io/forever",
    locator="Rendered family overview, site v1.39.425; preliminary beta roster; research lead only"}

local function Record(key, kind, game)
    data.records[#data.records+1]={key=key,kind=kind,game=game or "forever"}
end
local function Fact(subject, field, value, evidence, status)
    data.facts[#data.facts+1]={subject=subject,field=field,value=value,evidence=evidence,status=status or "observed"}
end
for _,row in ipairs({{"cat","Cat","cat-models"},{"bear","Bear","bear-models"},
    {"tallstrider","Tallstrider","galestrider"}}) do
    Record("family-"..row[1],"family")
    Fact("family-"..row[1],"name",row[2],row[3])
end
Fact("family-tallstrider","familyID",12,"galestrider")

-- The curated roster comes from websites; client enumeration supplies metadata,
-- not hunter eligibility. Names below normalize the sites' singular/plural labels.
Evidence("family-metadata", "#live-discovery-2026-10-16-build-160170425",
    "discover revision 1, run 91, capture 1; C_CreatureInfo.GetCreatureFamilyInfo IDs/names/iconFile; reviewed 2026-10-16")
data.evidence[#data.evidence+1]={key="petopia-forever-roster",game="forever",kind="reference",
    date="2026-10-16",url="https://www.wow-petopia.com/forever/",
    locator="Browse Pet Families: 19 families; site under construction. Core Hound listed; its appearance status is not confirmed. Names normalized to client singular forms."}
data.evidence[#data.evidence+1]={key="beastmaster-forever-roster",game="forever",kind="reference",
    date="2026-10-16",url="https://beastmaster.io/forever",
    locator="Rendered overview v1.39.425: 18 family cards; preliminary beta roster. Core Hound absent from this overview, not evidence of unavailability. Names normalized to client singular forms."}
for _,row in ipairs({
    {"bat","Bat",24,132182}, {"bear","Bear",4,132183},
    {"bird-of-prey","Bird of Prey",26,132192}, {"boar","Boar",5,132184},
    {"carrion-bird","Carrion Bird",7,132200}, {"cat","Cat",2,132185},
    {"core-hound","Core Hound",312,236191}, {"crab","Crab",8,132186},
    {"crocolisk","Crocolisk",6,132187}, {"fox","Fox",319,458223},
    {"gorilla","Gorilla",9,132189}, {"hyena","Hyena",25,132190},
    {"raptor","Raptor",11,132193}, {"scorpid","Scorpid",20,132195},
    {"spider","Spider",3,132196}, {"tallstrider","Tallstrider",12,132198},
    {"turtle","Turtle",21,132199}, {"wind-serpent","Wind Serpent",27,132202},
    {"wolf","Wolf",1,132203},
}) do
    local key="family-"..row[1]
    if row[1]~="cat" and row[1]~="bear" and row[1]~="tallstrider" then
        Record(key,"family"); Fact(key,"name",row[2],"family-metadata")
    end
    if row[1]~="tallstrider" then Fact(key,"familyID",row[3],"family-metadata") end
    Fact(key,"iconFileID",row[4],"family-metadata")
    Fact(key,"name",row[2],"petopia-forever-roster","reference")
    if row[1]~="core-hound" then Fact(key,"name",row[2],"beastmaster-forever-roster","reference") end
end

for _,row in ipairs({{3035,1059,126171,"cat","cat-models"},
    {251115,136606,7581790,"bear","bear-models"}}) do
    local creature,appearance="creature-"..row[1],"appearance-"..row[2]
    Record(creature,"creature"); Record(appearance,"appearance")
    Fact(creature,"creatureID",row[1],row[5])
    Fact(creature,"family","family-"..row[4],row[5])
    Fact(creature,"appearance",appearance,row[5],"confirmed")
    Fact(appearance,"displayID",row[2],row[5])
    Fact(appearance,"modelFileID",row[3],row[5])
    Fact(appearance,"portraitVerified",true,row[5],"confirmed")
    Fact(appearance,"modelVerified",true,row[5],"confirmed")
end
-- Pet names do not establish wild NPC names. Neither stable record supplies a spawn.
Record("creature-251707","creature")
Fact("creature-251707","creatureID",251707,"galestrider")
Fact("creature-251707","name","Ornery Galestrider","galestrider")
Fact("creature-251707","family","family-tallstrider","galestrider")
Fact("creature-251707","observedLevel",9,"galestrider")
Fact("creature-251707","observerArea","Zephras Isle / Gustberry Lowlands","galestrider")
Fact("creature-251707","observerMapID",2521,"galestrider")

-- Spell presence on an active pet supplies no wild acquisition relationship.
for _,row in ipairs({{17255,"Bite",2},{16827,"Claw",1},{4188,"Great Stamina",2},
    {14916,"Growl",2},{24549,"Natural Armor",2},{1263113,"Slower Attack",2},{1742,"Cower",1}}) do
    local ability,rank="ability-for-"..row[1],"spell-"..row[1]
    Record(ability,"ability"); Record(rank,"rank")
    Fact(ability,"name",row[2],"pet-switch")
    Fact(rank,"ability",ability,"pet-switch")
    Fact(rank,"spellID",row[1],"pet-switch")
    -- Slower Attack II is preserved as a label; its Roman numeral is not a measured rank progression.
    if row[1]==1263113 then Fact(rank,"label","Slower Attack II","pet-switch")
    else Fact(rank,"ordinal",row[3],"pet-switch") end
end

-- Unmapped trainer rows are source observations, not identified rank/source links.
for _,row in ipairs({{3,18,"Great Stamina (Rank 2)",true},{4,24,"Great Stamina (Rank 3)",false}}) do
    local key="trainer-row-stamina-"..row[1]
    Record(key,"source")
    Fact(key,"sourceType","trainer-observation","trainer")
    Fact(key,"serviceName","Great Stamina","trainer")
    Fact(key,"serviceRank","Rank "..row[1],"trainer")
    Fact(key,"requiredLevel",row[2],"trainer")
    Fact(key,"prerequisiteText",row[3],"trainer")
    Fact(key,"prerequisiteSatisfied",row[4],"trainer")
    Fact(key,"availability","unavailable","trainer")
end
Fact("trainer-row-stamina-3","rawCost",400,"trainer")

-- Classic records have separate keys and no assumed mapping to Forever spell IDs.
Record("classic-stamina","ability","classic")
Record("classic-pet-trainer","source","classic")
Fact("classic-stamina","name","Great Stamina","petopia-stamina","reference")
Fact("classic-pet-trainer","sourceType","trainer","petopia-stamina","reference")
for _,row in ipairs({{2,12,10},{3,18,15},{4,24,25}}) do
    local key="classic-stamina-"..row[1]
    Record(key,"rank","classic")
    for field,value in pairs({ability="classic-stamina",ordinal=row[1],petLevel=row[2],
        trainingPoints=row[3],allFamilies=true,source="classic-pet-trainer"}) do
        Fact(key,field,value,"petopia-stamina","reference")
    end
    if row[1]>2 then Fact(key,"previous","classic-stamina-"..(row[1]-1),"petopia-stamina","reference") end
end
