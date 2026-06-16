local RSGCore = exports['rsg-core']:GetCoreObject()
BathingSessions = {}

RegisterServerEvent('rsg-bathing:server:canEnterBath')
AddEventHandler('rsg-bathing:server:canEnterBath', function(town)
    local src = source
    if not Config.BathingZones[town] then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local currentMoney = Player.PlayerData.money['cash']

    if not BathingSessions[town] then
        if currentMoney >= Config.NormalBathPrice then
            Player.Functions.RemoveMoney('cash', Config.NormalBathPrice)
            BathingSessions[town] = src
            TriggerClientEvent('rsg-bathing:client:ToggleInvincibility', src, true)
            TriggerClientEvent('rsg-bathing:client:StartBath', src, town)
        else
            TriggerClientEvent('ox_lib:notify', src, { title = locale('notify_not_enough_money'), type = 'error', duration = 5000 })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, { title = locale('notify_occupied'), type = 'error', duration = 5000 })
    end
end)

RegisterServerEvent('rsg-bathing:server:canEnterDeluxeBath')
AddEventHandler('rsg-bathing:server:canEnterDeluxeBath', function(town)
    local src = source
    if not Config.BathingZones[town] then return end
    if BathingSessions[town] == src then

        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        local currentMoney = Player.PlayerData.money['cash']

        if currentMoney >= Config.DeluxeBathPrice then
            Player.Functions.RemoveMoney('cash', Config.DeluxeBathPrice)
            TriggerClientEvent('rsg-bathing:client:StartDeluxeBath', src, town)
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
        TriggerClientEvent('rsg-bathing:client:ToggleInvincibility', source, false)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for town, player in pairs(BathingSessions) do
        if player == src then
            BathingSessions[town] = nil
        end
    end
end)

RegisterServerEvent('rsg-bathing:server:undressPlayer')
AddEventHandler('rsg-bathing:server:undressPlayer', function()
    exports['rsg-wardrobe']:RemovePlayerClothing(source)
end)

RegisterServerEvent('rsg-bathing:server:dressPlayer')
AddEventHandler('rsg-bathing:server:dressPlayer', function()
    exports['rsg-wardrobe']:DressPlayer(source)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for town, player in pairs(BathingSessions) do
            TriggerClientEvent('rsg-bathing:client:ToggleInvincibility', player, false)
        end
        BathingSessions = {}
    end
end)