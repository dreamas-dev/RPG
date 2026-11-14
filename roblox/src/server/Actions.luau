-- What each hero is busy with: fighting a monster, chopping a tree or walking over to pick something up.
-- A hero does one thing at a time, as in OSRS: starting something new ends the old one. The client is told
-- the target so it walks the hero up to it and faces it; walking off with the stick or keys ends the action.
local Actions = {}

export type Action = {
	kind: string, -- "fight", "chop", "take"
	target: Model,
	reach: number?, -- studs from the target's edge at which the hero stops walking
	stop: (() -> ())?,
	[string]: any,
}

local current: { [Player]: Action } = {}
local remotes: Folder

function Actions.init(r: Folder)
	remotes = r
	r:WaitForChild("StopFight").OnServerEvent:Connect(function(player)
		Actions.stop(player)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		Actions.stop(player)
	end)
end

function Actions.get(player: Player, kind: string?): Action?
	local a = current[player]
	if a and (kind == nil or a.kind == kind) then
		return a
	end
	return nil
end

-- every hero busy with this kind of action
function Actions.all(kind: string): { [Player]: Action }
	local out = {}
	for player, a in current do
		if a.kind == kind then
			out[player] = a
		end
	end
	return out
end

function Actions.start(player: Player, action: Action)
	local old = current[player]
	current[player] = action
	if old and old.stop then
		old.stop()
	end
	remotes.Fight:FireClient(player, action.target, action.reach)
end

-- ends the hero's action (only if it is still `only`, when given)
function Actions.stop(player: Player, only: Action?)
	local a = current[player]
	if not a or (only and a ~= only) then
		return
	end
	current[player] = nil
	if a.stop then
		a.stop()
	end
	if player.Parent then
		remotes.Fight:FireClient(player, nil)
	end
end

return Actions
