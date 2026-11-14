-- The inventory: 28 slots in a 4 x 7 grid, opened with the Bag button. Each item is drawn as a small 3D model
-- (the same one that lies on the ground) with its count for stacks. Tapping an item opens its options:
-- Bury for bones, Drop and Examine. The server sends the slots as JSON in the player's "Inv" attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local Bag = {}

local player = Players.LocalPlayer
local SLOT = 52
local GAP = 4
local COLS = 4
local ROWS = Items.SLOTS // COLS

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

-- a picture of an item: its model in a ViewportFrame, the camera fitted around it at a three-quarter angle
function Bag.icon(id: string, parent: Instance): ViewportFrame?
	local def = Items.def(id)
	if not def then
		return nil
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Icon"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(170, 170, 170)
	vp.LightColor = Color3.fromRGB(255, 250, 235)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	local m = def.build()
	m:PivotTo(CFrame.new())
	m.Parent = vp
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local r = size.Magnitude / 2
	local dist = r / math.tan(math.rad(cam.FieldOfView / 2)) * 1.05
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.55, 0.75, 1).Unit * dist, cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = parent
	return vp
end

function Bag.init(gui: ScreenGui, font: Enum.Font, say: (string) -> ())
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local itemAction = remotes:WaitForChild("ItemAction") :: RemoteEvent

	local button = Instance.new("TextButton")
	button.Name = "BagButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -12, 1, -76)
	button.Size = UDim2.fromOffset(190, 48)
	button.BackgroundColor3 = Color3.fromRGB(96, 70, 44)
	button.Font = font
	button.TextSize = 20
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "🎒 Bag"
	corner(button, 14)
	stroke(button, 2, Color3.fromRGB(50, 34, 20))
	button.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Bag"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -12, 1, -132)
	panel.Size = UDim2.fromOffset(COLS * SLOT + (COLS - 1) * GAP + 16, ROWS * SLOT + (ROWS - 1) * GAP + 16)
	panel.BackgroundColor3 = Color3.fromRGB(62, 53, 41)
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	corner(panel, 12)
	stroke(panel, 2, Color3.fromRGB(120, 96, 60))
	panel.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local slots = {}
	for s = 1, Items.SLOTS do
		local col, row = (s - 1) % COLS, (s - 1) // COLS
		local f = Instance.new("TextButton")
		f.Name = "Slot" .. s
		f.Text = ""
		f.AutoButtonColor = false
		f.Position = UDim2.fromOffset(8 + col * (SLOT + GAP), 8 + row * (SLOT + GAP))
		f.Size = UDim2.fromOffset(SLOT, SLOT)
		f.BackgroundColor3 = Color3.fromRGB(44, 37, 29)
		f.BackgroundTransparency = 0.2
		corner(f, 8)
		f.Parent = panel
		local count = Instance.new("TextLabel")
		count.Name = "Count"
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromOffset(3, 1)
		count.Size = UDim2.new(1, -6, 0, 16)
		count.Font = font
		count.TextSize = 15
		count.TextColor3 = Color3.fromRGB(255, 230, 80)
		count.TextStrokeTransparency = 0.2
		count.TextXAlignment = Enum.TextXAlignment.Left
		count.ZIndex = 3
		count.Text = ""
		count.Parent = f
		slots[s] = { frame = f, count = count, id = nil :: string?, icon = nil :: Instance? }
	end

	local items = {} -- [slot] = { id, n }

	-- the options for one item, shown over the bag
	local menu = Instance.new("Frame")
	menu.Name = "ItemMenu"
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.fromOffset(170, 0)
	menu.AutomaticSize = Enum.AutomaticSize.Y
	menu.BackgroundColor3 = Color3.fromRGB(30, 26, 20)
	menu.Visible = false
	menu.ZIndex = 10
	corner(menu, 10)
	stroke(menu, 2, Color3.fromRGB(150, 120, 70))
	menu.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = menu
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = menu

	local function closeMenu()
		menu.Visible = false
		for _, c in menu:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local function option(text: string, order: number, color: Color3, fn: () -> ())
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(1, 0, 0, 38)
		b.BackgroundColor3 = color
		b.Font = font
		b.TextSize = 18
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = text
		b.ZIndex = 11
		corner(b, 8)
		b.Parent = menu
		b.Activated:Connect(function()
			closeMenu()
			fn()
		end)
	end

	local function openMenu(s: number)
		closeMenu()
		local it = items[s]
		local def = it and Items.def(it.id)
		if not def then
			return
		end
		local title = Instance.new("TextLabel")
		title.LayoutOrder = 0
		title.Size = UDim2.new(1, 0, 0, 24)
		title.BackgroundTransparency = 1
		title.Font = font
		title.TextSize = 18
		title.TextColor3 = Color3.fromRGB(255, 160, 64)
		title.Text = def.name
		title.ZIndex = 11
		title.Parent = menu
		local order = 1
		for _, action in def.actions or {} do
			option(action, order, Color3.fromRGB(70, 120, 60), function()
				itemAction:FireServer(s, action)
			end)
			order += 1
		end
		option("Drop", order, Color3.fromRGB(140, 60, 44), function()
			itemAction:FireServer(s, "Drop")
		end)
		option("Examine", order + 1, Color3.fromRGB(60, 74, 110), function()
			say(def.examine)
		end)
		option("Cancel", order + 2, Color3.fromRGB(70, 66, 60), function() end)
		-- next to the slot, kept inside the bag
		local f = slots[s].frame
		local x = math.clamp(f.Position.X.Offset + SLOT / 2, 85 + 4, panel.Size.X.Offset - 85 - 4)
		local y = math.clamp(f.Position.Y.Offset + SLOT / 2, 110, panel.Size.Y.Offset - 110)
		menu.Position = UDim2.fromOffset(x, y)
		menu.Visible = true
	end

	for s, slot in slots do
		slot.frame.Activated:Connect(function()
			if items[s] then
				openMenu(s)
			else
				closeMenu()
			end
		end)
	end

	local function refresh()
		local raw = player:GetAttribute("Inv")
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw or "[]")
		table.clear(items)
		if ok and type(list) == "table" then
			for _, it in list do
				items[it.s] = { id = it.id, n = it.n }
			end
		end
		local used = 0
		for s, slot in slots do
			local it = items[s]
			local id = it and it.id
			if id then
				used += 1
			end
			if slot.id ~= id then
				if slot.icon then
					slot.icon:Destroy()
					slot.icon = nil
				end
				slot.id = id
				if id then
					slot.icon = Bag.icon(id, slot.frame)
					-- a little pop when something new lands in the bag
					local vp = slot.icon :: ViewportFrame?
					if vp then
						vp.Size = UDim2.fromScale(0.5, 0.5)
						vp.Position = UDim2.fromScale(0.25, 0.25)
						TweenService:Create(vp, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
							{ Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }):Play()
					end
				end
			end
			local def = id and Items.def(id)
			slot.count.Text = (def and def.stack) and Items.short(it.n) or ""
		end
		button.RichText = true
		if button:GetAttribute("Compact") then
			button.Text = string.format("🎒<br/><font size=\"12\" color=\"#ffdc5a\">%d/%d</font>", used, Items.SLOTS)
		else
			button.Text = string.format("🎒 Bag  <font size=\"15\" color=\"#ffdc5a\">%d/%d</font>", used, Items.SLOTS)
		end
		if menu.Visible then
			closeMenu()
		end
	end
	player:GetAttributeChangedSignal("Inv"):Connect(refresh)
	button:GetAttributeChangedSignal("Compact"):Connect(refresh)
	refresh()

	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		closeMenu()
	end)

	return { panel = panel, button = button, scale = scale }
end

return Bag
