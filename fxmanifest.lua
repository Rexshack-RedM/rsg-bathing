fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-bathing'
version '1.0.4'

client_scripts {
    'client/client.lua',
    'client/structs.js'
}

server_scripts {
    'server/server.lua'
}

shared_scripts { 
    '@rsg-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

dependencies {
    'rsg-core',
    'rsg-appearance',
    'rsg-wardrobe'
}
