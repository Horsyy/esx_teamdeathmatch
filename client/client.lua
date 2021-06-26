ESX = nil
HasAlreadyEnteredMarker = false
LastZone = nil
CurrentAction = nil
CurrentActionMsg = nil
CurrentActionData = nil
isInMatch = false
isReady = false
currentTeam = ""
isEnableTeamDeathmatch = true
local blueTeam = 0
local redTeam = 0

local headblendData
local PreviousPed             = {}
local PreviousPedHead         = {}
local PreviousPedProps        = {}
local playerPed = GetPlayerPed(-1)
local face

local Keys = {
	["ESC"] = 322, ["BACKSPACE"] = 177, ["E"] = 38, ["ENTER"] = 18,	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173
}

TriggerEvent('chat:addSuggestion', '/quitmatch', 'Death Match quit.',{})
TriggerEvent('chat:addSuggestion', '/lb', 'Arena Leaderboard.',{})

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
	
	while not ESX.IsPlayerLoaded() do 
        Citizen.Wait(500)
	end
	
	if ESX.IsPlayerLoaded() then
		Citizen.Wait(81)
		local blip = AddBlipForCoord(Config.TeamDeathMatchBlip.x, Config.TeamDeathMatchBlip.y, Config.TeamDeathMatchBlip.z)
		SetBlipSprite(blip, 378)
		SetBlipDisplay(blip, 4)
		SetBlipScale(blip, 1.0)
		SetBlipColour(blip, 1)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString("<font face=\"ACBalooPaaji\">~r~Αρένα</font>")
		EndTextCommandSetBlipName(blip)	

		ESX.TriggerServerCallback("esx_teamdeathmatch:getStatus", function(result) 
			isEnableTeamDeathmatch = result
		end)
	end
end)

AddEventHandler('gameEventTriggered', function (name, args)
    if name == "CEventNetworkEntityDamage" and isInMatch then
        local victim = args[1]
        local attacker = args[2]
        local victimDied = args[4]
        
        if victimDied == 1 then 
            if IsEntityAPed(attacker) and IsPedAPlayer(attacker) and victim == PlayerPedId() then
				ESX.TriggerServerCallback('esx_teamdeathmatch:getDeaths', function(deaths)
					TriggerServerEvent("esx_teamdeathmatch:iamDead", currentTeam, deaths)
				end)
			end
			if IsEntityAPed(attacker) and IsPedAPlayer(attacker) and attacker == PlayerPedId() then
				ESX.TriggerServerCallback('esx_teamdeathmatch:getKills', function(kills, deaths)
					kd = (kills/deaths)
					TriggerServerEvent("esx_teamdeathmatch:iKilled", currentTeam, kills, ESX.Math.Round(kd))
				end)
            end
        end
    end

end)

AddEventHandler('esx_teamdeathmatch:hasEnterMarker', function(zone)
	CurrentAction     = 'shop_menu'
	CurrentActionMsg  = ""
	CurrentActionData = {zone = zone}
end)

AddEventHandler('esx_teamdeathmatch:hasExitedMarker', function(zone)
	CurrentAction = nil
	ESX.UI.Menu.CloseAll()
end)

-- Display markers
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)
		if isEnableTeamDeathmatch then
			local coords = GetEntityCoords(PlayerPedId())

			for k,v in pairs(Config.Deathmatch) do
				if(GetDistanceBetweenCoords(coords, v.enter_pos.x, v.enter_pos.y, v.enter_pos.z, true) < Config.DrawDistance) then
					DrawMarker(31, v.enter_pos.x, v.enter_pos.y, v.enter_pos.z+1, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.Size.x, Config.Size.y, Config.Size.z, v.color.r, v.color.g, v.color.b, 100, false, true, 2, false, false, false, false)
					ESX.Game.Utils.DrawText3D(vector3(v.enter_pos.x, v.enter_pos.y, v.enter_pos.z + 1.7), v.name, 1.5, 1)
				end
			end
		end
	end
end)

-- Enter / Exit marker events
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)
		if isEnableTeamDeathmatch then
			local coords      = GetEntityCoords(PlayerPedId())
			local isInMarker  = false
			local currentZone = nil

			for k,v in pairs(Config.Deathmatch) do
				if(GetDistanceBetweenCoords(coords, v.enter_pos.x, v.enter_pos.y, v.enter_pos.z, true) < Config.Size.x) then
					isInMarker  = true
					currentZone = k
					LastZone    = k
				end
			end
			if isInMarker and not HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = true
				TriggerEvent('esx_teamdeathmatch:hasEnterMarker', currentZone)
			end
			if not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_teamdeathmatch:hasExitedMarker', LastZone)
			end
		end
	end
