local Translations = {
    error = {
        var = 'text goes here',
    },
    success = {
        var = 'text goes here',
    },
    primary = {
        use_bath  = 'Use the Bath (%s$)',
        scrub  = 'Scrub ',
        service  = 'Luxury Service (%s$)',
        out  = 'Get Out',
    },
    menu = {
        var = 'text goes here',
    },
    commands = {
        var = 'text goes here',
    },
    progressbar = {
        var = 'text goes here',
    },
}


Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})