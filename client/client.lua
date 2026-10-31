local RSGCore = exports['rsg-core']:GetCoreObject()

local Prompts = {}          -- id -> prompt handle
local promptsEnabled = false
local blips = {}
local spawned = {}          -- entities (rag / maid) created this session
local bathingPed, currentRag = nil, nil
local currentAnimScene, currentCam, currentTown = nil, nil, nil
local hadDeluxe = false
local steamFx = nil
local foamFx = {}           -- bone -> looped ptfx handle

local PTFX_ASSET = 'scr_mg_bathing'
-- foam per scrub stage, values from RDR2 bathing.c (func_217); bones from rdr3_discoveries boneNames
local FOAM = {
    Scrub_Head      = { { 'scr_mg_bathing_foam_head', 21030, 0.4 }, { 'scr_mg_bathing_foam_torso', 14412, 0.4 } }, -- skel_head, skel_spine2
    Scrub_Left_Arm  = { { 'scr_mg_bathing_foam_forearm', 53675, 0.5 }, { 'scr_mg_bathing_foam_upperarm', 37873, 0.6 } },
    Scrub_Right_Arm = { { 'scr_mg_bathing_foam_upperarm', 46065, 0.6 }, { 'scr_mg_bathing_foam_forearm', 54187, 0.5 } },
    Scrub_Right_Leg = { { 'scr_mg_bathing_foam_upperarm', 6884, 1.5 } },   -- skel_r_thigh
    Scrub_Left_Leg  = { { 'scr_mg_bathing_foam_upperarm', 65478, 1.5 } },  -- skel_l_thigh
}

local CLEAN_SIGNALS = { 'Cleanliness_Right_Arm', 'Cleanliness_Left_Arm', 'Cleanliness_Left_Leg', 'Cleanliness_Right_Leg', 'Cleanliness_Head' }
local ANIM_DICTS = { 'MINI_GAMES@BATHING@REGULAR@ARTHUR', 'MINI_GAMES@BATHING@REGULAR@RAG', 'MINI_GAMES@BATHING@DELUXE@ARTHUR', 'MINI_GAMES@BATHING@DELUXE@MAID' }
local MOVE_NETWORKS = { 'Script_Mini_Game_Bathing_Regular', 'Script_Mini_Game_Bathing_Deluxe' }

LocalPlayer.state:set('isBathingActive', false, false)

---@deprecated use LocalPlayer.state.isBathingActive
exports('IsBathingActive', function()
    return LocalPlayer.state.isBathingActive
end)

RegisterNetEvent('rsg-bathing:client:ToggleInvincibility', function(state)
    LocalPlayer.state.invincible = state
end)

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function ped() return PlayerPedId() end

local function loadModel(model)
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function doorEntity(town)
    return GetEntityByDoorhash(Config.BathingZones[town].door, 0)
end

local function animSceneLoaded(scene) return Citizen.InvokeNative(0x477122B8D05E7968, scene, 1, 0) end
local function animSceneFinished(scene) return Citizen.InvokeNative(0xD8254CB2C586412B, scene, true) end
local function animScenePhase(scene) return Citizen.InvokeNative(0x3FBC3F51BF12DFBF, scene, Citizen.ResultAsFloat()) end

local function deleteAnimScene(scene)
    if scene and Citizen.InvokeNative(0x25557E324489393C, scene) then -- DOES_ANIM_SCENE_EXIST
        Citizen.InvokeNative(0x84EEDB2C6E650000, scene)                 -- _DELETE_ANIM_SCENE
    end
end

local function createScene(town, name, withMaid)
    local scene = Citizen.InvokeNative(0x1FCA98E33C1437B3, Config.BathingZones[town].dict, 0, name, false, true)
    SetAnimSceneEntity(scene, 'ARTHUR', ped(), 0)
    SetAnimSceneEntity(scene, 'Door', doorEntity(town), 0)
    if withMaid and bathingPed then SetAnimSceneEntity(scene, 'Female', bathingPed, 0) end
    LoadAnimScene(scene)
    while not animSceneLoaded(scene) do Wait(10) end
    return scene
end

local function startMoveNetwork(entity, network, clipset)
    TriggerEvent('rsg-bathing:TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS', { entity, network, clipset, `DEFAULT`, 'BATHING' })
end

