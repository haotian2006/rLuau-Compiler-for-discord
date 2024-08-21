local obj = function(value)
    return {value = value}
end

local module = {
    SERVER_RESTART = 60*19, -- 19 minutes so bot can auto afk
    DEFAULT_TIMEOUT = 15,
    MAX_STR_HEIGHT = 20,
    MAX_STR_WIDTH = 70,
    
    HOST_BOT_USERID = ""; -- Optional 
    ADMINS = {""} ,
    BLACKLIST = {""},
    DISCORD_TOKEN = "",
    APPLICATION_ID = "",
    URL = obj('http://localhost:6214'),
}

return module

