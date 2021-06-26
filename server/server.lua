ESX = nil
isEnableMatch = true
isMatchStart = false
Deathmatch = {
    BlueTeam = {
        name = "Blue Team",
        player_list = {},
        score = 0
    },
    RedTeam = {
        name = "Red Team",
        player_list = {},
        score = 0
    }
}
matchWin = 1

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

ESX.RegisterServerCallback('esx_teamdeathmatch:getStatus', function(source, cb)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if xPlayer ~= nil then
        cb(isEnableMatch)
    end
end)

RegisterServerEvent('esx_teamdeathmatch:toggleTeamdeathmatch')
AddEventHandler('esx_teamdeathmatch:toggleTeamdeathmatch', function() 
    if isEnableMatch then
        isEnableMatch = false
    else
        isEnableMatch = true
    end
    TriggerClientEvent('esx_teamdeathmatch:toggleTeamdeathmatch', -1, isEnableMatch)
end)

RegisterServerEvent('esx_teamdeathmatch:joinTeam')
AddEventHandler('esx_teamdeathmatch:joinTeam', function(team_name)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer ~= nil then
        if not isMatchStart then
            local _len = tablelength(Deathmatch[team_name])
            if _len < 5 then
                Deathmatch[team_name].player_list[_source] = {
                    isDead = false,
                    ready = false,
                    name = GetPlayerName(_source),
                    kill = 0,
                    ckill = 0,
                    death = 0
                }
                TriggerClientEvent('esx_teamdeathmatch:joinedMatch', _source, team_name, Deathmatch)
                updateUI()
				checkReady(xPlayer)
            end
        else
			xPlayer.showNotification("The match is going on. You ~r~cannot~s~ participate!")
        end
    end
end)

RegisterServerEvent('esx_teamdeathmatch:iamDead')
AddEventHandler('esx_teamdeathmatch:iamDead', function(team_name, alldeaths) 
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer ~= nil then
        Deathmatch[team_name].player_list[_source].isDead = true
        Deathmatch[team_name].player_list[_source].death = Deathmatch[team_name].player_list[_source].death + 1
        checkMatch(team_name)
        updateUI()

		MySQL.Async.execute("UPDATE deathmatch_score SET deaths = @deaths WHERE identifier = @identifier", { 
			['@identifier'] = xPlayer.getIdentifier(),
			['@deaths'] = (alldeaths + Deathmatch[team_name].player_list[_source].death)
		})

		TriggerClientEvent('esx_xp:Remove', _source, 100)
    end
end)

RegisterServerEvent('esx_teamdeathmatch:iKilled')
AddEventHandler('esx_teamdeathmatch:iKilled', function(team_name, allkills, kd) 
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer ~= nil then
        Deathmatch[team_name].player_list[_source].kill = Deathmatch[team_name].player_list[_source].kill + 1
        Deathmatch[team_name].player_list[_source].ckill = Deathmatch[team_name].player_list[_source].ckill + 1
        AnountKill(_source, team_name)
        updateUI()

		MySQL.Async.execute("UPDATE deathmatch_score SET kills = @kills WHERE identifier = @identifier", { 
			['@identifier'] = xPlayer.getIdentifier(),
			['@kills'] = (allkills + Deathmatch[team_name].player_list[_source].kill)
		})
		
		MySQL.Async.execute("UPDATE deathmatch_score SET kd = @kd WHERE identifier = @identifier", { 
			['@identifier'] = xPlayer.getIdentifier(),
			['@kd'] = kd
		})

		TriggerClientEvent('esx_xp:Add', _source, 100)
    end
end)

ESX.RegisterServerCallback('esx_teamdeathmatch:getKills',function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	local playerId = xPlayer.source
	MySQL.Async.fetchAll('SELECT * FROM deathmatch_score WHERE identifier = @identifier', {['@identifier'] = xPlayer.getIdentifier()}, function(data)
		if next(data) == nil then
			MySQL.Async.execute('INSERT INTO deathmatch_score (identifier, name, kills) VALUES (@identifier, @name, @kills)', {
				['@identifier']	= xPlayer.getIdentifier(),
				['@name']		= xPlayer.getName(),
				['@kills']		= 0
			})
			cb(0)
		else
			cb(data[1].kills, data[1].deaths)
		end
	end)
end)

ESX.RegisterServerCallback('esx_teamdeathmatch:getDeaths',function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	local playerId = xPlayer.source
	MySQL.Async.fetchAll('SELECT * FROM deathmatch_score WHERE identifier = @identifier', {['@identifier'] = xPlayer.getIdentifier()}, function(data)
		if next(data) == nil then
			MySQL.Async.execute('INSERT INTO deathmatch_score (identifier, name, deaths) VALUES (@identifier, @name, @deaths)', {
				['@identifier']	= xPlayer.getIdentifier(),
				['@name']		= xPlayer.getName(),
				['@deaths']		= 0
			})
			cb(0)
		else
			cb(data[1].deaths)
		end
	end)
end)

