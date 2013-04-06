--Login_msg - {msgID = "login", hasPlayer = false}        response
--Player_join - {msgID = "Player_join"}                      response
--Player_left - {msgID = "Player_left"}                      response
--Game_ready - {msgID = "Game_ready"}                  request
--Player_ready - {msgID = "Player_ready, status = false, playerSelf = false} response
--Game_start - {msgID = "Game_start"}                     response
require("socket")
require("json")

NetGate = {gateServer = socket.tcp(), CtlCmdEnum = {CONNECT = 1, SEND = 2, CLOSE = 3}}
function NetGate:WaitPeer(bindAddr, bindPort)
	assert(self.gatePeer == nil)
	local ret, errmsg = self.gateServer:bind(bindAddr, bindPort)
	if errmsg then
		error(errmsg)
	end
	local ret, errmsg = self.gateServer:listen(1)
	if errmsg then
		error(errmsg)
	end
	local gatePeer, errmsg = self.gateServer:accept()
	if errmsg then
		error(errmsg)
	end
	self.gatePeer = gatePeer
end
function NetGate:Recv()
	assert(self.gatePeer ~= nil)
	local rsl, wsl, errmsg = socket.select({self.gatePeer}, nil, 0.001)
	if errmsg and errmsg ~= "timeout" then
		error(errmsg)
	end
	if not errmsg then
		local line = self.gatePeer:receive()
		msg = json.decode(line)
		return msg.idx, msg.cmd, msg.line
	end
end
function NetGate:Send(jsonTable)
	assert(self.gatePeer ~= nil)
	local jsonStrLine = json.encode(jsonTable) .. "\r\n"
	local ret, errmsg = self.gatePeer:send(jsonStrLine)
	if errmsg then
		error(errmsg)
	end
end
function NetGate:SendToPlayer(playerId, jsonTable)
	local jsonTable = {idx = playerId, cmd = self.CtlCmdEnum.SEND, line = json.encode(jsonTable)}
	self:Send(jsonTable)
end
function NetGate:SendDisconnectPlayer(playerId)
	local jsonTable = {idx = playerId, cmd = self.CtlCmdEnum.CLOSE}
	self:Send(jsonTable)
end

function ItemCollection()
	local allItems = {itemCount = 0, items = {}}
	function allItems:AddItem(item)
		assert(self.items[item.id] == nil)
		self.itemCount = self.itemCount + 1
		self.items[item.id] = item
	end
	function allItems:DelItem(itemId)
		assert(self.items[itemId] ~= nil)
		self.itemCount = self.itemCount - 1
		self.items[itemId] = nil
	end
	function allItems:Tick()
		for k, v in self.items do
			v:Tick()
		end
	end
	return allItems
end

AllPlayers = ItemCollection()
AllTables = ItemCollection()

function TableItem()
	local id = table.maxn(AllTables.items) + 1
	local tableItem = {id = id}
	tableItem.players = ItemCollection()
	function tableItem:OnRecv(player, jsonTable)
		-- TODO:
	end
	AllTables:AddItem(tableItem)
	return tableItem
end

function Player(id)
	local player = {id = id}
	function player:OnRecv(jsonTable)
		print("OnRecv:" .. json.encode(jsonTable))
		if self.tableItem ~= nil then
			self.tableItem:OnRecv(self, jsonTable)
		end
		-- TODO:
	end
	function player:OnDisconnect()
		AllPlayers:DelItem(self.id)
		self.tableItem.players:DelItem(self.id)
		if self.tableItem.players.itemCount == 0 then
			AllTables:DelItem(self.tableItem.id)
		else
			for t, v in pairs(self.tableItem.players.items) do
				local jsonTable = {msgID = "Player_left"}
				v:Send(jsonTable)
			end
		end
	end
	function player:Send(jsonTable)
		NetGate:SendToPlayer(self.id, jsonTable)
	end
	function player:Disconnect()
		NetGate:SendDisconnectPlayer(self.id)
	end
	AllPlayers:AddItem(player)
	local joined = false
	local tableItem
	for t, v in pairs(AllTables.items) do
		tableItem = v
		if tableItem.players.itemCount < 2 then
			if tableItem.players.itemCount == 1 then
				local jsonTable = {msgID = "login", hasPlayer = true}
				player:Send(jsonTable)
				local jsonTable = {msgID = "Player_join"}
				for t, v in pairs(tableItem.players.items) do
					v:Send(jsonTable)
				end
			else
				assert(false)
			end
			joined = true
		end
	end
	if not joined then
		tableItem = TableItem()
		local jsonTable = {msgID = "login", hasPlayer = false}
		player:Send(jsonTable)
	end
	tableItem.players:AddItem(player)
	player.tableItem = tableItem
	return player
end

NetGate:WaitPeer("*", 54322)

while true do
	local playerId, cmd, msg = NetGate:Recv()
	local player = AllPlayers.items[playerId]
	if cmd == NetGate.CtlCmdEnum.CONNECT then
		Player(playerId)
	end
	if player ~= nil then
		if cmd == NetGate.CtlCmdEnum.SEND then
			jsonTable = json.decode(msg)
			player:OnRecv(jsonTable)
		elseif cmd == NetGate.CtlCmdEnum.CLOSE then
			player:OnDisconnect()
		else
			assert(false)
		end
	end
end
