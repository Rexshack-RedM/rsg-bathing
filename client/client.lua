local RSGCore = exports['rsg-core']:GetCoreObject()
BathingPed = nil
local currentAnimScene = nil
local currentCam = nil
local currentTown = nil

---@deprecated use state isBathingActive
exports('IsBathingActive', function()
    return LocalPlayer.state.isBathingActive
end)

RegisterNetEvent('rsg-bathing:client:ToggleInvincibility')
AddEventHandler('rsg-bathing:client:ToggleInvincibility', function(state)
    LocalPlayer.state.invincible = state
end)

Citizen.CreateThread(function()
    LocalPlayer.state.isBathingActive = false
    CreateBlips()
    CloseBathDoors()
    if RegisterPrompts() then
        local bath = nil

        while true do
            bath = GetClosestConsumer()
            if bath and not LocalPlayer.state.isBathingActive then
                if not PromptsEnabled then TogglePrompts({ "START_BATHING" }, true) end
                if PromptsEnabled then
                    if IsPromptCompleted("START_BATHING") then
                        currentTown = bath
                        Action("START_BATHING")
                    end
                end
            else
                if PromptsEnabled then TogglePrompts({ "START_BATHING" }, false) end
                Wait(250)
            end
            Wait(100)
        end
    end
end)

GetClosestConsumer = function()
    local playerCoords = GetEntityCoords(cache.ped)

    for townName,data in pairs(Config.BathingZones) do
        if #(playerCoords - data.consumer) < 1.0 then
            return townName
        end
    end
    return nil
end