end)

-- Menu Controls
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if isEnableTeamDeathmatch then
			if HasAlreadyEnteredMarker and not isInMatch then
				ESX.ShowHelpNotification("Press ~r~[~s~E~r~]~s~ ~w~to join ~p~" ..  Config.Deathmatch[CurrentActionData.zone].name)
			end

			if IsControlJustReleased(0, Keys['E']) and HasAlreadyEnteredMarker and not isInMatch then
				ESX.TriggerServerCallback('esx_teamdeathmatch:teamCount', function(blueTeam, redTeam)
					if CurrentActionData.zone == 'BlueTeam' and blueTeam < Config.TeamSize then
						JoinTeam(CurrentActionData.zone)
					elseif CurrentActionData.zone == 'RedTeam' and redTeam < Config.TeamSize then
						JoinTeam(CurrentActionData.zone)
					else
						ESX.ShowNotification("Current Teams: ~b~Good Team: ~y~" .. blueTeam .. " ~s~| ~r~Evil Team: ~y~" .. redTeam)
					end
				end)
			end
			if isInMatch then
				if IsControlJustPressed(0, 37) then
					ToggleScoreboard(true)
				end
				if IsControlJustReleased(0, 37) then
					ToggleScoreboard(false)
				end
			end
		end
	end
end)

function JoinTeam(name)
	local elements = {}

    table.insert(elements, {
		label = "Yes",
		value   = "yes"
	})
	table.insert(elements, {
		label = "No",
		value   = "no"
	})

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tpnrp_deathmatch_ask1', {
        title    = "Do you wanna join " .. Config.Deathmatch[name].name .. "?<br/>Reason: Do not bring along!",
        align    = 'left',
        elements = elements
    }, function(data, menu)
        if data.current.value == "yes" then
            TriggerServerEvent("esx_teamdeathmatch:joinTeam", name)
			SetEntityHealth(PlayerPedId(), 200)
        end

        menu.close()
    end, function(data, menu)
        menu.close()
    end)
end

function ToggleScoreboard(_val)
	SendNUIMessage({
		type = "show_game_scoreboard",
		show = _val
	})
end

RegisterCommand("quitmatch", function(source, args, rawCommand)
	local _playerPed = PlayerPedId()
	local playerPed = PlayerPedId()
	ESX.TriggerServerCallback('esx_teamdeathmatch:teamCount', function(blueTeam, redTeam)
		blueTeam = blueTeam
		redTeam = redTeam
	end)
	ESX.TriggerServerCallback('esx_teamdeathmatch:isMatchStart', function(isMatchStart)
		if not isMatchStart and isInMatch then
			ESX.Game.Teleport(_playerPed, vector3(-1662.35, -1104.08, 13.13),function() 
				TriggerServerEvent("esx_teamdeathmatch:quit", currentTeam)

				currentTeam = ""
				isInMatch = false
				isReady = false
				SendNUIMessage({
				type = "endgame"
				})
				FreezeEntityPosition(_playerPed, false)
				SetPedHairColor(playerPed, PreviousPedProps[68], PreviousPedProps[69])
				SetPedEyeColor(playerPed, PreviousPedProps[67])
				SetPedHeadBlendData(playerPed, headblendData.FirstFaceShape, headblendData.SecondFaceShape, headblendData.ThirdFaceShape, headblendData.FirstSkinTone, headblendData.SecondSkinTone, headblendData.ThirdSkinTone, 0);

				for i = 0, 12, 1 do
					SetPedComponentVariation(playerPed, PreviousPed[i].component, PreviousPed[i].drawable, PreviousPed[i].texture)
				end

				for i = 0, 12, 1 do
					SetPedHeadOverlay(playerPed, i, PreviousPedHead[i].overlayID, 1.0)
				end

				for i = 0, 7, 1 do
					ClearPedProp(playerPed, i)
				end

				for i = 0, 7, 1 do
					SetPedPropIndex(playerPed, PreviousPedProps[i].component, PreviousPedProps[i].drawable, PreviousPedProps[i].texture, true)
				end
			end)
			ESX.ShowNotification("You left the current ~r~Match~s~.")
		else
			ESX.ShowNotification("You must be in a ~r~Arena Match~s~ to execute this command.")
		end
	end)
end, false)


