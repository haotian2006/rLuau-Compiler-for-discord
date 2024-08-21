-- Run in Command Bar may need to run a few times

local HttpService = game:GetService("HttpService")

local CONFIG = require(game.ServerScriptService.CONFIG)
local DISCORD_TOKEN = CONFIG.DISCORD_TOKEN
local APPLICATION_ID =   CONFIG.APPLICATION_ID
local API_BASE_URL = `https://discord.com/api/v10/applications/{APPLICATION_ID}/commands`

local function fetchCommands()
    local headers = {
        ["Authorization"] = "Bot " .. DISCORD_TOKEN
    }

    local response = HttpService:RequestAsync({
        Url = API_BASE_URL,
        Method = "GET",
        Headers = headers
    })

    if response.Success then
        return HttpService:JSONDecode(response.Body)
    else
        warn("Failed to fetch commands:", response.StatusCode, response.StatusMessage)
        return {}
    end
end

local function deleteCommand(commandId)
    local url = API_BASE_URL .. "/" .. commandId
    local headers = {
        ["Authorization"] = "Bot " .. DISCORD_TOKEN
    }

    local response = HttpService:RequestAsync({
        Url = url,
        Method = "DELETE",
        Headers = headers
    })
task.wait(2)
    if response.Success then
        print("Command deleted successfully:", commandId)
    else
        warn("Failed to delete command:", response.StatusCode, response.StatusMessage)
    end
end

local function deleteAllCommands()
    local existingCommands = fetchCommands()
    for _, command in ipairs(existingCommands) do
        deleteCommand(command.id)
    end
end

deleteAllCommands()