ESX.RegisterServerCallback("esx_teamdeathmatch:leaderboard", function(source, cb)
	MySQL.Async.fetchAll('SELECT * FROM deathmatch_score ORDER BY kd DESC', {}, function(data)
		cb(data)
	end)
end)

RegisterServerEvent('esx_teamdeathmatch:playerReady')
AddEventHandler('esx_teamdeathmatch:playerReady', function(team_name)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer ~= nil then
        Deathmatch[team_name].player_list[_source].ready = true
        checkReady()
    end
end)

RegisterServerEvent('esx_teamdeathmatch:quit')
AddEventHandler('esx_teamdeathmatch:quit', function(team_name) 
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer ~= nil then
        if isPlayerInMatch(_source) then
            removePlayerFromMatch(_source)
            checkAllMatch()
        end
    end
end)

local countBlueTeam = 0
local countRedTeam = 0

function checkReady()
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(source)
    local _blueReady = true
    local _redReady = true
    local _cntBlue = 0
    local _cntRed = 0
    for k,v in pairs(Deathmatch["BlueTeam"].player_list) do
        if v ~= nil then
            _cntBlue = _cntBlue + 1
            if not v.ready then
                _blueReady = false
            end
        end
    end
    for k,v in pairs(Deathmatch["RedTeam"].player_list) do
        if v ~= nil then
            _cntRed = _cntRed + 1
            if not v.ready then
                _redReady = false
            end
        end
    end
	countBlueTeam = _cntBlue
	countRedTeam =  _cntRed
	if (_cntBlue == Config.TeamSize and _cntRed == Config.TeamSize) then
		isMatchStart = true
		startMatch()
	else
		xPlayer.showNotification('~r~Arena: ~b~Good Team: '.. _cntBlue.. ' ~s~| ~r~Evil Team: '.. _cntRed)
	end
end

ESX.RegisterServerCallback('esx_teamdeathmatch:isMatchStart',function(source, cb)
	cb(isMatchStart)
end)

ESX.RegisterServerCallback('esx_teamdeathmatch:teamCount',function(source, cb)
	cb(countBlueTeam, countRedTeam)
end)

function startMatch()
    for k,v in pairs(Deathmatch["BlueTeam"].player_list) do
        TriggerClientEvent('esx_teamdeathmatch:startMatch', k)
    end
    for k,v in pairs(Deathmatch["RedTeam"].player_list) do
        TriggerClientEvent('esx_teamdeathmatch:startMatch', k)
    end
end

function updateUI()
    for k,v in pairs(Deathmatch["BlueTeam"].player_list) do
        TriggerClientEvent('esx_teamdeathmatch:updateGameUI', k, Deathmatch)
    end
    for k,v in pairs(Deathmatch["RedTeam"].player_list) do
        TriggerClientEvent('esx_teamdeathmatch:updateGameUI', k, Deathmatch)
    end
end