RegisterNetEvent("esx_teamdeathmatch:joinedMatch")
AddEventHandler("esx_teamdeathmatch:joinedMatch", function(name, game_data)
	local _playerPed = PlayerPedId()
	local playerPed = PlayerPedId()
	isInMatch = true

	ESX.Game.Teleport(_playerPed, vector3(Config.Deathmatch[name].game_start_pos.x,Config.Deathmatch[name].game_start_pos.y, Config.Deathmatch[name].game_start_pos.z),function() 
		FreezeEntityPosition(_playerPed, true)
		for i = 0, 12, 1 do
			PreviousPed[i]= {component = i, drawable = GetPedDrawableVariation(playerPed, i), texture = GetPedTextureVariation(playerPed, i)}
		end

		TriggerEvent("hbw:GetHeadBlendData", PlayerPedId(), function(data)
			headblendData = data
		end)

		local headblendData = exports.hbw:GetHeadBlendData(PlayerPedId())

		for i = 0, 12, 1 do
			PreviousPedHead[i] = {overlayID = GetPedHeadOverlayValue(playerPed, i)}
		end

		PreviousPedProps[67] = GetPedEyeColor(PlayerPedId())
		PreviousPedProps[68] = GetPedHairColor(PlayerPedId())
		PreviousPedProps[69] = GetPedHairHighlightColor(PlayerPedId())

		for i = 0, 7, 1 do
			PreviousPedProps[i] = {component = i, drawable = GetPedPropIndex(playerPed, i), texture = GetPedTextureVariation(playerPed, i)}
		end
        
		setUniform(name, playerPed)
		for i = 0, 12, 1 do
			SetPedHeadOverlay(playerPed, i, PreviousPedHead[i].overlayID, 1.0)
		end

		SetPedComponentVariation(playerPed, PreviousPed[2].component, PreviousPed[2].drawable, PreviousPed[2].texture)
		SetPedHairColor(playerPed, PreviousPedProps[68], PreviousPedProps[69])
		SetPedEyeColor(playerPed, PreviousPedProps[67])
		SetPedHeadBlendData(playerPed, headblendData.FirstFaceShape, headblendData.SecondFaceShape, headblendData.ThirdFaceShape, headblendData.FirstSkinTone, headblendData.SecondSkinTone, headblendData.ThirdSkinTone, 0)
		ESX.ShowNotification("You have participated ~p~" .. Config.Deathmatch[name].name .. "~s~! If you wanna ~r~quit~s~ the match, type ~o~/quitmatch~s~.")
		currentTeam = name
		SendNUIMessage({
			type = "show_game_ui"
		})
		SendNUIMessage({
			type = "update_game_ui",
			game_ui = reMapData(game_data)
		})
	end)
end)

RegisterNetEvent("esx_teamdeathmatch:startMatch")
AddEventHandler("esx_teamdeathmatch:startMatch", function() 
	SendNUIMessage({
		type = "match_start"
	})
	FreezeEntityPosition(PlayerPedId(), false)
end)

RegisterNetEvent("esx_teamdeathmatch:updateGameUI")
AddEventHandler("esx_teamdeathmatch:updateGameUI", function(game_data)
	SendNUIMessage({
		type = "update_game_ui",
		game_ui = reMapData(game_data)
	})
end)

RegisterNetEvent("esx_teamdeathmatch:youWon")
AddEventHandler("esx_teamdeathmatch:youWon", function(game_data, winTeam)
	SendNUIMessage({
		type = "update_game_ui_win",
		game_ui = reMapData(game_data),
		win_team = winTeam
	})
end)

RegisterNetEvent("esx_teamdeathmatch:youLose")
AddEventHandler("esx_teamdeathmatch:youLose", function(game_data, winTeam)
	
	SendNUIMessage({
		type = "update_game_ui_lose",
		game_ui = reMapData(game_data),
		win_team = winTeam
	})
end)

RegisterNetEvent("esx_teamdeathmatch:newRound")
AddEventHandler("esx_teamdeathmatch:newRound", function(team_name)
	local _playerPed = PlayerPedId()
	SendNUIMessage({
		type = "new_round"
	})
	ESX.Game.Teleport(_playerPed, vector3(Config.Deathmatch[team_name].game_start_pos.x,Config.Deathmatch[team_name].game_start_pos.y, Config.Deathmatch[team_name].game_start_pos.z),function() 
		SetEntityHealth(_playerPed, 200)
	end)
end)

