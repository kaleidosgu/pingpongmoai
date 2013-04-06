----------------------------------------------------------------
-- Copyright (c) 2010-2011 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
----------------------------------------------------------------
----------------------------------------------------------------
-- Copyright (c) 2010-2011 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
----------------------------------------------------------------

MOAISim.openWindow ( "test", 320, 480 )

viewport = MOAIViewport.new ()
viewport:setSize ( 320, 480 )
viewport:setScale ( 320, 480 )

layer = MOAILayer2D.new ()
layer:setViewport ( viewport )
MOAISim.pushRenderPass ( layer )

gfxQuad = MOAIGfxQuad2D.new ()
gfxQuad:setTexture ( "moai.png" )
gfxQuad:setRect ( -64, -64, 64, 64 )

prop = MOAIProp2D.new ()
prop:setDeck ( gfxQuad )
prop:setLoc ( 0, 80 )
layer:insertProp ( prop )

font = MOAIFont.new ()
font:loadFromTTF ( "arialbd.ttf", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.?!", 12, 163 )

textbox = MOAITextBox.new ()
textbox:setFont ( font )
textbox:setRect ( -160, -80, 160, 80 )
textbox:setLoc ( 0, -100 )
textbox:setYFlip ( true )
textbox:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
layer:insertProp ( textbox )

local IP_ADDRESS = "222.70.204.94";

textbox:setString ( "Connecting server ..." )

local texture = MOAITexture.new()
texture:load("moai.png")

local endStr = "\r\n";


require("socket")
s_connect = socket.tcp()
s_connect:connect(IP_ADDRESS, 54321)


local State_none		= 0;
local State_waiting 	= 1;
local State_ready 		= 2;
local State_GameStart	= 3;
local State_PlayerReady	= 4;
local State_SelfReady	= 5;
local State_Unknown		= 6;

local current_state 	= State_none;
function onKeyboardEvent ( key, down )

	if down == false then
		if key >= 49 then
			if current_state == State_ready then
				print("dddddddd");
				local sendString = MOAIJsonParser.encode( { msgID="Game_ready"} )

				s_connect:send(sendString .. endStr);
			end
		end
	else
	end
end

MOAIInputMgr.device.keyboard:setCallback ( onKeyboardEvent )


function changeState()
	if current_state == State_none then
		textbox:setString ( "none ..." )
	elseif current_state == State_waiting then
		textbox:setString ( "Waiting player join ..." )
	elseif current_state == State_ready then
		textbox:setString ( "Waiting players ready..." )
	elseif current_state == State_GameStart then
		textbox:setString ( "Game start ..." )
	elseif current_state == State_PlayerReady then
		textbox:setString ( "Opponent is ready ..." )
	elseif current_state == State_Unknown then
		textbox:setString ( "Unknown error ..." )
	elseif current_state == State_SelfReady then
		textbox:setString ( "You have ready ..." )
	end
end

function processNetmessage( element )
	local receiveString = s_connect:receive();
	local receiveTable = MOAIJsonParser.decode( receiveString );
	print(receiveString);
	if receiveTable.msgID == "login" then
		if receiveTable.hasPlayer == true then
			--ready state
			current_state = State_ready;
			changeState();
		else
			--waiting state
			print("dd");
			current_state = State_waiting;
			changeState();
		end
	elseif receiveTable.msgID == "Player_join" then
		--ready state
		current_state = State_ready;
		changeState();
	elseif receiveTable.msgID == "Player_ready" then
		--player ready state
		if receiveTable.playerSelf == true then
			current_state = State_SelfReady;
		else
			current_state = State_PlayerReady;
			changeState();
		end
	elseif receiveTable.msgID == "Game_start" then
		--game start
		current_state = State_GameStart;
		changeState();
	else
		--unkonw state
		current_state = State_Unknown;
		changeState();
	end
	print("over");
end

function processNetwork()
	print("xixixi");
	local pool  = { s_connect }
	rx, wr, er  = socket.select( pool, nil, 0 );
	if rx ~= nil then
		for i,element in ipairs(rx) do
			print("start connect server5");
			processNetmessage(element)
			print("start connect server5aa");
		end
	else
		print("it is nil");
	end
end

local timer = MOAITimer.new ()

timer:setSpeed ( 10 )

timer:setMode(MOAITimer.LOOP)

timer:setListener ( MOAITimer.EVENT_TIMER_LOOP,processNetwork )

timer:start()