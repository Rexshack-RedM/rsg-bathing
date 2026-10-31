// TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS needs a native struct, which Lua can't build.
on('rsg-bathing:TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS', (args) => {
    const struct = new DataView(new ArrayBuffer(512));
    struct.setBigInt64(0, BigInt(args[2]), true);
    struct.setBigInt64(8, BigInt(args[3]), true);
    struct.setBigInt64(240, BigInt(CreateVarString(10, "LITERAL_STRING", args[4])), true);

    Citizen.invokeNative("0x139805C2A67C4795", args[0], args[1], struct, 1.0, 0, 0, 0);
});

// PLAY_PED_AMBIENT_SPEECH_NATIVE (0x8E04FEDD28D42462) with ScriptedSpeechParams (0x40 bytes):
// speechName, voiceName, variation, speechParamHash, listenerPed, syncOverNetwork, v7, v8
on('rsg-bathing:PLAY_SPEECH', (ped, speechName, voiceName, paramHash) => {
    const struct = new DataView(new ArrayBuffer(64));
    struct.setBigInt64(0, BigInt(CreateVarString(10, "LITERAL_STRING", speechName)), true);
    if (voiceName) struct.setBigInt64(8, BigInt(CreateVarString(10, "LITERAL_STRING", voiceName)), true);
    struct.setInt32(16, 0, true);
    struct.setInt32(24, paramHash | 0, true);
    struct.setInt32(32, 0, true);
    struct.setInt32(40, 1, true);
    struct.setInt32(48, 1, true);
    struct.setInt32(56, 1, true);

    Citizen.invokeNative("0x8E04FEDD28D42462", ped, struct);
});

// TASK_MOVE_NETWORK_ADVANCED_BY_NAME_WITH_INIT_PARAMS (0x7B6A04F98BBAFB2C): anchors the network to a world position/heading.
// Used for the rag exactly as RDR2 bathing.c does (tub origin, rot order 2, blend 3.0).
on('rsg-bathing:TASK_MOVE_NETWORK_ADVANCED', (args) => {
    const struct = new DataView(new ArrayBuffer(512));
    struct.setBigInt64(0, BigInt(args[2]), true);
    struct.setBigInt64(8, BigInt(args[3]), true);
    struct.setBigInt64(240, BigInt(CreateVarString(10, "LITERAL_STRING", args[4])), true);

    Citizen.invokeNative("0x7B6A04F98BBAFB2C", args[0], args[1], struct, args[5], args[6], args[7], 0.0, 0.0, args[8], 2, 3.0, 0, 0, 0, 0);
});
