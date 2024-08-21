-- Run in Command Bar may need to run a few times

local HttpService = game:GetService("HttpService")

local ENV = require(game.ServerScriptService.CONFIG)
local TOKEN = ENV.DISCORD_TOKEN
local ClientID = ENV.APPLICATION_ID

local url = `https://discord.com/api/v10/applications/{ClientID}/commands`


local commands = {
    {
        name = 'setalive',
        description = 'changes how long the server stays alive for',
        integration_types = {1},
        contexts = {0, 1, 2},
        type = 1,  
        options = {
            {
                name = 'time',
                description = 'time',
                type = 3, 
                required = true
            }
        }
    },
    {
        name = 'reset',
        description = 'force resets the server',
        integration_types = {1},
        contexts = {0, 1, 2},
        type = 1,
        options = {}

    },
    {
        name = 'rcompile',
        description = 'Runs rLuau code in roblox',
        integration_types = {1},
        contexts = {0, 1, 2},
        type = 1,  
        options = {
            {
                name = 'code',
                description = 'Code to run',
                type = 3, 
                required = true
            }
        }
    },
    {
        name = 'clear',
        description = 'stops all running scripts in roblox',
        integration_types = {1},
        contexts = {0, 1, 2},
        type = 1,
        options = {}

    },
    {
        name = 'alive',
        description = 'how long until the session resets',
        integration_types = {1},
        contexts = {0, 1, 2},
        type = 1,
        options = {}

    },
    {
        name = "rCompile",
        integration_types = {1},
        contexts = {0, 1, 2},
        type = 3
    },

    {
        name = 'rtasks',
        description = 'how many tasks are active in roblox',
        integration_types = {1},
        contexts = {0, 1, 2},
        type = 1,
        options = {}

    },


}




local function registerCommands()
    for _, command in ipairs(commands) do
        local data = HttpService:JSONEncode(command)
        local headers = {
            ["Authorization"] = "Bot " .. TOKEN,
            ["Content-Type"] = "application/json"
        }

        local response = HttpService:RequestAsync({
            Url = url,
            Method = "POST",
            Headers = headers,
            Body = data
        })
        task.wait(2)

        if response.Success then
            print("Registered")
        else
            warn("Failed to register command:", response.StatusCode, response.StatusMessage)
        end
    end
end

registerCommands()


