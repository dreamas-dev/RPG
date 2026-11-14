-- Woodcutting: tap a tree, the hero walks up, takes the bronze axe out and chops on the OSRS clock, one roll
-- every 4 ticks. A log goes in the bag with its xp; a normal tree then falls to a stump, an oak only sometimes.
-- Stumps grow back after a while. You need an axe in the bag and room for the logs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Skills = require(script.Parent.Skills)
local Actions = require(script.Parent.Actions)
local Inventory = require(script.Parent.Inventory)
local Sword = require(script.Parent.Sword)

local Woodcutting = {}

local rng = Random.new()
local trees = {} -- [Model] = { def, trunk, size, cf, leaves = { [BasePart] = transparency }, down }

local function fell(tree: Model)
	local t = trees[tree]
	if not t or t.down then
		return
	end
	t.down = true
	tree:SetAttribute("Stump", true)
	local click = tree:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MaxActivationDistance = 0
	end
	for leaf in t.leaves do
		leaf.Transparency = 1
		leaf.CanCollide = false
		leaf.CanQuery = false
	end
	-- the trunk shrinks to a stump: a cylinder's length runs along its local X, which points up here
	local stump = 1.3
	t.trunk.Size = Vector3.new(stump, t.size.Y * 1.15, t.size.Z * 1.15)
	t.trunk.CFrame = t.cf * CFrame.new(-(t.size.X - stump) / 2, 0, 0)
	t.trunk.Color = t.color:Lerp(Color3.fromRGB(200, 170, 120), 0.25)
	for player, a in Actions.all("chop") do
		if a.target == tree then
			Actions.stop(player, a)
		end
	end
	task.delay(rng:NextNumber(t.def.respawn[1], t.def.respawn[2]), function()
		for leaf, tr in t.leaves do
			leaf.Transparency = tr
			leaf.CanQuery = true
		end
		t.trunk.Size = t.size
		t.trunk.CFrame = t.cf
		t.trunk.Color = t.color
		t.down = false
		tree:SetAttribute("Stump", false)
		if click then
			click.MaxActivationDistance = 120
		end
	end)
end

function Woodcutting.chop(player: Player, tree: Model)
	local t = trees[tree]
	if not t or not Skills.rootOf(player) then
		return
	end
	if t.down then
		return
	end
	local lvl = Skills.level(player, "Woodcutting")
	if lvl < t.def.level then
		Skills.message(player, string.format("You need a Woodcutting level of %d to chop down this tree.", t.def.level))
		return
	end
	if not Inventory.has(player, Config.AXE) then
		Skills.message(player, "You do not have an axe which you have the Woodcutting level to use.")
		return
	end
	if not Inventory.canAdd(player, t.def.log, 1) then
		Skills.message(player, "Your inventory is too full to hold any more logs.")
		return
	end
	local current = Actions.get(player, "chop")
	if current and current.target == tree then
		return
	end
	local action
	action = {
		kind = "chop",
		target = tree,
		reach = 1.2,
		started = false,
		nextRoll = 0,
		stop = function()
			if action.started then
				Sword.hold(player, "sword")
			end
		end,
	}
	Actions.start(player, action)
end

local function roll(player: Player, a, t)
	local contact = Sword.swing(player.Character)
	task.delay(contact, function()
		if Actions.get(player, "chop") ~= a or t.down then
			return
		end
		local tree = a.target
		tree:SetAttribute("Chops", (tree:GetAttribute("Chops") or 0) + 1)
		if rng:NextNumber() >= Config.chopChance(t.def, Skills.level(player, "Woodcutting")) then
			return
		end
		if not Inventory.add(player, t.def.log, 1) then
			Skills.message(player, "Your inventory is too full to hold any more logs.")
			Actions.stop(player, a)
			return
		end
		Skills.message(player, t.def.log == "logs" and "You get some logs." or "You get some oak logs.")
		Skills.addXp(player, "Woodcutting", t.def.xp)
		if rng:NextNumber() < t.def.deplete then
			fell(a.target)
		elseif not Inventory.canAdd(player, t.def.log, 1) then
			Skills.message(player, "Your inventory is too full to hold any more logs.")
			Actions.stop(player, a)
		end
	end)
end

function Woodcutting.tick()
	local now = os.clock()
	for player, a in Actions.all("chop") do
		local t = trees[a.target]
		local _, hrp = Skills.rootOf(player)
		if not t or t.down or not hrp or not Inventory.has(player, Config.AXE) then
			Actions.stop(player, a)
			continue
		end
		local d = Skills.flat(hrp.Position, t.trunk.Position) - (a.target:GetAttribute("Radius") or 1)
		if d > 120 then
			Actions.stop(player, a)
		elseif d <= a.reach + 1.5 then
			if not a.started then
				a.started = true
				a.nextRoll = now + Config.TICK
				Sword.hold(player, "axe")
				Skills.message(player, "You swing your axe at the tree.")
			elseif now >= a.nextRoll - 0.05 then
				a.nextRoll = now + Config.CHOP_TICKS * Config.TICK
				roll(player, a, t)
			end
		end
	end
end

local function setup(tree: Model)
	local def = Config.TREES[tree:GetAttribute("Kind") or "Tree"]
	local trunk = tree:FindFirstChild("Trunk") :: BasePart?
	if not def or not trunk then
		return
	end
	local leaves = {}
	for _, p in tree:GetChildren() do
		if p:IsA("BasePart") and p ~= trunk then
			leaves[p] = p.Transparency
		end
	end
	trees[tree] = { def = def, trunk = trunk, size = trunk.Size, cf = trunk.CFrame, color = trunk.Color, leaves = leaves, down = false }
	tree.PrimaryPart = trunk
	tree:SetAttribute("Radius", trunk.Size.Y / 2)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 120
	click.Parent = tree
	click.MouseClick:Connect(function(player)
		Woodcutting.chop(player, tree)
	end)
end

function Woodcutting.init()
	for _, tree in CollectionService:GetTagged("Tree") do
		setup(tree)
	end
	CollectionService:GetInstanceAddedSignal("Tree"):Connect(setup)
end

return Woodcutting
