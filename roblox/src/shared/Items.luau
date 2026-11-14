-- Every item a hero can carry: its name, whether it stacks, what it does in the inventory and how it looks.
-- The same small part model is used for the item lying on the ground and for its picture in the inventory.
local Items = {}

export type Def = {
	name: string,
	stack: boolean?,
	actions: { string }?, -- what tapping it in the inventory offers, besides Drop
	examine: string,
	prayerXp: number?,
	build: () -> Model,
}

local function part(m: Model, props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Class" then
			p[k] = v
		end
	end
	p.Parent = m
	return p
end

-- a model whose pivot sits on the ground under its middle
local function new(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function finish(m: Model): Model
	local cf, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	return m
end

local GOLD = Color3.fromRGB(240, 196, 60)
local BONE = Color3.fromRGB(236, 230, 210)
local BARK = Color3.fromRGB(112, 78, 48)
local BRONZE = Color3.fromRGB(214, 156, 88)

local function coins(): Model
	local m = new("Coins")
	for i, off in { Vector3.new(0, 0, 0), Vector3.new(0.12, 0.16, 0.05), Vector3.new(-0.05, 0.32, -0.08), Vector3.new(0.55, 0, 0.35) } do
		part(m, { Shape = Enum.PartType.Cylinder, Name = "Coin" .. i, Size = Vector3.new(0.14, 0.8, 0.8), Color = GOLD,
			Material = Enum.Material.Metal, Reflectance = 0.25, CFrame = CFrame.new(off + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	return finish(m)
end

local function bones(): Model
	local m = new("Bones")
	local cf = CFrame.new(0, 0.22, 0) * CFrame.Angles(0, math.rad(25), 0)
	part(m, { Shape = Enum.PartType.Cylinder, Name = "Shaft", Size = Vector3.new(1.5, 0.26, 0.26), Color = BONE, Material = Enum.Material.SmoothPlastic, CFrame = cf })
	for _, x in { -0.75, 0.75 } do
		for _, z in { -0.13, 0.13 } do
			part(m, { Shape = Enum.PartType.Ball, Name = "Knob", Size = Vector3.new(0.38, 0.38, 0.38), Color = BONE, Material = Enum.Material.SmoothPlastic,
				CFrame = cf * CFrame.new(x, 0, z) })
		end
	end
	return finish(m)
end

local function logs(color: Color3, ring: Color3, thick: number): () -> Model
	return function()
		local m = new("Logs")
		for i, off in { CFrame.new(0, thick / 2, -thick * 0.52), CFrame.new(0, thick / 2, thick * 0.52), CFrame.new(0.1, thick * 1.35, 0) } do
			local cf = off * CFrame.Angles(0, math.rad(i * 7), 0)
			part(m, { Shape = Enum.PartType.Cylinder, Name = "Log", Size = Vector3.new(1.7, thick, thick), Color = color, Material = Enum.Material.Wood, CFrame = cf })
			for _, x in { -0.86, 0.86 } do
				part(m, { Shape = Enum.PartType.Cylinder, Name = "Ring", Size = Vector3.new(0.04, thick * 0.86, thick * 0.86), Color = ring,
					Material = Enum.Material.WoodPlanks, CFrame = cf * CFrame.new(x, 0, 0) })
			end
		end
		return finish(m)
	end
end

-- an axe lying on its side: a wooden haft and a bronze head
local function axe(): Model
	local m = new("Axe")
	local cf = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, math.rad(30), math.pi / 2)
	part(m, { Name = "Haft", Size = Vector3.new(0.2, 2, 0.2), Color = BARK, Material = Enum.Material.Wood, CFrame = cf })
	part(m, { Name = "Head", Size = Vector3.new(0.16, 0.42, 0.5), Color = BRONZE, Material = Enum.Material.Metal, CFrame = cf * CFrame.new(0, 0.78, -0.3) })
	part(m, { Class = "WedgePart", Name = "Edge", Size = Vector3.new(0.14, 0.62, 0.34), Color = BRONZE:Lerp(Color3.new(1, 1, 1), 0.15),
		Material = Enum.Material.Metal, CFrame = cf * CFrame.new(0, 0.78, -0.72) * CFrame.Angles(0, math.pi, 0) })
	return finish(m)
end

Items.DEFS = {
	coins = { name = "Coins", stack = true, examine = "Lovely money!", build = coins },
	bones = { name = "Bones", actions = { "Bury" }, prayerXp = 4.5, examine = "Bones are for burying!", build = bones },
	logs = { name = "Logs", examine = "A number of wooden logs.", build = logs(BARK, Color3.fromRGB(214, 176, 120), 0.62) },
	oak_logs = { name = "Oak logs", examine = "Logs cut from an oak tree.", build = logs(Color3.fromRGB(86, 62, 38), Color3.fromRGB(196, 150, 90), 0.72) },
	bronze_axe = { name = "Bronze axe", examine = "A woodcutter's axe.", build = axe },
} :: { [string]: Def }

Items.SLOTS = 28

function Items.def(id: string): Def?
	return Items.DEFS[id]
end

-- "1.2K" and "3.4M" for big stacks, as the inventory shows them
function Items.short(n: number): string
	if n >= 10000000 then
		return string.format("%dM", n // 1000000)
	elseif n >= 100000 then
		return string.format("%dK", n // 1000)
	end
	return tostring(n)
end

return Items