RegisterNetEvent('rsg-bathing:client:StartBath')
AddEventHandler('rsg-bathing:client:StartBath', function(town)
    LocalPlayer.state.isBathingActive = true
    currentTown = town
    if Config.BathingZones[town] then
        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true, 0, true, true)
        Citizen.InvokeNative(0x4820A6939D7CEF28, cache.ped, true)
        HolsterPedWeapons(cache.ped, false, false, false, true)

        LoadAllStreamings()

        LoadModel(`P_CS_RAG02X`)
        local rag = CreateObject(`P_CS_RAG02X`, GetEntityCoords(cache.ped), false, false, false, false, true)
        table.insert(Config.CreatedEntries, { type = "PED", handle = rag })
        SetModelAsNoLongerNeeded(`P_CS_RAG02X`)

        SetPedCanLegIk(cache.ped, false)
        SetPedLegIkMode(cache.ped, 0)
        ClearPedTasksImmediately(cache.ped, true, true)

        currentAnimScene = Citizen.InvokeNative(0x1FCA98E33C1437B3, Config.BathingZones[town].dict, 0, "s_regular_intro", false, true)
        SetAnimSceneEntity(currentAnimScene, "ARTHUR", cache.ped, 0)
        SetAnimSceneEntity(currentAnimScene, "Door", GetEntityByDoorhash(Config.BathingZones[town].door, 0), 0)

        LoadAnimScene(currentAnimScene)
        while not Citizen.InvokeNative(0x477122B8D05E7968, currentAnimScene, 1, 0) do Wait(10) end

        TriggerMusicEvent("MG_BATHING_START")
        StartAnimScene(currentAnimScene)

        while Citizen.InvokeNative(0x3FBC3F51BF12DFBF, currentAnimScene, Citizen.ResultAsFloat()) <= 0.3 do Wait(0) end

        UndressCharacter()

        while not Citizen.InvokeNative(0xD8254CB2C586412B, currentAnimScene, true) do Wait(0) end

        currentCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", 1)
        table.insert(Config.CreatedEntries, { type = "CAM", handle = currentCam })

        N_0x69d65e89ffd72313(true, true)
        SetCamCoord(currentCam, GetFinalRenderedCamCoord(), 0.0, 0.4, 0.5)
        SetCamRot(currentCam, GetFinalRenderedCamRot(1), 1)
        SetCamFov(currentCam, GetFinalRenderedCamFov())
        RenderScriptCams(true, true, 0, true, false, 0)

        TogglePrompts({ "STOP_BATHING", "REQUEST_DELUXE_BATHING", "SCRUB" }, true)

        TriggerEvent("rsg-bathing:TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS", { cache.ped, "Script_Mini_Game_Bathing_Regular", `CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR`, `DEFAULT`, "BATHING" })
        TriggerEvent("rsg-bathing:TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS", { rag, "Script_Mini_Game_Bathing_Regular", `CLIPSET@MINI_GAMES@BATHING@REGULAR@RAG`, `DEFAULT`, "BATHING" })

        ForceEntityAiAndAnimationUpdate(rag, true);
        Citizen.InvokeNative(0x55546004A244302A, cache.ped)

        local holdTime, bathMode = 0, 1
        while DoesCamExist(currentCam) do
            while not IsTaskMoveNetworkReadyForTransition(cache.ped) do Wait(100) end

            if IsPromptEnabled("SCRUB") and bathMode == #Config.BathingModes+1 then TogglePrompts({ "SCRUB" }, false) end
            if IsControlPressed(0, `INPUT_CONTEXT_X`) and IsPromptEnabled("SCRUB") then
                if IsPromptEnabled("REQUEST_DELUXE_BATHING") then TogglePrompts({ "REQUEST_DELUXE_BATHING" }, false) end

                while GetTaskMoveNetworkState(cache.ped) ~= "Scrub_Idle" do
                    RequestTaskMoveNetworkStateTransition(cache.ped, "Scrub_Idle");
                    RequestTaskMoveNetworkStateTransition((DoesEntityExist(BathingPed) and BathingPed) or rag, "Scrub_Idle");
                    Wait(200)
                end

                while IsControlPressed(0, `INPUT_CONTEXT_X`) do
                    if IsPromptCompleted("SCRUB") then
                        ClearPedEnvDirt(cache.ped)
                        ClearPedBloodDamage(cache.ped)
                        if DoesEntityExist(BathingPed) and not Config.BathingModes[bathMode].deluxe then
                            bathMode = bathMode + 1
                        end

                        holdTime = holdTime + (Config.BathingModes[bathMode].hold_power or 0.05)

                        if GetTaskMoveNetworkState(cache.ped) ~= Config.BathingModes[bathMode].transition then
                            SetCurrentCleaniest(rag, 0.0)

                            RequestTaskMoveNetworkStateTransition(cache.ped, Config.BathingModes[bathMode].transition);
                            RequestTaskMoveNetworkStateTransition((DoesEntityExist(BathingPed) and BathingPed) or rag, Config.BathingModes[bathMode].transition);
                        end

                        SetTaskMoveNetworkSignalFloat(cache.ped, "scrub_freq", Config.BathingModes[bathMode].scrub_freq);
                        SetTaskMoveNetworkSignalFloat((DoesEntityExist(BathingPed) and BathingPed) or rag, "scrub_freq", Config.BathingModes[bathMode].scrub_freq);

                        SetCurrentCleaniest(rag, holdTime)

                        if holdTime >= 1.0 then
                            holdTime = 0.0

                            if bathMode+1 > #Config.BathingModes then

                                TogglePrompts({ "REQUEST_DELUXE_BATHING", "SCRUB" }, false)

                                ClearPedEnvDirt(cache.ped)
                                ClearPedBloodDamage(cache.ped)
                                N_0xe3144b932dfdff65(cache.ped, 0.0, -1, 1, 1)
                                ClearPedDamageDecalByZone(cache.ped, 10, "ALL")
                                Citizen.InvokeNative(0x7F5D88333EE8A86F, cache.ped, 1)

                                bathMode = #Config.BathingModes+1
                                if DoesEntityExist(BathingPed) then
                                    Wait(750) ExitPremiumBath(true)
                                end
                            else bathMode = bathMode+1 end

                            break
                        end
                    end
                    Wait(100)
                end
                while not IsTaskMoveNetworkReadyForTransition(cache.ped) do Wait(10) end

                local resetTo = (((bathMode == #Config.BathingModes+1) or DoesEntityExist(BathingPed)) and "Bathing" or "Scrub_Idle")
                while GetTaskMoveNetworkState(cache.ped) ~= resetTo do
                    SetCurrentCleaniest(rag, 1.0)

                    while GetTaskMoveNetworkState(cache.ped) ~= "Scrub_Idle" do
                        RequestTaskMoveNetworkStateTransition(cache.ped, "Scrub_Idle");
                        RequestTaskMoveNetworkStateTransition((DoesEntityExist(BathingPed) and BathingPed) or rag, "Scrub_Idle");
                        Wait(200)
                    end

                    if resetTo ~= "Scrub_Idle" and (DoesEntityExist(BathingPed) and not IsControlPressed(0, `INPUT_CONTEXT_X`) or not DoesEntityExist(BathingPed)) then
                        RequestTaskMoveNetworkStateTransition(cache.ped, "Bathing");
                        RequestTaskMoveNetworkStateTransition((DoesEntityExist(BathingPed) and BathingPed) or rag, "Bathing");
                    elseif resetTo ~= "Scrub_Idle" and DoesEntityExist(BathingPed) and IsControlPressed(0, `INPUT_CONTEXT_X`) then
                        resetTo = "Scrub_Idle"
                    end
                    Wait(500)
                end
            end

            if IsPromptCompleted("REQUEST_DELUXE_BATHING") then
                Action("REQUEST_DELUXE_BATHING")
            end

            if IsPromptCompleted("STOP_BATHING") then
                Action("STOP_BATHING")
            end
            Wait(10)
        end
    end
end)

ExitBathing = function()
    local town, cam = currentTown, currentCam
    if DoesEntityExist(BathingPed) then
        ExitPremiumBath()
        return
    end

    if currentAnimScene and Citizen.InvokeNative(0x25557E324489393C, currentAnimScene) then
        Citizen.InvokeNative(0x84EEDB2C6E650000, currentAnimScene)
    end

    local outroScene = Citizen.InvokeNative(0x1FCA98E33C1437B3, Config.BathingZones[town].dict, 0, "s_regular_outro", false, true)
    SetAnimSceneEntity(outroScene, "ARTHUR", cache.ped, 0)
    SetAnimSceneEntity(outroScene, "Door", GetEntityByDoorhash(Config.BathingZones[town].door, 0), 0)

    LoadAnimScene(outroScene)
    while not Citizen.InvokeNative(0x477122B8D05E7968, outroScene, 1, 0) do Wait(10) end
    StartAnimScene(outroScene)

    if DoesCamExist(cam) then
        RenderScriptCams(false, false, 0, true, false, 0)
        DestroyCam(cam)
        currentCam = nil
    end

    while Citizen.InvokeNative(0x3FBC3F51BF12DFBF, outroScene, Citizen.ResultAsFloat()) <= 0.35 do Wait(1) end

    while not Citizen.InvokeNative(0xD8254CB2C586412B, outroScene, true) do Wait(10) end

    if Citizen.InvokeNative(0x25557E324489393C, outroScene) then
        Citizen.InvokeNative(0x84EEDB2C6E650000, outroScene)
    end

    DressCharacter()
    UnloadAllStreamings()
    N_0x69d65e89ffd72313(false, false)
    TriggerMusicEvent("MG_BATHING_STOP")
    Citizen.InvokeNative(0x704C908E9C405136, cache.ped)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)
    TriggerEvent('hud:client:UpdateCleanliness', 100)
    TriggerServerEvent("rsg-bathing:server:setBathAsFree", town)

    SetPedCanLegIk(cache.ped, true)
    SetPedLegIkMode(cache.ped, 2)
    LocalPlayer.state.isBathingActive = false
end

RegisterNetEvent('rsg-bathing:client:StartDeluxeBath')
AddEventHandler('rsg-bathing:client:StartDeluxeBath', function(town)
    if not currentAnimScene or not Citizen.InvokeNative(0x25557E324489393C, currentAnimScene) then return end
    Citizen.InvokeNative(0x84EEDB2C6E650000, currentAnimScene)

    currentAnimScene = Citizen.InvokeNative(0x1FCA98E33C1437B3, Config.BathingZones[town].dict, 0, "s_deluxe_intro", false, true)
    SetAnimSceneEntity(currentAnimScene, "ARTHUR", cache.ped, 0)
    SetAnimSceneEntity(currentAnimScene, "Door", GetEntityByDoorhash(Config.BathingZones[town].door, 0), 0)

    local model = IsPedMale(cache.ped) and Config.BathingZones[town].lady or Config.BathingZones[town].guy
    LoadModel(model)
    BathingPed = CreatePed(model, GetEntityCoords(cache.ped)-vector3(0.0, 0.0, -5.0), 0.0, false, false, true, true)
    table.insert(Config.CreatedEntries, { type = "PED", handle = BathingPed })
    Citizen.InvokeNative(0x283978A15512B2FE, BathingPed, true)
    SetAnimSceneEntity(currentAnimScene, "Female", BathingPed, 0)
    SetModelAsNoLongerNeeded(model)

    LoadAnimScene(currentAnimScene)
    while not Citizen.InvokeNative(0x477122B8D05E7968, currentAnimScene, 1, 0) do Wait(10) end
    PlaySoundFrontend("BATHING_DOOR_KNOCK_MASTER", 0, true, 0)
    Wait(1000)
    StartAnimScene(currentAnimScene)

    RenderScriptCams(false, false, 0, true, false, 0)

    while not Citizen.InvokeNative(0xD8254CB2C586412B, currentAnimScene, true) do Wait(10) end

    if Citizen.InvokeNative(0x25557E324489393C, currentAnimScene) then
        Citizen.InvokeNative(0x84EEDB2C6E650000, currentAnimScene)
    end

    TriggerEvent("rsg-bathing:TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS", { cache.ped, "Script_Mini_Game_Bathing_Deluxe", `CLIPSET@MINI_GAMES@BATHING@DELUXE@ARTHUR`, `DEFAULT`, "BATHING" })
    TriggerEvent("rsg-bathing:TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS", { BathingPed, "Script_Mini_Game_Bathing_Deluxe", `CLIPSET@MINI_GAMES@BATHING@DELUXE@MAID`, `DEFAULT`, "BATHING" })

    TogglePrompts({ "STOP_BATHING", "SCRUB" }, true)

    RenderScriptCams(true, true, 0, true, false, 0)
end)

RegisterNetEvent('rsg-bathing:client:HideDeluxePrompt')
AddEventHandler('rsg-bathing:client:HideDeluxePrompt', function()
    TogglePrompts({ "REQUEST_DELUXE_BATHING" }, false)
    TogglePrompts({ "STOP_BATHING", "SCRUB" }, true)
end)

ExitPremiumBath = function(disableScrub)
    local town, cam = currentTown, currentCam
    local outroScene = Citizen.InvokeNative(0x1FCA98E33C1437B3, Config.BathingZones[town].dict, 0, "s_deluxe_outro", false, true)
    SetAnimSceneEntity(outroScene, "ARTHUR", cache.ped, 0)
    SetAnimSceneEntity(outroScene, "Female", BathingPed, 0)
    SetAnimSceneEntity(outroScene, "Door", Citizen.InvokeNative(0xF7424890E4A094C0, Config.BathingZones[town].door, 0), 0)

    LoadAnimScene(outroScene)
    while not Citizen.InvokeNative(0x477122B8D05E7968, outroScene, 1, 0) do Wait(10) end
    StartAnimScene(outroScene)

    RenderScriptCams(false, false, 0, true, false, 0)

    while not Citizen.InvokeNative(0xD8254CB2C586412B, outroScene, true) do Wait(10) end

    if Citizen.InvokeNative(0x25557E324489393C, outroScene) then
        Citizen.InvokeNative(0x84EEDB2C6E650000, outroScene)
    end

    TriggerEvent("rsg-bathing:TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS", { cache.ped, "Script_Mini_Game_Bathing_Regular", `CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR`, `DEFAULT`, "BATHING" })
    TriggerEvent("rsg-bathing:TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS", { BathingPed, "Script_Mini_Game_Bathing_Deluxe", `CLIPSET@MINI_GAMES@BATHING@REGULAR@MAID`, `DEFAULT`, "BATHING" })

    TogglePrompts({ "STOP_BATHING", "SCRUB" }, true)
    if IsPromptEnabled("SCRUB") and disableScrub then TogglePrompts({ "SCRUB" }, false) end

    RenderScriptCams(true, true, 0, true, false, 0)
    DeletePed(BathingPed)
    BathingPed = nil
end

LoadModel = function(model)
    while not HasModelLoaded(model) do RequestModel(model) Wait(10) end
end

LoadAllStreamings = function()
    RequestAnimDict("MINI_GAMES@BATHING@REGULAR@ARTHUR");
    RequestAnimDict("MINI_GAMES@BATHING@REGULAR@RAG");
    RequestAnimDict("MINI_GAMES@BATHING@DELUXE@ARTHUR");
    RequestAnimDict("MINI_GAMES@BATHING@DELUXE@MAID");

    RequestClipSet("CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR");
    RequestClipSet("CLIPSET@MINI_GAMES@BATHING@REGULAR@RAG");
    RequestClipSet("CLIPSET@MINI_GAMES@BATHING@DELUXE@ARTHUR");
    RequestClipSet("CLIPSET@MINI_GAMES@BATHING@DELUXE@MAID");

    Citizen.InvokeNative(0x2B6529C54D29037A, "Script_Mini_Game_Bathing_Regular");
    Citizen.InvokeNative(0x2B6529C54D29037A, "Script_Mini_Game_Bathing_Deluxe");
end

UnloadAllStreamings = function()
    RemoveAnimDict("MINI_GAMES@BATHING@REGULAR@ARTHUR");
    RemoveAnimDict("MINI_GAMES@BATHING@REGULAR@RAG");
    RemoveAnimDict("MINI_GAMES@BATHING@DELUXE@ARTHUR");
    RemoveAnimDict("MINI_GAMES@BATHING@DELUXE@MAID");

    RemoveClipSet("CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR");
    RemoveClipSet("CLIPSET@MINI_GAMES@BATHING@REGULAR@RAG");
    RemoveClipSet("CLIPSET@MINI_GAMES@BATHING@DELUXE@ARTHUR");
    RemoveClipSet("CLIPSET@MINI_GAMES@BATHING@DELUXE@MAID");

    Citizen.InvokeNative(0x57A197AD83F66BBF, "Script_Mini_Game_Bathing_Regular");
    Citizen.InvokeNative(0x57A197AD83F66BBF, "Script_Mini_Game_Bathing_Deluxe");
end

function UndressCharacter()
    SetPedAllWeaponsVisibility(cache.ped, false)
    TriggerServerEvent('rsg-bathing:server:undressPlayer')
end

DressCharacter = function()
    local currentHealth = GetEntityHealth(cache.ped)
    local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, cache.ped, Citizen.ResultAsFloat())
    local currentStamina = Citizen.InvokeNative(0x775A1CA7893AA8B5, cache.ped, Citizen.ResultAsFloat()) / maxStamina * 100
    TriggerServerEvent('rsg-bathing:server:dressPlayer')
    Wait(1000)
    Citizen.InvokeNative(0x9C720776DAA43E7E, cache.ped, 0.0)
    Citizen.InvokeNative(0x44CB6447D2571AA0, cache.ped, -1.0)
    SetPedAllWeaponsVisibility(cache.ped, true)
    SetEntityHealth(cache.ped, currentHealth)
    Citizen.InvokeNative(0xC3D4B754C0E86B9E, cache.ped, currentStamina)