RegisterNetEvent("esx_teamdeathmatch:endMatch")
AddEventHandler("esx_teamdeathmatch:endMatch", function(team_name, win_team) 
	local _playerPed = PlayerPedId()
	local playerPed = PlayerPedId()
	SetEntityHealth(PlayerPedId(), 200)
	ESX.Game.Teleport(_playerPed, vector3(Config.Deathmatch[team_name].enter_pos.x,Config.Deathmatch[team_name].enter_pos.y, Config.Deathmatch[team_name].enter_pos.z),function() 
		SetPedHairColor(playerPed, PreviousPedProps[68], PreviousPedProps[69])
		SetPedEyeColor(playerPed, PreviousPedProps[67])
		SetPedHeadBlendData(playerPed, headblendData.FirstFaceShape, headblendData.SecondFaceShape, headblendData.ThirdFaceShape, headblendData.FirstSkinTone, headblendData.SecondSkinTone, headblendData.ThirdSkinTone, 0);

		for i = 0, 12, 1 do
			SetPedComponentVariation(playerPed, PreviousPed[i].component, PreviousPed[i].drawable, PreviousPed[i].texture)
		end

		for i = 0, 12, 1 do
			SetPedHeadOverlay(playerPed, i, PreviousPedHead[i].overlayID, 1.0)
		end

		for i = 0, 7, 1 do
			ClearPedProp(playerPed, i)
		end

		for i = 0, 7, 1 do
			SetPedPropIndex(playerPed, PreviousPedProps[i].component, PreviousPedProps[i].drawable, PreviousPedProps[i].texture, true)
		end

		ESX.ShowNotification("" .. Config.Deathmatch[win_team].name .. " ~g~won~s~!")

		currentTeam = ""
		isInMatch = false
		isReady = false
		SendNUIMessage({
			type = "endgame"
		})
	end)
end)

RegisterNetEvent("esx_teamdeathmatch:matchFinished")
AddEventHandler("esx_teamdeathmatch:matchFinished", function(game_data, win_team) 
	SendNUIMessage({
		type = "update_game_ui_win_finished",
		game_ui = reMapData(game_data),
		win_team = win_team
	})
end)

RegisterNetEvent("esx_teamdeathmatch:doToggle")
AddEventHandler("esx_teamdeathmatch:doToggle", function(enable) 
	TriggerServerEvent("esx_teamdeathmatch:toggleTeamdeathmatch")
end)

RegisterNetEvent("esx_teamdeathmatch:toggleTeamdeathmatch")
AddEventHandler("esx_teamdeathmatch:toggleTeamdeathmatch", function(enable) 
	isEnableTeamDeathmatch = enable
end)

RegisterNetEvent("esx_teamdeathmatch:anountVoice")
AddEventHandler("esx_teamdeathmatch:anountVoice", function(_type, _kill) 
	SendNUIMessage({
		type = "voice_anount",
		team = _type,
		kill = _kill
	})
end)

RegisterCommand("lb", function(source, args, rawCommand)
	leaderboard()
end, false)

function leaderboard()
	local players = {}
	local elements = {}
	ESX.TriggerServerCallback("esx_teamdeathmatch:leaderboard", function(data) players = data end)
	Citizen.Wait(250)
	for k,v in pairs(players) do
		table.insert(elements, {label = '<span style="color: green;">' .. v.name .. '</span> - Kills: ' .. v.kills .. ' | Deaths: ' .. v.deaths .. ' | KD: ' .. v.kd .. '.0'})
	end
	ESX.UI.Menu.Open('leader', GetCurrentResourceName(), "esx_teamdeathmatch",
		{
			title    = 'Arena Leaderboard',
			align    = "center",
			elements = elements
		},
	function(data, menu)
	end, function(data, menu)
		menu.close()
	end)
end

function reMapData(game_data)
	local cntRed = 0
	local _redList = game_data["RedTeam"].player_list
	game_data["RedTeam"].player_list = {}
	for k,v in pairs(_redList) do
		cntRed = cntRed + 1
		game_data["RedTeam"].player_list[cntRed] = v
	end

	local cntBlue = 0
	local _blueList = game_data["BlueTeam"].player_list
	game_data["BlueTeam"].player_list = {}
	for k,v in pairs(_blueList) do
		cntBlue = cntBlue + 1
		game_data["BlueTeam"].player_list[cntBlue] = v
	end
	return game_data
end

function dump(o)
	if type(o) == 'table' then
	   local s = '{ '
	   for k,v in pairs(o) do
		  if type(k) ~= 'number' then k = '"'..k..'"' end
		  s = s .. '['..k..'] = ' .. dump(v) .. ','
	   end
	   return s .. '} '
	else
	   return tostring(o)
	end
end

function setUniform(name, playerPed)
	TriggerEvent('skinchanger:getSkin', function(skin)
		local uniformObject

		if skin.sex == 0 then
			uniformObject = Config.Deathmatch[name].skin.male
		else
			uniformObject = Config.Deathmatch[name].skin.male
		end

		if uniformObject then
			TriggerEvent('skinchanger:loadClothes', skin, uniformObject)
		else
			ESX.ShowNotification('No outfit found.')
		end
	end)
end