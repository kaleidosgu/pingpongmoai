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
function AllTables:JoinFreeChair(player)
	for t, tableItem in pairs(self.items) do
		assert(tableItem.players.itemCount < 3 and tableItem.players.itemCount > 0)
		if tableItem.players.itemCount == 1 then
			tableItem:JoinPlayer(player)
			return tableItem
		end
	end
	local tableItem = TableItem()
	tableItem:JoinPlayer(player)
	return tableItem
end

function TableItem()
	local id = table.maxn(AllTables.items) + 1
	local tableItem = {id = id}
	tableItem.players = ItemCollection()
	function tableItem:OnRecv(player, jsonTable)
		-- TODO:
	end
	function tableItem:JoinPlayer(player)
		local joined = false
		local hasOtherPlayer = false
		for i = 1, 2, 1 do
			if self.chairs[i] == nil then
				if not joined then
					self.chairs[i] = {player = player, status = 0}
					joined = true
				end
			else
				hasOtherPlayer = true
				local jsonTable = {msgID = "Player_join"}
				for t, otherPlayer in pairs(self.players.items) do
					otherPlayer:Send(jsonTable)
				end
			end
		end
		assert(joined)
		self.players:AddItem(player)
		local jsonTable = {msgID = "login", hasPlayer = hasOtherPlayer}
		player.tableItem = self
		player:Send(jsonTable)
	end
	function tableItem:LeavePlayer(playerId)
		self.players:DelItem(playerId)
		if self.players.itemCount == 0 then
			AllTables:DelItem(self.id)
		else
			for i = 1, 2, 1 do
				if self.chairs[i] ~= nil and self.chairs[i].player.id == playerId then
					self.chairs[i].player.tableItem = nil
					self.chairs[i] = nil
				end
			end
			for t, player in pairs(self.players.items) do
				local jsonTable = {msgID = "Player_left"}
				player:Send(jsonTable)
			end
		end
	end
	tableItem.chairs = {}
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
		self.tableItem:LeavePlayer(self.id)
	end
	function player:Send(jsonTable)
		NetGate:SendToPlayer(self.id, jsonTable)
	end
	function player:Disconnect()
		NetGate:SendDisconnectPlayer(self.id)
	end
	AllPlayers:AddItem(player)
	AllTables:JoinFreeChair(player)
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