end

SetCurrentCleaniest = function(rag, value)
    SetTaskMoveNetworkSignalFloat(cache.ped, "Cleanliness_Right_Arm", value);
    SetTaskMoveNetworkSignalFloat(cache.ped, "Cleanliness_Left_Arm", value);
    SetTaskMoveNetworkSignalFloat(cache.ped, "Cleanliness_Left_Leg", value);
    SetTaskMoveNetworkSignalFloat(cache.ped, "Cleanliness_Right_Leg", value);
    SetTaskMoveNetworkSignalFloat(cache.ped, "Cleanliness_Head", value);

    SetTaskMoveNetworkSignalFloat(rag, "Cleanliness_Right_Arm", value);
    SetTaskMoveNetworkSignalFloat(rag, "Cleanliness_Left_Arm", value);
    SetTaskMoveNetworkSignalFloat(rag, "Cleanliness_Left_Leg", value);
    SetTaskMoveNetworkSignalFloat(rag, "Cleanliness_Right_Leg", value);
    SetTaskMoveNetworkSignalFloat(rag, "Cleanliness_Head", value);

    if DoesEntityExist(BathingPed) then
        SetTaskMoveNetworkSignalFloat(BathingPed, "Cleanliness_Right_Arm", value);
        SetTaskMoveNetworkSignalFloat(BathingPed, "Cleanliness_Left_Arm", value);
        SetTaskMoveNetworkSignalFloat(BathingPed, "Cleanliness_Left_Leg", value);
        SetTaskMoveNetworkSignalFloat(BathingPed, "Cleanliness_Right_Leg", value);
        SetTaskMoveNetworkSignalFloat(BathingPed, "Cleanliness_Head", value);
    end
