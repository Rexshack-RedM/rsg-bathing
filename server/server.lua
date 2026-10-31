local RSGCore = exports['rsg-core']:GetCoreObject()

-- BathingSessions[town] = { src = playerId, deluxe = bool }
local BathingSessions = {}
-- PlayerTown[src] = town (reverse lookup, one bath per player)
local PlayerTown = {}
local lastRequest = {}
local REQUEST_COOLDOWN_MS = 1500

local function notify(src, key)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'),
        description = locale(key),
        type = 'error',
        duration = 5000
    })
end

local function onCooldown(src)
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < REQUEST_COOLDOWN_MS then return true end
    lastRequest[src] = now
    return false
end

local function isNearBath(src, town)
    local zone = Config.BathingZones[town]
    if not zone then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    -- player stands at the consumer to pay, but sits at the tub (rag) once bathing
    local coords = GetEntityCoords(ped)
    local tub = vector3(zone.rag.x, zone.rag.y, zone.rag.z)
    return math.min(#(coords - zone.consumer), #(coords - tub)) <= Config.ServerMaxDistance
end

local function freeSession(src, cleaned)
    local town = PlayerTown[src]
    if not town then return end
    local session = BathingSessions[town]
    local reward = session and (session.deluxe and Config.Rewards.deluxe or Config.Rewards.regular)
    BathingSessions[town] = nil
    PlayerTown[src] = nil
    TriggerClientEvent('rsg-bathing:client:ToggleInvincibility', src, false)

    if cleaned then
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.SetMetaData('cleanliness', 100)
            if reward and reward.clearStress then
                Player.Functions.SetMetaData('stress', 0)
                TriggerClientEvent('hud:client:UpdateStress', src, 0)
            end
        end
    end
end

RegisterNetEvent('rsg-bathing:server:canEnterBath', function(town)
    local src = source
    if type(town) ~= 'string' or not Config.BathingZones[town] then return end
    if onCooldown(src) or PlayerTown[src] then return end
    if not isNearBath(src, town) then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if BathingSessions[town] then return notify(src, 'notify_occupied') end
    if not Player.Functions.RemoveMoney('cash', Config.NormalBathPrice, 'bathhouse-bath') then
        return notify(src, 'notify_not_enough_money')
    end

    BathingSessions[town] = { src = src, deluxe = false }
    PlayerTown[src] = town
    TriggerClientEvent('rsg-bathing:client:ToggleInvincibility', src, true)
    TriggerClientEvent('rsg-bathing:client:StartBath', src, town)
end)

RegisterNetEvent('rsg-bathing:server:canEnterDeluxeBath', function()
    local src = source
    local town = PlayerTown[src]
    local session = town and BathingSessions[town]
    if not session or session.src ~= src or session.deluxe then return end
    if onCooldown(src) or not isNearBath(src, town) then
        return TriggerClientEvent('rsg-bathing:client:RestorePrompts', src)
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Player.Functions.RemoveMoney('cash', Config.DeluxeBathPrice, 'bathhouse-deluxe') then
        notify(src, 'notify_not_enough_money')
        return TriggerClientEvent('rsg-bathing:client:HideDeluxePrompt', src)
    end

    session.deluxe = true
    TriggerClientEvent('rsg-bathing:client:StartDeluxeBath', src, town)
end)

RegisterNetEvent('rsg-bathing:server:setBathAsFree', function()
    freeSession(source, true)
end)

-- clothing only changes for a player who actually has an active bath session
RegisterNetEvent('rsg-bathing:server:undressPlayer', function()
    local src = source
    if not PlayerTown[src] then return end
    exports['rsg-wardrobe']:RemovePlayerClothing(src)
end)

RegisterNetEvent('rsg-bathing:server:dressPlayer', function()
    local src = source
    if not PlayerTown[src] then return end
    exports['rsg-wardrobe']:DressPlayer(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local town = PlayerTown[src]
    if town then BathingSessions[town] = nil end
    PlayerTown[src] = nil
    lastRequest[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(PlayerTown) do
        TriggerClientEvent('rsg-bathing:client:ToggleInvincibility', src, false)
        exports['rsg-wardrobe']:DressPlayer(src)
    end
end)
