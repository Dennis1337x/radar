Radar = {}
Radar.visible = false
local DRAW_POST_GUI = false
local screenWidth, screenHeight = guiGetScreenSize()

function screenScale(val)
	if screenWidth < 1920 then
		return val * screenWidth / 1920
	end
	return val
end

local width, height = screenScale(270), screenScale(270)
local screenOffset = screenScale(20)
local WORLD_SIZE = 3072
local CHUNK_SIZE = 256
local CHUNKS_COUNT = 12
local SCALE_FACTOR = 1.5
local arrowSize = 25
local playerTextureSize = 25
local blipTextureSize = 25

local radar = 
{
	x = 50,
	y = screenHeight-50 - 250,
	width  = 260,
	height = 260,
}


function getRadarCoords ()
	return radar.x, radar.y, radar.width, radar.height
end

local maskShader
local renderTarget
local maskTexture

local arrowTexture
local playerTexture

local DEFAULT_SCALE = 3
local MAX_SPEED_SCALE = 1.3

local scale = DEFAULT_SCALE
local fallbackTo2d = true
local camera
local chunkRenderSize -- Обновляется каждый кадр
local chunksTextures = {}

local font = dxCreateFont('assets/fonts/speed.ttf',12)

local players = {}
local blips = {}
local blipTextures = {}
local rAlpha, gAlpha, bAlpha = 245, 245, 245
local green = true

setTimer ( function()
	green = not green
end, 5000, 0 )
setTimer (function()
	local pos = Vector3 (localPlayer.position)
	position1 = getZoneName(pos, true)
	position2 = getZoneName(pos)
end, 1000, 0)


local function drawRadarChunk(x, y, chunkX, chunkY)
	local chunkID = chunkX + chunkY * CHUNKS_COUNT
	if chunkID < 0 or chunkID > 143 or chunkX >= CHUNKS_COUNT or chunkY >= CHUNKS_COUNT or chunkX < 0 or chunkY < 0 then
		return
	end

	local posX, posY = ((x - (chunkX) * CHUNK_SIZE) / CHUNK_SIZE) * chunkRenderSize,
				       ((y - (chunkY) * CHUNK_SIZE) / CHUNK_SIZE) * chunkRenderSize
	dxDrawImage(width / 2 - posX, width / 2 - posY, chunkRenderSize, chunkRenderSize, chunksTextures[chunkID])
end

local function drawRadarSection(x, y)
	local chunkX = math.floor(x / CHUNK_SIZE)
	local chunkY = math.floor(y / CHUNK_SIZE)

	drawRadarChunk(x, y, chunkX - 1, chunkY)
	drawRadarChunk(x, y, chunkX, chunkY)
	drawRadarChunk(x, y, chunkX + 1, chunkY)

	drawRadarChunk(x, y, chunkX - 1, chunkY - 1)
	drawRadarChunk(x, y, chunkX, chunkY - 1)
	drawRadarChunk(x, y, chunkX + 1, chunkY - 1)

	drawRadarChunk(x, y, chunkX - 1, chunkY + 1)
	drawRadarChunk(x, y, chunkX, chunkY + 1)
	drawRadarChunk(x, y, chunkX + 1, chunkY + 1)
end

local function drawBlips()
	local px, py, pz = getElementPosition(localPlayer)
	for i,blip in ipairs(getElementsByType("blip")) do
		local x, y, z = getElementPosition(blip)
		if getDistanceBetweenPoints2D(x, y, px, py) < 100 then
			Radar.drawImageOnMap(
				x, y, camera.rotation.z,
				"assets/textures/radar/icons/"..blip.icon..".png",
				blipTextureSize,
				blipTextureSize
			)
		end
	end
end

local function drawPlayers()
	for player in pairs(players) do
		if player ~= localPlayer and player.streamedIn then

			local color = tocolor(255, 255, 255, 255)
			Radar.drawImageOnMap(player.position.x, player.position.y, player.rotation.z,
				playerTexture, playerTextureSize, playerTextureSize, color)
		end
	end
end

local function drawRadar()
	local x = (localPlayer.position.x + 3000) / 6000 * WORLD_SIZE
	local y = (-localPlayer.position.y + 3000) / 6000 * WORLD_SIZE

	local sectionX = x
	local sectionY = y
	drawRadarSection(sectionX, sectionY)
	drawPlayers()
	local color = tocolor(255, 255, 255)

	-- Пример использования:
	-- Radar.drawImageOnMap(700, 900, 0, arrowTexture,
		-- arrowSize, arrowSize,
		-- tocolor(16, 160, 207))

	dxDrawImage(
		(width - arrowSize) / 2,
		(height - arrowSize) / 2,
		arrowSize,
		arrowSize,
		arrowTexture,
		-localPlayer.rotation.z,
		0,
		0,
		color
	)

	drawBlips()