-- rag prop: spawned and animated relative to the tub origin (Config rag = bathing.c f_60 / f_63)
local function createRag(town)
    if currentRag and DoesEntityExist(currentRag) then return currentRag end
    if not loadModel(`P_CS_RAG02X`) then return nil end
    local r = Config.BathingZones[town].rag
    currentRag = CreateObject(`P_CS_RAG02X`, r.x, r.y + 0.2, r.z + 2.0, false, false, false, false, true)
    spawned[#spawned + 1] = currentRag
    SetModelAsNoLongerNeeded(`P_CS_RAG02X`)
    TriggerEvent('rsg-bathing:TASK_MOVE_NETWORK_ADVANCED', { currentRag, 'Script_Mini_Game_Bathing_Regular', `CLIPSET@MINI_GAMES@BATHING@REGULAR@RAG`, `DEFAULT`, 'BATHING', r.x, r.y, r.z, r.w })
    ForceEntityAiAndAnimationUpdate(currentRag, true)
    return currentRag
end

local function deleteRag()
    if currentRag and DoesEntityExist(currentRag) then DeleteEntity(currentRag) end
    currentRag = nil
end

local function partner()
    return (bathingPed and DoesEntityExist(bathingPed)) and bathingPed or currentRag
end

local function transition(state)
    RequestTaskMoveNetworkStateTransition(ped(), state)
    RequestTaskMoveNetworkStateTransition(partner(), state)
end

local function setSignal(name, value)
    SetTaskMoveNetworkSignalFloat(ped(), name, value)
    SetTaskMoveNetworkSignalFloat(partner(), name, value)
end

local function setCleanliness(value)
    for _, sig in ipairs(CLEAN_SIGNALS) do
        SetTaskMoveNetworkSignalFloat(ped(), sig, value)
        if currentRag then SetTaskMoveNetworkSignalFloat(currentRag, sig, value) end
        if bathingPed and DoesEntityExist(bathingPed) then SetTaskMoveNetworkSignalFloat(bathingPed, sig, value) end
    end
end

local function fullyCleanPed(p)
    if not DoesEntityExist(p) then return end
    ClearPedEnvDirt(p)
    ClearPedBloodDamage(p)
    SetPedDirtCleaned(p, 0.0, -1, 1, 1)
    ClearPedDamageDecalByZone(p, 10, 'ALL')
    Citizen.InvokeNative(0x7F5D88333EE8A86F, p, 1) -- clear wetness
end

local function loadStreaming(load)
    for _, dict in ipairs(ANIM_DICTS) do
        if load then RequestAnimDict(dict); RequestClipSet('CLIPSET@' .. dict)
        else RemoveAnimDict(dict); RemoveClipSet('CLIPSET@' .. dict) end
    end
    for _, net in ipairs(MOVE_NETWORKS) do
        Citizen.InvokeNative(load and 0x2B6529C54D29037A or 0x57A197AD83F66BBF, net) -- request / remove move network def
    end
end

---------------------------------------------------------------------------
-- effects
---------------------------------------------------------------------------
local function loadPtfx()
    local hash = joaat(PTFX_ASSET)
    if HasNamedPtfxAssetLoaded(hash) then return true end
    RequestNamedPtfxAsset(hash)
    local timeout = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function startSteam(town)
    if not Config.Effects.steam or steamFx then return end
    if not loadPtfx() then return end
    local pos = Config.BathingZones[town].steam or Config.BathingZones[town].rag
    UseParticleFxAsset(PTFX_ASSET)
    steamFx = StartParticleFxLoopedAtCoord('scr_mg_bathing_tub_steam', pos.x, pos.y, pos.z, 90.0, 0.0, 0.0, 1.0, false, false, false, false)
end

local function startFoam(stage)
    local list = Config.Effects.foam and FOAM[stage]
    if not list or not loadPtfx() then return end
    for _, fx in ipairs(list) do
        local bone = fx[2]
        if not foamFx[bone] or not DoesParticleFxLoopedExist(foamFx[bone]) then
            UseParticleFxAsset(PTFX_ASSET)
            foamFx[bone] = StartParticleFxLoopedOnPedBone(fx[1], ped(), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, fx[3], false, false, false)
        end
    end
end

local function stopFoam()
    for bone, fx in pairs(foamFx) do
        if DoesParticleFxLoopedExist(fx) then StopParticleFxLooped(fx, false) end
        foamFx[bone] = nil
    end
end

local function stopAllFx()
    stopFoam()
    if steamFx and DoesParticleFxLoopedExist(steamFx) then StopParticleFxLooped(steamFx, false) end
    steamFx = nil
end

---------------------------------------------------------------------------
-- speech (lines from RDR2 bathing.c)
---------------------------------------------------------------------------
local function speak(speaker, line, voice, params)
    if not Config.Speech.enabled or not speaker or not DoesEntityExist(speaker) then return end
    if IsAmbientSpeechPlaying(speaker) then return end
    TriggerEvent('rsg-bathing:PLAY_SPEECH', speaker, line, voice or false, params or `SPEECH_PARAMS_FORCE_NORMAL`)
end

-- only the bathing lady has the attendant voice lines
local function maidSpeak(line)
    if not bathingPed or not currentTown then return end
    local zone = Config.BathingZones[currentTown]
    if GetEntityModel(bathingPed) ~= zone.lady or not zone.maidVoice then return end
    speak(bathingPed, line, zone.maidVoice)
end

local function playerSpeak(line)
    speak(ped(), line, nil, `SPEECH_PARAMS_FORCE_NORMAL_CRITICAL`)
end

---------------------------------------------------------------------------
-- rewards
---------------------------------------------------------------------------
local function applyRewards()
    local reward = hadDeluxe and Config.Rewards.deluxe or Config.Rewards.regular
    if not reward then return end
    local p = ped()
    if reward.refillCores then
        Citizen.InvokeNative(0xC6258F41D86676E0, p, 0, 100) -- _SET_ATTRIBUTE_CORE_VALUE health
        Citizen.InvokeNative(0xC6258F41D86676E0, p, 1, 100) -- stamina
        PlaySoundFrontend('Core_Full', 'Consumption_Sounds', true, 0)
    end
    if reward.fortify and reward.fortify > 0 then
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, p, 0, reward.fortify + 0.0, true) -- ENABLE_ATTRIBUTE_OVERPOWER health
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, p, 1, reward.fortify + 0.0, true) -- stamina
    end
