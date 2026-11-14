-- The hero's 28 inventory slots and the items lying on the ground. Coins stack in one slot, everything else
-- takes a slot each. Tapping an item in the bag can Bury it (bones) or Drop it; dropped items and monster loot
-- lie where they fell, only their owner can take them for a minute, then anyone, until they vanish.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Items = require(ReplicatedStorage:WaitForChild("Shared").Items)
local Data = require(script.Parent.Data)
local Skills = require(script.Parent.Skills)
local Actions = require(script.Parent.Actions)

local Inventory = {}

local folder: Folder
local lastAction = {} -- [Player] = os.clock() of the last bury, so bones go in one every two ticks

local function slots(player: Player): { any }?
	local p = Data.get(player)
	return p and p.inv
end

function Inventory.count(player: Player, id: string): number
	local inv = slots(player)
	local n = 0
	for s = 1, Items.SLOTS do
		local it = inv and inv[s]
		if it and it.id == id then
			n += it.n
		end
	end
	return n
end

function Inventory.has(player: Player, id: string): boolean
	return Inventory.count(player, id) > 0
end

function Inventory.free(player: Player): number
	local inv = slots(player)
	if not inv then
		return 0
	end
	local n = 0
	for s = 1, Items.SLOTS do
		if not inv[s] then
			n += 1
		end
	end
	return n
end

function Inventory.canAdd(player: Player, id: string, n: number): boolean
	local def = Items.def(id)
	if not def or not slots(player) then
		return false
	end
	if def.stack then
		return Inventory.has(player, id) or Inventory.free(player) > 0
	end
	return Inventory.free(player) >= n
end

-- puts n of an item in the bag; false (and nothing added) when there is no room
function Inventory.add(player: Player, id: string, n: number): boolean
	local inv = slots(player)
	local def = Items.def(id)
	if not inv or not def or n < 1 or not Inventory.canAdd(player, id, n) then
		return false
	end
	if def.stack then
		for s = 1, Items.SLOTS do
			local it = inv[s]
			if it and it.id == id then
				it.n = math.min(2147483647, it.n + n)
				Data.publishInv(player)
				return true
			end
		end
		for s = 1, Items.SLOTS do
			if not inv[s] then
				inv[s] = { id = id, n = n }
				break
			end
		end
	else
		local left = n
		for s = 1, Items.SLOTS do
			if left == 0 then
				break
			end
			if not inv[s] then
				inv[s] = { id = id, n = 1 }
				left -= 1
			end
		end
	end
	Data.publishInv(player)
	return true
end

function Inventory.removeSlot(player: Player, s: number): { id: string, n: number }?
	local inv = slots(player)
	local it = inv and inv[s]
	if not it then
		return nil
	end
	inv[s] = false
	Data.publishInv(player)
	return it
end

-- ===== items on the ground =====

local function groundAt(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(ignore, enemies)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position or Vector3.new(pos.X, 0, pos.Z)
end

function Inventory.take(player: Player, m: Model)
	if not m.Parent or m.Parent ~= folder then
		return
	end
	local owner = m:GetAttribute("Owner")
	if owner and owner ~= player.UserId and os.clock() < (m:GetAttribute("PrivateUntil") or 0) then
		Skills.message(player, "That isn't yours to take yet.")
		return
	end
	Actions.start(player, { kind = "take", target = m, reach = 0.5 })
end

local function pickUp(player: Player, m: Model)
	local id, n = m:GetAttribute("Item"), m:GetAttribute("N") or 1
	if not Inventory.add(player, id, n) then
		Skills.message(player, "You don't have enough inventory space.")
		return
	end
	m:Destroy()
end

-- lays an item on the ground near pos; owner (a player) has it to themselves for a minute
function Inventory.drop(id: string, n: number, pos: Vector3, owner: Player?): Model?
	local def = Items.def(id)
	if not def then
		return nil
	end
	local m = def.build()
	m.Name = def.name
	local at = groundAt(pos)
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	-- a wider invisible pad under the item, easy to tap on a phone
	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = false
	pad.Transparency = 1
	pad.Size = Vector3.new(2.6, 1.2, 2.6)
	pad.CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0))
	pad.Parent = m
	m.PrimaryPart = pad
	m:SetAttribute("Item", id)
	m:SetAttribute("N", n)
	m:SetAttribute("Radius", 0.6)
	if owner then
		m:SetAttribute("Owner", owner.UserId)
		m:SetAttribute("PrivateUntil", os.clock() + Config.LOOT_PRIVATE)
	end
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 80
	click.Parent = m
	click.MouseClick:Connect(function(player)
		Inventory.take(player, m)
	end)
	m.Parent = folder
	task.delay(Config.LOOT_LIFETIME, function()
		if m.Parent then
			m:Destroy()
		end
	end)
	return m
end

-- ===== using items =====

local function onAction(player: Player, s: any, action: any)
	if type(s) ~= "number" or type(action) ~= "string" then
		return
	end
	local inv = slots(player)
	local it = inv and inv[s]
	local def = it and Items.def(it.id)
	if not def then
		return
	end
	local _, hrp = Skills.rootOf(player)
	if action == "Drop" then
		if not hrp then
			return
		end
		Inventory.removeSlot(player, s)
		Inventory.drop(it.id, it.n, hrp.Position - Vector3.new(0, 2.5, 0), player)
	elseif action == "Bury" and def.prayerXp then
		if not hrp or os.clock() - (lastAction[player] or 0) < Config.TICK * 2 - 0.05 then
			return
		end
		lastAction[player] = os.clock()
		Inventory.removeSlot(player, s)
		Skills.message(player, "You bury the bones.")
		Skills.addXp(player, "Prayer", def.prayerXp)
		local hum = Skills.rootOf(player)
		if hum then
			hum:Move(Vector3.zero)
		end
	end
end

function Inventory.tick()
	for player, a in Actions.all("take") do
		local m = a.target
		local _, hrp = Skills.rootOf(player)
		if not m.Parent or not hrp then
			Actions.stop(player, a)
			continue
		end
		local d = Skills.flat(hrp.Position, m:GetPivot().Position)
		if d <= Config.PICKUP_REACH then
			Actions.stop(player, a)
			pickUp(player, m)
		elseif d > 120 then
			Actions.stop(player, a)
		end
	end
end

function Inventory.init(remotes: Folder)
	folder = Instance.new("Folder")
	folder.Name = "GroundItems"
	folder.Parent = workspace
	local r = Instance.new("RemoteEvent")
	r.Name = "ItemAction"
	r.Parent = remotes
	r.OnServerEvent:Connect(onAction)
	Data.onLoaded(function(player)
		Data.publishInv(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return Inventory
