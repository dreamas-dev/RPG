-- Melee on the OSRS clock: everything happens on 0.6 s ticks. Tap a rat to fight it; your hero walks up (the
-- client) and swings every 5 ticks with the longsword while the rat bites back every 4. Accuracy and max hit are
-- rolled from levels, the combat style and the sword's bonuses; damage gives 4 xp per point to the style's skill
-- and 1.33 to Hitpoints. A rat that dies falls over and comes back a little later somewhere in the granary yard.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Sword = require(script.Parent.Sword)
local World = require(script.Parent.World)
local Skills = require(script.Parent.Skills)
local Actions = require(script.Parent.Actions)
local Inventory = require(script.Parent.Inventory)

local rootOf, flat, level, addXp = Skills.rootOf, Skills.flat, Skills.level, Skills.addXp

local Combat = {}

local RAT_ASSET = 3374795585 -- "Rat" by Roblox
local RAT_RADIUS = 1.6

local remotes: Folder
local rng = Random.new()
local enemies = {} -- [Model] = state
local template: Model?

local function fightOf(player: Player?)
	return player and Actions.get(player, "fight")
end

local function splat(target: BasePart, dmg: number, by: Player?)
	remotes.Splat:FireAllClients(target, dmg, by)
end

-- ===== the rats =====

local function yardPoint(): Vector3
	local y = World.RAT_YARD
	return y.center + Vector3.new(rng:NextNumber(-0.42, 0.42) * y.size.X, 0, rng:NextNumber(-0.4, 0.4) * y.size.Z)
end

