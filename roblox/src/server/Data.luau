-- Saves every hero: skills, combat style and the 28 inventory slots, in one DataStore key per player.
-- A save is loaded before the hero's state is handed out, holds a session lock so two servers never write
-- the same key, is saved again every few minutes, when the player leaves and when the server shuts down.
-- In Studio without API access the game runs without saving; a live server that can't load a save sends
-- the player back instead of letting them play on a blank one that would overwrite it later.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Items = require(ReplicatedStorage:WaitForChild("Shared").Items)

local Data = {}

local VERSION = 1
local LOCK_STALE = 300 -- seconds after which another server's lock counts as left over from a crash
local AUTOSAVE = 180
local CALL_LIMIT = 8 -- seconds one DataStore call may take before it counts as failed

local store: DataStore? = nil
local profiles = {} -- [Player] = profile
local offline = false
local loadedHooks = {}

export type Profile = {
	v: number,
	xp: { [string]: number },
	style: string,
	inv: { any }, -- [slot] = { id, n } or false
}

local function blank(): Profile
	local xp = {}
	for _, skill in Config.SKILLS do
		xp[skill] = Config.START_XP[skill] or 0
	end
	local inv = table.create(Items.SLOTS, false)
	for i, item in Config.START_ITEMS do
		inv[i] = { id = item.id, n = item.n }
	end
	return { v = VERSION, xp = xp, style = "accurate", inv = inv }
end

-- slots are saved as a list of { s, id, n } so empty slots never leave holes in the JSON
local function packInv(inv: { any }): { any }
	local out = {}
	for s = 1, Items.SLOTS do
		local it = inv[s]
		if it then
			table.insert(out, { s = s, id = it.id, n = it.n })
		end
	end
	return out
end

local function unpackInv(list: { any }?): { any }
	local inv = table.create(Items.SLOTS, false)
	for _, it in list or {} do
		if type(it) == "table" and type(it.s) == "number" and it.s >= 1 and it.s <= Items.SLOTS and Items.def(it.id) then
			inv[it.s] = { id = it.id, n = math.max(1, math.floor(tonumber(it.n) or 1)) }
		end
	end
	return inv
end

-- an old save gains whatever newer versions added, so nothing is lost when the game grows
local function migrate(saved: { [string]: any }): Profile
	local p = blank()
	if type(saved.xp) == "table" then
		for _, skill in Config.SKILLS do
			local v = tonumber(saved.xp[skill])
			if v then
				p.xp[skill] = math.max(v, 0)
			end
		end
	end
	if type(saved.style) == "string" then
		p.style = Config.styleById(saved.style).id
	end
	if saved.inv then
		p.inv = unpackInv(saved.inv)
	end
	return p
end

