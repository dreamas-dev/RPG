-- Endless Road: builds the starter town, loads every hero's save, hands out the longsword and runs the
-- game clock: combat, woodcutting and picking things up all move on the same 0.6 s OSRS tick.
-- BUILD er-2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local World = require(script.Parent.World)
local Data = require(script.Parent.Data)
local Skills = require(script.Parent.Skills)
local Actions = require(script.Parent.Actions)
local Inventory = require(script.Parent.Inventory)
local Sword = require(script.Parent.Sword)
local Combat = require(script.Parent.Combat)
local Woodcutting = require(script.Parent.Woodcutting)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "Splat", "Xp", "Fight", "Message", "SetStyle", "StopFight" } do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end

World.build()
Skills.init(remotes)
Actions.init(remotes)
Inventory.init(remotes)
remotes.Parent = ReplicatedStorage
Data.init()
Sword.init()
Combat.init(remotes)
Woodcutting.init()

-- for play tests in Studio: the command bar gets its own copies of these modules, so it reaches the live ones
-- through this function, e.g. Test:Invoke("give", player, "bones", 3)
if RunService:IsStudio() then
	local test = Instance.new("BindableFunction")
	test.Name = "Test"
	test.OnInvoke = function(cmd: string, player: Player, ...)
		local args = { ... }
		if cmd == "give" then
			return Inventory.add(player, args[1], args[2] or 1)
		elseif cmd == "chop" then
			return Woodcutting.chop(player, args[1])
		elseif cmd == "take" then
			return Inventory.take(player, args[1])
		elseif cmd == "drop" then
			return Inventory.drop(args[1], args[2] or 1, args[3], player) ~= nil
		elseif cmd == "action" then
			local a = Actions.get(player)
			return a and a.kind
		elseif cmd == "xp" then
			return Skills.addXp(player, args[1], args[2])
		end
		return nil
	end
	test.Parent = ServerStorage
end

task.spawn(function()
	while true do
		task.wait(Config.TICK)
		for _, step in { Combat.tick, Woodcutting.tick, Inventory.tick } do
			local ok, err = pcall(step)
			if not ok then
				warn("tick: " .. tostring(err))
			end
		end
	end
end)