function checkMatch(team_name)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
    local cntPlayers = 0
    local cntDead = 0
    for k,v in pairs(Deathmatch[team_name].player_list) do
        if v ~= nil then
            if v.isDead then
                cntDead = cntDead + 1
            end
            cntPlayers = cntPlayers + 1
        end
    end

    if cntPlayers == cntDead then
        local winTeam = ""
        if team_name == "BlueTeam" then
            winTeam = "RedTeam"
        else
            winTeam = "BlueTeam"
        end
        Deathmatch[winTeam].score = Deathmatch[winTeam].score + 1
        if Deathmatch[winTeam].score == matchWin then
            for k,v in pairs(Deathmatch[winTeam].player_list) do
                TriggerClientEvent('esx_teamdeathmatch:matchFinished', k, Deathmatch, winTeam)
            end
            for k,v in pairs(Deathmatch[team_name].player_list) do
                TriggerClientEvent('esx_teamdeathmatch:matchFinished', k, Deathmatch, winTeam)
            end
			xPlayer.showNotification('~r~Arena: ~p~'.. Deathmatch[winTeam].name .. '~s~ won the final match!')
            SetTimeout(15000, function()
				countBlueTeam = 0
				countRedTeam = 0

                for k,v in pairs(Deathmatch[winTeam].player_list) do
                    if v.isDead then
                        Deathmatch[winTeam].player_list[k].isDead = false
                        TriggerClientEvent('esx_ambulancejob:revive', k)
                    end
                    SetTimeout(1500, function() 
                        TriggerClientEvent('esx_teamdeathmatch:endMatch', k, winTeam, winTeam)
                    end)
					if v.isDead then
                        Deathmatch[winTeam].player_list[k].isDead = false
                        TriggerClientEvent('esx_ambulancejob:revive', k)
                    end
                end
                for k,v in pairs(Deathmatch[team_name].player_list) do
                    if v.isDead then
                        Deathmatch[team_name].player_list[k].isDead = false
                        TriggerClientEvent('esx_ambulancejob:revive', k)
                    end
                    SetTimeout(1500, function() 
                        local _player = ESX.GetPlayerFromId(k)
                        TriggerClientEvent('esx_teamdeathmatch:endMatch', k, team_name, winTeam)
                    end)
                end
                resetMatch()
            end)
        else
            for k,v in pairs(Deathmatch[winTeam].player_list) do
                TriggerClientEvent('esx_teamdeathmatch:youWon', k, Deathmatch, winTeam)
            end

            for k,v in pairs(Deathmatch[team_name].player_list) do
                TriggerClientEvent('esx_teamdeathmatch:youLose', k, Deathmatch, winTeam)
            end

            SetTimeout(15000, function()
                for k,v in pairs(Deathmatch[winTeam].player_list) do
                    if v.isDead then
                        Deathmatch[winTeam].player_list[k].isDead = false
                        TriggerClientEvent('esx_ambulancejob:revive', k)
                    end
                    Deathmatch[winTeam].player_list[k].ckill = 0
                    SetTimeout(1000, function() 
                        TriggerClientEvent('esx_teamdeathmatch:newRound', k, winTeam)
                    end)
                end
                for k,v in pairs(Deathmatch[team_name].player_list) do
                    if v.isDead then
                        Deathmatch[team_name].player_list[k].isDead = false
                        TriggerClientEvent('esx_ambulancejob:revive', k)
                    end
                    Deathmatch[team_name].player_list[k].ckill = 0
                    SetTimeout(1000, function() 
                        TriggerClientEvent('esx_teamdeathmatch:newRound', k, team_name)
                    end)
                end
            end)
        end
    end
end

function resetMatch()
    Deathmatch = {
        BlueTeam = {
            name = "Blue Team",
            player_list = {},
            score = 0
        },
        RedTeam = {
            name = "Red Team",
            player_list = {},
            score = 0
        }
    }
    isMatchStart = false
	countBlueTeam = 0
	countRedTeam =  0
end

function checkAllMatch()
    local cntPlayers = 0
    for k,v in pairs(Deathmatch["RedTeam"].player_list) do
        if v ~= nil then
            cntPlayers = cntPlayers + 1
        end
    end
    for k,v in pairs(Deathmatch["BlueTeam"].player_list) do
        if v ~= nil then
            cntPlayers = cntPlayers + 1
        end
    end
    if cntPlayers <= 0 then
        resetMatch()
    end
end

function isPlayerInMatch(_source)
    for k,v in pairs(Deathmatch["BlueTeam"].player_list) do
        if k == _source then
            return true
        end
    end
    for k,v in pairs(Deathmatch["RedTeam"].player_list) do
        if k == _source then
            return true
        end
    end
    return false
end

function removePlayerFromMatch(_source)
    for k,v in pairs(Deathmatch["BlueTeam"].player_list) do
        if k == _source then
            Deathmatch["BlueTeam"].player_list[_source] = nil
            return true
        end
    end

    for k,v in pairs(Deathmatch["RedTeam"].player_list) do
        if k == _source then
            Deathmatch["RedTeam"].player_list[_source] = nil
            return true
        end
    end
    return false
end

function AnountKill(_source, team_name)
    local _other_team_name = "RedTeam"
    if team_name == "RedTeam" then
        _other_team_name = "BlueTeam"
    end
    local _kill = ""
    if Deathmatch[team_name].player_list[_source].ckill == 2 then
        _kill = "double"
    elseif Deathmatch[team_name].player_list[_source].ckill == 3 then
        _kill = "triple"
    elseif Deathmatch[team_name].player_list[_source].ckill == 4 then
        _kill = "quadra"
    elseif Deathmatch[team_name].player_list[_source].ckill == 5 then
        _kill = "penta"
    end
    for k,v in pairs(Deathmatch[team_name].player_list) do
        TriggerClientEvent('esx_teamdeathmatch:anountVoice', k, "allied", _kill)
    end
    for k,v in pairs(Deathmatch[_other_team_name].player_list) do
        TriggerClientEvent('esx_teamdeathmatch:anountVoice', k, "enemy", _kill)
    end
end


function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

AddEventHandler('playerDropped', function(reason)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
    if xPlayer ~= nil and isMatchStart then
        if isPlayerInMatch(_source) then
            removePlayerFromMatch(_source)
        end
	end
end)

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