end

local function destroyCam()
    if currentCam and DoesCamExist(currentCam) then
        RenderScriptCams(false, false, 0, true, false, 0)
        DestroyCam(currentCam, false)
    end
    currentCam = nil
end

local function deleteSpawned()
    for i = #spawned, 1, -1 do
        if DoesEntityExist(spawned[i]) then DeleteEntity(spawned[i]) end
        spawned[i] = nil
    end
    bathingPed, currentRag = nil, nil
end

---------------------------------------------------------------------------
-- prompts
---------------------------------------------------------------------------
local function setPrompt(prompt, state)
    PromptSetEnabled(prompt, state)
    PromptSetVisible(prompt, state)
end

local function togglePrompts(ids, state)
    if ids == 'ALL' then
        for _, prompt in pairs(Prompts) do setPrompt(prompt, state) end
    else
        for _, id in ipairs(ids) do
            if Prompts[id] then setPrompt(Prompts[id], state) end
        end
    end
    promptsEnabled = state
end

local function promptCompleted(id)
    return Prompts[id] and PromptHasHoldModeCompleted(Prompts[id]) or false
end

local function promptEnabled(id)
    return Prompts[id] and PromptIsEnabled(Prompts[id]) or false
end

local function registerPrompts()
    for _, data in ipairs(Config.Prompts) do
        local prompt = PromptRegisterBegin()
        PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', data.label))
        PromptSetControlAction(prompt, data.control or 0xDFF812F9)
        PromptSetHoldMode(prompt, data.time or 1000)
        PromptRegisterEnd(prompt)
        setPrompt(prompt, false)
        Prompts[data.id] = prompt
    end
end

---------------------------------------------------------------------------
-- clothing
---------------------------------------------------------------------------
local function undressCharacter()
    SetPedAllWeaponsVisibility(ped(), false)
    TriggerServerEvent('rsg-bathing:server:undressPlayer')
end

local function dressCharacter()
    local p = ped()
    local health = GetEntityHealth(p)
    local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, p, Citizen.ResultAsFloat())
    local stamina = Citizen.InvokeNative(0x775A1CA7893AA8B5, p, Citizen.ResultAsFloat()) / maxStamina * 100
    TriggerServerEvent('rsg-bathing:server:dressPlayer')
    Wait(1000)
    p = ped() -- wardrobe may rebuild the ped
    Citizen.InvokeNative(0x9C720776DAA43E7E, p, 0.0)
    Citizen.InvokeNative(0x44CB6447D2571AA0, p, -1.0)
    SetPedAllWeaponsVisibility(p, true)
    SetEntityHealth(p, health)
    Citizen.InvokeNative(0xC3D4B754C0E86B9E, p, stamina)
