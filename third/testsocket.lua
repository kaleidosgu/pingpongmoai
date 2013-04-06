
require("socket")
s = socket.tcp()
print(s:connect("222.70.204.94 ", 54321))

local endStr = "\r\n";

json = require("json")
local sendString = json.encode( { player_name="test"} )

s:send(sendString .. endStr);

local a = s:receive()

o = json.decode(a)
table.foreach(o,print)