end

addEventHandler("onClientRender", root, function ()
	if not getElementData(localPlayer, "hud:closed") then
		if not Radar.visible then
			return
		end
		if getElementData(localPlayer, 'stickerGarage') == true then return end

		scale = DEFAULT_SCALE
		-- Отдаление радара при быстрой езде
		if localPlayer.vehicle then
			local speed = localPlayer.vehicle.velocity.length
			scale = scale - math.min(MAX_SPEED_SCALE, speed * 2)
		end
		chunkRenderSize = CHUNK_SIZE * scale / SCALE_FACTOR

		if not fallbackTo2d then
			-- Отрисовка радара в renderTarget
			dxSetRenderTarget(renderTarget, true)
			drawRadar()
			dxSetRenderTarget()

			-- Следование за игроком
			maskShader:setValue("gUVRotAngle", -math.rad(camera.rotation.z))
			maskShader:setValue("gUVPosition", 0, 0)
			maskShader:setValue("gUVScale", 1.3, 1.3)
			maskShader:setValue("sPicTexture", renderTarget)
			maskShader:setValue("sMaskTexture", maskTexture)

			if green == true then
				rAlpha, gAlpha, bAlpha = rAlpha - 2.07, gAlpha - 0.45, bAlpha - 0.86
				if rAlpha <= 255 or gAlpha <= 255 or bAlpha <= 255 then
					rAlpha, gAlpha, bAlpha = 255, 255, 255
				end
			else
				rAlpha, gAlpha, bAlpha = rAlpha + 2.07, gAlpha + 0.45, bAlpha + 0.86
				if rAlpha >= 245 or gAlpha >= 245 or bAlpha >= 245 then
					rAlpha, gAlpha, bAlpha = 245, 245, 245
				end
			end

			dxDrawImage(
				screenOffset,
				screenHeight - height - screenOffset,
				width,
				height,
				maskShader,
				0, 0, 0,
				tocolor(255, 255, 255, 255),
				DRAW_POST_GUI
			)

			dxDrawImage(
				screenOffset,
				screenHeight - height - screenOffset,
				width,
				height,
				"assets/textures/radar/radar.png",
				0, 0, 0,
				tocolor(rAlpha, gAlpha, bAlpha, 255),
				DRAW_POST_GUI
			)
			--[[dxDrawImage(
				screenOffset+200,
				screenHeight - height - screenOffset+180,
				252,
				93,
				"assets/textures/radar/gps.png",
				0, 0, 0,
				tocolor(rAlpha, gAlpha, bAlpha, 255),
				DRAW_POST_GUI
			)
			dxDrawText(
				position2,
				screenOffset+290,
				screenHeight - height - screenOffset+215,
				screenOffset+200,
				screenHeight - height - screenOffset+180,
				tocolor(255, 255, 255, 255),
				1,
				font
			)]]--
		end
	end
end)

addEventHandler("onClientElementStreamIn", root, function()
	if source.type == "player" then
		players[source] = true
	elseif source.type == "blip" then
		blips[source] = true
	end
end)

addEventHandler("onClientElementStreamOut", root, function()
	if source.type == "player" then
		players[source] = nil
	elseif source.type == "blip" then
		blips[source] = nil
	end
end)

addEventHandler("onClientPlayerJoin", root, function()
	players[source] = true
end)

addEventHandler("onClientPlayerQuit", root, function()
	players[source] = nil
end)

--[[function createShader(name, ...)
	local element = dxCreateShader(name)
end]]

function Radar.start()
	if renderTarget then
		return false
	end
	renderTarget = dxCreateRenderTarget(width, height, true)
	maskShader = dxCreateShader("assets/mask3d.fx")
	fallbackTo2d = false
	if not (renderTarget and maskShader) then
		fallbackTo2d = true
		outputDebugString("Radar: Failed to create renderTarget or shader")
		return
	end
	maskTexture = dxCreateTexture("assets/textures/radar/mask.png")
	maskShader:setValue("gUVRotCenter", 0.5, 0.5)
	maskShader:setValue("sMaskTexture", maskTexture)
	for i = 0, 143 do
		chunksTextures[i] = dxCreateTexture("assets/textures/radar/map/radar" .. i .. ".png", "dxt5", true, "clamp")
	end
	camera = getCamera()
	arrowTexture = DxTexture("assets/textures/radar/arrow.png")
	playerTexture = DxTexture("assets/textures/radar/arrow.png")
	players = {}
	for i,v in ipairs(getElementsByType("player")) do
		if isElementStreamedIn(v) then
			players[v] = true
		end
	end
