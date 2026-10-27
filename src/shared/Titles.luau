--!strict
-- Cosmetic titles shown under the name on nametags. Earned from Critterdex pages, rebirths and
-- the group; the player picks one in the Critterdex (data.title).

export type Title = { id: string, text: string, color: Color3 }

local Titles: { [string]: Title } = {}

local function add(id: string, text: string, color: Color3)
	Titles[id] = { id = id, text = text, color = color }
end

-- Critterdex zone pages
add("MeadowRanger", "Meadow Ranger", Color3.fromRGB(140, 235, 110))
add("SwampStalker", "Swamp Stalker", Color3.fromRGB(110, 200, 150))
add("VolcanoVeteran", "Volcano Veteran", Color3.fromRGB(255, 150, 80))
-- Critterdex mutation pages
add("ShinyHunter", "Shiny Hunter", Color3.fromRGB(255, 240, 150))
add("GiantTamer", "Giant Tamer", Color3.fromRGB(255, 180, 120))
add("TinyFinder", "Tiny Finder", Color3.fromRGB(200, 220, 255))
add("GoldDigger", "Gold Digger", Color3.fromRGB(255, 205, 60))
add("FrostKeeper", "Frost Keeper", Color3.fromRGB(170, 225, 255))
add("RainbowChaser", "Rainbow Chaser", Color3.fromRGB(255, 150, 230))
-- Rebirths
add("Reborn1", "Reborn", Color3.fromRGB(200, 160, 255))
add("Reborn2", "Twice Reborn", Color3.fromRGB(180, 130, 255))
add("Reborn3", "Thrice Reborn", Color3.fromRGB(160, 100, 255))
-- Group
add("PackMember", "Pack Member", Color3.fromRGB(120, 200, 255))

return Titles
