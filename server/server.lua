local RSGCore = exports['rsg-core']:GetCoreObject()

-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function versionCheckPrint(_type, log)
    local color = _type == 'success' and '^2' or '^1'

    print(('^5['..GetCurrentResourceName()..']%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/Rexshack-RedM/rsg-bathing/main/version.txt', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        if not text then 
            versionCheckPrint('error', 'Currently unable to run a version check.')
            return 
        end

        --versionCheckPrint('success', ('Current Version: %s'):format(currentVersion))
        --versionCheckPrint('success', ('Latest Version: %s'):format(text))
        
        if text == currentVersion then
            versionCheckPrint('success', 'You are running the latest version.')
        else
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

-----------------------------------------------------------------------

BathingSessions = {}

RegisterServerEvent("rsg-bathing:server:canEnterBath")
AddEventHandler("rsg-bathing:server:canEnterBath", function(town)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local currentMoney = Player.PlayerData.money["cash"]

    if not BathingSessions[town] then
        if currentMoney >= Config.NormalBathPrice then
            Player.Functions.RemoveMoney("cash", Config.NormalBathPrice)
            BathingSessions[town] = src
            TriggerClientEvent("rsg-bathing:client:StartBath", src, town)
        else
            print("NOTIFICATION HERE")
        end
    else
        print("NOTIFICATION HERE")
    end
end)


RegisterServerEvent("rsg-bathing:server:canEnterDeluxeBath")
AddEventHandler("rsg-bathing:server:canEnterDeluxeBath", function(p1 , p2 , p3)
    local src = source
    if BathingSessions[p2] == src then

        local Player = RSGCore.Functions.GetPlayer(src)
        local currentMoney = Player.PlayerData.money["cash"]
            
        if currentMoney >= Config.DeluxeBathPrice then
            Player.Functions.RemoveMoney("cash", Config.DeluxeBathPrice)
            TriggerClientEvent("rsg-bathing:client:StartDeluxeBath", src , p1 , p2 , p3)
        else
            print("NOTIFICATION HERE")
            TriggerClientEvent("rsg-bathing:client:HideDeluxePrompt", src)
        end
    end
end)

RegisterServerEvent("rsg-bathing:server:setBathAsFree")
AddEventHandler("rsg-bathing:server:setBathAsFree", function(town)
    if BathingSessions[town] == source then
        BathingSessions[town] = nil
    end
end)

AddEventHandler('playerDropped', function()
    for town,player in pairs(BathingSessions) do
        if player == source then
            BathingSessions[town] = nil
        end
    end
end)

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()