end

Action = function(name)
    TogglePrompts("ALL", false)

    if (name == "START_BATHING") then
        TriggerServerEvent("rsg-bathing:server:canEnterBath", currentTown)
    elseif (name == "REQUEST_DELUXE_BATHING") then
        TriggerServerEvent("rsg-bathing:server:canEnterDeluxeBath", currentTown)
    elseif (name == "STOP_BATHING") then
        ExitBathing()
    end
    Wait(500)
end

-- prompts
RegisterPrompts = function()
    local newTable = {}

    for i=1, #Config.Prompts do
        local prompt = Citizen.InvokeNative(0x04F97DE45A519419, Citizen.ResultAsInteger())
        Citizen.InvokeNative(0x5DD02A8318420DD7, prompt, CreateVarString(10, "LITERAL_STRING", Config.Prompts[i].label))
        Citizen.InvokeNative(0xB5352B7494A08258, prompt, Config.Prompts[i].control or 0xDFF812F9)
        Citizen.InvokeNative(0x94073D5CA3F16B7B, prompt, Config.Prompts[i].time or 1000)

        Citizen.InvokeNative(0xF7AA2696A22AD8B9, prompt)

        Citizen.InvokeNative(0x8A0FB4D03A630D21, prompt, false)
        Citizen.InvokeNative(0x71215ACCFDE075EE, prompt, false)

        table.insert(Config.CreatedEntries, { type = "PROMPT", handle = prompt })
        newTable[Config.Prompts[i].id] = prompt
    end

    Config.Prompts = newTable
    return true