end

---------------------------------------------------------------------------
-- deluxe
---------------------------------------------------------------------------
local function exitPremiumBath(disableScrub)
    local town = currentTown
    local outro = createScene(town, 's_deluxe_outro', true)
    StartAnimScene(outro)
    maidSpeak('FAREWELL_LEVEL1')
    RenderScriptCams(false, false, 0, true, false, 0)
    while not animSceneFinished(outro) do Wait(10) end
    deleteAnimScene(outro)

    if bathingPed and DoesEntityExist(bathingPed) then DeleteEntity(bathingPed) end
    bathingPed = nil

    startMoveNetwork(ped(), 'Script_Mini_Game_Bathing_Regular', `CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR`)
    createRag(town)

    togglePrompts({ 'STOP_BATHING', 'SCRUB' }, true)
    if disableScrub then togglePrompts({ 'SCRUB' }, false) end

    RenderScriptCams(true, true, 0, true, false, 0)
end

RegisterNetEvent('rsg-bathing:client:StartDeluxeBath', function(town)
    if town ~= currentTown or not LocalPlayer.state.isBathingActive then return end
    if not currentAnimScene or not Citizen.InvokeNative(0x25557E324489393C, currentAnimScene) then return end
    deleteAnimScene(currentAnimScene)

    local zone = Config.BathingZones[town]
    local model = IsPedMale(ped()) and zone.lady or zone.guy
    if not loadModel(model) then return end
    bathingPed = CreatePed(model, GetEntityCoords(ped()) + vector3(0.0, 0.0, 5.0), 0.0, false, false, true, true)
    spawned[#spawned + 1] = bathingPed
    Citizen.InvokeNative(0x283978A15512B2FE, bathingPed, true) -- set random outfit variation
    SetModelAsNoLongerNeeded(model)

    hadDeluxe = true
    currentAnimScene = createScene(town, 's_deluxe_intro', true)
    PlaySoundFrontend('BATHING_DOOR_KNOCK_MASTER', 0, true, 0)
    maidSpeak('OFFER_SPECIAL_BATH')
    Wait(1000)
    StartAnimScene(currentAnimScene)
    while animScenePhase(currentAnimScene) <= 0.05 do Wait(0) end
    deleteRag() -- the attendant takes over scrubbing (bathing.c)
    maidSpeak('ACCEPT_SPECIAL_BATH')
    RenderScriptCams(false, false, 0, true, false, 0)

    while not animSceneFinished(currentAnimScene) do Wait(10) end
    deleteAnimScene(currentAnimScene)

    startMoveNetwork(ped(), 'Script_Mini_Game_Bathing_Deluxe', `CLIPSET@MINI_GAMES@BATHING@DELUXE@ARTHUR`)
    startMoveNetwork(bathingPed, 'Script_Mini_Game_Bathing_Deluxe', `CLIPSET@MINI_GAMES@BATHING@DELUXE@MAID`)

    togglePrompts({ 'STOP_BATHING', 'SCRUB' }, true)
    RenderScriptCams(true, true, 0, true, false, 0)
end)

RegisterNetEvent('rsg-bathing:client:RestorePrompts', function()
    if not LocalPlayer.state.isBathingActive or bathingPed then return end
    togglePrompts({ 'STOP_BATHING', 'REQUEST_DELUXE_BATHING', 'SCRUB' }, true)
end)

RegisterNetEvent('rsg-bathing:client:HideDeluxePrompt', function()
    togglePrompts({ 'REQUEST_DELUXE_BATHING' }, false)
    togglePrompts({ 'STOP_BATHING', 'SCRUB' }, true)
end)

---------------------------------------------------------------------------
-- exit
---------------------------------------------------------------------------
local function exitBathing()
    if bathingPed and DoesEntityExist(bathingPed) then
        exitPremiumBath()
        return
    end

    local town = currentTown
    deleteAnimScene(currentAnimScene)
    currentAnimScene = nil

    local outro = createScene(town, Config.BathingZones[town].outro or 's_regular_outro')
    StartAnimScene(outro)
    destroyCam()

    while animScenePhase(outro) <= 0.35 do Wait(0) end
    while not animSceneFinished(outro) do Wait(10) end
    deleteAnimScene(outro)

    stopAllFx()
    fullyCleanPed(ped())
    dressCharacter()
    applyRewards()
    hadDeluxe = false
    deleteSpawned()
    loadStreaming(false)
    RequestLetterBoxNow(false, false)
    TriggerMusicEvent('MG_BATHING_STOP')
    Citizen.InvokeNative(0x704C908E9C405136, ped())
    TriggerEvent('hud:client:UpdateCleanliness', 100)
    TriggerServerEvent('rsg-bathing:server:setBathAsFree') -- server sets cleanliness metadata

    SetPedCanLegIk(ped(), true)
    SetPedLegIkMode(ped(), 2)
    LocalPlayer.state:set('isBathingActive', false, false)
end

local function action(name)
    togglePrompts('ALL', false)
    if name == 'START_BATHING' then
        TriggerServerEvent('rsg-bathing:server:canEnterBath', currentTown)
    elseif name == 'REQUEST_DELUXE_BATHING' then
        TriggerServerEvent('rsg-bathing:server:canEnterDeluxeBath')
    elseif name == 'STOP_BATHING' then
        exitBathing()
    end
    Wait(500)
end

---------------------------------------------------------------------------
-- bath loop
---------------------------------------------------------------------------
local function waitState(state)
    while GetTaskMoveNetworkState(ped()) ~= state do
        transition(state)
        Wait(200)
    end
end

RegisterNetEvent('rsg-bathing:client:StartBath', function(town)
    local zone = Config.BathingZones[town]
    if not zone or LocalPlayer.state.isBathingActive then return end
    LocalPlayer.state:set('isBathingActive', true, false)
    currentTown = town

    local p = ped()
    SetCurrentPedWeapon(p, `WEAPON_UNARMED`, true, 0, true, true)
    Citizen.InvokeNative(0x4820A6939D7CEF28, p, true)
    HolsterPedWeapons(p, false, false, false, true)

    loadStreaming(true)

    SetPedCanLegIk(p, false)
    SetPedLegIkMode(p, 0)
    ClearPedTasksImmediately(p, true, true)

    currentAnimScene = createScene(town, 's_regular_intro')
    TriggerMusicEvent('MG_BATHING_START')
    StartAnimScene(currentAnimScene)

    while animScenePhase(currentAnimScene) <= 0.3 do Wait(0) end
    undressCharacter()
    while not animSceneFinished(currentAnimScene) do Wait(0) end

    currentCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RequestLetterBoxNow(true, true)
    SetCamCoord(currentCam, GetFinalRenderedCamCoord())
    SetCamRot(currentCam, GetFinalRenderedCamRot(1), 1)
    SetCamFov(currentCam, GetFinalRenderedCamFov())
    RenderScriptCams(true, true, 0, true, false, 0)

    togglePrompts({ 'STOP_BATHING', 'REQUEST_DELUXE_BATHING', 'SCRUB' }, true)
    startSteam(town)
    hadDeluxe = false

    startMoveNetwork(p, 'Script_Mini_Game_Bathing_Regular', `CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR`)
    createRag(town)
    Citizen.InvokeNative(0x55546004A244302A, p)

    local modes = Config.BathingModes
    local holdTime, bathMode = 0.0, 1
    local lastChat = GetGameTimer()

    while currentCam and DoesCamExist(currentCam) do
        while not IsTaskMoveNetworkReadyForTransition(ped()) do Wait(100) end

        if bathMode > #modes and promptEnabled('SCRUB') then togglePrompts({ 'SCRUB' }, false) end

        if IsControlPressed(0, `INPUT_CONTEXT_X`) and promptEnabled('SCRUB') then
            if promptEnabled('REQUEST_DELUXE_BATHING') then togglePrompts({ 'REQUEST_DELUXE_BATHING' }, false) end
            waitState('Scrub_Idle')

            while IsControlPressed(0, `INPUT_CONTEXT_X`) do
                if promptCompleted('SCRUB') then
                    fullyCleanPed(ped())
                    if bathingPed and not modes[bathMode].deluxe then bathMode = bathMode + 1 end

                    holdTime = holdTime + (modes[bathMode].hold_power or 0.05)

                    if GetTaskMoveNetworkState(ped()) ~= modes[bathMode].transition then
                        setCleanliness(0.0)
                        transition(modes[bathMode].transition)
                    end
                    setSignal('scrub_freq', modes[bathMode].scrub_freq)
                    setCleanliness(holdTime)
                    startFoam(modes[bathMode].transition)

                    if bathingPed and GetGameTimer() - lastChat > Config.Speech.chatInterval then
                        lastChat = GetGameTimer()
                        maidSpeak('CHAT_BATH_LEVEL1')
                    end

                    if holdTime >= 1.0 then
                        holdTime = 0.0
                        if bathingPed then maidSpeak('SCRUB_RESPONSE') else playerSpeak('SIGH_LOW') end
                        if bathMode + 1 > #modes then
                            togglePrompts({ 'REQUEST_DELUXE_BATHING', 'SCRUB' }, false)
                            fullyCleanPed(ped())
                            bathMode = #modes + 1
                            if bathingPed then Wait(750) exitPremiumBath(true) end
                        else
                            bathMode = bathMode + 1
                        end
                        break
                    end
                end
                Wait(100)
            end

            while not IsTaskMoveNetworkReadyForTransition(ped()) do Wait(10) end

            local resetTo = (bathMode > #modes or bathingPed) and 'Bathing' or 'Scrub_Idle'
            while GetTaskMoveNetworkState(ped()) ~= resetTo do
                setCleanliness(1.0)
                waitState('Scrub_Idle')
                if resetTo ~= 'Scrub_Idle' then
                    if bathingPed and IsControlPressed(0, `INPUT_CONTEXT_X`) then
                        resetTo = 'Scrub_Idle'
                    else
                        transition('Bathing')
                    end
                end
                Wait(500)
            end
        end

        if promptCompleted('REQUEST_DELUXE_BATHING') then action('REQUEST_DELUXE_BATHING') end
        if promptCompleted('STOP_BATHING') then action('STOP_BATHING') end
        Wait(10)
    end
end)

---------------------------------------------------------------------------
-- world setup + proximity loop
---------------------------------------------------------------------------
local function closestTub(coords)
    local nearest, nearestDist = nil, math.huge
    for town, data in pairs(Config.BathingZones) do
        local d = #(coords - data.consumer)
        if d < nearestDist then nearest, nearestDist = town, d end
    end
    return nearest, nearestDist
end

local function setupWorld()
    for _, data in pairs(Config.BathingZones) do
        if Config.ShowBlips then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 0xB04092F8, data.consumer) -- BLIP_ADD_FOR_COORDS
            SetBlipSprite(blip, `blip_bath_house`, true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', locale('blip_name'))) -- _SET_BLIP_NAME
            blips[#blips + 1] = blip
        end
        if data.door and not IsDoorRegisteredWithSystem(data.door) then
            Citizen.InvokeNative(0xD99229FE93B46286, data.door, 1, 1, 0, 0, 0, 0) -- _ADD_DOOR_TO_SYSTEM_NEW
            DoorSystemSetDoorState(data.door, 1)
        end
    end
end

CreateThread(function()
    setupWorld()
    registerPrompts()

    while true do
        local sleep = 1000
        if not LocalPlayer.state.isBathingActive then
            local town, dist = closestTub(GetEntityCoords(ped()))
            if dist < 15.0 then sleep = 250 end
            if town and dist <= Config.InteractDistance then
                sleep = 100
                if not promptsEnabled then togglePrompts({ 'START_BATHING' }, true) end
                if promptCompleted('START_BATHING') then
                    currentTown = town
                    action('START_BATHING')
                end
            elseif promptsEnabled then
                togglePrompts({ 'START_BATHING' }, false)
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isBathingActive then
        ClearPedTasksImmediately(ped(), true, true)
        RequestLetterBoxNow(false, false)
        TriggerMusicEvent('MG_BATHING_STOP')
        SetPedCanLegIk(ped(), true)
        SetPedLegIkMode(ped(), 2)
        SetPedAllWeaponsVisibility(ped(), true)
    end
    LocalPlayer.state:set('isBathingActive', false, false)
    LocalPlayer.state.invincible = false
    deleteAnimScene(currentAnimScene)
    stopAllFx()
    destroyCam()
    deleteSpawned()
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, prompt in pairs(Prompts) do PromptDelete(prompt) end
end)
