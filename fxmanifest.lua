fx_version 'adamant'

game 'gta5'

author 'Horse#0001'
description 'Team Deathmatch'
version '1.0.0'

client_scripts {
    '@es_extended/locale.lua',
	'config.lua',
	'client/client.lua'
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'@es_extended/locale.lua',
	'config.lua',
	'server/server.lua'
}

ui_page('html/index.html')

files({
    'html/*.html',
	'html/index_files/*.js',
	'html/index_files/*.css',
	'html/sounds/*.mp3'
})