end

TogglePrompts = function(data, state)
    if data == "ALL" then
        for _, prompt in pairs(Config.Prompts) do
            Citizen.InvokeNative(0x8A0FB4D03A630D21, prompt, state)
            Citizen.InvokeNative(0x71215ACCFDE075EE, prompt, state)
        end
    else
        for _, name in ipairs(data) do
            local prompt = Config.Prompts[name]
            if prompt then
                Citizen.InvokeNative(0x8A0FB4D03A630D21, prompt, state)
                Citizen.InvokeNative(0x71215ACCFDE075EE, prompt, state)
            end
        end
    end
    PromptsEnabled = state
end

IsPromptCompleted = function(name)
    if Config.Prompts[name] then
        return Citizen.InvokeNative(0xE0F65F0640EF0617, Config.Prompts[name])
    end
    return false
end

IsPromptEnabled = function(name)
    if Config.Prompts[name] then
        return PromptIsEnabled(Config.Prompts[name])
    end
    return false
end

-- blips
CreateBlips = function()
    for townName, data in pairs(Config.BathingZones) do
        Wait(10)
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 0xB04092F8, data.consumer)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, "blip_bath_house"))
        SetBlipSprite(blip, `blip_bath_house`)

        table.insert(Config.CreatedEntries, { type = "BLIP", handle = blip })
    end
end

-- doors
CloseBathDoors = function()
    for townName,data in pairs(Config.BathingZones) do
        if data.door then
            if not IsDoorRegisteredWithSystem(data.door) then
                Citizen.InvokeNative(0xD99229FE93B46286, data.door, 1, 1, 0, 0, 0, 0)
                DoorSystemSetDoorState(data.door, 1)     
            end
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        LocalPlayer.state.isBathingActive = false

        for i=1, #Config.CreatedEntries do
            local entry = Config.CreatedEntries[i]
            if entry.type == "PED" then
                if DoesEntityExist(entry.handle) then DeleteEntity(entry.handle) end
            elseif entry.type == "BLIP" then
                RemoveBlip(entry.handle)
            elseif entry.type == "PROMPT" then
                Citizen.InvokeNative(0x00EDE88D4D13CF59, entry.handle)
            elseif entry.type == "CAM" then
                if DoesCamExist(entry.handle) then RenderScriptCams(false, false, 0, false, false, false) DestroyCam(entry.handle) end
            end
        end

        Config.CreatedEntries = {}
    end
end)