local function spawnEnemy(kind: string)
	local def = Config.ENEMIES[kind]
	local m = (template :: Model):Clone()
	m.Name = kind
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local pos = yardPoint()
	m:PivotTo(CFrame.new(pos + Vector3.new(0, hrp.Size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Level", def.level)
	m:SetAttribute("Hp", def.hp)
	m:SetAttribute("MaxHp", def.hp)
	m:SetAttribute("Radius", RAT_RADIUS)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 120
	click.CursorIcon = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png"
	click.Parent = m
	m.Parent = workspace:FindFirstChild("Enemies") or workspace
	hrp:SetNetworkOwner(nil)
	CollectionService:AddTag(m, "Enemy")

	local state = { kind = kind, def = def, hp = def.hp, alive = true, model = m, hum = hum, hrp = hrp, home = pos,
		target = nil :: Player?, nextBite = 0, nextWander = os.clock() + rng:NextNumber(1, 4) }
	enemies[m] = state

	-- the walk cycle that comes with the model (Roblox's own animation)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local anim = m:FindFirstChildWhichIsA("Animation", true)
	if anim then
		local walk = animator:LoadAnimation(anim)
		walk.Looped = true
		hum.Running:Connect(function(speed)
			if speed > 0.5 and state.alive then
				if not walk.IsPlaying then
					walk:Play(0.1)
				end
				walk:AdjustSpeed(speed / 7)
			elseif walk.IsPlaying then
				walk:Stop(0.15)
			end
		end)
	end

	click.MouseClick:Connect(function(player)
		Combat.attack(player, m)
	end)
end

local function killEnemy(state, killer: Player?)
	state.alive = false
	state.model:SetAttribute("Dead", true)
	state.hum:MoveTo(state.hrp.Position)
	local cd = state.model:FindFirstChildOfClass("ClickDetector")
	if cd then
		cd:Destroy()
	end
	for player, f in Actions.all("fight") do
		if f.target == state.model then
			Actions.stop(player, f)
		end
	end
	-- the loot falls where it died; the hero who killed it has it to themselves for a minute
	local at = state.hrp.Position
	for i, drop in state.def.drops or {} do
		if rng:NextNumber() < drop.chance then
			local n = drop.n or rng:NextInteger(drop.min, drop.max)
			local spread = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			Inventory.drop(drop.id, n, at + spread, killer)
		end
	end
	task.delay(1.6, function()
		enemies[state.model] = nil
		state.model:Destroy()
	end)
	task.delay(state.def.respawn, spawnEnemy, state.kind)
end

-- ===== fighting =====

function Combat.attack(player: Player, m: Model)
	local state = enemies[m]
	local hum, hrp = rootOf(player)
	if not state or not state.alive or not hum then
		return
	end
	-- single combat, as in OSRS
	local other = fightOf(state.target)
	if state.target and state.target ~= player and other and other.target == m then
		remotes.Message:FireClient(player, "Someone else is fighting that.", "info")
		return
	end
	if flat(hrp.Position, state.hrp.Position) > 120 then
		return
	end
	local f = fightOf(player)
	if f and f.target == m then
		return
	end
	Actions.start(player, { kind = "fight", target = m, reach = Config.REACH - 1, nextSwing = 0 })
end

local function swing(player: Player, f)
	local state = enemies[f.target]
	local hum, hrp = rootOf(player)
	if not state or not hum then
		return
	end
	local contact = Sword.swing(player.Character)
	-- the rat fights back from the first swing on
	if not state.target then
		state.target = player
		state.nextBite = os.clock() + Config.TICK * 2
	end
	task.delay(contact, function()
		if fightOf(player) ~= f or not state.alive then
			return
		end
		local style = Config.styleById(player:GetAttribute("Style"))
		local sword = Config.SWORD
		local effAtt = level(player, "Attack") + style.attack + 8
		local effStr = level(player, "Strength") + style.strength + 8
		local attackRoll = effAtt * (sword.attack + 64)
		local defenceRoll = (state.def.defence + 9) * 64
		local maxHit = math.max(1, math.floor(0.5 + effStr * (sword.strength + 64) / 640))
		local dmg = 0
		if rng:NextNumber() < Config.hitChance(attackRoll, defenceRoll) then
			dmg = math.min(rng:NextInteger(0, maxHit), state.hp)
		end
		state.hp -= dmg
		state.model:SetAttribute("Hp", state.hp)
		if dmg > 0 then
			state.model:SetAttribute("Hurt", (state.model:GetAttribute("Hurt") or 0) + 1)
			addXp(player, style.skill, dmg * 4)
			addXp(player, "Hitpoints", dmg * 4 / 3)
		end
		splat(state.hrp, dmg, player)
		if state.hp <= 0 then
			killEnemy(state, player)
		end
	end)
end

local function bite(state, player: Player)
	local hum, hrp = rootOf(player)
	if not hum then
		return
	end
	state.model:SetAttribute("Atk", (state.model:GetAttribute("Atk") or 0) + 1)
	task.delay(0.2, function()
		if not state.alive or not hum.Parent or hum.Health <= 0 then
			return
		end
		local style = Config.styleById(player:GetAttribute("Style"))
		local attackRoll = (state.def.attack + 9) * 64
		local defenceRoll = (level(player, "Defence") + style.defence + 8) * 64
		local dmg = 0
		if rng:NextNumber() < Config.hitChance(attackRoll, defenceRoll) then
			dmg = rng:NextInteger(0, state.def.maxHit)
		end
		if dmg > 0 then
			hum.Health = math.max(0, hum.Health - dmg)
		end
		splat(hrp, dmg, nil)
	end)
end

function Combat.tick()
	local now = os.clock()
	for player, f in Actions.all("fight") do
		local state = enemies[f.target]
		local hum, hrp = rootOf(player)
		if not state or not state.alive or not hum then
			Actions.stop(player, f)
			continue
		end
		local d = flat(hrp.Position, state.hrp.Position) - RAT_RADIUS
		if d > 60 then
			Actions.stop(player, f)
		elseif d <= Config.REACH and now >= f.nextSwing - 0.05 then
			f.nextSwing = now + Config.SWORD.speed * Config.TICK
			swing(player, f)
		end
	end
	for _, state in enemies do
		if not state.alive then
			continue
		end
		local p = state.target
		local hum, hrp
		if p then
			hum, hrp = rootOf(p)
		end
		-- give up when the hero is gone, dead or has run off
		if p and (not hum or flat(hrp.Position, state.home) > 70 or not (fightOf(p) and (fightOf(p) :: any).target == state.model) and flat(hrp.Position, state.hrp.Position) > 14) then
			state.target = nil
			state.hum:MoveTo(state.home)
			continue
		end
		if p and hrp then
			local d = flat(hrp.Position, state.hrp.Position)
			if d > RAT_RADIUS + 2.4 then
				local toward = (state.hrp.Position - hrp.Position) * Vector3.new(1, 0, 1)
				state.hum:MoveTo(hrp.Position + toward.Unit * (RAT_RADIUS + 1.6))
			else
				state.hum:MoveTo(state.hrp.Position)
				state.hrp.CFrame = CFrame.lookAt(state.hrp.Position, Vector3.new(hrp.Position.X, state.hrp.Position.Y, hrp.Position.Z))
			end
			if d <= Config.REACH + RAT_RADIUS and now >= state.nextBite then
				state.nextBite = now + state.def.speed * Config.TICK
				bite(state, p)
			end
		elseif now >= state.nextWander then
			state.nextWander = now + rng:NextNumber(3, 8)
			state.hum.WalkSpeed = state.def.walk * 0.6
			state.hum:MoveTo(yardPoint())
		end
		if p then
			state.hum.WalkSpeed = state.def.walk * 1.4
		end
	end
end

-- ===== players =====

local function setupPlayer(player: Player)
	local function onChar(char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		-- skills come from the save: wait for it before setting the hero's hitpoints
		while not player:GetAttribute("Loaded") and player.Parent do
			player:GetAttributeChangedSignal("Loaded"):Wait()
		end
		local hp = level(player, "Hitpoints")
		hum.MaxHealth = hp
		hum.Health = hp
		hum.Died:Connect(function()
			Actions.stop(player)
			remotes.Message:FireClient(player, "Oh dear, you are dead!", "dead")
		end)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		task.spawn(onChar, player.Character)
	end
end

function Combat.init(r: Folder)
	remotes = r

	-- Hitpoints work as in OSRS: no Roblox health regeneration, one point back a minute instead
	if not StarterPlayer.StarterCharacterScripts:FindFirstChild("Health") then
		local none = Instance.new("Script")
		none.Name = "Health"
		none.Parent = StarterPlayer.StarterCharacterScripts
	end
	task.spawn(function()
		while true do
			task.wait(60)
			for _, p in Players:GetPlayers() do
				local hum = rootOf(p)
				if hum and hum.Health < hum.MaxHealth then
					hum.Health = math.min(hum.MaxHealth, hum.Health + 1)
				end
			end
		end
	end)

	remotes.SetStyle.OnServerEvent:Connect(function(player, id)
		if type(id) == "string" and Config.styleById(id).id == id then
			player:SetAttribute("Style", id)
		end
	end)

	-- for play tests in Studio: the command bar has its own copy of this module, so it starts fights through this
	if game:GetService("RunService"):IsStudio() then
		local test = Instance.new("BindableEvent")
		test.Name = "TestAttack"
		test.Event:Connect(Combat.attack)
		test.Parent = game:GetService("ServerStorage")
	end

	for _, p in Players:GetPlayers() do
		setupPlayer(p)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(p)
		for _, state in enemies do
			if state.target == p then
				state.target = nil
			end
		end
	end)

	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	local ok, loaded = pcall(InsertService.LoadAsset, InsertService, RAT_ASSET)
	if ok then
		local rig = loaded:FindFirstChildWhichIsA("Humanoid", true)
		template = rig and rig.Parent :: Model
		if template then
			template.Parent = nil
			local hum = template:FindFirstChildOfClass("Humanoid") :: Humanoid
			-- an R15 humanoid stands its root part HipHeight above the ground; the meshes only ride along
			hum.RigType = Enum.HumanoidRigType.R15
			hum.HipHeight = 0.1
			for _, d in template:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.CanCollide = d.Name == "HumanoidRootPart"
					d.Massless = d.Name ~= "HumanoidRootPart"
				end
			end
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			hum.BreakJointsOnDeath = false
			hum.MaxHealth = math.huge
			hum.Health = math.huge
			template.PrimaryPart = template:FindFirstChild("HumanoidRootPart")
			for _ = 1, Config.ENEMIES.Rat.count do
				spawnEnemy("Rat")
			end
		end
	else
		warn("Rat model failed to load: " .. tostring(loaded))
	end

end

return Combat