-- runs a DataStore call, giving up after CALL_LIMIT seconds so a stall never holds a save hostage
local function call(fn: () -> any): (boolean, any)
	local done = false
	local ok, result = false, "timed out"
	task.spawn(function()
		local a, b = pcall(fn)
		if not done then
			done = true
			ok, result = a, b
		end
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < CALL_LIMIT do
		task.wait(0.1)
	end
	done = true
	return ok, result
end

local function key(player: Player): string
	return "hero_" .. player.UserId
end

-- hands the profile's state to the game: attributes the server systems and the client read
local function apply(player: Player, p: Profile)
	for _, skill in Config.SKILLS do
		player:SetAttribute("XP_" .. skill, p.xp[skill] or 0)
	end
	player:SetAttribute("Style", p.style)
end

-- reads the live state back into the profile before it is written
local function collect(player: Player, p: Profile)
	for _, skill in Config.SKILLS do
		p.xp[skill] = player:GetAttribute("XP_" .. skill) or p.xp[skill]
	end
	p.style = player:GetAttribute("Style") or p.style
end

local function load(player: Player): Profile?
	if offline then
		return blank()
	end
	for attempt = 1, 5 do
		local result: Profile? = nil
		-- the last try takes the lock over: the other server's saves then see it is no longer theirs and stop
		local force = attempt == 5
		local ok, err = call(function()
			-- fwjelaa-ignore: datastore-no-pcall (call() runs this inside pcall with a time limit)
			return (store :: DataStore):UpdateAsync(key(player), function(saved)
				saved = type(saved) == "table" and saved or {}
				local lock = saved.lock
				if not force and type(lock) == "table" and lock.job ~= game.JobId and os.time() - (lock.at or 0) < LOCK_STALE then
					result = nil
					return nil -- another server still has this hero open; try again shortly
				end
				result = migrate(saved)
				local out = table.clone(saved)
				out.lock = { job = game.JobId, at = os.time() }
				return out
			end)
		end)
		if ok and result then
			return result
		end
		if not ok then
			warn(string.format("Load %d for %s failed: %s", attempt, player.Name, tostring(err)))
		end
		if not player.Parent then
			return nil
		end
		task.wait(attempt * 2)
	end
	return nil
end

local function save(player: Player, release: boolean): boolean
	local p = profiles[player]
	if not p or offline then
		return true
	end
	collect(player, p)
	local ok, err = call(function()
		-- fwjelaa-ignore: datastore-no-pcall (call() runs this inside pcall with a time limit)
		return (store :: DataStore):UpdateAsync(key(player), function(saved)
			saved = type(saved) == "table" and saved or {}
			local lock = saved.lock
			if type(lock) == "table" and lock.job ~= game.JobId and os.time() - (lock.at or 0) < LOCK_STALE then
				return nil -- another server took the hero over; never write over its newer state
			end
			return {
				v = VERSION,
				xp = p.xp,
				style = p.style,
				inv = packInv(p.inv),
				lock = (not release) and { job = game.JobId, at = os.time() } or nil,
				savedAt = os.time(),
			}
		end)
	end)
	if not ok then
		warn(string.format("Save for %s failed: %s", player.Name, tostring(err)))
	end
	return ok
end

function Data.get(player: Player): Profile?
	return profiles[player]
end

function Data.isOffline(): boolean
	return offline
end

-- runs fn(player, profile) once the player's save is loaded (at once if it already is)
function Data.onLoaded(fn: (Player, Profile) -> ())
	table.insert(loadedHooks, fn)
	for player, p in profiles do
		task.spawn(fn, player, p)
	end
end

local function onPlayer(player: Player)
	local p = load(player)
	if not player.Parent then
		return
	end
	if not p then
		if RunService:IsStudio() then
			p = blank()
		else
			player:Kick("Your save could not be loaded right now. Please rejoin in a minute.")
			return
		end
	end
	profiles[player] = p
	apply(player, p)
	player:SetAttribute("SavedAt", os.clock())
	player:SetAttribute("Loaded", true)
	for _, fn in loadedHooks do
		task.spawn(fn, player, p)
	end
end

function Data.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("EndlessRoad_Heroes")
	end)
	if ok then
		store = result
		-- Studio without API access (or an unpublished place) answers every call with an error: play on unsaved
		if RunService:IsStudio() then
			local probe = call(function()
				-- fwjelaa-ignore: datastore-no-pcall (call() runs this inside pcall with a time limit)
				return result:GetAsync("probe")
			end)
			offline = not probe
		end
	else
		offline = true
	end
	if offline then
		warn("Endless Road: DataStores are not reachable here, progress is not saved this session")
	end
	workspace:SetAttribute("SavesOff", offline)

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			save(player, true)
			profiles[player] = nil
		end
	end)
	-- autosaves, spread out so they don't all hit the store at once
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE / math.max(1, #Players:GetPlayers()))
			local list = {}
			for player in profiles do
				table.insert(list, player)
			end
			table.sort(list, function(a, b)
				return (a:GetAttribute("SavedAt") or 0) < (b:GetAttribute("SavedAt") or 0)
			end)
			local player = list[1]
			if player and os.clock() - (player:GetAttribute("SavedAt") or 0) >= AUTOSAVE then
				player:SetAttribute("SavedAt", os.clock())
				task.spawn(save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		local left = 0
		for player in profiles do
			left += 1
			task.spawn(function()
				save(player, true)
				left -= 1
			end)
		end
		local t0 = os.clock()
		while left > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

-- the inventory is sent to the client as JSON in a player attribute
function Data.publishInv(player: Player)
	local p = profiles[player]
	if p then
		player:SetAttribute("Inv", HttpService:JSONEncode(packInv(p.inv)))
	end
end

return Data
