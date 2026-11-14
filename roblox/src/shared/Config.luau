-- Rules shared by the server and the clients: OSRS-style melee (game ticks of 0.6 s, accuracy and max hit
-- rolls), the skills' xp curve, the longsword, the rat, trees and loot.
local Config = {}

Config.TICK = 0.6

-- the hero's one-handed moves: our own uploaded animations (0 = not uploaded yet, Roblox's sword slash stands in)
Config.ANIM = {
	Hold = 71244894888144, -- AnimBuilder's Hold: the OSRS stance, in place of Roblox's arm-straight-out tool pose
	Slash = 92915599436003, -- AnimBuilder's Slash: from the stance over the shoulder, down in front, follow-through
	RobloxSlash = 522635514, -- Roblox's own R15 tool slash
}
Config.CONTACT = 0.33 -- seconds from the start of a swing to the blade landing (the Slash's "Hit" marker)

Config.SOUNDS = {
	Swish = 9126283272,
	Hit = 9120893061,
}

Config.SWORD = {
	name = "Bronze longsword",
	speed = 5, -- ticks between swings
	attack = 6, -- slash attack bonus
	strength = 5,
	color = Color3.fromRGB(214, 156, 88),
}

Config.STYLES = {
	{ id = "accurate", name = "Accurate", skill = "Attack", attack = 3, strength = 0, defence = 0 },
	{ id = "aggressive", name = "Aggressive", skill = "Strength", attack = 0, strength = 3, defence = 0 },
	{ id = "defensive", name = "Defensive", skill = "Defence", attack = 0, strength = 0, defence = 3 },
}

Config.REACH = 5 -- studs between the hero and the target's edge for a melee swing

Config.ENEMIES = {
	Rat = {
		level = 1,
		hp = 2,
		attack = 1,
		strength = 1,
		defence = 1,
		maxHit = 1,
		speed = 4, -- ticks between bites
		respawn = 15, -- seconds
		count = 7,
		walk = 7,
		-- what it leaves behind: always its bones, sometimes a few coins
		drops = { { id = "bones", n = 1, chance = 1 }, { id = "coins", min = 1, max = 8, chance = 0.4 } },
	},
}

-- Woodcutting: a roll every 4 ticks while chopping; the chance climbs from low (level 1) to high (level 99)
-- out of 256, as in OSRS for a bronze axe. A normal tree falls after one log, an oak has a 1 in 8 chance a log.
Config.CHOP_TICKS = 4
Config.TREES = {
	Tree = { name = "Tree", level = 1, xp = 25, log = "logs", low = 64, high = 200, deplete = 1, respawn = { 8, 14 } },
	Oak = { name = "Oak", level = 15, xp = 37.5, log = "oak_logs", low = 32, high = 100, deplete = 1 / 8, respawn = { 14, 22 } },
}
Config.AXE = "bronze_axe"
Config.START_ITEMS = { { id = "bronze_axe", n = 1 } }

-- ground items: only whoever dropped or earned them can take them at first, then anyone, then they are gone
Config.LOOT_PRIVATE = 60
Config.LOOT_LIFETIME = 180
Config.PICKUP_REACH = 3

Config.SKILLS = { "Attack", "Strength", "Defence", "Hitpoints", "Prayer", "Woodcutting" }
Config.START_XP = { Hitpoints = 1154 } -- level 10 Hitpoints, as every new adventurer has

-- total xp needed for each level (the standard RuneScape curve)
local XP = { [1] = 0 }
do
	local points = 0
	for lvl = 1, 98 do
		points += math.floor(lvl + 300 * 2 ^ (lvl / 7))
		XP[lvl + 1] = math.floor(points / 4)
	end
end

function Config.levelFor(xp: number): number
	local lvl = 1
	while lvl < 99 and xp >= XP[lvl + 1] do
		lvl += 1
	end
	return lvl
end

function Config.xpFor(level: number): number
	return XP[math.clamp(level, 1, 99)]
end

-- the chance an attack roll beats a defence roll
function Config.hitChance(attackRoll: number, defenceRoll: number): number
	if attackRoll > defenceRoll then
		return 1 - (defenceRoll + 2) / (2 * (attackRoll + 1))
	end
	return attackRoll / (2 * (defenceRoll + 1))
end

-- the combat level from the five combat skills (OSRS: melee only so far)
function Config.combatLevel(levels: { [string]: number }): number
	local base = 0.25 * ((levels.Defence or 1) + (levels.Hitpoints or 10) + math.floor((levels.Prayer or 1) / 2))
	local melee = 0.325 * ((levels.Attack or 1) + (levels.Strength or 1))
	return math.floor(base + melee)
end

-- the chance out of 1 that one woodcutting roll gets a log
function Config.chopChance(tree, level: number): number
	local l = math.clamp(level, 1, 99)
	return (1 + math.floor(tree.low * (99 - l) / 98 + tree.high * (l - 1) / 98 + 0.5)) / 256
end

function Config.styleById(id: string?)
	for _, s in Config.STYLES do
		if s.id == id then
			return s
		end
	end
	return Config.STYLES[1]
end

return Config