end

function Radar.setRotation(x, y, z)
	if not x or not y then
		return false
	end
	if not z then
		z = 0
	end
	if not maskShader then
		return false
	end
	dxSetShaderTransform(maskShader, x, y, z)
end

function Radar.setVisible(visible)
	Radar.visible = not not visible
end

function Radar.drawImageOnMap(globalX, globalY, rotationZ, image, imgWidth, imgHeight, color)
	if not image then
		return
	end
	if not color then
		color = tocolor(255, 255, 255)
	end
	local relativeX, relativeY = localPlayer.position.x - globalX,
								 localPlayer.position.y - globalY
	local mapX, mapY = 	relativeX / 6000 * WORLD_SIZE * scale / SCALE_FACTOR,
						relativeY / 6000 * WORLD_SIZE * scale / SCALE_FACTOR

	local distance = mapX * mapX + mapY * mapY
	-- Картинка слишком далеко от игрока, нет смысла рисовать
	if distance > chunkRenderSize * chunkRenderSize * 9 then
		return
	end
	dxDrawImage((width -  imgWidth) / 2 - mapX,
				(height - imgHeight) / 2 + mapY, imgWidth, imgHeight, image,
				 -rotationZ, 0, 0, color)
end

addEventHandler("onClientResourceStart", resourceRoot, function ()
	setPlayerHudComponentVisible("all", false)
	setPlayerHudComponentVisible ( 'crosshair', true )

	Radar.start()
	showAll()
end)

--====================================================================================================================================================================================================================--

local showPlayers
local playerBlips = {}

--====================================================================================================================================================================================================================--

addEventHandler("onClientResourceStart", resourceRoot, function()
	if fileExists("showPlayers/false") then
		showPlayers = false
	elseif fileExists("showPlayers/true") then
		showPlayers = true
	else
		showPlayers = "near"
	end
	refreshPlayerBlips()
	--[[for _, blip in ipairs(getElementsByType ("blip")) do
		table.insert (delayedBlips, blip)
	end]]
end)

--[[addEventHandler("onClientResourceStart", root, function()
	blips = {}
	for _, blip in ipairs(getElementsByType ("blip")) do
		table.insert (blips, blip)
	end
end)]]--


--====================================================================================================================================================================================================================--

function refreshPlayerBlips()
	for i, blip in pairs(playerBlips) do
		if isElement(blip) then destroyElement(blip) end
		playerBlips[i] = nil
	end
	if (showPlayers == "near") then
		for _, player in ipairs( getElementsByType("player") ) do
			local r,g,b = getPlayerNametagColor(player)
			playerBlips[player] = createBlipAttachedTo(player, 0, 2, r, g, b, 255, 0, 500)
		end
	elseif (showPlayers) then
		for _, player in ipairs( getElementsByType("player") ) do
			local r,g,b = getPlayerNametagColor(player)
			playerBlips[player] = createBlipAttachedTo(player, 0, 2, r, g, b)
		end
	else
		local r,g,b = getPlayerNametagColor(localPlayer)
		playerBlips[localPlayer] = createBlipAttachedTo(localPlayer, 0, 2, r, g, b)
	end
end

--====================================================================================================================================================================================================================--

function createBlipForPlayer(player)
	if isElement(player) then
		local r,g,b = getPlayerNametagColor(player)
		if (showPlayers == "near") then
			playerBlips[player] = createBlipAttachedTo(player, 0, 2, r, g, b, 255, 0, 500)
		elseif (showPlayers) then
			playerBlips[player] = createBlipAttachedTo(player, 0, 2, r, g, b)
		end
	end
end

--====================================================================================================================================================================================================================--

addEventHandler("onClientPlayerJoin", root, function()
	setTimer(createBlipForPlayer, 1000, 1, source)
end)

--====================================================================================================================================================================================================================--

addEventHandler("onClientPlayerQuit", root, function()
	if isElement(playerBlips[source]) then destroyElement(playerBlips[source]) end
end)

--====================================================================================================================================================================================================================--
function getRadarCoords()
	return radar.x, radar.y, radar.width, radar.height
end


-- Web Site : https://sparrow-mta.blogspot.com/

-- Facebook : https://facebook.com/sparrowgta/
-- İnstagram : https://instagram.com/sparrowmta/
-- YouTube : https://youtube.com/c/SparroWMTA/

-- Discord : https://discord.gg/DzgEcvy