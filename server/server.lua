local RSGCore = exports['rsg-core']:GetCoreObject()
BathingSessions = {}

RegisterServerEvent('rsg-bathing:server:canEnterBath')
AddEventHandler('rsg-bathing:server:canEnterBath', function(town)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local currentMoney = Player.PlayerData.money['cash']

    if not BathingSessions[town] then
        if currentMoney >= Config.NormalBathPrice then
            Player.Functions.RemoveMoney('cash', Config.NormalBathPrice)
            BathingSessions[town] = src
            TriggerClientEvent('rsg-bathing:client:StartBath', src, town)
        else
            TriggerClientEvent('ox_lib:notify', src, { title = locale('notify_not_enough_money'), type = 'error', duration = 5000 })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, { title = locale('notify_occupied'), type = 'error', duration = 5000 })
    end
end)

RegisterServerEvent('rsg-bathing:server:canEnterDeluxeBath')
AddEventHandler('rsg-bathing:server:canEnterDeluxeBath', function(animscene, town, cam)
    local src = source
    if BathingSessions[town] == src then

        local Player = RSGCore.Functions.GetPlayer(src)
        local currentMoney = Player.PlayerData.money['cash']

        if currentMoney >= Config.DeluxeBathPrice then
            Player.Functions.RemoveMoney('cash', Config.DeluxeBathPrice)
            TriggerClientEvent('rsg-bathing:client:StartDeluxeBath', src, animscene, town, cam)
        else
            TriggerClientEvent('ox_lib:notify', src, { title = locale('notify_not_enough_money'), type = 'error', duration = 5000 })
            TriggerClientEvent('rsg-bathing:client:HideDeluxePrompt', src)
        end
    end
end)

RegisterServerEvent('rsg-bathing:server:setBathAsFree')
AddEventHandler('rsg-bathing:server:setBathAsFree', function(town)
    if BathingSessions[town] == source then
        BathingSessions[town] = nil
    end
end)

AddEventHandler('playerDropped', function()
    for town, player in pairs(BathingSessions) do
        if player == source then
            BathingSessions[town] = nil
        end
    end
end)