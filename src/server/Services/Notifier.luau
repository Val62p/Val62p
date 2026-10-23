--!strict
-- Notifications serveur → client (RemoteEvent `Notify`). Texte déjà rédigé côté serveur.
local Notifier = {}
Notifier.__index = Notifier

export type Payload = { kind: string, text: string, data: { [string]: any }? }

function Notifier.new(remote: any)
	return setmetatable({ remote = remote }, Notifier)
end

function Notifier:send(player: Player, kind: string, text: string, data: { [string]: any }?)
	if player.Parent == nil then
		return
	end
	self.remote:FireClient(player, { kind = kind, text = text, data = data } :: Payload)
end

return Notifier
