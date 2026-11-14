-- Skill xp lives in player attributes (XP_<skill>), loaded from and saved to the hero's save by Data.
-- Everything that gives xp goes through Skills.addXp, which sends the xp drop and the level-up message.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Skills = {}

local remotes: Folder

function Skills.init(r: Folder)
	remotes = r
end

function Skills.xp(player: Player, skill: string): number
	return player:GetAttribute("XP_" .. skill) or 0
end

function Skills.level(player: Player, skill: string): number
	return Config.levelFor(Skills.xp(player, skill))
end

function Skills.message(player: Player, text: string, kind: string?)
	remotes.Message:FireClient(player, text, kind or "info")
end

function Skills.addXp(player: Player, skill: string, amount: number)
	local before = Skills.level(player, skill)
	player:SetAttribute("XP_" .. skill, math.min(200000000, Skills.xp(player, skill) + amount))
	remotes.Xp:FireClient(player, skill, amount)
	local after = Skills.level(player, skill)
	if after > before then
		Skills.message(player, string.format("Congratulations, your %s level is now %d.", skill, after), "level")
		if skill == "Hitpoints" then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.MaxHealth = after
				hum.Health = math.min(after, hum.Health + (after - before))
			end
		end
	end
end

-- the hero's humanoid and root part while alive
function Skills.rootOf(player: Player): (Humanoid?, BasePart?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and hrp and hum.Health > 0 then
		return hum, hrp
	end
	return nil, nil
end

function Skills.flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

return Skills
