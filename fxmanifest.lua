fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-bathing'
version '1.1.4'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua',
    'client/structs.js'
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua'
}

files {
    'locales/*.json'
}

dependencies {
    'rsg-core',
    'rsg-appearance',
    'rsg-wardrobe'
}

lua54 'yes'
